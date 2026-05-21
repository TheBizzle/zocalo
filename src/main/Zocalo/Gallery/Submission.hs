{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric  #-}
module Zocalo.Gallery.Submission(AllSubmissions(..), Submission(..), SubmissionSendable(..)) where

import Data.Aeson(ToJSON)

import GHC.Generics(Generic)

import Zocalo.Gallery.Comment(Comment)


data AllSubmissions
  = AllSubmissions {
      galleryName :: Text
    , isModerated :: Bool
    , submissions :: [SubmissionSendable]
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
    , uploader     :: Text
    , image        :: Text
    , isOwner      :: Bool
    , canModerate  :: Bool
    , metadata     :: Maybe Text
    , comments     :: [Comment]
    , creationTime :: Integer
    } deriving (Generic, Show, ToJSON)
