{-# LANGUAGE DeriveAnyClass  #-}
{-# LANGUAGE DeriveGeneric   #-}
{-# LANGUAGE TemplateHaskell #-}
module Zocalo.Common.ConfigReader(ConfigPath(..), readConfigText, readDBConnStr) where

import Control.Monad(fail)
import Language.Haskell.TH(Exp, Q)
import Language.Haskell.TH.Syntax(addDependentFile, lift, runIO)

import Data.Aeson(camelTo2, defaultOptions, FromJSON(parseJSON), genericParseJSON, Options(fieldLabelModifier))
import Data.Yaml(decodeFileEither)

import GHC.Generics(Generic)

import qualified Data.Text.Encoding as TE


data AppConfig = AppConfig
  { general  :: GeneralConfig
  , database :: DatabaseConfig
  , mail     :: MailConfig
  } deriving (Generic, Show)

data GeneralConfig = GeneralConfig
  { cryptographySecret :: Text
  } deriving (Generic, Show)

data DatabaseConfig = DatabaseConfig
  { host :: Text
  , dbPort :: Int
  , dbName :: Text
  , username :: Text
  , password :: Text
  } deriving (Generic, Show)

data MailConfig = MailConfig
  { mailtrapApiSecret :: Text
  , senderAddress :: Text
  , senderName :: Text
  } deriving (Generic, Show)

options :: Options
options = defaultOptions { fieldLabelModifier = camelTo2 '-' }

instance FromJSON AppConfig where
  parseJSON = genericParseJSON options

instance FromJSON GeneralConfig where
  parseJSON = genericParseJSON options

instance FromJSON DatabaseConfig where
  parseJSON = genericParseJSON options

instance FromJSON MailConfig where
  parseJSON = genericParseJSON options

data ConfigPath
  = GeneralSecret
  | DatabaseDBName
  | DatabaseDBPort
  | DatabaseHost
  | DatabaseUsername
  | DatabasePassword
  | MailMailtrapSecret
  | MailSenderAddress
  | MailSenderName

readConfigText :: ConfigPath -> Q Exp
readConfigText path =
  do
    config <- loadConfig
    case path of
      GeneralSecret      -> lift $ cryptographySecret $  general config
      DatabaseDBName     -> lift $             dbName $ database config
      DatabaseDBPort     -> lift $             dbPort $ database config
      DatabaseHost       -> lift $               host $ database config
      DatabaseUsername   -> lift $           username $ database config
      DatabasePassword   -> lift $           password $ database config
      MailMailtrapSecret -> lift $  mailtrapApiSecret $     mail config
      MailSenderAddress  -> lift $      senderAddress $     mail config
      MailSenderName     -> lift $         senderName $     mail config

readDBConnStr :: Q Exp
readDBConnStr =
  do
    config <- loadConfig
    let db = database config
    lift $ TE.encodeUtf8 $
      "host=" <> (host db) <> " dbname=" <> (dbName db) <>
      " user=" <> (username db) <> " password=" <> (password db) <>
      " port=" <> (showText $ dbPort db)

configFile :: FilePath
configFile = "conf/actual.yaml"

loadConfig :: Q AppConfig
loadConfig =
  do
    addDependentFile configFile
    result <- runIO $ decodeFileEither configFile
    case result of
      Left err     -> fail $ "Failed to parse '" <> configFile <> "': " <> show err
      Right config -> pure config
