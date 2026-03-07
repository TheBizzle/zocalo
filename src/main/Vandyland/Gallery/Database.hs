{-# LANGUAGE DataKinds                  #-}
{-# LANGUAGE DeriveAnyClass             #-}
{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE DerivingStrategies         #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GADTs                      #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE QuasiQuotes                #-}
{-# LANGUAGE StandaloneDeriving         #-}
{-# LANGUAGE TemplateHaskell            #-}
{-# LANGUAGE TypeFamilies               #-}
{-# LANGUAGE TypeOperators              #-}
{-# LANGUAGE UndecidableInstances       #-}

module Vandyland.Gallery.Database(approveSubmission, AuthActionResult(DoesNotExist, Duplicate, Expired, Incorrect, Successful, Unconfirmed), checkUserExists, confirmNewUser, forbidSubmission, isValid, logout, PrivilegedActionResult(Fulfilled, NotAuthorized, NotFound), readCommentsFor, readGalleryListings, readSessionExists, readStarterConfigFor, readSubmissionData, readSubmissionsLite, readSubmissionListings, readSubmissionListingsForModeration, readTemplateName, registerNewSession, registerNewUser, storeOTP, suppressSubmission, tokenMatchesAccountName, uniqueSessionName, validateOTP, writeComment, writeSubmission) where

import Control.Monad.Logger(NoLoggingT, runNoLoggingT)
import Control.Monad.Trans.Reader(ReaderT)
import Control.Monad.Trans.Resource(ResourceT)

import Data.List(sortBy)
import Data.Ord(comparing)
import Data.Time(addUTCTime, getCurrentTime, NominalDiffTime, UTCTime)
import Data.Time.Clock.POSIX(utcTimeToPOSIXSeconds)
import Data.UUID(UUID)

import qualified Data.Text as Text
import qualified Data.UUID as UUID

import Database.Persist((<-.), (=.), (==.), count, delete, deleteWhere, Entity(entityKey, entityVal), insert, selectFirst, selectList, SelectOpt(Asc), update, upsert)
import Database.Persist.Postgresql(runMigration, runSqlPersistMPool, SqlBackend, withPostgresqlPool)
import Database.Persist.TH(mkMigrate, mkPersist, persistLowerCase, share, sqlSettings)

import System.Random(randomIO)

import Vandyland.Common.DBCredentials(password, username)

import Vandyland.Gallery.Comment(Comment(Comment, time))
import Vandyland.Gallery.RandGen(generateName)
import Vandyland.Gallery.Submission(GalleryListing(GalleryListing), Submission(Submission), SubmissionListing(SubmissionListing))

share [mkPersist sqlSettings, mkMigrate "migrateAll"] [persistLowerCase|
GalleryDB
    galleryName     Text
    templateName    Text
    ownerName       Text
    getsPrescreened Bool
    config          Text Maybe
    description     Text
    dateAdded       UTCTime
    UniqueNames galleryName ownerName
    deriving Show
SubmissionDB
    sessionName          Text
    uploadName           Text
    base64Image          Text
    authorToken          Text Maybe
    isSuppressed         Bool
    isForbidden          Bool
    isAwaitingModeration Bool
    metadata             Text Maybe
    extraData            Text
    dateAdded            UTCTime
    Primary sessionName uploadName
    deriving Show
CommentDB
    uuid         Text
    comment      Text
    author       Text
    parent       Text Maybe
    sessionName  Text
    uploadName   Text
    time         UTCTime
    Primary uuid
    deriving Show
AuthDB
    authEmail      Text
    isConfirmed    Bool
    otp            Text Maybe
    otpExpiration  UTCTime Maybe
    authToken      Text Maybe
    tokenBirthday  UTCTime Maybe
    Primary authEmail
    deriving Show
ConfirmationDB
    confirmationAddr Text
    authHash         Text
    dateAdded        UTCTime
    Primary confirmationAddr
    deriving Show
|]

uniqueSessionName :: IO Text
uniqueSessionName = withDB $
  do
    name       <- liftIO generateName
    entryMaybe <- selectFirst [SubmissionDBSessionName ==. (Text.toLower name)] []
    case entryMaybe of
      Nothing  -> return name
      (Just _) -> liftIO uniqueSessionName

uniqueSubmissionName :: Text -> IO Text
uniqueSubmissionName sessionName = withDB $
  do
    name       <- liftIO generateName
    entryMaybe <- selectFirst [SubmissionDBSessionName ==. (Text.toLower sessionName), SubmissionDBUploadName ==. (Text.toLower name)] []
    case entryMaybe of
      Nothing  -> return name
      (Just _) -> liftIO $ uniqueSubmissionName sessionName

registerNewSession :: Text -> Text -> Bool -> Maybe Text -> Text -> UUID -> IO Bool
registerNewSession template name getsPrescreened configMaybe description token = withDB $
  do
    entityMaybe <- selectFirst [GalleryDBGalleryName ==. name] []
    rows        <- selectList  [SubmissionDBSessionName ==. (Text.toLower name)] []
    if isJust entityMaybe || (not . null) rows then
      return False
    else
      do
        timestamp     <- liftIO getCurrentTime
        (accNameM, _) <- liftIO $ tokenToAccountName token
        let insertionM = pam accNameM $ \accName -> insert $ GalleryDB (Text.toLower name) (Text.toLower template) accName getsPrescreened configMaybe description timestamp
        maybe (return False) (>> return True) insertionM

readGalleryListings :: UUID -> IO [GalleryListing]
readGalleryListings token = withDB $
    do
      accNameMaybe <- token |> tokenToAccountName >=> return . fst >>> liftIO
      rows         <- maybe (return []) (\accName -> selectList [GalleryDBOwnerName ==. accName] [Asc GalleryDBDateAdded]) accNameMaybe
      let particles = map (entityVal &> dbToGalListingParticle) rows
      flip mapM particles $ \(name, template, isPre, desc, cDate) -> liftIO $ withDB $ do
        numWaiting  <- count [SubmissionDBSessionName ==. (Text.toLower name), SubmissionDBIsAwaitingModeration ==. True]
        rows        <- selectList [ SubmissionDBSessionName          ==. (Text.toLower name)
                                  , SubmissionDBIsAwaitingModeration ==. False
                                  , SubmissionDBIsForbidden          ==. False
                                  ] [Asc SubmissionDBDateAdded]
        let uploads     = map entityVal rows
        let numApproved = length uploads
        let cTime       = asPOSIX cDate
        let lTime       = getMax cTime uploads
        return $ GalleryListing name template desc isPre numWaiting numApproved cTime lTime
    where
      getMax initTime = (map extractSubDateAdded) >>> (foldr chooseLater initTime)
      chooseLater a b = if a < b then b else a

readSubmissionListings :: Text -> IO [SubmissionListing]
readSubmissionListings sessionName = withDB $
    do
      rows <- selectList [ SubmissionDBSessionName          ==. (Text.toLower sessionName)
                         , SubmissionDBIsAwaitingModeration ==. False
                         , SubmissionDBIsForbidden          ==. False
                         ] [Asc SubmissionDBDateAdded]
      return $ map (entityVal &> dbToSubListing) rows

readSessionExists :: Text -> IO Bool
readSessionExists sessionName = withDB $
    do
      gEntityMaybe <- selectFirst [GalleryDBGalleryName    ==. (Text.toLower sessionName)] []
      sEntityMaybe <- selectFirst [SubmissionDBSessionName ==. (Text.toLower sessionName)] []
      return $ (isJust gEntityMaybe || isJust sEntityMaybe)

readSubmissionListingsForModeration :: Text -> UUID -> IO (PrivilegedActionResult [Text])
readSubmissionListingsForModeration sessionName token = withDB $
    do
      entityMaybe <- selectFirst [GalleryDBGalleryName ==. (Text.toLower sessionName)] []
      case entityMaybe of
        Nothing       -> return NotFound
        (Just entity) -> liftIO $ withDB $ do
          let modName  = entity |> entityVal &> extractOwnerName
          doesMatch   <- liftIO $ tokenMatchesAccountName modName token
          if doesMatch then do
            rows <- selectList [SubmissionDBSessionName ==. (Text.toLower sessionName), SubmissionDBIsAwaitingModeration ==. True] [Asc SubmissionDBDateAdded]
            return $ Fulfilled $ map (entityVal &> extractUploadName) rows
          else
            return NotAuthorized

readSubmissionData :: Text -> Text -> Maybe UUID -> IO (PrivilegedActionResult Text)
readSubmissionData sessionName uploadName tokenMaybe = withDB $
    do
      sEntityMaybe <- selectFirst [SubmissionDBSessionName ==. (Text.toLower sessionName), SubmissionDBUploadName ==. (Text.toLower uploadName)] []
      gEntityMaybe <- selectFirst [GalleryDBGalleryName ==. (Text.toLower sessionName)] []
      let teacherNameMaybe  = map (entityVal &> extractOwnerName) gEntityMaybe
      let pairMaybe         = (,) <$> teacherNameMaybe <*> tokenMaybe
      modNameMatches       <- maybe (return False) (uncurry tokenMatchesAccountName >>> liftIO) pairMaybe
      maybe (return NotFound) (entityVal &> retrieveSubmission extractData tokenMaybe modNameMatches &> liftIO) sEntityMaybe

readSubmissionsLite :: Text -> Maybe UUID -> [Text] -> IO [Submission]
readSubmissionsLite sessionName tokenMaybe names = withDB $
    do
      entities  <- selectList [SubmissionDBSessionName ==. (Text.toLower sessionName), SubmissionDBUploadName <-. (map Text.toLower names)] [Asc SubmissionDBDateAdded]
      let subs   = map entityVal entities
      validSubs <- flip mapM subs $ \sub -> liftIO $ withDB $ do
        gEntityMaybe         <- selectFirst [GalleryDBGalleryName ==. (extractSessionName sub)] []
        let teacherNameMaybe  = map (entityVal &> extractOwnerName) gEntityMaybe
        let pairMaybe         = (,) <$> teacherNameMaybe <*> tokenMaybe
        modNameMatches       <- maybe (return False) (uncurry tokenMatchesAccountName >>> liftIO) pairMaybe
        liftIO $ retrieveSubmission (dbToSubmission teacherNameMaybe) tokenMaybe modNameMatches sub
      return $ validSubs >>= collectFulfilled
  where
    collectFulfilled (Fulfilled x) = [x]
    collectFulfilled _             = []

readTemplateName :: Text -> IO (Maybe Text)
readTemplateName sessionName = withDB $
  do
    entityMaybe <- selectFirst [GalleryDBGalleryName ==. (Text.toLower sessionName)] []
    return $ map (entityVal >>> extractTemplateName) entityMaybe

suppressSubmission :: Text -> Text -> UUID -> IO (PrivilegedActionResult ())
suppressSubmission sessionName uploadName token = withDB $
  do
    entityMaybe  <- selectFirst [SubmissionDBSessionName ==. (Text.toLower sessionName), SubmissionDBUploadName ==. (Text.toLower uploadName)] []
    galleryMaybe <- selectFirst [GalleryDBGalleryName ==. (Text.toLower sessionName)] []
    case entityMaybe of
      Nothing       -> return NotFound
      (Just entity) -> do
        let modNameMaybe  = map (entityVal &> extractOwnerName) galleryMaybe
        isModerator      <- maybe (return False) (flip tokenMatchesAccountName token >>> liftIO) modNameMaybe
        let isUploader    = (Just token) == (entity |> entityVal &> extractToken)
        if isUploader || isModerator then do
          void $ update (entityKey entity) [SubmissionDBIsSuppressed =. True]
          return $ Fulfilled ()
        else
          return NotAuthorized

forbidSubmission :: Text -> Text -> UUID -> IO (PrivilegedActionResult ())
forbidSubmission = moderateSubmission True

approveSubmission :: Text -> Text -> UUID -> IO (PrivilegedActionResult ())
approveSubmission = moderateSubmission False

moderateSubmission :: Bool -> Text -> Text -> UUID -> IO (PrivilegedActionResult ())
moderateSubmission isForbidden sessionName uploadName token = withDB $
  do
    entityMaybe <- selectFirst [SubmissionDBSessionName ==. (Text.toLower sessionName), SubmissionDBUploadName ==. (Text.toLower uploadName)] []
    case entityMaybe of
      Nothing       -> return NotFound
      (Just entity) -> do
        gEntityMaybe     <- selectFirst [GalleryDBGalleryName ==. (Text.toLower sessionName)] []
        let modNameMaybe  = map (entityVal &> extractOwnerName) gEntityMaybe
        modNameMatches   <- maybe (return False) (flip tokenMatchesAccountName token >>> liftIO) modNameMaybe
        if modNameMatches then do
          void $ update (entityKey entity) [SubmissionDBIsForbidden          =. isForbidden]
          void $ update (entityKey entity) [SubmissionDBIsAwaitingModeration =. False]
          return $ Fulfilled ()
        else
          return NotAuthorized

writeSubmission :: Text -> Text -> Maybe UUID -> Maybe Text -> Text -> IO Text
writeSubmission sessionName imageBytes tokenMaybe metadata extraData = withDB $
    do
      uploadName   <- liftIO $ uniqueSubmissionName sessionName
      timestamp    <- liftIO getCurrentTime
      gEntityMaybe <- selectFirst [GalleryDBGalleryName ==. (Text.toLower sessionName)] []
      let tokey     = map UUID.toText tokenMaybe
      let getsPreed = maybe False (entityVal &> extractGetsPrescreened) gEntityMaybe
      let subDB     = SubmissionDB (Text.toLower sessionName) (Text.toLower uploadName) imageBytes tokey False False getsPreed metadata extraData timestamp
      void $ insert subDB
      return uploadName

readStarterConfigFor :: Text -> IO (Maybe (Maybe Text))
readStarterConfigFor galleryName = withDB $
  do
    entryMaybe <- selectFirst [GalleryDBGalleryName ==. (Text.toLower galleryName)] []
    return $ map (entityVal &> extractStarterConfig) entryMaybe

readCommentsFor :: Text -> Text -> IO [Comment]
readCommentsFor sessionName uploadName = withDB $
    do
      rows <- selectList [CommentDBSessionName ==. (Text.toLower sessionName), CommentDBUploadName ==. (Text.toLower uploadName)] [Asc CommentDBTime]
      rows |> (map $ entityVal &> dbToComment) &> (sortBy $ comparing time) &> return

writeComment :: Text -> Text -> Text -> Text -> Maybe UUID -> IO ()
writeComment comment uploadName sessionName author parent = withDB $
    do
      timestamp <- liftIO getCurrentTime
      uuid      <- liftIO randomIO
      let commentDB = CommentDB (UUID.toText uuid) comment author (map UUID.toText parent) (Text.toLower sessionName) (Text.toLower uploadName) timestamp
      void $ insert commentDB
      return ()

withDB :: ReaderT SqlBackend (NoLoggingT (ResourceT IO)) a -> IO a
withDB action = runNoLoggingT $ withPostgresqlPool connStr 50 $ \pool -> liftIO $
  do
    flip runSqlPersistMPool pool $
      do
        --runMigration migrateAll -- We do this for every DB transaction?  Major performance issue at scale, I'd expect. --JAB (10/4/20)
        action
  where
    connStr = "host=localhost dbname=vandyland user=" <> username <> " password=" <> password <> " port=5432"

retrieveSubmission :: (SubmissionDB -> a) -> Maybe UUID -> Bool -> SubmissionDB -> IO (PrivilegedActionResult a)
retrieveSubmission f givenTokenMaybe modNameMatches submission = withDB $
    do
      let authorTokenMaybe = extractToken           submission
      let needsModeration  = extractNeedsModeration submission
      let isSuppressed     = extractIsSuppressed    submission
      return $
        if givenTokenMaybe == authorTokenMaybe || modNameMatches || ((not needsModeration) && (not isSuppressed)) then
          Fulfilled $ f submission
        else
          NotAuthorized

checkUserExists :: Text -> IO Bool
checkUserExists emailAddr = withDB $
  do
    let lowerEmail = Text.toLower emailAddr
    authMaybe <- selectFirst [AuthDBAuthEmail ==. lowerEmail, AuthDBIsConfirmed ==. True] []
    case (map entityVal authMaybe) of
      Nothing -> return False
      _       -> return True

registerNewUser :: Text -> UUID -> IO AuthActionResult
registerNewUser emailAddr confirmationToken = withDB $
  do
    let lowerEmail = Text.toLower emailAddr
    authMaybe <- selectFirst [AuthDBAuthEmail ==. lowerEmail, AuthDBIsConfirmed ==. True] []
    case (map entityVal authMaybe) of
      Nothing -> do
        let confToken = UUID.toText confirmationToken
        now <- liftIO getCurrentTime
        deleteWhere [AuthDBAuthEmail ==. lowerEmail]
        _ <- insert $ AuthDB lowerEmail False Nothing Nothing Nothing Nothing
        _ <- upsert (ConfirmationDB lowerEmail confToken now) [ConfirmationDBAuthHash =. (Text.toLower confToken), ConfirmationDBDateAdded =. now]
        return Successful
      (Just _) -> return Duplicate

confirmNewUser :: UUID -> IO AuthActionResult
confirmNewUser confirmationToken = withDB $
  do
    let confToken = Text.toLower $ UUID.toText confirmationToken
    confMaybe <- selectFirst [ConfirmationDBAuthHash ==. confToken] []
    case confMaybe of
      Nothing           -> return DoesNotExist
      (Just confEntity) -> do
        now <- liftIO getCurrentTime
        let conf      = entityVal confEntity
        let timeAdded = extractConfirmDateAdded conf
        let deadline  = addUTCTime ((60 * 10) :: NominalDiffTime) timeAdded
        if now <= deadline then do
          authMaybe <- selectFirst [AuthDBAuthEmail ==. (Text.toLower $ extractConfirmAddr conf)] []
          case authMaybe of
            Nothing           -> return DoesNotExist
            (Just authEntity) -> do
              void $ update (entityKey authEntity) [AuthDBIsConfirmed =. True]
              void $ delete (entityKey confEntity)
              return Successful
        else
          return Expired

storeOTP :: Text -> Text -> IO AuthActionResult
storeOTP emailAddr otp = withDB $
  do
    entityMaybe <- selectFirst [AuthDBAuthEmail ==. (Text.toLower emailAddr)] []
    case entityMaybe of
      Nothing       -> return DoesNotExist
      (Just entity) ->
        if ((entityVal >>> extractAuthIsConfirmed) entity) then do
          now          <- liftIO getCurrentTime
          let deadline  = addUTCTime ((60 * 10) :: NominalDiffTime) now
          void $ update (entityKey entity) [AuthDBOtp =. Just otp, AuthDBOtpExpiration =. Just deadline]
          return Successful
        else
          return Unconfirmed

validateOTP :: Text -> Text -> UUID -> IO AuthActionResult
validateOTP emailAddr passcode token = withDB $
  do
    entityMaybe <- selectFirst [AuthDBAuthEmail ==. (Text.toLower emailAddr)] []
    case entityMaybe of
      Nothing       -> return DoesNotExist
      (Just entity) -> do
        now <- liftIO getCurrentTime
        let auth        = entityVal entity
        let isConfirmed = extractAuthIsConfirmed auth
        let isCorrect   = maybe False (== (Text.toLower passcode)) (extractAuthOTP      auth)
        let isOnTime    = maybe False (now <=)                     (extractAuthOTPExpir auth)
        if not isConfirmed then
          return Unconfirmed
        else if not isOnTime then
          return Expired
        else if not isCorrect then
          return Incorrect
        else do
          let authToken = Text.toLower $ UUID.toText token
          let pairs = [AuthDBOtp =. Nothing, AuthDBOtpExpiration =. Nothing, AuthDBAuthToken =. Just authToken, AuthDBTokenBirthday =. Just now]
          void $ update (entityKey entity) pairs
          return Successful

tokenToAccountName :: UUID -> IO (Maybe Text, AuthActionResult)
tokenToAccountName token = withDB $
  do
    let authToken = Text.toLower $ UUID.toText token
    entityMaybe <- selectFirst [AuthDBAuthToken ==. (Just authToken)] []
    case entityMaybe of
      Nothing       -> return (Nothing, DoesNotExist)
      (Just entity) -> do
        now <- liftIO getCurrentTime
        let auth        = entityVal entity
        let expirationM = map (addUTCTime ((60 * 60 * 24 * 90) :: NominalDiffTime)) $ extractAuthTokenBirthday auth
        let isOnTime    = maybe False (now <=) expirationM
        if isOnTime then do
          let email = extractAuthEmail auth
          return (Just email, Successful)
        else
          return (Nothing, Expired)

tokenMatchesAccountName :: Text -> UUID -> IO Bool
tokenMatchesAccountName name = tokenToAccountName >=> (\(nm, res) -> return $ nm == (Just name) && res == Successful)

isValid :: UUID -> IO AuthActionResult
isValid = tokenToAccountName >=> return . snd

logout :: UUID -> IO AuthActionResult
logout token = withDB $
  do
    let authToken = Text.toLower $ UUID.toText token
    entityMaybe <- selectFirst [AuthDBAuthToken ==. (Just authToken)] []
    case entityMaybe of
      Nothing       -> return DoesNotExist
      (Just entity) -> do
        void $ update (entityKey entity) [AuthDBAuthToken =. Nothing, AuthDBTokenBirthday =. Nothing]
        return Successful

extractTemplateName :: GalleryDB -> Text
extractTemplateName (GalleryDB _ tn _ _ _ _ _) = tn

extractOwnerName :: GalleryDB -> Text
extractOwnerName (GalleryDB _ _ onm _ _ _ _) = onm

extractGetsPrescreened :: GalleryDB -> Bool
extractGetsPrescreened (GalleryDB _ _ _ gp _ _ _) = gp

extractStarterConfig :: GalleryDB -> Maybe Text
extractStarterConfig (GalleryDB _ _ _ _ sc _ _) = sc

dbToGalListingParticle :: GalleryDB -> (Text, Text, Bool, Text, UTCTime)
dbToGalListingParticle (GalleryDB gn tp _ gp _ de da) = (gn, tp, gp, de, da)

dbToSubListing :: SubmissionDB -> SubmissionListing
dbToSubListing (SubmissionDB _ uploadName _ _ isSuppressed _ _ _ _ _) = SubmissionListing uploadName isSuppressed

dbToSubmission :: Maybe Text -> SubmissionDB -> Submission
dbToSubmission ownerName (SubmissionDB _ uploadName image token _ _ _ metadata _ _) =
  Submission uploadName image (token >>= UUID.fromText) ownerName metadata

dbToComment :: CommentDB -> Comment
dbToComment (CommentDB uuid comment author parent _ _ time) = Comment uuid comment author parent (asPOSIX time)

extractSessionName :: SubmissionDB -> Text
extractSessionName (SubmissionDB sn _ _ _ _ _ _ _ _ _) = sn

extractUploadName :: SubmissionDB -> Text
extractUploadName (SubmissionDB _ un _ _ _ _ _ _ _ _) = un

extractToken :: SubmissionDB -> Maybe UUID
extractToken (SubmissionDB _ _ _ token _ _ _ _ _ _) = token >>= UUID.fromText

extractIsSuppressed :: SubmissionDB -> Bool
extractIsSuppressed (SubmissionDB _ _ _ _ isSuppressed _ _ _ _ _) = isSuppressed

extractNeedsModeration :: SubmissionDB -> Bool
extractNeedsModeration (SubmissionDB _ _ _ _ _ _ needsModeration _ _ _) = needsModeration

extractData :: SubmissionDB -> Text
extractData (SubmissionDB _ _ _ _ _ _ _ _ extraData _) = extraData

extractSubDateAdded :: SubmissionDB -> Integer
extractSubDateAdded (SubmissionDB _ _ _ _ _ _ _ _ _ dateAdded) = asPOSIX dateAdded

extractAuthEmail :: AuthDB -> Text
extractAuthEmail (AuthDB email _ _ _ _ _) = email

extractAuthIsConfirmed :: AuthDB -> Bool
extractAuthIsConfirmed (AuthDB _ isConfirmed _ _ _ _) = isConfirmed

extractAuthOTP :: AuthDB -> Maybe Text
extractAuthOTP (AuthDB _ _ otp _ _ _) = otp

extractAuthOTPExpir :: AuthDB -> Maybe UTCTime
extractAuthOTPExpir (AuthDB _ _ _ expir _ _) = expir

extractAuthTokenBirthday :: AuthDB -> Maybe UTCTime
extractAuthTokenBirthday (AuthDB _ _ _ _ _ birthday) = birthday

extractConfirmAddr :: ConfirmationDB -> Text
extractConfirmAddr (ConfirmationDB addr _ _) = addr

extractConfirmDateAdded :: ConfirmationDB -> UTCTime
extractConfirmDateAdded (ConfirmationDB _ _ dateAdded) = dateAdded

asPOSIX :: UTCTime -> Integer
asPOSIX = utcTimeToPOSIXSeconds >>> (* 1000) >>> round

data AuthActionResult
  = Successful
  | Incorrect
  | Unconfirmed
  | Duplicate
  | Expired
  | DoesNotExist
  deriving (Show, Eq)

data PrivilegedActionResult a
  = Fulfilled a
  | NotAuthorized
  | NotFound
