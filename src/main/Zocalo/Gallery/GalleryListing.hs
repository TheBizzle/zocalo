{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric  #-}
module Zocalo.Gallery.GalleryListing(GalleryListing(..)) where

import Data.Aeson(ToJSON)

import GHC.Generics(Generic)


data GalleryListing
  = GalleryListing {
    id            :: Int
  , name          :: Text
  , template      :: Text
  , description   :: Text
  , isPrescreened :: Bool
  , numWaiting    :: Word
  , numApproved   :: Word
  , creationTime  :: Integer
  , lastSubTime   :: Integer
  } deriving (Generic, Show, ToJSON)
