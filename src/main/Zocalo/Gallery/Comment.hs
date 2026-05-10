{-# LANGUAGE DeriveGeneric #-}
module Zocalo.Gallery.Comment(Comment(..)) where

import Data.Aeson(ToJSON)

import GHC.Generics(Generic)

data Comment
  = Comment {
      id           :: Int64
    , comment      :: Text
    , author       :: Text
    , parentID     :: Maybe Int64
    , creationTime :: Integer
    } deriving (Generic, Show)

instance ToJSON Comment
