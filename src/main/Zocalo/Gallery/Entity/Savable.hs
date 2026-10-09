module Zocalo.Gallery.Entity.Savable(
    CommentSavable(..)
  , GallerySavable(..)
  , SubmissionSavable(..)
  , SubmissionStatus(..)
  ) where

import Data.NanoID(NanoID)
import Data.Time(UTCTime)


data GallerySavable =
  GallerySavable
    { displayName  :: Text
    , templateName :: Text
    , galleryID    :: NanoID
    , teacherName  :: Text
    , timeAdded    :: UTCTime
    , description  :: Maybe Text
    , starter      :: Maybe Text
    , submissions  :: [SubmissionSavable]
    }

data SubmissionSavable =
  SubmissionSavable
    { uploaderName :: Text
    , base64Image  :: Text
    , dateAdded    :: UTCTime
    , status       :: SubmissionStatus
    , metadata     :: Maybe Text
    , extraData    :: Text
    , comments     :: [CommentSavable]
    }

data CommentSavable =
  CommentSavable
    { comment :: Text
    , author  :: Text
    , time    :: UTCTime
    }

data SubmissionStatus
  = Disallowed
  | Public
  | SelfRevoked
  | Waiting
