module Zocalo.Gallery.Controller(routes, runMigrations) where

import Data.CaseInsensitive(CI)

import Snap.Core(getHeader, getParam, getsRequest, Method(DELETE, GET, POST), Snap, writeBS, writeText)
import Snap.Util.FileServe(serveDirectory)
import Snap.Util.GZip(withCompression)

import System.Directory(getDirectoryContents)

import Zocalo.Common.SnapHelpers(
    allowingCORS, Arg(Arg), asBool, asNanoID, asToken, decodeText, encodeText, failWith, free
  , getParamV, getParamVM, handle1, handle2, handle3, notEmpty, notifyBadParams, ok
  , succeed, withFileUploads
  )

import Zocalo.Gallery.Auth.FancyAuth(
    issueNewStudentTokens, issueNewTeacherTokens, issueTotallyNewStudentTokens, validateStudentAccessToken
  , validateStudentRefreshToken, validateTeacherAccessToken, validateTeacherRefreshToken
  )

import Zocalo.Gallery.Auth.AuthorizedUser(AuthorizedStudent(studentID), AuthorizedTeacher)

import Zocalo.Gallery.ActionResult(
    ActionError(Duplicate, Expired, Incorrect, InternalError, Malformed, NotAuthorized, NotFound, Unconfirmed)
  , ActionResult
  )

import Zocalo.Gallery.OldAuth(setUpNewUser, sendOTP)

import Zocalo.Gallery.Database(
    approveSubmission, checkUserExists, confirmNewUser, forbidSubmission, logoutStudent, logoutTeacher
  , readCommentsFor, readGalleryListings, readStarterConfigFor, readSubmissionData, readSubmissionsLite
  , readSubmissionListings, readSubmissionListingsForModeration, readWhoIsTeacher, registerNewGallery
  , readTemplateName, registerNewTeacher, runMigrations, storeOTP, suppressSubmission, validateOTP
  , writeComment, writeSubmission
  )

import Zocalo.Gallery.LowerText(asLowerText, lowText)

import Zocalo.Gallery.Submission(Submission(Submission), SubmissionSendable(SubmissionSendable))

import qualified Data.ByteString.Base64 as Base64
import qualified Data.List              as List
import qualified Data.Map               as Map
import qualified Data.Text.Encoding     as TextEncoding
import qualified Data.UUID              as UUID
import qualified Data.UUID.V4           as UUIDGen
import qualified Text.Read              as TRead


routes :: [(ByteString, Snap ())]
routes = [ ("echo/:param"                                     ,      ac POST   handleEchoData)
         , ("api/version"                                     ,      ac GET    handleAPIVersion)
         , ("api/auth/student/fresh-cookies"                  ,      ac POST   handleNewStudent)
         , ("api/auth/student/logout"                         ,      ac POST   handleStudentLogout)
         , ("api/auth/student/refresh"                        ,      ac POST   handleStudentTokenRefresh)
         , ("api/auth/teacher/refresh"                        ,      ac POST   handleTeacherTokenRefresh)
         , ("api/auth/teacher/register"                       ,      ac POST   handleRegister)
         , ("api/auth/teacher/confirm/:token"                 ,      ac GET    handleTeacherAuthConfirm)
         , ("api/auth/teacher/request-otp"                    ,      ac POST   handleRequestOTP)
         , ("api/auth/teacher/verify-otp"                     ,      ac POST   handleVerifyOTP)
         , ("api/auth/teacher/is-logged-in/"                  ,      ac GET    handleTeacherIsLoggedIn)
         , ("api/auth/teacher/logout"                         ,      ac POST   handleTeacherLogout)
         , ("api/auth/teacher/verify-cookie"                  ,      ac POST   handleRegister)
         , ("api/auth/teacher/who-am-i"                       , wc $ ac GET    handleWhoIsTeacher)
         , ("api/galleries/public/:nano-id/starter-config"    , wc $ ac GET    handleGetStarterConfig)
         , ("api/galleries/public/:nano-id/template-name"     ,      ac GET    handleGetTemplateName)
         , ("api/galleries/teacher/new-session"               ,      ac POST   handleNewSessionWithParams)
         , ("api/galleries/teacher/overview"                  , wc $ ac GET    handleListGalleries)
         , ("api/galleries/:nano-id/:item-id/student/comment" ,      ac POST   handleSubmitComment)
         , ("api/galleries/:nano-id/:item-id/student/comments", wc $ ac GET    handleGetComments)
         , ("api/galleries/:nano-id/student/submission"       ,      ac POST   handleUploadFile)
         , ("api/galleries/:nano-id/student/submissions"      , wc $ ac GET    handleListSession)

         , ("uploads/:session-id/:item-id"                                , wc $ ac GET    handleDownloadItem)
         , ("uploads/:session-id/:item-id"                                ,      ac DELETE handleSuppressItem)
         , ("uploads/:session-id/:item-id/:token/approve"                 ,      ac POST   handleApproveItem)
         , ("uploads/:session-id/:item-id/:token/reject"                  ,      ac POST   handleForbidItem)
         , ("mod-listings/:session-id/:token"                             , wc $ ac GET    handleListSessionForModeration)
         , ("data-lite"                                                   , wc $ ac POST   handleSubmissionsLite)
         , ("uploader-token"                                              ,      ac GET    handleGetUploaderToken)
         , ("gallery-types"                                               ,      ac GET    handleGetGalleryTypes)

         , ("/assets"                                                     ,                serveDirectory "frontend/dist/assets")
         ]
  where
    wc = withCompression
    ac = allowingCORS

