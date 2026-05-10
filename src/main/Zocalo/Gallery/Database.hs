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

module Zocalo.Gallery.Database(approveSubmission, checkIsOkayOTPRate, checkUserExists, confirmNewUser, forbidSubmission, logoutTeacher, lookupTeacherRefreshToken, readCommentsFor, readGalleryListings, readStarterConfigFor, readSubmissionData, readSubmissionsLite, readSubmissionListings, readSubmissionListingsForModeration, readTemplateName, readWhoIsTeacher, registerNewGallery, registerNewUser, runMigrations, storeOTP, suppressSubmission, uniqueGalleryName, upsertTeacherRefreshToken, validateOTP, writeComment, writeSubmission) where

import Control.Monad.Logger(NoLoggingT, runNoLoggingT)
import Control.Monad.Trans.Reader(ReaderT)
import Control.Monad.Trans.Resource(ResourceT)

import Data.List(sortBy)
import Data.NanoID(nanoID, NanoID, unNanoID)
import Data.Ord(comparing)
import Data.Time(addUTCTime, getCurrentTime, UTCTime)
import Data.Time.Clock.POSIX(utcTimeToPOSIXSeconds)
import Data.Type.Equality(type (~))

import Database.Persist((<-.), (=.), (==.), (>=.), count, Entity(Entity, entityKey, entityVal), get, getBy, insert, insertUnique, Key, PersistEntity, PersistEntityBackend, selectFirst, selectList, SelectOpt(Asc), Unique, update, updateWhere, upsert)
import Database.Persist.Postgresql(runMigration, runSqlPersistMPool, SqlBackend, withPostgresqlPool)
import Database.Persist.Sql(fromSqlKey, toSqlKey)
import Database.Persist.TH(mkMigrate, mkPersist, share, sqlSettings)

import System.Random.MWC(createSystemRandom)

import Zocalo.Common.DBCredentials(password, username)
import Zocalo.Common.SecureToken(hashToken, SecureToken(tokenText), tokenFromText)

import Zocalo.Gallery.Auth.AuthorizedUser(AuthorizedStudent(AStudent, studentID), AuthorizedTeacher(ATeacher, teacherAddr))

import Zocalo.Gallery.ActionResult(ActionError(Duplicate, Expired, Incorrect, NotAuthorized, NotFound, Unconfirmed), ActionResult)
import Zocalo.Gallery.Comment(Comment(Comment, creationTime))
import Zocalo.Gallery.DBSnakeCase(bizzleSnakeCase)
import Zocalo.Gallery.GalleryListing(GalleryListing(GalleryListing))
import Zocalo.Gallery.LowerText(asLowerText, LowerText, lowText)
import Zocalo.Gallery.RandGen(generateName)
import Zocalo.Gallery.Submission(Submission(Submission), SubmissionListing(SubmissionListing))

import qualified Data.Text          as Text
import qualified Data.Text.Encoding as TE


share [mkPersist sqlSettings, mkMigrate "migrateAll"] [bizzleSnakeCase|

TeacherDB
  emailAddr    LowerText
  firstName    Text
  lastName     Text
  organization Text Maybe
  isConfirmed  Bool
  createdAt    UTCTime
  UniqueTeacherEmail emailAddr
  deriving Show

ConfirmationTokenDB
  teacherID TeacherDBId
  token     Text
  birthday  UTCTime
  wasUsed   Bool
  UniqueConfirmationToken token
  deriving Show

OTPRequestDB
  teacherID TeacherDBId
  passcode  Text
  birthday  UTCTime
  wasUsed   Bool
  deriving Show

TeacherRefreshTokenDB
  teacherID  TeacherDBId
  hash       Text
  birthday   UTCTime
  wasRevoked Bool
  UniqueTeacherRefreshTokenHash hash
  deriving Show

StudentRefreshTokenDB
  studentName Text
  hash        Text
  birthday    UTCTime
  wasRevoked  Bool
  UniqueStudentRefreshTokenHash hash
  deriving Show

GalleryDB
  galleryName     LowerText
  galleryDisplay  Text
  templateName    Text
  ownerID         TeacherDBId
  nanoID          Text
  getsPrescreened Bool
  config          Text Maybe
  description     Text
  dateAdded       UTCTime
  UniqueGallery ownerID galleryName
  UniqueGalleryNano nanoID
  deriving Show

SubmissionDB
  galleryID            GalleryDBId
  uploadName           LowerText
  uploadDisplay        Text
  base64Image          Text
  authorID             StudentRefreshTokenDBId
  isSuppressed         Bool
  isForbidden          Bool
  isAwaitingModeration Bool
  metadata             Text Maybe
  extraData            Text
  dateAdded            UTCTime
  UniqueSubmission galleryID uploadName
  deriving Show

CommentDB
  comment  Text
  author   Text
  parent   CommentDBId Maybe
  uploadID SubmissionDBId
  time     UTCTime
  deriving Show

|]

