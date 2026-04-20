{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric  #-}
module Zocalo.Gallery.Submission(GalleryListing(..), Submission(..), SubmissionListing(..), SubmissionSendable(..)) where

import Data.Aeson(ToJSON)

import GHC.Generics(Generic)


data SubmissionListing
  = SubmissionListing {
      subName      :: Text
    , isSuppressed :: Bool
    } deriving (Generic, Show, ToJSON)

data GalleryListing
  = GalleryListing {
    galleryName   :: Text
  , template      :: Text
  , description   :: Text
  , isPrescreened :: Bool
  , numWaiting    :: Int
  , numApproved   :: Int
  , creationTime  :: Integer
  , lastSubTime   :: Integer
  } deriving (Generic, Show, ToJSON)

data Submission
  = Submission {
      uploadName'  :: Text
    , base64Image' :: Text
    , studentID'   :: Word64
    , metadata'    :: Maybe Text
    } deriving Show

data SubmissionSendable
  = SubmissionSendable {
      uploadName   :: Text
    , base64Image  :: Text
    , isOwner      :: Bool
    , canModerate  :: Bool
    , metadata     :: Maybe Text
    } deriving (Generic, Show, ToJSON)
