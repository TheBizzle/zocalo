{-# LANGUAGE TemplateHaskell #-}
module Zocalo.Common.AppConfig(
    applicationSecret, dbConnStr, domain, isHTTPSEnabled, mailtrapSecret, mailSenderAddress, mailSenderName
  ) where

import Zocalo.Common.ConfigReader(
    ConfigPath( GeneralDomain, GeneralHTTPSEnabled, GeneralSecret, MailMailtrapSecret, MailSenderAddress
              , MailSenderName
              )
  , readConfigValue, readDBConnStr
  )


dbConnStr :: ByteString
dbConnStr = $(readDBConnStr)

isHTTPSEnabled :: Bool
isHTTPSEnabled = $(readConfigValue GeneralHTTPSEnabled)

applicationSecret, domain, mailtrapSecret, mailSenderAddress, mailSenderName :: Text
applicationSecret = $(readConfigValue GeneralSecret)
domain            = $(readConfigValue GeneralDomain)
mailtrapSecret    = $(readConfigValue MailMailtrapSecret)
mailSenderAddress = $(readConfigValue MailSenderAddress)
mailSenderName    = $(readConfigValue MailSenderName)