uniqueGalleryName :: Int -> IO Text
uniqueGalleryName teacherIDNum =
  do
    name   <- generateName
    result <- withGallery (toSqlKey $ fromIntegral teacherIDNum) (asLowerText name) chillax
    case result of
      Success _ -> uniqueGalleryName teacherIDNum
      Failure _ -> return name

uniqueSubmissionName :: NanoID -> IO Text
uniqueSubmissionName nid =
  do
    name   <- generateName
    result <- withSubmission2 nid (asLowerText name) chillax
    case result of
      Success _ -> uniqueSubmissionName nid
      Failure _ -> return name

registerNewGallery :: AuthorizedTeacher -> Text -> Text -> Bool -> Maybe Text -> Text -> IO (ActionResult Int64)
registerNewGallery teacher template galleryName getsPrescreened configMaybe description =
  withTeacher teacher.teacherAddr $
    \(teacherID, _) -> do
      timestamp      <- getCurrentTime
      let lName       = asLowerText galleryName
      let lTemplate   = Text.toLower template
      rng            <- createSystemRandom
      rawNanoID      <- nanoID rng
      let nid         = TE.decodeUtf8 $ unNanoID rawNanoID
      let galleryDB   = GalleryDB lName galleryName lTemplate teacherID nid getsPrescreened configMaybe description timestamp
      insertionM     <- withDB $ insertUnique galleryDB
      return $ case insertionM of
        Nothing  -> Failure Duplicate
        Just key -> Success $ fromSqlKey key

readGalleryListings :: AuthorizedTeacher -> IO (ActionResult [GalleryListing])
readGalleryListings teacher =
  withTeacher teacher.teacherAddr $
    \(teacherID, _) -> do
      rows     <- withDB $ selectList [GalleryDBOwnerID ==. teacherID] [Asc GalleryDBDateAdded]
      listings <- flip mapM rows $ \(Entity subID (GalleryDB _ name template _ _ isPre _ desc cDate)) -> withDB $ do
        numWaiting <- count [SubmissionDBGalleryID ==. subID, SubmissionDBIsAwaitingModeration ==. True]
        rows       <- selectList [ SubmissionDBGalleryID            ==. subID
                                 , SubmissionDBIsAwaitingModeration ==. False
                                 , SubmissionDBIsForbidden          ==. False
                                 ] [Asc SubmissionDBDateAdded]
        let sid         = fromIntegral $ fromSqlKey subID
        let uploads     = map entityVal rows
        let numApproved = length uploads
        let cTime       = asPOSIX cDate
        let lTime       = getMax cTime uploads
        return $ GalleryListing sid name template desc isPre numWaiting numApproved cTime lTime
      return $ Success listings
  where
    getMax initTime = (map extractSubDateAdded) >>> (foldr chooseLater initTime)
    chooseLater a b = if a < b then b else a

readSubmissionListings :: NanoID -> IO (ActionResult [SubmissionListing])
readSubmissionListings nid =
  withGalleryNano nid $
    \(gID, _) -> withDB $ do
      rows <- selectList [ SubmissionDBGalleryID            ==. gID
                         , SubmissionDBIsAwaitingModeration ==. False
                         , SubmissionDBIsForbidden          ==. False
                         ] [Asc SubmissionDBDateAdded]
      return $ Success $ map (entityVal &> dbToSubListing) rows

