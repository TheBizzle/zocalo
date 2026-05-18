{-# LANGUAGE TemplateHaskell #-}
module Zocalo.Gallery.Auth.FancyAuth(genSecureToken, issueNewStudentTokens, issueNewTeacherTokens, issueTotallyNewStudentTokens, SecureToken(SecureToken, tokenText), validateStudentAccessToken, validateStudentRefreshToken, validateTeacherAccessToken, validateTeacherRefreshToken) where

import Control.Lens((^.), (.~), (&))

import Crypto.JOSE.JWK(fromOctets, JWK)
import Crypto.JWT(Alg(HS256), Audience(Audience), claimAud, claimExp, ClaimsSet, claimSub, decodeCompact, defaultJWTValidationSettings, emptyClaimsSet, encodeCompact, JOSE, JWTError, newJWSHeader, NumericDate(NumericDate), runJOSE, signClaims, SignedJWT, string, verifyClaims)

import Data.FileEmbed(embedFile)
import Data.String(fromString)
import Data.Text.Encoding(decodeUtf8, encodeUtf8)
import Data.Time(addUTCTime, NominalDiffTime)
import Data.Time.Clock.POSIX(getCurrentTime, getPOSIXTime, posixSecondsToUTCTime)

import Snap.Core(
    addResponseCookie
  , Cookie(Cookie, cookieDomain, cookieExpires, cookieHttpOnly, cookieName, cookiePath, cookieSecure, cookieValue)
  , getCookie, getHeader, getsRequest, modifyResponse, Snap
  )

import Zocalo.Common.SecureToken(genSecureToken, SecureToken(SecureToken, tokenText))

import Zocalo.Gallery.Auth.AuthorizedUser(AuthorizedStudent(AStudent), AuthorizedTeacher(ATeacher), AuthorizedUser(readUser))

import Zocalo.Gallery.ActionResult(ActionError(Incorrect, InternalError, Malformed, NotAuthorized), ActionResult)
import Zocalo.Gallery.Database(registerNewStudent, lookupStudentRefreshToken, lookupTeacherRefreshToken, setStudentRefreshToken, setTeacherRefreshToken)
import Zocalo.Gallery.LowerText(lowText)

import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy  as LazyBS
import qualified Data.Text             as Text


data Scope
  = Student
  | Teacher

issueTotallyNewStudentTokens :: Text -> Snap (ActionResult Text)
issueTotallyNewStudentTokens studentName =
  do
    identAR <- liftIO $ registerNewStudent studentName
    identAR `failOrM` (\ident -> issueNewStudentTokens $ AStudent (fromIntegral ident) studentName)

issueNewStudentTokens :: AuthorizedStudent -> Snap (ActionResult Text)
issueNewStudentTokens astud@(AStudent studID studName) =
    issueNewTokens (setStudentRefreshToken astud) identifier Student 180
  where
    identifier = (showText studID) <> "|" <> studName

issueNewTeacherTokens :: AuthorizedTeacher -> Snap (ActionResult Text)
issueNewTeacherTokens ateach@(ATeacher addr) =
  issueNewTokens (setTeacherRefreshToken ateach) (lowText addr) Teacher 28

issueNewTokens :: (SecureToken -> IO (ActionResult ())) -> Text -> Scope -> NominalDiffTime -> Snap (ActionResult Text)
issueNewTokens storeToken identifier scope daysToLive =
  do
    refreshToken  <- attachRefreshCookie
    updateAR      <- liftIO $ storeToken refreshToken
    accessTokenAR <- liftIO $ genAccessTokenAR scope identifier
    return $ updateAR *> accessTokenAR
  where
    -- Ideally, `cookieSecure` would be `True`.  But the real app does HTTPS via a proxy.  --Jason B. (3/15/26)
    attachRefreshCookie :: Snap SecureToken
    attachRefreshCookie =
      do
        refreshToken   <- liftIO genSecureToken
        now            <- liftIO getCurrentTime
        let pathM       = Just "/"
        let inXDays     = 60 * 60 * 24 * daysToLive
        let expirDateM  = Just $ inXDays `addUTCTime` now
        let cookieName  = refreshTokenName <> "|" <> (scopeBS scope)
        let fullCookie  = Cookie { cookieDomain   = Nothing
                                 , cookieExpires  = expirDateM
                                 , cookieHttpOnly = True
                                 , cookieName     = cookieName
                                 , cookiePath     = pathM
                                 , cookieSecure   = False
                                 , cookieValue    = encodeUtf8 refreshToken.tokenText
                                 }
        modifyResponse $ addResponseCookie fullCookie
        return refreshToken

    genAccessTokenAR :: Scope -> Text -> IO (ActionResult Text)
    genAccessTokenAR scope identifier =
      do
        now             <- getPOSIXTime
        let newClaimSub  = Just $ fromString $ Text.unpack $ identifier
        let newClaimAud  = Just $ Audience [fromString $ BS.unpack $ galleryJWTAudience <> "|" <> (scopeBS scope)]
        let newClaimExp  = Just $ NumericDate $ posixSecondsToUTCTime $ now + (60 * 5) -- 5 minutes
        let claims       = emptyClaimsSet & (claimAud .~ newClaimAud) & (claimExp .~ newClaimExp) & (claimSub .~ newClaimSub)
        tokenE          <- runJOSE (signClaims jwtSecret (newJWSHeader ((), HS256)) claims :: JOSE JWTError IO SignedJWT)
        return $ case tokenE of
          Left  _   -> Failure InternalError
          Right jwt -> Success $ decodeUtf8 $ LazyBS.toStrict $ encodeCompact jwt

validateStudentAccessToken :: Snap (ActionResult AuthorizedStudent)
validateStudentAccessToken = validateAccessToken Student

validateTeacherAccessToken :: Snap (ActionResult AuthorizedTeacher)
validateTeacherAccessToken = validateAccessToken Teacher

validateAccessToken :: AuthorizedUser a => Scope -> Snap (ActionResult a)
validateAccessToken scope =
  do
    authM <- getsRequest $ getHeader "Authorization"
    case authM of
      Just authHeader -> do
        let tokenBSM = BS.stripPrefix (BS.pack "Bearer ") authHeader
        case tokenBSM of
          Nothing      -> return $ Failure Malformed
          Just tokenBS -> do
            verified <- liftIO $ verifyJWT scope tokenBS
            return $ case verified of
              Failure           _ -> Failure Incorrect
              Success     Nothing -> Failure Malformed
              Success (Just user) -> Success user
      Nothing -> return $ Failure NotAuthorized

validateStudentRefreshToken :: Snap (ActionResult AuthorizedStudent)
validateStudentRefreshToken = validateRefreshToken Student lookupStudentRefreshToken

validateTeacherRefreshToken :: Snap (ActionResult AuthorizedTeacher)
validateTeacherRefreshToken = validateRefreshToken Teacher lookupTeacherRefreshToken

validateRefreshToken :: Scope -> (SecureToken -> IO (ActionResult a)) -> Snap (ActionResult a)
validateRefreshToken scope lookupUser =
  do
    let cookieName  = refreshTokenName <> "|" <> (scopeBS scope)
    refreshTokenCM <- getCookie cookieName
    maybe (return $ Failure NotAuthorized)
          (cookieValue &> decodeUtf8 &> SecureToken &> lookupUser &> liftIO)
          refreshTokenCM

verifyJWT :: AuthorizedUser user => Scope -> ByteString -> IO (ActionResult (Maybe user))
verifyJWT scope tokenBS =
  claimsEIO <&> \case Left       _ -> Failure Incorrect
                      Right claims ->
                        case claims ^. claimSub of
                          Just sub -> Success $ readUser $ sub ^. string
                          Nothing  -> Failure Malformed
  where
    claimsEIO :: IO (Either JWTError ClaimsSet)
    claimsEIO =
      runJOSE $ do
        jwt <- decodeCompact $ LazyBS.fromStrict tokenBS
        verifyClaims (defaultJWTValidationSettings (== audience)) jwtSecret jwt

    audience = fromString $ BS.unpack $ galleryJWTAudience <> "|" <> (scopeBS scope)

scopeBS :: Scope -> ByteString
scopeBS Student = "student"
scopeBS Teacher = "teacher"

refreshTokenName :: ByteString
refreshTokenName = "refresh_token"

jwtSecret :: JWK
jwtSecret = fromOctets $(embedFile ".app_secret.txt")

galleryJWTAudience :: ByteString
galleryJWTAudience = "gallery"
