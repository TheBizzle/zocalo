module Zocalo.Gallery.OldAuth(sendOTP, setUpNewUser) where

import Data.Text(intercalate)

import qualified Data.Map  as Map
import qualified Data.Text as Text

import Zocalo.Common.SecureToken(SecureToken(tokenText))

import Zocalo.Gallery.Auth.FancyAuth(genSecureToken)

import Zocalo.Gallery.ActionResult(ActionResult)
import Zocalo.Gallery.Database(checkIsOkayOTPRate)
import Zocalo.Gallery.RandGen(generate6Digit)
import Zocalo.Gallery.WebReq(HTTPMethod(POST), httpRequest, HTTPRequest(HTTPRequest), MailtrapBody(MailtrapBody))

sendOTP :: Text -> IO (ActionResult Text)
sendOTP emailAddr =
    do
      resultV <- checkIsOkayOTPRate emailAddr
      case resultV of
        Failure x -> return $ Failure x
        Success _ -> do
          n       <- generate6Digit
          let otp  = Text.justifyRight 6 '0' $ showText n
          void $ sendMail emailAddr "Your Zócalo gallery sign-in code" $ body otp
          return $ Success otp
    where
      body otp =
        intercalate "<br>" $
          [ "You attempted to sign in to the Zócalo gallery website.  Your one-time passcode is:"
          , ""
          , "<b>" <> otp <> "</b>"
          , ""
          , "This code expires in 10 minutes."
          , ""
          , "If you did not attempt to sign in, you can safely ignore this message."
          ]

setUpNewUser :: Text -> Text -> IO SecureToken
setUpNewUser emailAddr registrationURL =
    do
      token <- genSecureToken
      void $ sendMail emailAddr "Zócalo Registration" $ body token.tokenText
      return token
  where
    body token = "A Zócalo gallery account has been registered for this e-mail address.  Please click <a href='" <> registrationURL <> token <> "'>this link</a> to confirm your registration."

sendMail :: Text -> Text -> Text -> IO Text
sendMail emailAddr subject text = httpRequest req
  where
    req  = HTTPRequest POST "https://send.api.mailtrap.io/api/send" Map.empty body
    body = MailtrapBody emailAddr subject text