readSubmissionListingsForModeration :: AuthorizedTeacher -> LowerText -> IO (ActionResult [LowerText])
readSubmissionListingsForModeration teacher galleryName =
  withGallery2 teacher.teacherAddr galleryName $
    \(galleryID, _) -> do
      canModerate <- (Just teacher) `ownsOneNamed` galleryName
      if canModerate then withDB $ do
        rows <- selectList [ SubmissionDBGalleryID            ==. galleryID
                           , SubmissionDBIsAwaitingModeration ==. True
                           ] [Asc SubmissionDBDateAdded]
        return $ Success $ map (entityVal &> extractUploadName) rows
      else
        return $ Failure NotAuthorized

readSubmissionData :: Maybe AuthorizedTeacher -> Maybe AuthorizedStudent -> NanoID -> LowerText -> IO (ActionResult Text)
readSubmissionData teacherM studentM nid uploadName =
  withSubmission2 nid uploadName $
    \(_, uploadDB) ->
      do
        dta <- processSubmissionAuth extractData teacherM studentM uploadDB
        return $ second fst dta

readSubmissionsLite :: Maybe AuthorizedTeacher -> Maybe AuthorizedStudent -> NanoID -> [Text] -> IO (ActionResult [(Submission, Bool)])
readSubmissionsLite teacherM studentM nid names =
  withGalleryNano nid $
    \(galleryID, _) -> do
      entities  <- withDB $ selectList [ SubmissionDBGalleryID  ==. galleryID
                                       , SubmissionDBUploadName <-. (map asLowerText names)
                                       ] [Asc SubmissionDBDateAdded]
      validSubs <- flip mapM entities $
        \entity -> liftIO $ do
          let key = fromIntegral $ fromSqlKey $ entityKey entity
          let val = entityVal entity
          processSubmissionAuth (dbToSubmission key) teacherM studentM val
      return $ Success $ validSubs >>= collectSuccessful
  where
    collectSuccessful (Success x) = [x]
    collectSuccessful _           = []

readTemplateName :: NanoID -> IO (ActionResult Text)
readTemplateName nid =
  withGalleryNano nid $
    \(_, galleryDB) -> return $ Success $ extractTemplateName galleryDB

readWhoIsTeacher :: AuthorizedTeacher -> IO (ActionResult Int64)
readWhoIsTeacher teacher =
  withTeacher teacher.teacherAddr $
    \(teacherID, _) -> return $ Success $ fromSqlKey teacherID

suppressSubmission :: Maybe AuthorizedTeacher -> Maybe AuthorizedStudent -> NanoID -> LowerText -> IO (ActionResult ())
suppressSubmission teacherM studentM nid uploadName =
  withSubmission2 nid uploadName $
    \(uploadID, _) -> do
      result <- canDeleteSubmission2 teacherM studentM nid uploadName
      case result of
        Success canDeleteIt ->
          if canDeleteIt then do
            withDB $ update uploadID [SubmissionDBIsSuppressed =. True]
            return $ Success ()
          else
            return $ Failure NotAuthorized
        x -> return $ second (const ()) x

forbidSubmission :: AuthorizedTeacher -> LowerText -> LowerText -> IO (ActionResult ())
forbidSubmission = moderateSubmission True

approveSubmission :: AuthorizedTeacher -> LowerText -> LowerText -> IO (ActionResult ())
approveSubmission = moderateSubmission False

moderateSubmission :: Bool -> AuthorizedTeacher -> LowerText -> LowerText -> IO (ActionResult ())
moderateSubmission isForbidden teacher galleryName uploadName =
  withTeacher teacher.teacherAddr $
    \(teacherID, _) ->
      withSubmission3 (fromIntegral $ fromSqlKey teacherID) galleryName uploadName $
        \(uploadID, _) -> do
          canModerate <- (Just teacher) `ownsOneNamed` galleryName
          if canModerate then withDB $ do
            update uploadID [SubmissionDBIsForbidden          =. isForbidden]
            update uploadID [SubmissionDBIsAwaitingModeration =. False]
            return $ Success ()
          else
            return $ Failure NotAuthorized