handleEchoData :: Snap ()
handleEchoData = handle1 (Arg "param" notEmpty) $ \param -> withFileUploads $ \fileMap -> do
  paramValueM <- getParam $ TextEncoding.encodeUtf8 param
  let valueM = paramValueM <|> (Map.lookup param fileMap)
  case valueM of
    Nothing      -> notifyBadParams [param]
    (Just value) -> writeBS value

handleNewSessionWithParams :: Snap ()
handleNewSessionWithParams =
  ifAuthorizedTeacher $ \teacher -> withFileUploads $ \fileMap -> do
    gps      <- getParamVM fileMap $ Arg "gets-prescreened" asBool
    template <- getParamVM fileMap $ Arg "template"         notEmpty
    sid      <- getParamVM fileMap $ Arg "gallery-name"     notEmpty
    desc     <- getParamVM fileMap $ Arg "description"      free
    let config = map genConfigMaybe $ lookupParam "config" fileMap
    let tupleV = (,,,,) <$> template <*> sid <*> gps <*> config <*> desc
    bimapM_ notifyBadParams (_handleNewSessionWithParams teacher) tupleV
  where
    lookupParam param fileMap = maybe (Failure [param]) Success $ Map.lookup param fileMap

    genConfigMaybe     "" = Nothing
    genConfigMaybe config = Just $ TextEncoding.decodeUtf8 config

    _handleNewSessionWithParams :: AuthorizedTeacher -> (Text, Text, Bool, Maybe Text, Text) -> Snap ()
    _handleNewSessionWithParams teacher (template, name, getsPrescreened, config, desc) =
      do
        result <- liftIO $ registerNewGallery teacher template name getsPrescreened config desc
        whenSuccess result $ encodeText &> succeed "text/plain"

handleListGalleries :: Snap ()
handleListGalleries =
  ifAuthorizedTeacher $ \teacher ->
    do
      listingsResult <- liftIO $ readGalleryListings teacher
      whenSuccess listingsResult $ encodeText &> succeed "application/json"

handleListSession :: Snap ()
handleListSession =
  ifAuthorizedStudent $ \student ->
    handle1 (Arg "nano-id" asNanoID) $
      \nanoID ->
        do
          listingsResult <- liftIO $ readSubmissionListings student nanoID
          whenSuccess listingsResult $ encodeText &> succeed "application/json"

handleListSessionForModeration :: Snap ()
handleListSessionForModeration =
  ifAuthorizedTeacher $ \teacher ->
    handle1 (Arg "session-id" notEmpty) $
      \sessionID ->
        do
          listingsResult <- liftIO $ readSubmissionListingsForModeration teacher $ asLowerText sessionID
          whenSuccess listingsResult $ (map lowText) &> encodeText &> succeed "application/json"

handleWhoIsTeacher :: Snap ()
handleWhoIsTeacher =
  ifAuthorizedTeacher $ \teacher ->
    do
      resultV <- liftIO $ readWhoIsTeacher teacher
      whenSuccess (map showText resultV) $ succeed "text/plain"

