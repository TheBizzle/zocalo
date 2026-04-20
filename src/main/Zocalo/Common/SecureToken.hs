module Zocalo.Common.SecureToken(genSecureToken, hashToken, SecureToken(SecureToken, tokenText), tokenFromText) where

import Crypto.Hash(Digest, hash, SHA256)
import Crypto.Random(getRandomBytes)

import Data.Text.Encoding(decodeUtf8, encodeUtf8)

import qualified Data.ByteString            as BS
import qualified Data.ByteArray.Encoding    as BAE
import qualified Data.ByteString.Base64.URL as B64
import qualified Data.Text.Encoding         as TE


newtype SecureToken =
  SecureToken { tokenText :: Text }
  deriving (Eq, Show)

genSecureToken :: IO SecureToken
genSecureToken = (getRandomBytes 32) <&> (B64.encode &> decodeUtf8 &> SecureToken)

hashToken :: SecureToken -> Text
hashToken = tokenText &> encodeUtf8 &> hashIt &> BAE.convertToBase BAE.Base16 &> TE.decodeUtf8
  where
    hashIt :: ByteString -> Digest SHA256
    hashIt = hash

tokenFromText :: Text -> Maybe SecureToken
tokenFromText x =
  case checkToken x of
    Right True -> Just $ SecureToken x
    _          -> Nothing
  where
    checkToken = encodeUtf8 &> B64.decode &> (second $ BS.length &> (== 32))