writeSubmission :: AuthorizedStudent -> NanoID -> Text -> Maybe Text -> Text -> IO (ActionResult Text)
writeSubmission student nid imageBytes metadata extraData =
  withGalleryNano nid $
    \(galleryID, gallery) -> do
      uploadName      <- uniqueSubmissionName nid
      let lUploadName  = asLowerText uploadName
      let studID       = student |> studentID &> fromIntegral &> toSqlKey
      gEntityMaybe    <- withDB $ selectFirst [GalleryDBGalleryName ==. (extractGalleryName gallery)] []
      let getsPreed    = maybe False (entityVal &> extractGetsPrescreened) gEntityMaybe
      timestamp       <- getCurrentTime
      let subDB        = SubmissionDB galleryID lUploadName uploadName imageBytes studID False False getsPreed metadata extraData timestamp
      void $ withDB $ insert subDB
      return $ Success uploadName

readStarterConfigFor :: NanoID -> IO (ActionResult (Maybe Text))
readStarterConfigFor nid =
  withGalleryNano nid $
    \(_, galleryDB) ->
      return $ Success $ extractStarterConfig galleryDB

readCommentsFor :: NanoID -> LowerText -> IO (ActionResult [Comment])
readCommentsFor nid uploadName =
  withSubmission2 nid uploadName $
    \(uploadID, _) -> do
      rows <- withDB $ selectList [CommentDBUploadID ==. uploadID] [Asc CommentDBTime]
      return $ Success $ rows |> (map dbToComment) &> (sortBy $ comparing creationTime)

writeComment :: NanoID -> LowerText -> Maybe Int64 -> Text -> Text -> IO (ActionResult ())
writeComment nid uploadName parentIDM author comment =
  withSubmission2 nid uploadName $
    \(uploadID, _) -> do
      timestamp       <- getCurrentTime
      let parentDBIDM  = map toSqlKey parentIDM
      void $ withDB $ insert $ CommentDB comment author parentDBIDM uploadID timestamp
      return $ Success ()

runMigrations :: IO ()
runMigrations = liftIO $ withDB $ runMigration migrateAll

withDB :: ReaderT SqlBackend (NoLoggingT (ResourceT IO)) a -> IO a
withDB action = runNoLoggingT $ withPostgresqlPool connStr 50 $ runSqlPersistMPool action &> liftIO
  where
    connStr = "host=localhost dbname=zocalo user=" <> username <> " password=" <> password <> " port=5432"

processSubmissionAuth :: (SubmissionDB -> a) -> Maybe AuthorizedTeacher -> Maybe AuthorizedStudent -> SubmissionDB -> IO (ActionResult (a, Bool))
processSubmissionAuth f teacherM studentM submission =
  do
    let needsModeration  = extractNeedsModeration submission
    let isSuppressed     = extractIsSuppressed    submission
    canDelete           <- canDeleteSubmission teacherM studentM submission
    return $
      if canDelete || ((not needsModeration) && (not isSuppressed)) then
        Success (f submission, canDelete)
      else
        Failure NotAuthorized

ownsOneNamed :: Maybe AuthorizedTeacher -> LowerText -> IO Bool
ownsOneNamed Nothing                _           = return False
ownsOneNamed (Just (ATeacher addr)) galleryName =
  do
    result <- withGallery2 addr galleryName chillax
    return $ case result of
      Success _ -> True
      _         -> False

canDeleteSubmission2 :: Maybe AuthorizedTeacher -> Maybe AuthorizedStudent -> NanoID -> LowerText -> IO (ActionResult Bool)
canDeleteSubmission2 teacherM studentM nid uploadName =
  withSubmission2 nid uploadName $
    \(_, subDB) -> Success <$> canDeleteSubmission teacherM studentM subDB

canDeleteSubmission :: Maybe AuthorizedTeacher -> Maybe AuthorizedStudent -> SubmissionDB -> IO Bool
canDeleteSubmission teacherM studentM submission =
  do
    (Just (GalleryDB galleryName _ _ _ _ _ _ _ _)) <- withDB $ get submission.submissionDBGalleryID
    (teacherM `ownsOneNamed` galleryName) <|> (belongsToThisStudent studentM)
  where
    belongsToThisStudent Nothing                    = return False
    belongsToThisStudent (Just (AStudent studID _)) = return $ submission |> extractStudentID &> (== studID)

