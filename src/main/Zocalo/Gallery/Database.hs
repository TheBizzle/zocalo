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

module Zocalo.Gallery.Database(approveSubmission, checkIsOkayOTPRate, checkUserExists, confirmNewUser, forbidSubmission, logoutStudent, logoutTeacher, lookupStudentRefreshToken, lookupTeacherRefreshToken, readGalleryListings, readStarterConfigFor, readSubmissionData, readSubmissionListings, readSubmissionListingsForModeration, readTemplateName, readWhoIsTeacher, registerNewGallery, registerNewStudent, registerNewTeacher, runMigrations, setStudentRefreshToken, setTeacherRefreshToken, storeOTP, suppressSubmission, validateOTP, writeComment, writeSubmission) where

import Control.Monad.Logger(NoLoggingT, runNoLoggingT)
import Control.Monad.Trans.Reader(ReaderT)
import Control.Monad.Trans.Resource(ResourceT)

import Data.List(sortBy)
import Data.NanoID(nanoID, NanoID(NanoID), unNanoID)
import Data.Ord(comparing)
import Data.Time(addUTCTime, getCurrentTime, UTCTime)
import Data.Time.Clock.POSIX(utcTimeToPOSIXSeconds)

import Database.Persist((=.), (==.), (>=.), count, Entity(Entity, entityKey, entityVal), get, getBy, insert, insertUnique, Key, PersistEntity, PersistEntityBackend, selectFirst, selectList, SelectOpt(Asc), Unique, update, updateWhere, upsert)
import Database.Persist.Postgresql(runMigration, runSqlPersistMPool, SqlBackend, withPostgresqlPool)
import Database.Persist.Sql(fromSqlKey, toSqlKey)
import Database.Persist.TH(mkMigrate, mkPersist, share, sqlSettings)

import System.Random.MWC(createSystemRandom)

import Zocalo.Common.DBCredentials(password, username)
import Zocalo.Common.SecureToken(hashToken, SecureToken(tokenText), tokenFromText)

import Zocalo.Gallery.Auth.AuthorizedUser(AuthorizedStudent(AStudent, studentID, studentName), AuthorizedTeacher(ATeacher, teacherAddr))

import Zocalo.Gallery.ActionResult(ActionError(Duplicate, Expired, Incorrect, NotAuthorized, NotFound, Unconfirmed), ActionResult)
import Zocalo.Gallery.Comment(Comment(Comment, creationTime))
import Zocalo.Gallery.DBSnakeCase(bizzleSnakeCase)
import Zocalo.Gallery.GalleryListing(GalleryListing(GalleryListing))
import Zocalo.Gallery.LowerText(asLowerText, LowerText)
import Zocalo.Gallery.StudentUploadResponse(StudentUploadResponse(StudentUploadResponse))

import Zocalo.Gallery.Submission(
    AllSubmissions(AllSubmissions)
  , Submission(Submission)
  , SubmissionID(SubID)
  , SubmissionSendable(SubmissionSendable)
  )

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
  base64Image          Text
  authorID             StudentRefreshTokenDBId
  isSuppressed         Bool
  isForbidden          Bool
  isAwaitingModeration Bool
  metadata             Text Maybe
  extraData            Text
  dateAdded            UTCTime
  deriving Show

CommentDB
  comment  Text
  author   Text
  parent   CommentDBId Maybe
  uploadID SubmissionDBId
  time     UTCTime
  deriving Show

|]

registerNewGallery :: AuthorizedTeacher -> Text -> Text -> Bool -> Maybe Text -> Text -> IO (ActionResult NanoID)
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
        Just _   -> Success rawNanoID

readGalleryListings :: AuthorizedTeacher -> IO (ActionResult [GalleryListing])
readGalleryListings teacher =
  withTeacher teacher.teacherAddr $
    \(teacherID, _) -> do
      rows     <- withDB $ selectList [GalleryDBOwnerID ==. teacherID] [Asc GalleryDBDateAdded]
      listings <- flip mapM rows $ \(Entity subID (GalleryDB _ name template _ rawNID isPre _ desc cDate)) -> withDB $ do
        waitingCount <- count [SubmissionDBGalleryID ==. subID, SubmissionDBIsAwaitingModeration ==. True]
        rows         <- selectList [ SubmissionDBGalleryID            ==. subID
                                   , SubmissionDBIsAwaitingModeration ==. False
                                   , SubmissionDBIsForbidden          ==. False
                                   , SubmissionDBIsSuppressed         ==. False
                                   ] [Asc SubmissionDBDateAdded]
        let uploads     = map entityVal rows
        let numApproved = length uploads
        let numWaiting  = fromIntegral waitingCount
        let nid         = NanoID $ TE.encodeUtf8 rawNID
        let cTime       = asPOSIX cDate
        let lTime       = getMax cTime uploads
        return $ GalleryListing nid name template desc isPre numWaiting numApproved cTime lTime
      return $ Success listings
  where
    getMax initTime = (map extractSubDateAdded) >>> (foldr chooseLater initTime)
    chooseLater a b = if a < b then b else a