handleDownloadItem :: Snap ()
handleDownloadItem =
  handle2 (Arg "nano-id" asNanoID, Arg "item-id" notEmpty) $
    \(nanoID, uploadID) ->
      withAuthorizations $ \teacherM studM -> do
        let uid   = asLowerText uploadID
        dlResult <- liftIO $ readSubmissionData teacherM studM nanoID uid
        whenSuccess dlResult $ succeed "text/plain"

handleSuppressItem :: Snap ()
handleSuppressItem =
  handle2 (Arg "nano-id" asNanoID, Arg "item-id" notEmpty) $
    \(nanoID, uploadID) ->
      withAuthorizations $ \teacherM studM -> do
        do
          let uid = asLowerText uploadID
          result <- liftIO $ suppressSubmission teacherM studM nanoID uid
          whenSuccess result $ const $ succeed "text/plain" "Submission successfully suppressed"

handleApproveItem :: Snap ()
handleApproveItem =
  ifAuthorizedTeacher $ \teacher ->
    handle2 (Arg "session-id" notEmpty, Arg "item-id" notEmpty) $
      \(sessionID, uploadID) ->
        do
          let sid = asLowerText sessionID
          let uid = asLowerText uploadID
          result <- liftIO $ approveSubmission teacher sid uid
          whenSuccess result $ const $ succeed "text/plain" "Submission approved"

handleForbidItem :: Snap ()
handleForbidItem =
  ifAuthorizedTeacher $ \teacher ->
    handle2 (Arg "session-id" notEmpty, Arg "item-id" notEmpty) $
      \(sessionID, uploadID) ->
        do
          let sid = asLowerText sessionID
          let uid = asLowerText uploadID
          result <- liftIO $ forbidSubmission teacher sid uid
          whenSuccess result $ const $ succeed "text/plain" "Submission successfully forbidden"

handleGetUploaderToken :: Snap ()
handleGetUploaderToken = genToken |> liftIO &>= (succeed "text/plain")

genToken :: IO Text
genToken = UUIDGen.nextRandom <&> UUID.toText

handleSubmissionsLite :: Snap ()
handleSubmissionsLite =
  handle2 (Arg "nano-id" asNanoID, Arg "names" free) $
    \(nanoID, namesText) ->
      withAuthorizations $ \teacherM studM -> do
        let namesM = decodeText namesText :: Maybe [Text]
        case namesM of
          Nothing      -> failWith 422 $ writeText $ "Parameter 'names' is invalid JSON: " <> namesText
          (Just names) -> do
            pairsResult <- liftIO $ readSubmissionsLite teacherM studM nanoID names
            whenSuccess pairsResult $ (map $ convert studM) &> encodeText &> succeed "application/json"
  where
    convert studM (Submission xid name b64 sid meta time, canDelete) =
      let xidder  = fromIntegral xid
          studIDM = maybe False (studentID &> (== sid)) studM
      in
        SubmissionSendable xidder name b64 studIDM canDelete meta time

handleUploadFile :: Snap ()
handleUploadFile =
  ifAuthorizedStudent $ \student -> withFileUploads $ \fileMap -> do
    let datum   = lookupParam "data"  fileMap
    let image   = lookupParam "image" fileMap
    nanoID     <- getParamVM fileMap $ Arg "nano-id"  asNanoID
    metadata   <- getParamVM fileMap $ Arg "metadata" notEmpty
    let meta    = (map Just metadata) <> (Success Nothing)
    let tupleV  = (,,,) <$> nanoID <*> image <*> meta <*> datum
    case tupleV of
      Failure es    -> notifyBadParams es
      Success tuple -> do
        uploadNameResult <- liftIO $ (uncurry4 $ writeSubmission student) tuple
        whenSuccess uploadNameResult $ encodeText &> succeed "text/plain"
  where
    lookupParam param fileMap =
      case Map.lookup param fileMap of
        Nothing       -> Failure [param]
        (Just result) -> Success $
          case TextEncoding.decodeUtf8' result of
            Right good -> good
            Left     _ -> TextEncoding.decodeUtf8 $ Base64.encode result

handleGetComments :: Snap ()
handleGetComments =
  handle2 (Arg "nano-id" asNanoID, Arg "item-id" notEmpty) $
    \(nanoID, uploadID) -> do
      let uid = asLowerText uploadID
      commentsResult <- liftIO $ readCommentsFor nanoID uid
      whenSuccess commentsResult $ encodeText &> succeed "application/json"