checkUserExists :: LowerText -> IO Bool
checkUserExists emailAddr =
  do
    authMaybe <- withDB $ selectFirst [TeacherDBEmailAddr ==. emailAddr, TeacherDBIsConfirmed ==. True] []
    return $ isJust authMaybe

registerNewUser :: LowerText -> Text -> Text -> Maybe Text -> SecureToken -> IO (ActionResult ())
registerNewUser emailAddr firstName lastName orgM confirmationToken =
  do
    teacherM <- withDB $ selectFirst [TeacherDBEmailAddr ==. emailAddr, TeacherDBIsConfirmed ==. True] []
    if isJust teacherM then
      return $ Failure Duplicate
    else do
      now           <- getCurrentTime
      let confToken  = confirmationToken.tokenText
      void $ withDB $ do
        (Entity tID _) <- upsert (TeacherDB emailAddr firstName lastName orgM False now)
                                 [ TeacherDBFirstName    =. firstName, TeacherDBLastName  =. lastName
                                 , TeacherDBOrganization =.      orgM, TeacherDBCreatedAt =. now
                                 ]
        updateWhere [ConfirmationTokenDBTeacherID ==. tID] [ConfirmationTokenDBWasUsed =. True]
        insert $ ConfirmationTokenDB tID confToken now False

      return $ Success ()

confirmNewUser :: SecureToken -> IO (ActionResult AuthorizedTeacher)
confirmNewUser confirmationToken =
  withPair (UniqueConfirmationToken confirmationToken.tokenText) $
    \(cTokenID, (ConfirmationTokenDB teacherID cToken dateAdded wasUsed)) -> do
      result <- withDB $ get teacherID
      case result of
        Nothing                              -> return $ Failure NotFound
        Just (TeacherDB emailAddr _ _ _ _ _) ->
          if (tokenFromText cToken) == (Just confirmationToken) then do
            now          <- getCurrentTime
            let deadline  = addUTCTime (60 * 10) (traceShowId dateAdded)
            if now <= deadline && (not wasUsed) then withDB $ do
              update teacherID [TeacherDBIsConfirmed       =. True]
              update  cTokenID [ConfirmationTokenDBWasUsed =. True]
              return $ Success $ ATeacher emailAddr
            else
              return $ Failure Expired
          else
            return $ Failure Incorrect

storeOTP :: LowerText -> Text -> IO (ActionResult ())
storeOTP emailAddr otp =
  withTeacher emailAddr $
    \(teacherID, teacherDB) ->
      if extractTeacherIsConfirmed teacherDB then do
        now <- getCurrentTime
        void $ withDB $ do
          updateWhere [OTPRequestDBTeacherID ==. teacherID] [OTPRequestDBWasUsed =. True]
          insert $ OTPRequestDB teacherID otp now False
        return $ Success ()
      else
        return $ Failure Unconfirmed

validateOTP :: LowerText -> Text -> IO (ActionResult AuthorizedTeacher)
validateOTP emailAddr passcode =
  withTeacher emailAddr $
    \(teacherID, teacherDB) -> do
      otpM <- withDB $ selectFirst [OTPRequestDBTeacherID ==. teacherID, OTPRequestDBWasUsed ==. False] []
      case otpM of
        Nothing             -> return $ Failure NotFound
        Just (Entity _ otp) -> do
          now             <- getCurrentTime
          let isConfirmed  = extractTeacherIsConfirmed teacherDB
          let isCorrect    = (extractOTPPasscode otp) == passcode
          let isOnTime     = (extractOTPBirthday otp) <= (addUTCTime (60 * 10) now)
          if not isConfirmed then
            return $ Failure Unconfirmed
          else if not isOnTime then
            return $ Failure Expired
          else if not isCorrect then
            return $ Failure Incorrect
          else do
            withDB $ updateWhere [OTPRequestDBTeacherID ==. teacherID, OTPRequestDBPasscode ==. passcode]
                                 [OTPRequestDBWasUsed =. True]
            return $ Success $ ATeacher $ extractEmailAddr teacherDB