readSubmissionListings :: AuthorizedStudent -> NanoID -> IO (ActionResult AllSubmissions)
readSubmissionListings student nid =
  withGalleryNano nid $
    \(gID, (GalleryDB _ gname _ _ _ isPrescreened _ _ _)) -> withDB $ do
      entities <- selectList [ SubmissionDBGalleryID            ==. gID
                             , SubmissionDBIsAwaitingModeration ==. False
                             , SubmissionDBIsForbidden          ==. False
                             , SubmissionDBIsSuppressed         ==. False
                             ] [Asc SubmissionDBDateAdded]
      subs <- liftIO $ mapM (toSubmissionSendable (Just student) Nothing) entities
      return $ Success $ AllSubmissions gname isPrescreened subs

readSubmissionListingsForModeration :: AuthorizedTeacher -> NanoID -> IO (ActionResult [SubmissionSendable])
readSubmissionListingsForModeration teacher nid =
  withGalleryNano nid $
    \(galleryID, galleryDB) -> do
      canModerate <- (Just teacher) `ownsOneNamed` (extractGalleryName galleryDB)
      if canModerate then withDB $ do
        rows <- selectList [ SubmissionDBGalleryID            ==. galleryID
                           , SubmissionDBIsAwaitingModeration ==. True
                           ] [Asc SubmissionDBDateAdded]
        subs <- liftIO $ mapM (toSubmissionSendable Nothing $ Just teacher) rows
        return $ Success subs
      else
        return $ Failure NotAuthorized

readSubmissionData :: Maybe AuthorizedTeacher -> Maybe AuthorizedStudent -> SubmissionID -> IO (ActionResult Text)
readSubmissionData teacherM studentM subID =
  withSubmission subID $
    \(_, subDB) -> do
      pairAR <- processSubmissionAuth extractData teacherM studentM subDB
      return $ second fst pairAR

readTemplateName :: NanoID -> IO (ActionResult Text)
readTemplateName nid =
  withGalleryNano nid $
    \(_, galleryDB) -> return $ Success $ extractTemplateName galleryDB

readWhoIsTeacher :: AuthorizedTeacher -> IO (ActionResult Int64)
readWhoIsTeacher teacher =
  withTeacher teacher.teacherAddr $
    \(teacherID, _) -> return $ Success $ fromSqlKey teacherID

suppressSubmission :: Maybe AuthorizedTeacher -> Maybe AuthorizedStudent -> SubmissionID -> IO (ActionResult ())
suppressSubmission teacherM studentM subID =
  withSubmission subID $
    \(subKey, subDB) -> do
      canDeleteIt <- canDeleteSubmission teacherM studentM subDB
      if canDeleteIt then do
        withDB $ update subKey [SubmissionDBIsSuppressed =. True]
        return $ Success ()
      else
        return $ Failure NotAuthorized

forbidSubmission :: AuthorizedTeacher -> SubmissionID -> IO (ActionResult ())
forbidSubmission = moderateSubmission True

approveSubmission :: AuthorizedTeacher -> SubmissionID -> IO (ActionResult ())
approveSubmission = moderateSubmission False

moderateSubmission :: Bool -> AuthorizedTeacher -> SubmissionID -> IO (ActionResult ())
moderateSubmission isForbidden teacher submissionID =
  withSubmission submissionID $
    \(subKey, subDB) -> do
      galleryM <- withDB $ get $ extractGalleryID subDB
      case galleryM of
        Nothing      -> return $ Failure NotFound
        Just gallery -> do
          canModerate <- (Just teacher) `ownsOneNamed` (extractGalleryName gallery)
          if canModerate then withDB $ do
            update subKey [SubmissionDBIsForbidden          =. isForbidden]
            update subKey [SubmissionDBIsAwaitingModeration =.       False]
            return $ Success ()
          else
            return $ Failure NotAuthorized

writeSubmission :: AuthorizedStudent -> NanoID -> Text -> Maybe Text -> Text -> IO (ActionResult StudentUploadResponse)
writeSubmission student nid imageBytes metadata extraData =
  withGalleryNano nid $
    \(galleryID, gallery) -> do
      let studID     = student |> studentID &> fromIntegral &> toSqlKey
      gEntityMaybe  <- withDB $ selectFirst [GalleryDBGalleryName ==. (extractGalleryName gallery)] []
      let getsPreed  = maybe False (entityVal &> extractGetsPrescreened) gEntityMaybe
      timestamp     <- getCurrentTime
      let subDB      = SubmissionDB galleryID imageBytes studID False False getsPreed metadata extraData timestamp
      subID         <- withDB $ insert subDB
      return $ Success $ StudentUploadResponse $ fromIntegral $ fromSqlKey subID

