{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
module Zocalo.Gallery.Entity.StudentUploadResponse(
    StudentUploadResponse(id, StudentUploadResponse)
  , UploadCommentResponse(commentedID, UploadCommentResponse)
  , UploadDeleteResponse(deletedID, UploadDeleteResponse)
  ) where

import Data.Aeson(ToJSON)

import GHC.Generics(Generic)

import Zocalo.Gallery.Entity.Comment(Comment)


data StudentUploadResponse
  = StudentUploadResponse { id :: Word64 }
  deriving (Generic, Show, ToJSON)

data UploadCommentResponse
  = UploadCommentResponse { comment :: Comment, commentedID :: Word64 }
  deriving (Generic, Show, ToJSON)

data UploadDeleteResponse
  = UploadDeleteResponse { deletedID :: Word64 }
  deriving (Generic, Show, ToJSON)