-- TODO: How/when do refresh tokens get revoked?
-- TODO: Are `data` files blobs?

lookupTeacherRefreshToken :: SecureToken -> IO (ActionResult AuthorizedTeacher)
lookupTeacherRefreshToken refreshToken =
  do
    withPair (UniqueTeacherRefreshTokenHash $ hashToken refreshToken) $
      \(_, TeacherRefreshTokenDB teacherID _ birthday wasRevoked) -> do
        now           <- getCurrentTime
        let in28Days   = 60 * 60 * 24 * 7 * 4
        let expirDate  = in28Days `addUTCTime` birthday
        if (not wasRevoked) && (now <= expirDate) then do
          result <- withDB $ get teacherID
          case result of
            Nothing                         -> return $ Failure NotFound
            Just (TeacherDB addr _ _ _ _ _) -> return $ Success $ ATeacher addr
        else
          return $ Failure Expired

upsertTeacherRefreshToken :: LowerText -> SecureToken ->  IO (ActionResult ())
upsertTeacherRefreshToken emailAddr refreshToken =
  withTeacher emailAddr $
    \(teacherID, _) -> do
      now             <- getCurrentTime
      let refreshHash  = hashToken refreshToken
      void $ withDB $ upsert (TeacherRefreshTokenDB teacherID refreshHash now False)
                             [ TeacherRefreshTokenDBHash =. refreshHash, TeacherRefreshTokenDBBirthday =. now
                             , TeacherRefreshTokenDBWasRevoked =. False]
      return $ Success ()

logoutTeacher :: AuthorizedTeacher -> IO (ActionResult ())
logoutTeacher teacher =
  withTeacher teacher.teacherAddr $
    \(teacherID, _) -> do
      withDB $ updateWhere [TeacherRefreshTokenDBTeacherID ==. teacherID] [TeacherRefreshTokenDBWasRevoked =. True]
      return $ Success ()

checkIsOkayOTPRate :: LowerText -> IO (ActionResult Bool)
checkIsOkayOTPRate emailAddr =
  withTeacher emailAddr $
    \(teacherID, _) -> do
      now           <- getCurrentTime
      let _30MinAgo  = addUTCTime (-60 * 30) now
      results       <- withDB $ selectList [OTPRequestDBTeacherID ==. teacherID, OTPRequestDBBirthday >=. _30MinAgo] []
      return $ Success $ (length results) < 5

chillax :: a -> IO (ActionResult ())
chillax = const $ return $ Success ()

withTeacher :: LowerText -> ((TeacherDBId, TeacherDB) -> IO (ActionResult a)) -> IO (ActionResult a)
withTeacher addr f =
  withPair (UniqueTeacherEmail addr) f

withGallery :: TeacherDBId -> LowerText -> ((GalleryDBId, GalleryDB) -> IO (ActionResult a)) -> IO (ActionResult a)
withGallery teacherID galleryName f =
  withPair (UniqueGallery teacherID galleryName) f

withGallery2 :: LowerText -> LowerText -> ((GalleryDBId, GalleryDB) -> IO (ActionResult a)) -> IO (ActionResult a)
withGallery2 teacherAddr galleryName f =
  withTeacher teacherAddr $
    \(teacherID, _) ->
      withGallery teacherID galleryName f

withGalleryNano :: NanoID -> ((GalleryDBId, GalleryDB) -> IO (ActionResult a)) -> IO (ActionResult a)
withGalleryNano nid f =
  withPair (UniqueGalleryNano $ TE.decodeUtf8 $ unNanoID nid) f

withSubmission :: GalleryDBId -> LowerText -> ((SubmissionDBId, SubmissionDB) -> IO (ActionResult a)) -> IO (ActionResult a)
withSubmission galleryID uploadName f =
  withPair (UniqueSubmission galleryID uploadName) f

