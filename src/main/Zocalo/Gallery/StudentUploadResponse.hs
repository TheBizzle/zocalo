{-# LANGUAGE DeriveGeneric #-}
module Zocalo.Gallery.StudentUploadResponse(StudentUploadResponse(..)) where

import Data.Aeson(ToJSON)

import GHC.Generics(Generic)


data StudentUploadResponse
  = StudentUploadResponse {
      id   :: Int64
    , name :: Text
    } deriving (Generic, Show)

instance ToJSON StudentUploadResponse
