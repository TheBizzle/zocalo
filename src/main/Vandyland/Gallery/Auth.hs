module Vandyland.Gallery.Auth(genLoginToken, sendOTP, setUpNewUser) where

import Data.Text(intercalate)
import Data.UUID(UUID)

import qualified Data.Map     as Map
import qualified Data.Text    as Text
import qualified Data.UUID.V4 as UUIDGen
import qualified Data.UUID    as UUID

import Vandyland.Gallery.RandGen(generate6Digit)
import Vandyland.Gallery.WebReq(HTTPMethod(POST), httpRequest, HTTPRequest(HTTPRequest), MailtrapBody(MailtrapBody))

genLoginToken :: IO UUID
genLoginToken = genToken

sendOTP :: Text -> IO Text
sendOTP emailAddr =
    do
      n       <- generate6Digit
      let otp  = Text.justifyRight 6 '0' $ showText n
      _       <- sendMail emailAddr "Your gallery sign-in code" $ body otp
      return otp
    where
      body otp =
        intercalate "<br>" $
          [ "You attempted to sign in to the collaborative gallery website.  Your one-time passcode is:"
          , ""
          , "<b>" <> otp <> "</b>"
          , ""
          , "This code expires in 10 minutes."
          , ""
          , "If you did not attempt to sign in, you can safely ignore this message."
          ]

setUpNewUser :: Text -> Text -> IO UUID
setUpNewUser emailAddr registrationURL =
    do
      token <- genToken
      _     <- sendMail emailAddr "Gallery Registration" $ body $ UUID.toText token
      return token
  where
    body token = "A gallery account has been registered for this e-mail address.  Please click <a href='" <> registrationURL <> token <> "'>this link</a> to confirm your registration."

sendMail :: Text -> Text -> Text -> IO Text
sendMail emailAddr subject text = httpRequest req
  where
    req  = HTTPRequest POST "https://send.api.mailtrap.io/api/send" Map.empty body
    body = MailtrapBody emailAddr subject text

genToken :: IO UUID
genToken = UUIDGen.nextRandom