readStarterConfigFor :: NanoID -> IO (ActionResult (Maybe Text))
readStarterConfigFor nid =
  withGalleryNano nid $
    \(_, galleryDB) ->
      return $ Success $ extractStarterConfig galleryDB

writeComment :: AuthorizedStudent -> Word64 -> Maybe Int64 -> Text -> IO (ActionResult ())
writeComment student uploadID parentIDM comment =
  do
    let uploadKey    = toSqlKey $ fromIntegral uploadID
    timestamp       <- getCurrentTime
    let parentDBIDM  = map toSqlKey parentIDM
    void $ withDB $ insert $ CommentDB comment student.studentName parentDBIDM uploadKey timestamp
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

canDeleteSubmission :: Maybe AuthorizedTeacher -> Maybe AuthorizedStudent -> SubmissionDB -> IO Bool
canDeleteSubmission teacherM studentM submission =
  do
    (Just (GalleryDB galleryName _ _ _ _ _ _ _ _)) <- withDB $ get submission.submissionDBGalleryID
    isOwningTeacher <- teacherM `ownsOneNamed` galleryName
    isOwningStudent <- belongsToThisStudent studentM
    return $ isOwningTeacher || isOwningStudent
  where
    belongsToThisStudent Nothing                    = return False
    belongsToThisStudent (Just (AStudent studID _)) = return $ submission |> extractStudentID &> (== studID)

checkUserExists :: LowerText -> IO Bool
checkUserExists emailAddr =
  do
    authMaybe <- withDB $ selectFirst [TeacherDBEmailAddr ==. emailAddr, TeacherDBIsConfirmed ==. True] []
    return $ isJust authMaybe

registerNewTeacher :: LowerText -> Text -> Text -> Maybe Text -> SecureToken -> IO (ActionResult ())
registerNewTeacher emailAddr firstName lastName orgM confirmationToken =
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
            let deadline  = addUTCTime (60 * 10) dateAdded
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

lookupStudentRefreshToken :: SecureToken -> IO (ActionResult AuthorizedStudent)
lookupStudentRefreshToken refreshToken =
  do
    withPair (UniqueStudentRefreshTokenHash $ hashToken refreshToken) $
      \(key, StudentRefreshTokenDB studentName _ birthday wasRevoked) -> do
        now           <- getCurrentTime
        let in180Days  = 60 * 60 * 24 * 180
        let expirDate  = in180Days `addUTCTime` birthday
        return $ if (not wasRevoked) && (now <= expirDate) then
          Success $ AStudent (fromIntegral $ fromSqlKey key) studentName
        else
          Failure Expired

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

registerNewStudent :: Text -> IO (ActionResult Int64)
registerNewStudent studentName =
  do
    now   <- getCurrentTime
    ident <- withDB $ insert (StudentRefreshTokenDB studentName "" now False)
    return $ Success $ fromSqlKey ident

setStudentRefreshToken :: AuthorizedStudent -> SecureToken -> IO (ActionResult ())
setStudentRefreshToken (AStudent studentID studentName) refreshToken =
  withStudent (fromIntegral studentID) $
    \(key, (StudentRefreshTokenDB sName _ _ wasRevoked)) -> do
      if wasRevoked then
        return $ Failure Expired
      else if studentName /= sName then
        return $ Failure Incorrect
      else do
        now             <- getCurrentTime
        let refreshHash  = hashToken refreshToken
        withDB $ update key [ StudentRefreshTokenDBHash     =. refreshHash
                            , StudentRefreshTokenDBBirthday =. now
                            ]
        return $ Success ()

setTeacherRefreshToken :: AuthorizedTeacher -> SecureToken -> IO (ActionResult ())
setTeacherRefreshToken (ATeacher emailAddr) refreshToken =
  withTeacher emailAddr $
    \(teacherID, _) -> do
      now             <- getCurrentTime
      let refreshHash  = hashToken refreshToken
      void $ withDB $ upsert (TeacherRefreshTokenDB teacherID refreshHash now False)
                             [ TeacherRefreshTokenDBHash =. refreshHash, TeacherRefreshTokenDBBirthday =. now
                             , TeacherRefreshTokenDBWasRevoked =. False]
      return $ Success ()

logoutStudent :: AuthorizedStudent -> IO (ActionResult ())
logoutStudent student =
  withStudent (fromIntegral student.studentID) $
    \(studentID, _) -> do
      withDB $ update studentID [StudentRefreshTokenDBWasRevoked =. True]
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

