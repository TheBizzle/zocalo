{-# LANGUAGE FlexibleContexts, QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
module Zocalo.Gallery.WebReq(HTTPMethod(..), httpRequest, HTTPRequest(..), MailtrapBody(MailtrapBody)) where

import Control.Monad(mzero)

import Data.Aeson((.:), (.=), FromJSON(parseJSON), object, ToJSON(toJSON), Value(Object))
import Data.CaseInsensitive(CI, mk)
import Data.FileEmbed(embedFile)

import Network.HTTP.Simple(getResponseBody, httpJSON, parseRequest_, Request, setRequestBodyJSON, setRequestHeader)

import Text.Regex.PCRE.Heavy(gsub, re)

import qualified Data.List          as List
import qualified Data.Map           as Map
import qualified Data.Text          as Text
import qualified Data.Text.Encoding as TE


data HTTPRequest
  = HTTPRequest {
    method      :: HTTPMethod
  , url         :: Text
  , headers     :: Map Text Text
  , body        :: MailtrapBody
  } deriving (Show)

data HTTPMethod
  = GET
  | HEAD
  | POST
  | PUT
  | DELETE
  | TRACE
  | OPTIONS
  | CONNECT
  | PATCH
  deriving (Show)

data MailtrapBody
  = MailtrapBody {
    toAddr  :: Text
  , subject :: Text
  , html    :: Text
  }
  deriving (Show)

transform :: Text -> Text
transform =
  Text.replace "<br>" "\n" &>
    gsub [re|<[^>]*>|] ("" :: Text) &>
    traceShowId

instance ToJSON MailtrapBody where
  toJSON (MailtrapBody toAddr subject html) =
    object
      [ "from" .= object [
          "email" .= asText "registration@rendupo.com"
        , "name"  .= asText "RenDuPo"
        ]
      , "to" .= [object [
          "email" .= toAddr
        ]]
      , "subject"  .= subject
      , "headers"  .= mailHeaders
      , "html"     .= html
      , "text"     .= transform html
      , "category" .= asText "Authentication"
      ]

data MailtrapResponse
  = MailtrapResponse {
    success    :: Bool
  , messageIDs :: [Text]
  }
  deriving (Show)

instance FromJSON MailtrapResponse where
  parseJSON (Object v) = MailtrapResponse <$>
                         v .: "success" <*>
                         v .: "message_ids"
  parseJSON _          = mzero

httpRequest :: HTTPRequest -> IO Text
httpRequest (HTTPRequest method url headers body) =
    do
      let request = setRequestBodyJSON body $ fullHeaders $ parseRequest_ $ Text.unpack $ (showText method) <> " " <> url
      response <- httpJSON request
      return $ showText (getResponseBody response :: MailtrapResponse)
  where
    headerPairs :: [(CI ByteString, ByteString)]
    headerPairs = map ((mapAll2 TE.encodeUtf8) >>> (mapFst mk)) allPairs
      where
        authPair = ("Authorization", "Bearer " <> mailtrapBearer)
        allPairs = List.insert authPair $ Map.toList headers

    fullHeaders :: Request -> Request
    fullHeaders = foldr (>>>) id $ map (\(k, v) -> setRequestHeader k [v]) headerPairs

mailHeaders :: Value
mailHeaders =
  object
    [
    ]

mailtrapBearer :: Text
mailtrapBearer = Text.strip $ TE.decodeUtf8 $ $(embedFile ".mailtrap_secret.txt")