handleSubmitComment :: Snap ()
handleSubmitComment =
  ifAuthorizedStudent $ \student -> withFileUploads $ \fileMap -> do
    nanoIDV     <- getParamVM fileMap $ Arg "nano-id" asNanoID
    uploadIDV   <- getParamVM fileMap $ Arg "item-id" notEmpty
    parentV     <- getParamVM fileMap $ Arg "parent"  free
    commentV    <- getParamVM fileMap $ Arg "comment" notEmpty
    let uidV     = map asLowerText uploadIDV
    let tupleV   = (,,) <$> nanoIDV <*> uidV <*> commentV
    let pidM     = validation (const Nothing) (asString &> TRead.readMaybe) parentV
    bimapM_ notifyBadParams (helper student pidM) tupleV
  where
    helper student pidM (nid, uid, comment) =
      do
        result <- liftIO $ writeComment student nid uid pidM comment
        whenSuccess result $ const $ writeText ""

handleGetTemplateName :: Snap ()
handleGetTemplateName =
  handle1 (Arg "nano-id" asNanoID) $ \nanoID ->
    do
      templateNameResult <- liftIO $ readTemplateName nanoID
      whenSuccess templateNameResult writeText

handleGetStarterConfig :: Snap ()
handleGetStarterConfig =
  handle1 (Arg "nano-id" asNanoID) $ \nanoID ->
    do
      let errorMsg        = "No starter config has been uploaded for gallery '" <> (showText nanoID) <> "'."
      starterMaybeResult <- liftIO $ readStarterConfigFor nanoID
      whenSuccess starterMaybeResult $
        \case Nothing        -> failWith 404 $ writeText errorMsg
              (Just starter) -> succeed "text/plain" starter

handleGetGalleryTypes :: Snap ()
handleGetGalleryTypes =
  do
    paths <- liftIO $ getDirectoryContents "gallery"
    let truePaths = List.filter (not . (flip elem) [".", ".."]) paths
    (encodeText &> (succeed "application/json")) truePaths

handleRegister :: Snap ()
handleRegister =
  handle3 (Arg "email" notEmpty, Arg "firstName" notEmpty, Arg "lastName" notEmpty) $
    \(rawAddr, firstName, lastName) ->
      do
        orgV       <- getParamV $ Arg "organization" notEmpty
        let orgM    = validation (const Nothing) Just orgV
        let addr    = asLowerText rawAddr
        isExistent <- liftIO $ checkUserExists addr
        if not isExistent then do
         returnAddress     <- genRegistrationURL
         registrationToken <- liftIO $ setUpNewUser       addr returnAddress
         result            <- liftIO $ registerNewTeacher addr firstName lastName orgM registrationToken
         whenSuccess result $ const ok
        else
          failWith 409 $ writeText $ "An account for that e-mail address already exists."

handleTeacherAuthConfirm :: Snap ()
handleTeacherAuthConfirm =
  handle1 (Arg "token" asToken) $ \token ->
    do
      emailResult <- liftIO $ confirmNewUser token
      whenSuccess emailResult $ \teacher -> do
        accessTokenResult <- issueNewTeacherTokens teacher
        whenSuccess accessTokenResult $ succeed "text/plain"

handleRequestOTP :: Snap ()
handleRequestOTP =
  handle1 (Arg "email" notEmpty) $ \rawAddr ->
    do
      let addr   = asLowerText rawAddr
      otpResult <- liftIO $ sendOTP addr
      whenSuccess otpResult $ \otp -> do
        result <- liftIO $ storeOTP addr otp
        whenSuccess result $ const ok

handleVerifyOTP :: Snap ()
handleVerifyOTP =
  handle2 (Arg "email" notEmpty, Arg "passcode" notEmpty) $
    \(emailAddr, passcode) ->
      do
        result <- liftIO $ validateOTP (asLowerText emailAddr) passcode
        whenSuccess result $ \teacher -> do
          accessTokenResult <- issueNewTeacherTokens teacher
          whenSuccess accessTokenResult $ succeed "text/plain"

