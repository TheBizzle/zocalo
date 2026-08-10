module Zocalo.Gallery.Controller(routes, runMigrations) where

import Control.Concurrent.STM.TVar(modifyTVar', readTVarIO)
import Control.Exception(finally)
import Control.Monad(forever)

import Data.CaseInsensitive(CI)
import Data.NanoID(unNanoID)

import GHC.Conc(atomically, TVar)

import Network.WebSockets(acceptRequest, receiveData, sendTextData)
import Network.WebSockets.Snap(runWebSocketsSnap)

import Snap.Core(getHeader, getParam, getsRequest, Method(DELETE, GET, POST), Snap, writeBS, writeText)
import Snap.Util.FileServe(serveDirectory)
import Snap.Util.GZip(withCompression)

import Zocalo.Common.SnapHelpers(
    allowingCORS, Arg(Arg), asBool, asNanoID, asNonNeg, asToken, encodeText, failWith, free, getParamV
  , getParamVM, handle1, handle2, handle3, notEmpty, notifyBadParams, ok, succeed, withFileUploads
  )

import Zocalo.Gallery.Auth.AuthorizedUser(AuthorizedStudent, AuthorizedTeacher)

import Zocalo.Gallery.Auth.FancyAuth(
    issueNewStudentTokens, issueNewTeacherTokens, issueTotallyNewStudentTokens, validateStudentAccessToken
  , validateStudentRefreshToken, validateTeacherAccessToken, validateTeacherRefreshToken
  , validateStudentAccessTokenRaw, validateTeacherAccessTokenRaw
  )

import Zocalo.Gallery.ActionResult(
    ActionError(Duplicate, Expired, Incorrect, InternalError, Malformed, NotAuthorized, NotFound, Unconfirmed)
  , ActionResult
  )

import Zocalo.Gallery.Database(
    approveSubmission, checkUserExists, confirmNewUser, forbidSubmission, logoutStudent, logoutTeacher
  , readGalleryListings, readStarterConfigFor, readSubmissionData, readSubmissionListings
  , readSubmissionListingsForModeration, readWhoIsTeacher, registerNewGallery, readTemplateName
  , registerNewTeacher, runMigrations, storeOTP, suppressSubmission, validateOTP, writeComment
  , writeSubmission
  )

import Zocalo.Gallery.LowerText(asLowerText)
import Zocalo.Gallery.OldAuth(setUpNewUser, sendOTP)

import Zocalo.Gallery.SocketClient(
    GalleryObserverClient(GalleryObserverClient, gocConnection, gocGalleryID, gocStudent)
  , ModeratorClient(ModeratorClient, mcConnection, mcGalleryID, mcTeacher)
  )

import Zocalo.Gallery.StudentUploadResponse(
    UploadCommentResponse(UploadCommentResponse)
  , UploadDeleteResponse(UploadDeleteResponse)
  )

import Zocalo.Gallery.Submission(SubmissionID(SubID), SubmissionSendable(SubmissionSendable))

import qualified Data.ByteString.Base64 as Base64
import qualified Data.Map               as Map
import qualified Data.Text.Encoding     as TextEncoding
import qualified Text.Read              as TRead


routes :: TVar (Map AuthorizedTeacher ModeratorClient) ->
          TVar (Map AuthorizedStudent GalleryObserverClient) ->
          [(ByteString, Snap ())]
routes moderators students =
    [ ("echo/:param"                                     ,      ac POST   handleEchoData)
    , ("api/version"                                     ,      ac GET    handleAPIVersion)
    , ("api/auth/student/fresh-cookies"                  ,      ac POST   handleNewStudent)
    , ("api/auth/student/logout"                         ,      ac POST   handleStudentLogout)
    , ("api/auth/student/refresh"                        ,      ac POST   handleStudentTokenRefresh)
    , ("api/auth/teacher/refresh"                        ,      ac POST   handleTeacherTokenRefresh)
    , ("api/auth/teacher/register"                       ,      ac POST   handleRegister)
    , ("api/auth/teacher/confirm/:token"                 ,      ac POST   handleTeacherAuthConfirm)
    , ("api/auth/teacher/request-otp"                    ,      ac POST   handleRequestOTP)
    , ("api/auth/teacher/verify-otp"                     ,      ac POST   handleVerifyOTP)
    , ("api/auth/teacher/is-logged-in/"                  ,      ac GET    handleTeacherIsLoggedIn)
    , ("api/auth/teacher/logout"                         ,      ac POST   handleTeacherLogout)
    , ("api/auth/teacher/verify-cookie"                  ,      ac POST   handleRegister)
    , ("api/auth/teacher/who-am-i"                       , wc $ ac GET    handleWhoIsTeacher)
    , ("api/galleries/teacher/new-session"               ,      ac POST   handleNewSessionWithParams)
    , ("api/galleries/teacher/overview"                  , wc $ ac GET    handleListGalleries)
    , ("api/galleries/:nano-id/student/:item-id/comment" ,      ac POST   (handleSubmitComment students))
    , ("api/galleries/:nano-id/student/starter-config"   , wc $ ac GET    handleGetStarterConfig)
    , ("api/galleries/:nano-id/student/submission"       ,      ac POST   (handleUploadFile students moderators))
    , ("api/galleries/:nano-id/student/submissions/:jwt" ,                handleStudentSocket students)
    , ("api/galleries/:nano-id/student/template-name"    ,      ac GET    handleGetTemplateName)
    , ("api/galleries/:nano-id/student/:item-id"         , wc $ ac GET    handleDownloadItem)
    , ("api/galleries/:nano-id/student/:item-id"         ,      ac DELETE (handleSuppressItem students moderators))
    , ("api/galleries/:nano-id/teacher/:item-id/approve" ,      ac POST   (handleApproveItem students moderators))
    , ("api/galleries/:nano-id/teacher/:item-id/reject"  ,      ac POST   (handleForbidItem students moderators))
    , ("api/galleries/:nano-id/teacher/moderable/:jwt"   ,                handleModeratorSocket moderators)
    , ("/assets"                                         ,                serveDirectory "frontend/dist/assets")
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
        whenSuccess result $ unNanoID &> TextEncoding.decodeUtf8 &> succeed "text/plain"

handleListGalleries :: Snap ()
handleListGalleries =
  ifAuthorizedTeacher $ \teacher ->
    do
      listingsResult <- liftIO $ readGalleryListings teacher
      whenSuccess listingsResult $ encodeText &> succeed "application/json"

handleWhoIsTeacher :: Snap ()
handleWhoIsTeacher =
  ifAuthorizedTeacher $ \teacher ->
    do
      resultV <- liftIO $ readWhoIsTeacher teacher
      whenSuccess (map showText resultV) $ succeed "text/plain"

handleDownloadItem :: Snap ()
handleDownloadItem =
  withAuthorizations $ \teacherM studM ->
    handle1 (Arg "item-id" asNonNeg) $
      \uploadID ->
        do
          dlResult <- liftIO $ readSubmissionData teacherM studM $ SubID uploadID
          whenSuccess dlResult $ succeed "text/plain"

handleSuppressItem :: TVar (Map AuthorizedStudent GalleryObserverClient) ->
                      TVar (Map AuthorizedTeacher       ModeratorClient) ->
                      Snap ()
handleSuppressItem students teachers =
  withAuthorizations $ \teacherM studM ->
    handle2 (Arg "nano-id" asNanoID, Arg "item-id" asNonNeg) $
      \(galleryID, uploadID) ->
        do
          result <- liftIO $ suppressSubmission teacherM studM $ SubID uploadID
          whenSuccess result $ const $ do

            studentClients <- liftIO $ readTVarIO students
            for_ studentClients $ \client ->
              when (client.gocGalleryID == galleryID) $
                liftIO $ sendTextData client.gocConnection $ encodeText $ UploadDeleteResponse uploadID

            teacherClients <- liftIO $ readTVarIO teachers
            for_ teacherClients $ \client ->
              when (client.mcGalleryID == galleryID && (Just client.mcTeacher) /= teacherM) $
                liftIO $ sendTextData client.mcConnection $ encodeText $ UploadDeleteResponse uploadID

            succeed "text/plain" "Submission successfully suppressed"

handleApproveItem :: TVar (Map AuthorizedStudent GalleryObserverClient) ->
                     TVar (Map AuthorizedTeacher       ModeratorClient) ->
                     Snap ()
handleApproveItem students teachers =
  ifAuthorizedTeacher $ \teacher ->
    handle2 (Arg "nano-id" asNanoID, Arg "item-id" asNonNeg) $
      \(galleryID, uploadID) ->
        do
          result <- liftIO $ approveSubmission teacher $ SubID uploadID
          whenSuccess result $
            \submission@(SubmissionSendable ssid _ _ _ _ _ _ _) -> do

              studentClients <- liftIO $ readTVarIO students
              for_ studentClients $ \client ->
                when (client.gocGalleryID == galleryID) $
                  liftIO $ sendTextData client.gocConnection $ encodeText [submission]

              teacherClients <- liftIO $ readTVarIO teachers
              for_ teacherClients $ \client ->
                when (client.mcGalleryID == galleryID && client.mcTeacher /= teacher) $
                  liftIO $ sendTextData client.mcConnection $ encodeText $ UploadDeleteResponse $ fromIntegral ssid

              succeed "text/plain" "Submission approved"

handleForbidItem :: TVar (Map AuthorizedStudent GalleryObserverClient) ->
                    TVar (Map AuthorizedTeacher       ModeratorClient) ->
                    Snap ()
handleForbidItem students teachers =
  ifAuthorizedTeacher $ \teacher ->
    handle2 (Arg "nano-id" asNanoID, Arg "item-id" asNonNeg) $
      \(galleryID, uploadID) ->
        do
          result <- liftIO $ forbidSubmission teacher $ SubID uploadID

          whenSuccess result $ const $ do
            studentClients <- liftIO $ readTVarIO students
            for_ studentClients $ \client ->
              when (client.gocGalleryID == galleryID) $
                liftIO $ sendTextData client.gocConnection $ encodeText $ UploadDeleteResponse uploadID

            teacherClients <- liftIO $ readTVarIO teachers
            for_ teacherClients $ \client ->
              when (client.mcGalleryID == galleryID && client.mcTeacher /= teacher) $
                liftIO $ sendTextData client.mcConnection $ encodeText $ UploadDeleteResponse uploadID

            succeed "text/plain" "Submission successfully forbidden"

handleUploadFile :: TVar (Map AuthorizedStudent GalleryObserverClient) ->
                    TVar (Map AuthorizedTeacher       ModeratorClient) ->
                    Snap ()
handleUploadFile students teachers =
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
        pairResult <- liftIO $ (uncurry4 $ writeSubmission student) tuple
        whenSuccess pairResult $
          \(uploadID, getsPreed, submission) -> do

            studentClients <- liftIO $ readTVarIO students
            for_ studentClients $ \client ->
              when ((Success client.gocGalleryID) == nanoID && (not getsPreed) && client.gocStudent /= student) $
                liftIO $ sendTextData client.gocConnection $ encodeText [submission]

            teacherClients <- liftIO $ readTVarIO teachers
            for_ teacherClients $ \client ->
              when ((Success client.mcGalleryID) == nanoID) $
                liftIO $ sendTextData client.mcConnection $ encodeText [submission]

            succeed "text/plain" $ encodeText uploadID
  where
    lookupParam param fileMap =
      case Map.lookup param fileMap of
        Nothing       -> Failure [param]
        (Just result) -> Success $
          case TextEncoding.decodeUtf8' result of
            Right good -> good
            Left     _ -> TextEncoding.decodeUtf8 $ Base64.encode result

handleSubmitComment :: TVar (Map AuthorizedStudent GalleryObserverClient) -> Snap ()
handleSubmitComment students =
  ifAuthorizedStudent $ \student -> withFileUploads $ \fileMap -> do
    nanoIDV     <- getParamVM fileMap $ Arg "nano-id" asNanoID
    uploadIDV   <- getParamVM fileMap $ Arg "item-id" asNonNeg
    parentV     <- getParamVM fileMap $ Arg "parent"  free
    commentV    <- getParamVM fileMap $ Arg "comment" notEmpty
    let tupleV   = (,,) <$> nanoIDV <*> uploadIDV <*> commentV
    let pidM     = validation (const Nothing) (asString &> TRead.readMaybe) parentV
    bimapM_ notifyBadParams (helper student pidM) tupleV
  where
    helper student pidM (nid, uid, comment) =
      do
        result <- liftIO $ writeComment student uid pidM comment
        whenSuccess result $
          \comment -> do
            studentClients <- liftIO $ readTVarIO students
            for_ studentClients $ \client ->
              when (client.gocGalleryID == nid && client.gocStudent /= student) $
                liftIO $ sendTextData client.gocConnection $ encodeText $ UploadCommentResponse comment uid
            writeText ""

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

handleModeratorSocket :: TVar (Map AuthorizedTeacher ModeratorClient) -> Snap ()
handleModeratorSocket moderators = do
  handle2 (Arg "nano-id" asNanoID, Arg "jwt" notEmpty) $
    \(galleryID, jwt) ->
      ifAuthorizedTeacherRaw jwt $ \teacher ->
        runWebSocketsSnap $ \pending -> do

          connection <- acceptRequest pending
          let client = ModeratorClient teacher galleryID connection
          atomically $ modifyTVar' moderators $ teacher `Map.insert` client

          let cleanup = atomically $ modifyTVar' moderators $ Map.delete teacher
          (flip finally cleanup) $ do

            listingsResult <- readSubmissionListingsForModeration teacher galleryID

            let response =
                  case listingsResult of
                    (Success   x) -> encodeText x
                    (Failure err) -> "{ \"error\": \"" <> (showText err) <> "\" }"

            sendTextData connection response

            forever $ do -- Keeps the connection alive --Jason B. (7/19/26)
              _ <- receiveData connection :: IO Text
              pure ()

handleStudentSocket :: TVar (Map AuthorizedStudent GalleryObserverClient) -> Snap ()
handleStudentSocket students = do
  handle2 (Arg "nano-id" asNanoID, Arg "jwt" notEmpty) $
    \(galleryID, jwt) ->
      ifAuthorizedStudentRaw jwt $ \student ->
        runWebSocketsSnap $ \pending -> do

          connection <- acceptRequest pending
          let client = GalleryObserverClient student galleryID connection
          atomically $ modifyTVar' students $ student `Map.insert` client

          let cleanup = atomically $ modifyTVar' students $ Map.delete student
          (flip finally cleanup) $ do

            listingsResult <- liftIO $ readSubmissionListings student galleryID

            let responses =
                  case listingsResult of
                    (Success (meta, subs)) -> [encodeText meta, encodeText subs]
                    (Failure          err) -> ["{ \"error\": \"" <> (showText err) <> "\" }"]

            for_ responses $ sendTextData connection

            forever $ do -- Keeps the connection alive --Jason B. (7/19/26)
              _ <- receiveData connection :: IO Text
              pure ()

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

ifAuthorizedStudentRaw :: Text -> (AuthorizedStudent -> Snap ()) -> Snap ()
ifAuthorizedStudentRaw jwt ifGood =
  do
    studentV <- validateStudentAccessTokenRaw $ TextEncoding.encodeUtf8 jwt
    validation (const $ failWith 401 $ writeText "No valid student access token.") ifGood studentV

ifAuthorizedTeacher :: (AuthorizedTeacher -> Snap ()) -> Snap ()
ifAuthorizedTeacher ifGood =
  do
    teacherV <- validateTeacherAccessToken
    validation (const $ failWith 401 $ writeText "No valid teacher access token.") ifGood teacherV

ifAuthorizedTeacherRaw :: Text -> (AuthorizedTeacher -> Snap ()) -> Snap ()
ifAuthorizedTeacherRaw jwt ifGood =
  do
    teacherV <- validateTeacherAccessTokenRaw $ TextEncoding.encodeUtf8 jwt
    validation (const $ failWith 401 $ writeText "No valid teacher access token.") ifGood teacherV
