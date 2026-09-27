{-# LANGUAGE TemplateHaskell #-}
module Zocalo.Common.AppConfig(
    applicationSecret, dbConnStr, mailtrapSecret, mailSenderAddress, mailSenderName
  ) where

import Zocalo.Common.ConfigReader(
    ConfigPath( GeneralSecret, MailMailtrapSecret, MailSenderAddress, MailSenderName)
  , readConfigText, readDBConnStr
  )


dbConnStr :: ByteString
dbConnStr = $(readDBConnStr)

applicationSecret, mailtrapSecret, mailSenderAddress, mailSenderName :: Text
applicationSecret = $(readConfigText GeneralSecret)
mailtrapSecret    = $(readConfigText MailMailtrapSecret)
mailSenderAddress = $(readConfigText MailSenderAddress)
mailSenderName    = $(readConfigText MailSenderName)
