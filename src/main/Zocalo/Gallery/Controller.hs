module Zocalo.Gallery.Controller(routes, runMigrations) where

import Data.CaseInsensitive(CI)

import qualified Data.List          as List
import qualified Data.Map           as Map
import qualified Data.Text.Encoding as TextEncoding
import qualified Data.UUID          as UUID
import qualified Data.UUID.V4       as UUIDGen

import Snap.Core(getHeader, getParam, getsRequest, Method(DELETE, GET, POST), Snap, writeText)
import Snap.Util.FileServe(serveDirectory)
import Snap.Util.GZip(withCompression)

import System.Directory(getDirectoryContents)

import Zocalo.Common.SnapHelpers(
    allowingCORS, Arg(Arg), asBool, asNonNegInt, asToken, decodeText, encodeText, failWith, free
  , getParamV, getParamVM, handle1, handle2, handle3, handle6, notEmpty, notifyBadParams, ok
  , succeed, withFileUploads
  )

import Zocalo.Gallery.Auth.FancyAuth(
    issueNewTeacherTokens, validateStudentAccessToken, validateTeacherAccessToken, validateTeacherRefreshToken
  )

import Zocalo.Gallery.Auth.AuthorizedUser(AuthorizedStudent(studentID), AuthorizedTeacher(ATeacher))

import Zocalo.Gallery.ActionResult(
    ActionError(Duplicate, Expired, Incorrect, InternalError, Malformed, NotAuthorized, NotFound, Unconfirmed)
  , ActionResult
  )

import Zocalo.Gallery.OldAuth(setUpNewUser, sendOTP)

import Zocalo.Gallery.Database(
    approveSubmission, checkUserExists, confirmNewUser, forbidSubmission, logoutTeacher, readCommentsFor
  , readGalleryListings, readStarterConfigFor, readSubmissionData, readSubmissionsLite
  , readSubmissionListings, readSubmissionListingsForModeration, readWhoIsTeacher, registerNewGallery
  , readTemplateName, registerNewUser, runMigrations, storeOTP, suppressSubmission, validateOTP
  , writeComment, writeSubmission
  )

import Zocalo.Gallery.Submission(Submission(Submission), SubmissionSendable(SubmissionSendable))