withSubmission :: SubmissionID -> ((SubmissionDBId, SubmissionDB) -> IO (ActionResult a)) -> IO (ActionResult a)
withSubmission (SubID subID) f =
  do
    let subKey  = toSqlKey $ fromIntegral subID
    subM       <- withDB $ get subKey
    case subM of
      Nothing    -> return $ Failure NotFound
      Just subDB -> f (subKey, subDB)

withStudent :: Int64 -> ((StudentRefreshTokenDBId, StudentRefreshTokenDB) -> IO (ActionResult a)) -> IO (ActionResult a)
withStudent studentID f =
  do
    let studentKey  = toSqlKey studentID
    studentM       <- withDB $ get studentKey
    case studentM of
      Nothing        -> return $ Failure NotFound
      Just studentDB -> f (studentKey, studentDB)

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

withPair :: (PersistEntity e, PersistEntityBackend e ~ SqlBackend) =>
            Unique e -> ((Key e, e) -> IO (ActionResult a)) -> IO (ActionResult a)
withPair key f =
  do
    entityM <- withDB $ getBy key
    case entityM of
      Nothing               -> return $ Failure NotFound
      Just (Entity xID xDB) -> f (xID, xDB)

toSubmissionSendable :: Maybe AuthorizedStudent -> Maybe AuthorizedTeacher -> Entity SubmissionDB ->
                        IO SubmissionSendable
toSubmissionSendable studentM teacherM entity =
  do
    let key       = entityKey entity
    let subID     = fromIntegral $ fromSqlKey key
    let val       = entityVal entity
    uploaderM    <- liftIO $ withDB $ get $ case val of (SubmissionDB _ _ uid _ _ _ _ _ _) -> uid
    let uploader  = maybe "<unknown>" extractStudentName uploaderM
    canDelete    <- liftIO $ canDeleteSubmission teacherM studentM val
    commentRows  <- liftIO $ withDB $ selectList [CommentDBUploadID ==. key] [Asc CommentDBTime]
    let comments  = commentRows |> (map dbToComment) &> (sortBy $ comparing creationTime)
    return $ case dbToSubmission subID val of
      (Submission xid b64 sid meta time) ->
        let xidder = fromIntegral xid
            isMine = maybe False (studentID &> (== sid)) studentM
        in
          SubmissionSendable xidder uploader b64 isMine canDelete meta comments time

extractGalleryName :: GalleryDB -> LowerText
extractGalleryName (GalleryDB gn _ _ _ _ _ _ _ _) = gn

extractTemplateName :: GalleryDB -> Text
extractTemplateName (GalleryDB _ _ tn _ _ _ _ _ _) = tn

extractGetsPrescreened :: GalleryDB -> Bool
extractGetsPrescreened (GalleryDB _ _ _ _ _ gp _ _ _) = gp

extractStarterConfig :: GalleryDB -> Maybe Text
extractStarterConfig (GalleryDB _ _ _ _ _ _ sc _ _) = sc

dbToSubmission :: Word64 -> SubmissionDB -> Submission
dbToSubmission subID (SubmissionDB _ image studentID _ _ _ metadata _ time) =
  Submission subID image (fromIntegral $ fromSqlKey studentID) metadata $ asPOSIX time

dbToComment :: (Entity CommentDB) -> Comment
dbToComment (Entity cid (CommentDB comment author parentIDM _ time)) =
  Comment (fromSqlKey cid) comment author (map fromSqlKey parentIDM) $ asPOSIX time

extractStudentName :: StudentRefreshTokenDB -> Text
extractStudentName (StudentRefreshTokenDB name _ _ _) = name

extractGalleryID :: SubmissionDB -> GalleryDBId
extractGalleryID (SubmissionDB gid _ _ _ _ _ _ _ _) = gid

extractStudentID :: SubmissionDB -> Word64
extractStudentID (SubmissionDB _ _ authorID _ _ _ _ _ _) = fromIntegral $ fromSqlKey authorID

extractIsSuppressed :: SubmissionDB -> Bool
extractIsSuppressed (SubmissionDB _ _ _ isSuppressed _ _ _ _ _) = isSuppressed

extractNeedsModeration :: SubmissionDB -> Bool
extractNeedsModeration (SubmissionDB _ _ _ _ _ needsModeration _ _ _) = needsModeration

extractData :: SubmissionDB -> Text
extractData (SubmissionDB _ _ _ _ _ _ _ extraData _) = extraData

extractSubDateAdded :: SubmissionDB -> Integer
extractSubDateAdded (SubmissionDB _ _ _ _ _ _ _ _ dateAdded) = asPOSIX dateAdded

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
