{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric  #-}
module Zocalo.Gallery.Submission(Submission(..), SubmissionListing(..), SubmissionSendable(..)) where

import Data.Aeson(ToJSON)

import GHC.Generics(Generic)


data SubmissionListing
  = SubmissionListing {
      subName      :: Text
    , isSuppressed :: Bool
    } deriving (Generic, Show, ToJSON)

data Submission
  = Submission {
      id'           :: Word64
    , uploadName'   :: Text
    , base64Image'  :: Text
    , studentID'    :: Word64
    , metadata'     :: Maybe Text
    , creationTime' :: Integer
    } deriving Show

data SubmissionSendable
  = SubmissionSendable {
      id           :: Int64
    , uploadName   :: Text
    , image        :: Text
    , isOwner      :: Bool
    , canModerate  :: Bool
    , metadata     :: Maybe Text
    , creationTime :: Integer
    } deriving (Generic, Show, ToJSON)
