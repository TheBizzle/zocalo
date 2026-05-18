{-# LANGUAGE TemplateHaskell #-}
module Zocalo.Gallery.Auth.FancyAuth(genSecureToken, issueNewTeacherTokens, SecureToken(SecureToken, tokenText), validateStudentAccessToken, validateTeacherAccessToken, validateTeacherRefreshToken) where

import Control.Lens((^.), (.~), (&))

import Crypto.JOSE.JWK(fromOctets, JWK)
import Crypto.JWT(Alg(HS256), Audience(Audience), claimAud, claimExp, ClaimsSet, claimSub, decodeCompact, defaultJWTValidationSettings, emptyClaimsSet, encodeCompact, JOSE, JWTError, newJWSHeader, NumericDate(NumericDate), runJOSE, signClaims, SignedJWT, string, StringOrURI, verifyClaims)

import Data.FileEmbed(embedFile)
import Data.String(fromString)
import Data.Text.Encoding(decodeUtf8, encodeUtf8)
import Data.Time(addUTCTime)
import Data.Time.Clock.POSIX(getCurrentTime, getPOSIXTime, posixSecondsToUTCTime)

import Snap.Core(
    addResponseCookie
  , Cookie(Cookie, cookieDomain, cookieExpires, cookieHttpOnly, cookieName, cookiePath, cookieSecure, cookieValue)
  , getCookie, getHeader, getsRequest, modifyResponse, Snap
  )

import Zocalo.Common.SecureToken(genSecureToken, SecureToken(SecureToken, tokenText))

import Zocalo.Gallery.Auth.AuthorizedUser(AuthorizedStudent, AuthorizedTeacher(ATeacher), AuthorizedUser(readUser))

import Zocalo.Gallery.ActionResult(ActionError(Incorrect, InternalError, Malformed, NotAuthorized), ActionResult)
import Zocalo.Gallery.Database(lookupTeacherRefreshToken, upsertTeacherRefreshToken)
import Zocalo.Gallery.LowerText(lowText)

import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy  as LazyBS
import qualified Data.Text             as Text


issueNewTeacherTokens :: AuthorizedTeacher -> Snap (ActionResult Text)
issueNewTeacherTokens (ATeacher addr) =
  do
    refreshToken  <- attachRefreshCookie
    upsertionAR   <- liftIO $ upsertTeacherRefreshToken addr refreshToken
    accessTokenAR <- liftIO $ genAccessTokenAR $ lowText addr
    return $ upsertionAR *> accessTokenAR
  where
    -- Ideally, `cookieSecure` would be `True`.  But the real app does HTTPS via a proxy.  --Jason B. (3/15/26)
    attachRefreshCookie :: Snap SecureToken
    attachRefreshCookie =
      do
        refreshToken   <- liftIO genSecureToken
        now            <- liftIO getCurrentTime
        let pathM       = Just "/"
        let in28Days    = 60 * 60 * 24 * 7 * 4
        let expirDateM  = Just $ in28Days `addUTCTime` now
        let fullCookie  = Cookie { cookieDomain   = Nothing
                                 , cookieExpires  = expirDateM
                                 , cookieHttpOnly = True
                                 , cookieName     = refreshTokenName
                                 , cookiePath     = pathM
                                 , cookieSecure   = False
                                 , cookieValue    = encodeUtf8 refreshToken.tokenText
                                 }
        modifyResponse $ addResponseCookie fullCookie
        return refreshToken

    genAccessTokenAR :: Text -> IO (ActionResult Text)
    genAccessTokenAR username =
      do
        now             <- getPOSIXTime
        let newClaimSub  = Just $ fromString $ Text.unpack username
        let newClaimAud  = Just $ Audience [galleryJWTAudience]
        let newClaimExp  = Just $ NumericDate $ posixSecondsToUTCTime $ now + 60 * 5 -- 5 minutes
        let claims       = emptyClaimsSet & (claimAud .~ newClaimAud) & (claimExp .~ newClaimExp) & (claimSub .~ newClaimSub)
        tokenE          <- runJOSE (signClaims jwtSecret (newJWSHeader ((), HS256)) claims :: JOSE JWTError IO SignedJWT)
        return $ case tokenE of
          Left  _   -> Failure InternalError
          Right jwt -> Success $ decodeUtf8 $ LazyBS.toStrict $ encodeCompact jwt

validateStudentAccessToken :: Snap (ActionResult AuthorizedStudent)
validateStudentAccessToken =
  return $ Failure NotAuthorized -- TODO

validateTeacherAccessToken :: Snap (ActionResult AuthorizedTeacher)
validateTeacherAccessToken =
  do
    authM <- getsRequest $ getHeader "Authorization"
    case authM of
      Just authHeader -> do
        let tokenBSM = BS.stripPrefix (BS.pack "Bearer ") authHeader
        case tokenBSM of
          Nothing      -> return $ Failure Malformed
          Just tokenBS -> do
            verified <- liftIO $ verifyJWT tokenBS
            return $ case verified of
              Failure           _ -> Failure Incorrect
              Success     Nothing -> Failure Malformed
              Success (Just user) -> Success user
      Nothing -> return $ Failure NotAuthorized

validateTeacherRefreshToken :: Snap (ActionResult AuthorizedTeacher)
validateTeacherRefreshToken =
  do
    refreshTokenCM <- getCookie refreshTokenName
    maybe (return $ Failure NotAuthorized)
          (cookieValue &> decodeUtf8 &> SecureToken &> lookupTeacherRefreshToken &> liftIO)
          refreshTokenCM

verifyJWT :: AuthorizedUser user => ByteString -> IO (ActionResult (Maybe user))
verifyJWT tokenBS =
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
        verifyClaims (defaultJWTValidationSettings (== galleryJWTAudience)) jwtSecret jwt

refreshTokenName :: ByteString
refreshTokenName = "refresh_token"

jwtSecret :: JWK
jwtSecret = fromOctets $(embedFile ".app_secret.txt")

galleryJWTAudience :: StringOrURI
galleryJWTAudience = "gallery"