withSubmission2 :: NanoID -> LowerText -> ((SubmissionDBId, SubmissionDB) -> IO (ActionResult a)) -> IO (ActionResult a)
withSubmission2 nid uploadName f =
  withGalleryNano nid $
    \(galleryID, _) ->
      withSubmission galleryID uploadName f

withSubmission3 :: Int -> LowerText -> LowerText -> ((SubmissionDBId, SubmissionDB) -> IO (ActionResult a)) -> IO (ActionResult a)
withSubmission3 teacherIDNum galleryName uploadName f =
  withGallery (toSqlKey $ fromIntegral teacherIDNum) galleryName $
    \(galleryID, _) ->
      withSubmission galleryID uploadName f

withPair :: (PersistEntity e, PersistEntityBackend e ~ SqlBackend) =>
            Unique e -> ((Key e, e) -> IO (ActionResult a)) -> IO (ActionResult a)
withPair key f =
  do
    entityM <- withDB $ getBy key
    case entityM of
      Nothing               -> return $ Failure NotFound
      Just (Entity xID xDB) -> f (xID, xDB)

extractGalleryName :: GalleryDB -> LowerText
extractGalleryName (GalleryDB gn _ _ _ _ _ _ _ _) = gn

extractTemplateName :: GalleryDB -> Text
extractTemplateName (GalleryDB _ _ tn _ _ _ _ _ _) = tn

extractGetsPrescreened :: GalleryDB -> Bool
extractGetsPrescreened (GalleryDB _ _ _ _ _ gp _ _ _) = gp

extractStarterConfig :: GalleryDB -> Maybe Text
extractStarterConfig (GalleryDB _ _ _ _ _ _ sc _ _) = sc

dbToSubListing :: SubmissionDB -> SubmissionListing
dbToSubListing (SubmissionDB _ uploadName _ _ _ isSuppressed _ _ _ _ _) = SubmissionListing (lowText uploadName) isSuppressed

dbToSubmission :: Word64 -> SubmissionDB -> Submission
dbToSubmission subID (SubmissionDB _ _ uploadName image studentID _ _ _ metadata _ time) =
  Submission subID uploadName image (fromIntegral $ fromSqlKey studentID) metadata $ asPOSIX time

dbToComment :: (Entity CommentDB) -> Comment
dbToComment (Entity cid (CommentDB comment author parentIDM _ time)) =
  Comment (fromSqlKey cid) comment author (map fromSqlKey parentIDM) $ asPOSIX time

extractUploadName :: SubmissionDB -> LowerText
extractUploadName (SubmissionDB _ un _ _ _ _ _ _ _ _ _) = un

extractStudentID :: SubmissionDB -> Word64
extractStudentID (SubmissionDB _ _ _ _ authorID _ _ _ _ _ _) = fromIntegral $ fromSqlKey authorID

extractIsSuppressed :: SubmissionDB -> Bool
extractIsSuppressed (SubmissionDB _ _ _ _ _ isSuppressed _ _ _ _ _) = isSuppressed

extractNeedsModeration :: SubmissionDB -> Bool
extractNeedsModeration (SubmissionDB _ _ _ _ _ _ _ needsModeration _ _ _) = needsModeration

extractData :: SubmissionDB -> Text
extractData (SubmissionDB _ _ _ _ _ _ _ _ _ extraData _) = extraData

extractSubDateAdded :: SubmissionDB -> Integer
extractSubDateAdded (SubmissionDB _ _ _ _ _ _ _ _ _ _ dateAdded) = asPOSIX dateAdded

extractEmailAddr :: TeacherDB -> LowerText
extractEmailAddr (TeacherDB addr _ _ _ _ _) = addr

extractTeacherIsConfirmed :: TeacherDB -> Bool
extractTeacherIsConfirmed (TeacherDB _ _ _ _ isConfirmed _) = isConfirmed

extractOTPPasscode :: OTPRequestDB -> Text
extractOTPPasscode (OTPRequestDB _ passcode _ _) = passcode

extractOTPBirthday :: OTPRequestDB -> UTCTime
extractOTPBirthday (OTPRequestDB _ _ birthday _) = birthday

asPOSIX :: UTCTime -> Integer
asPOSIX = utcTimeToPOSIXSeconds >>> (* 1000) >>> round