handleTeacherIsLoggedIn :: Snap ()
handleTeacherIsLoggedIn =
  do
    vldtn <- validateTeacherAccessToken
    validation (const $ succeed "text/plain" "0") (const $ succeed "text/plain" "1") vldtn

handleTeacherLogout :: Snap ()
handleTeacherLogout =
  do
    teacherV <- validateTeacherRefreshToken
    whenSuccess teacherV $ \teacher -> do
      result <- liftIO $ logoutTeacher teacher
      whenSuccess result $ const ok

handleTeacherTokenRefresh :: Snap ()
handleTeacherTokenRefresh =
  do
    teacherResult <- validateTeacherRefreshToken
    whenSuccess teacherResult $ \teacher -> do
      accessTokenResult <- issueNewTeacherTokens teacher
      whenSuccess accessTokenResult $ succeed "text/plain"

genRegistrationURL :: Snap Text
genRegistrationURL =
  do
    hostM      <- getHeaderText "Host"
    originM    <- getHeaderText "Origin"
    let host    = fromMaybe "" hostM
    let origin  = fromMaybe "" originM
    let proto   = if origin == ("http://" <> host) then "http" else "https"
    return $ proto <> "://" <> host <> "/galleries/teacher/confirm/"

handleNewStudent :: Snap ()
handleNewStudent =
  handle1 (Arg "username" notEmpty) $ \username ->
    do
      accessTokenResult <- issueTotallyNewStudentTokens username
      whenSuccess accessTokenResult $ succeed "text/plain"

handleStudentTokenRefresh :: Snap ()
handleStudentTokenRefresh =
  do
    studentResult <- validateStudentRefreshToken
    whenSuccess studentResult $ \student -> do
      accessTokenResult <- issueNewStudentTokens student
      whenSuccess accessTokenResult $ succeed "text/plain"

handleStudentLogout :: Snap ()
handleStudentLogout =
  do
    studentResult <- validateStudentRefreshToken
    whenSuccess studentResult $ \student -> do
      result <- liftIO $ logoutStudent student
      whenSuccess result $ const ok

getHeaderText :: CI ByteString -> Snap (Maybe Text)
getHeaderText headerName =
  do
    headerValue <- getsRequest $ getHeader headerName
    return $ map TextEncoding.decodeUtf8 headerValue

whenSuccess :: ActionResult a -> (a -> Snap ()) -> Snap ()
whenSuccess (Success             x) f = f x
whenSuccess (Failure     Malformed) _ = failWith 400 $ writeText $ "The supplied data was malformed."
whenSuccess (Failure NotAuthorized) _ = failWith 401 $ writeText $ "Your request does not have the proper authentication cookies for that."
whenSuccess (Failure     Incorrect) _ = failWith 401 $ writeText $ "Incorrect passcode"
whenSuccess (Failure   Unconfirmed) _ = failWith 403 $ writeText $ "This user account has not been confirmed.  Please click the link in the confirmation e-mail and then try again."
whenSuccess (Failure       Expired) _ = failWith 403 $ writeText $ "Your access to this resource has expired.  Please start over."
whenSuccess (Failure      NotFound) _ = failWith 404 $ writeText $ "That user does not exist"
whenSuccess (Failure     Duplicate) _ = failWith 409 $ writeText $ "Something just like that already exists."
whenSuccess (Failure InternalError) _ = failWith 500 $ writeText $ "Internal error"

handleAPIVersion :: Snap ()
handleAPIVersion = writeText "2.0.0"

withAuthorizations :: (Maybe AuthorizedTeacher -> Maybe AuthorizedStudent -> Snap a) -> Snap a
withAuthorizations f =
  do
    teacherV <- validateTeacherAccessToken
    studentV <- validateStudentAccessToken
    f (validation (const Nothing) Just teacherV) (validation (const Nothing) Just studentV)

ifAuthorizedStudent :: (AuthorizedStudent -> Snap ()) -> Snap ()
ifAuthorizedStudent ifGood =
  do
    studentV <- validateStudentAccessToken
    validation (const $ failWith 401 $ writeText "No valid student access token.") ifGood studentV

ifAuthorizedTeacher :: (AuthorizedTeacher -> Snap ()) -> Snap ()
ifAuthorizedTeacher ifGood =
  do
    teacherV <- validateTeacherAccessToken
    validation (const $ failWith 401 $ writeText "No valid teacher access token.") ifGood teacherV