routes :: [(ByteString, Snap ())]
routes = [ ("echo/:param"                                                   ,      ac POST   handleEchoData)
         , ("api/version"                                                   ,      ac GET    handleAPIVersion)
         , ("api/auth/teacher/refresh"                                      ,      ac POST   handleTeacherTokenRefresh)
         , ("api/auth/teacher/register"                                     ,      ac POST   handleRegister)
         , ("api/auth/teacher/confirm/:token"                               ,      ac GET    handleAuthConfirm)
         , ("api/auth/teacher/request-otp"                                  ,      ac POST   handleRequestOTP)
         , ("api/auth/teacher/verify-otp"                                   ,      ac POST   handleVerifyOTP)
         , ("api/auth/teacher/is-logged-in/"                                ,      ac GET    handleTeacherIsLoggedIn)
         , ("api/auth/teacher/logout"                                       ,      ac POST   handleLogout)
         , ("api/auth/teacher/verify-cookie"                                ,      ac POST   handleRegister)
         , ("api/auth/teacher/who-am-i"                                     , wc $ ac GET    handleWhoIsTeacher)
         , ("api/galleries/public/comments/:teacher-id/:session-id/:item-id", wc $ ac GET    handleGetComments)
         , ("api/galleries/public/:session-id/template-name"                ,      ac GET    handleGetTemplateName)
         , ("api/galleries/student/comments"                                ,      ac POST   handleSubmitComment)
         , ("api/galleries/teacher/new-session"                             ,      ac POST   handleNewSessionWithParams)
         , ("api/galleries/teacher/overview"                                , wc $ ac GET    handleListGalleries)

         , ("uploads"                                                     ,      ac POST   handleUpload)
         , ("file-uploads"                                                ,      ac POST   handleUploadFile)
         , ("uploads/:session-id/:item-id"                                , wc $ ac GET    handleDownloadItem)
         , ("uploads/:session-id/:item-id"                                ,      ac DELETE handleSuppressItem)
         , ("uploads/:session-id/:item-id/:token/approve"                 ,      ac POST   handleApproveItem)
         , ("uploads/:session-id/:item-id/:token/reject"                  ,      ac POST   handleForbidItem)
         , ("starter-config/:session-id"                                  , wc $ ac GET    handleGetStarterConfig)
         , ("listings/:session-id"                                        , wc $ ac GET    handleListSession)
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
  prm <- getParam $ TextEncoding.encodeUtf8 param
  maybe (notifyBadParams [param]) writeText ((map TextEncoding.decodeUtf8 prm) <|> (Map.lookup param fileMap))

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
    genConfigMaybe config     = if config == "" then Nothing else Just config

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
  handle2 (Arg "teacher-id" asNonNegInt, Arg "session-id" notEmpty) $
    \(teacherID, sessionID) ->
      do
        listingsResult <- liftIO $ readSubmissionListings teacherID sessionID
        whenSuccess listingsResult $ encodeText &> succeed "application/json"

handleListSessionForModeration :: Snap ()
handleListSessionForModeration =
  ifAuthorizedTeacher $ \teacher ->
    handle1 (Arg "session-id" notEmpty) $
      \sessionID ->
        do
          listingsResult <- liftIO $ readSubmissionListingsForModeration teacher sessionID
          whenSuccess listingsResult $ encodeText &> succeed "application/json"

handleWhoIsTeacher :: Snap ()
handleWhoIsTeacher =
  ifAuthorizedTeacher $ \teacher ->
    do
      resultV <- liftIO $ readWhoIsTeacher teacher
      whenSuccess (map showText resultV) $ succeed "text/plain"

handleDownloadItem :: Snap ()
handleDownloadItem =
  handle3 (Arg "teacher-id" asNonNegInt, Arg "session-id" notEmpty, Arg "item-id" notEmpty) $
    \(teacherID, sessionID, uploadID) ->
      withAuthorizations $ \teacherM studM -> do
        dlResult <- liftIO $ readSubmissionData teacherM studM teacherID sessionID uploadID
        whenSuccess dlResult $ succeed "text/plain"

handleSuppressItem :: Snap ()
handleSuppressItem =
  handle3 (Arg "teacher-id" asNonNegInt, Arg "session-id" notEmpty, Arg "item-id" notEmpty) $
    \(teacherID, sessionID, uploadID) ->
      withAuthorizations $ \teacherM studM -> do
        do
          result <- liftIO $ suppressSubmission teacherM studM teacherID sessionID uploadID
          whenSuccess result $ const $ succeed "text/plain" "Submission successfully suppressed"

handleApproveItem :: Snap ()
handleApproveItem =
  ifAuthorizedTeacher $ \teacher ->
    handle2 (Arg "session-id" notEmpty, Arg "item-id" notEmpty) $
      \(sessionID, uploadID) ->
        do
          result <- liftIO $ approveSubmission teacher sessionID uploadID
          whenSuccess result $ const $ succeed "text/plain" "Submission approved"

handleForbidItem :: Snap ()
handleForbidItem =
  ifAuthorizedTeacher $ \teacher ->
    handle2 (Arg "session-id" notEmpty, Arg "item-id" notEmpty) $
      \(sessionID, uploadID) ->
        do
          result <- liftIO $ forbidSubmission teacher sessionID uploadID
          whenSuccess result $ const $ succeed "text/plain" "Submission successfully forbidden"

handleGetUploaderToken :: Snap ()
handleGetUploaderToken = genToken |> liftIO &>= (succeed "text/plain")

genToken :: IO Text
genToken = UUIDGen.nextRandom <&> UUID.toText

handleSubmissionsLite :: Snap ()
handleSubmissionsLite =
  handle3 (Arg "teacher-id" asNonNegInt, Arg "session-id" notEmpty, Arg "names" free) $
    \(teacherID, sessionID, namesText) ->
      withAuthorizations $ \teacherM studM -> do
        let namesM = decodeText namesText :: Maybe [Text]
        case namesM of
          Nothing      -> failWith 422 $ writeText $ "Parameter 'names' is invalid JSON: " <> namesText
          (Just names) -> do
            pairsResult <- liftIO $ readSubmissionsLite teacherM studM teacherID sessionID names
            whenSuccess pairsResult $ (map $ convert studM) &> encodeText &> succeed "application/json"
  where
    convert studM (Submission name b64 sid meta, canDelete) =
      SubmissionSendable name b64 (maybe False (studentID &> (== sid)) studM) canDelete meta

handleUpload :: Snap ()
handleUpload =
  do
    dataV  <- getParamV $ Arg "data"  free
    imageV <- getParamV $ Arg "image" free
    handleUploadHelper dataV imageV Map.empty

handleUploadFile :: Snap ()
handleUploadFile = withFileUploads $ \fileMap -> handleUploadHelper (lookupParam "data" fileMap) (lookupParam "image" fileMap) fileMap
  where
    lookupParam param fileMap = maybe (Failure [param]) Success $ Map.lookup param fileMap

handleUploadHelper :: Validation [Text] Text -> Validation [Text] Text -> Map Text Text -> Snap ()
handleUploadHelper datum image fileMap =
  ifAuthorizedStudent $ \student ->
    do
      teacherID <- getParamVM fileMap $ Arg "teacher-id" asNonNegInt
      sessionID <- getParamVM fileMap $ Arg "session-id" notEmpty
      metadata  <- getParamVM fileMap $ Arg "metadata"   notEmpty
      let meta   = (map Just metadata) <> (Success Nothing)
      let tupleV = (,,,,) <$> teacherID <*> sessionID <*> image <*> meta <*> datum
      case tupleV of
        Failure es    -> notifyBadParams es
        Success tuple -> do
          uploadNameResult <- liftIO $ (uncurry5 $ writeSubmission student) tuple
          whenSuccess uploadNameResult $ succeed "text/plain"

handleGetComments :: Snap ()
handleGetComments = handle3 (Arg "teacher-id" asNonNegInt, Arg "session-id" notEmpty, Arg "item-id" notEmpty) $
  \(teacherID, sessionName, uploadName) -> do
    commentsResult <- liftIO $ readCommentsFor teacherID sessionName uploadName
    whenSuccess commentsResult $ encodeText &> succeed "application/json"

handleSubmitComment :: Snap ()
handleSubmitComment =
  handle6 ( Arg "teacher-id" asNonNegInt, Arg "session-id" notEmpty, Arg "item-id" notEmpty
          , Arg "parent" free, Arg "author" notEmpty, Arg "comment" notEmpty) $
    \(teacherID, sessionName, uploadName, parent, author, comment) -> do
      result <- liftIO $ writeComment teacherID sessionName uploadName (UUID.fromText parent) author comment
      whenSuccess result $ const $ writeText ""

handleGetTemplateName :: Snap ()
handleGetTemplateName =
  handle2 (Arg "teacher-id" asNonNegInt, Arg "session-id" notEmpty) $ \(teacherID, sessionID) ->
    do
      templateNameResult <- liftIO $ readTemplateName teacherID sessionID
      whenSuccess templateNameResult writeText

handleGetStarterConfig :: Snap ()
handleGetStarterConfig =
  handle2 (Arg "teacher-id" asNonNegInt, Arg "session-id" notEmpty) $ \(teacherID, sessionID) ->
    do
      let ident           = "(" <> (showText teacherID) <> " | " <> sessionID <> ")"
      starterMaybeResult <- liftIO $ readStarterConfigFor teacherID sessionID
      whenSuccess starterMaybeResult $
        \case Nothing        -> failWith 404 $ writeText $ "No starter config has been uploaded for gallery '" <> ident <> "'."
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
    \(email, firstName, lastName) ->
      do
        orgV       <- getParamV $ Arg "organization" notEmpty
        let orgM    = validation (const Nothing) Just orgV
        isExistent <- liftIO $ checkUserExists email
        if not isExistent then do
         returnAddress     <- genRegistrationURL
         registrationToken <- liftIO $    setUpNewUser email returnAddress
         result            <- liftIO $ registerNewUser email firstName lastName orgM registrationToken
         whenSuccess result $ const ok
        else
          failWith 409 $ writeText $ "An account for that e-mail address already exists."

handleAuthConfirm :: Snap ()
handleAuthConfirm =
  handle1 (Arg "token" asToken) $ \token ->
    do
      emailResult <- liftIO $ confirmNewUser token
      whenSuccess emailResult $ \(ATeacher emailAddr) -> do
        accessTokenResult <- issueNewTeacherTokens emailAddr
        whenSuccess accessTokenResult $ succeed "text/plain"

handleRequestOTP :: Snap ()
handleRequestOTP =
  handle1 (Arg "email" notEmpty) $ \email ->
    do
      otpResult <- liftIO $ sendOTP email
      whenSuccess otpResult $ \otp -> do
        result <- liftIO $ storeOTP email otp
        whenSuccess result $ const ok

handleVerifyOTP :: Snap ()
handleVerifyOTP =
  handle2 (Arg "email" notEmpty, Arg "passcode" notEmpty) $
    \(emailAddr, passcode) ->
      do
        result <- liftIO $ validateOTP emailAddr passcode
        whenSuccess result $ const $ do
          accessTokenResult <- issueNewTeacherTokens emailAddr
          whenSuccess accessTokenResult $ succeed "text/plain"

handleTeacherIsLoggedIn :: Snap ()
handleTeacherIsLoggedIn =
  do
    vldtn <- validateTeacherAccessToken
    validation (const $ succeed "text/plain" "0") (const $ succeed "text/plain" "1") vldtn

handleLogout :: Snap ()
handleLogout =
  do
    teacherV <- validateTeacherRefreshToken
    whenSuccess teacherV $ \teacher -> do
      result <- liftIO $ logoutTeacher teacher
      whenSuccess result $ const ok

handleTeacherTokenRefresh :: Snap ()
handleTeacherTokenRefresh =
  do
    teacherResult <- validateTeacherRefreshToken
    whenSuccess teacherResult $ \(ATeacher emailAddr) -> do
      accessTokenResult <- issueNewTeacherTokens emailAddr
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
