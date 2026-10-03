{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric  #-}
module Zocalo.Gallery.ZipMaker(makeArchive) where

import Codec.Archive.Zip(addEntryToArchive, emptyArchive, Entry, fromArchive, toEntry)

import Data.Aeson((.:), decode, encode, FromJSON, parseJSON, ToJSON, withObject)
import Data.List(zip)
import Data.NanoID(NanoID)
import Data.Time(UTCTime)
import Data.Time.Clock.POSIX(POSIXTime)

import GHC.Generics(Generic)

import Zocalo.Gallery.Auth.AuthorizedUser(AuthorizedTeacher)
import Zocalo.Gallery.Database.Database(readGalleryForSave)
import Zocalo.Gallery.Entity.ActionResult(ActionResult)

import Zocalo.Gallery.Entity.Savable(
    CommentSavable(CommentSavable)
  , GallerySavable(GallerySavable)
  , SubmissionSavable(SubmissionSavable)
  , SubmissionStatus(Disallowed, Public, SelfRevoked, Waiting)
  )

import qualified Data.ByteString.Base64 as Base64
import qualified Data.ByteString.Lazy   as LBS
import qualified Data.Text              as Text
import qualified Data.Text.Encoding     as TE


makeArchive :: POSIXTime -> AuthorizedTeacher -> NanoID -> IO (ActionResult (ByteString, LBS.ByteString))
makeArchive epoch teacher galleryID =
  do
    result <- readGalleryForSave teacher galleryID
    return $ map (galleryToZIP epoch) result

galleryToZIP :: POSIXTime -> GallerySavable -> (ByteString, LBS.ByteString)
galleryToZIP rawEpoch (GallerySavable name templateName gid descM starterM subs) =
    (filename, fromArchive archive)
  where
    epoch         = floor rawEpoch
    filename      = TE.encodeUtf8 $ Text.intercalate "===" ["zocalo", name, templateName, showText gid]
    descEntryM    = map (textToLBS &> toEntry  "description.txt"                 epoch)    descM
    starterEntryM = map (textToLBS &> toEntry ("starter." <> (starterExt templateName)) epoch) starterM
    uploadEntries = (zip [1..] subs) >>= (subToEntry rawEpoch templateName)
    entries       = (catMaybes [descEntryM, starterEntryM]) <> uploadEntries
    archive       = foldr addEntryToArchive emptyArchive entries

starterExt :: Text -> String
starterExt "geogebra"      = "ggb"
starterExt "netlogo"       = "nlogox"
starterExt "netlogo-world" = "json"
starterExt "netsblox"      = "xml"
starterExt "sweeping-area" = "json"
starterExt _               = "txt"

subToEntry :: POSIXTime -> Text -> (Int, SubmissionSavable) -> [Entry]
subToEntry rawEpoch templateName
           (index, SubmissionSavable uploaderName base64Image dateAdded status metadataM extraData comments) =
    [ addEntry "info.txt" $ encode info
    , dataEntry
    ] <> (maybeToList imageEntryM)
  where
    epoch                      = floor rawEpoch
    baseName                   = "uploads/" <> (show index) <> "_" <> (asString uploaderName) <> "/"
    addEntry filename contents = toEntry (baseName <> filename) epoch contents

    descLBSM             = map (TE.encodeUtf8 &> LBS.fromStrict) metadataM
    descM                = (descLBSM >>= (\md -> decode md :: Maybe Metadata)) <&> desc
    commentJSONs         = map commentToJSONable comments
    info                 = SubmissionJSONable descM (statusToName status) dateAdded commentJSONs
    (dataExt, dataBytes) = extAndData templateName extraData
    dataEntry            = addEntry ("data." <> dataExt) dataBytes

    imageEntryM = map (addEntry "image.png") $ imageToLBS base64Image

extAndData :: Text -> Text -> (String, LBS.ByteString)
extAndData "geogebra"      extraData = (   "ggb", textToLBS extraData)
extAndData "netlogo"       extraData = ("nlogox", textToLBS extraData)
extAndData "netlogo-world" extraData = (  "json", textToLBS extraData)
extAndData "netsblox"      extraData = (   "xml", textToLBS extraData)
extAndData "segregation"   extraData = (   "txt", textToLBS extraData)
extAndData "sweeping-area" extraData = (  "json", textToLBS extraData)
extAndData _               extraData = (   "txt", textToLBS extraData)

commentToJSONable :: CommentSavable -> CommentJSONable
commentToJSONable (CommentSavable c a t) = CommentJSONable c a t

statusToName :: SubmissionStatus -> Text
statusToName Disallowed  = "disallowed"
statusToName Public      = "public"
statusToName SelfRevoked = "self-revoked"
statusToName Waiting     = "waiting"

textToLBS :: Text -> LBS.ByteString
textToLBS = TE.encodeUtf8 &> LBS.fromStrict

imageToLBS :: Text -> (Maybe LBS.ByteString)
imageToLBS = TE.encodeUtf8 &> Base64.decode &> (either (const Nothing) $ LBS.fromStrict &> Just)

data SubmissionJSONable
  = SubmissionJSONable
      { description :: Maybe Text
      , status      :: Text
      , uploadTime  :: UTCTime
      , comments    :: [CommentJSONable]
      } deriving (Generic, ToJSON)

data CommentJSONable
  = CommentJSONable
      { comment :: Text
      , author  :: Text
      , time    :: UTCTime
      } deriving (Generic, ToJSON)

data Metadata = Metadata { desc :: Text }

instance FromJSON Metadata where
  parseJSON = withObject "Metadata" $ \o -> Metadata <$> o .: "description"
