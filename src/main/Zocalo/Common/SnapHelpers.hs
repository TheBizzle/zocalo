{-# LANGUAGE TupleSections #-}
module Zocalo.Common.SnapHelpers(allowingCORS, Arg(Arg), asBool, asBytes, asInt, asNanoID, asNonNegInt, asToken, asUUID, Constraint(Constraint), decodeText, encodeText, failWith, free, getParamV, getParamVM, handle1, handle2, handle3, handle4, handle5, handle6, notEmpty, notifyBadParams, ok, succeed, withFileUploads) where

import Codec.Compression.Zlib.Internal(decompressST, defaultDecompressParams, foldDecompressStreamWithInput, gzipFormat)

import Control.Lens((#))

import Data.Aeson(decode, encode, FromJSON, ToJSON)
import Data.NanoID(defaultAlphabet, NanoID(NanoID), unAlphabet)
import Data.Text.Encoding(decodeUtf8, encodeUtf8)
import Data.UUID(UUID)
import Data.Validation(_Failure, _Success)

import Snap.Core(getParam, method, Method, modifyResponse, setContentType, setResponseStatus, Snap, writeText)
import Snap.Util.CORS(applyCORS, defaultOptions)
import Snap.Util.FileUploads(defaultFileUploadPolicy, defaultUploadPolicy, FormFile(formFileValue), handleFormUploads, PartInfo(partFieldName), setMaximumFileSize, setMaximumFormInputSize, storeAsLazyByteString)

import System.IO.Streams(InputStream)

import Zocalo.Common.SecureToken(SecureToken, tokenFromText)

import qualified Data.ByteString.Char8   as BSChar
import qualified Data.ByteString.Lazy    as LazyByteString
import qualified Data.Map                as Map
import qualified Data.Text               as Text
import qualified Data.Text.Lazy          as LazyText
import qualified Data.Text.Lazy.Encoding as LazyTextEncoding
import qualified Data.UUID               as UUID


data Constraint t =
  Constraint (ByteString -> ByteString -> Validation [Text] t)

data Arg t =
  Arg ByteString (Constraint t)

handle1 :: Arg t -> (t -> Snap ()) -> Snap ()
handle1 arg onSuccess =
  do
    arg <- getParamV arg
    bimapM_ notifyBadParams onSuccess arg

handle2 :: (Arg t1, Arg t2) -> ((t1, t2) -> Snap ()) -> Snap ()
handle2 (arg1, arg2) onSuccess =
  do
    arg1 <- getParamV arg1
    arg2 <- getParamV arg2
    let tupleV = (,) <$> arg1 <*> arg2
    bimapM_ notifyBadParams onSuccess tupleV

handle3 :: (Arg t1, Arg t2, Arg t3) -> ((t1, t2, t3) -> Snap ()) -> Snap ()
handle3 (arg1, arg2, arg3) onSuccess =
  do
    arg1 <- getParamV arg1
    arg2 <- getParamV arg2
    arg3 <- getParamV arg3
    let tupleV = (,,) <$> arg1 <*> arg2 <*> arg3
    bimapM_ notifyBadParams onSuccess tupleV

handle4 :: (Arg t1, Arg t2, Arg t3, Arg t4) -> ((t1, t2, t3, t4) -> Snap ()) -> Snap ()
handle4 (arg1, arg2, arg3, arg4) onSuccess =
  do
    arg1 <- getParamV arg1
    arg2 <- getParamV arg2
    arg3 <- getParamV arg3
    arg4 <- getParamV arg4
    let tupleV = (,,,) <$> arg1 <*> arg2 <*> arg3 <*> arg4
    bimapM_ notifyBadParams onSuccess tupleV

handle5 :: (Arg t1, Arg t2, Arg t3, Arg t4, Arg t5) -> ((t1, t2, t3, t4, t5) -> Snap ()) -> Snap ()
handle5 (arg1, arg2, arg3, arg4, arg5) onSuccess =
  do
    arg1 <- getParamV arg1
    arg2 <- getParamV arg2
    arg3 <- getParamV arg3
    arg4 <- getParamV arg4
    arg5 <- getParamV arg5
    let tupleV = (,,,,) <$> arg1 <*> arg2 <*> arg3 <*> arg4 <*> arg5
    bimapM_ notifyBadParams onSuccess tupleV

handle6 :: (Arg t1, Arg t2, Arg t3, Arg t4, Arg t5, Arg t6) -> ((t1, t2, t3, t4, t5, t6) -> Snap ()) -> Snap ()
handle6 (arg1, arg2, arg3, arg4, arg5, arg6) onSuccess =
  do
    arg1 <- getParamV arg1
    arg2 <- getParamV arg2
    arg3 <- getParamV arg3
    arg4 <- getParamV arg4
    arg5 <- getParamV arg5
    arg6 <- getParamV arg6
    let tupleV = (,,,,,) <$> arg1 <*> arg2 <*> arg3 <*> arg4 <*> arg5 <*> arg6
    bimapM_ notifyBadParams onSuccess tupleV

decodeText :: FromJSON a => Text -> Maybe a
decodeText = encodeUtf8 &> LazyByteString.fromStrict &> decode

encodeText :: ToJSON a => a -> Text
encodeText = encode &> LazyTextEncoding.decodeUtf8 &> LazyText.toStrict

getParamV :: Arg to -> Snap (Validation [Text] to)
getParamV (Arg paramName (Constraint constrain)) =
  do
    param <- getParam paramName
    let paramV = maybe (_Failure # [decodeUtf8 paramName]) (_Success #) param
    return $ case paramV of
               (Success value) -> constrain paramName value
               (Failure errs)  -> _Failure # errs

getParamVM :: Map Text ByteString -> Arg to -> Snap (Validation [Text] to)
getParamVM paramMap (Arg paramName (Constraint constrain)) =
  do
    param      <- getParam paramName
    let paramA  = param <|> (Map.lookup (decodeUtf8 paramName) paramMap)
    let paramV  = maybe (_Failure # [decodeUtf8 paramName]) (_Success #) paramA
    return $ case paramV of
      (Success value) -> constrain paramName value
      (Failure errs)  -> _Failure # errs

allowingCORS :: Method -> Snap () -> Snap ()
allowingCORS mthd f = applyCORS defaultOptions $ method mthd f

notifyBadParams :: [Text] -> Snap ()
notifyBadParams = (map ("Missing/invalid parameter: " <>)) &> unlines &> writeText &> (failWith 422)

failWith :: Int -> Snap () -> Snap ()
failWith x snap =
  do
    modifyResponse $ setResponseStatus x $ statusName x
    snap
  where
    statusName 400 = "Bad Request"
    statusName 401 = "Unauthorized"
    statusName 403 = "Forbidden"
    statusName 404 = "Not Found"
    statusName 409 = "Conflict"
    statusName 422 = "Unprocessable Entity"
    statusName y   = error $ traceShowId $ "Unhandled status: " <> (showText y)

succeed :: ByteString -> Text -> Snap ()
succeed contentType output =
  do
    modifyResponse $ setContentType contentType
    writeText output

ok :: Snap ()
ok = succeed "text/plain" ""

asNanoID :: Constraint NanoID
asNanoID = Constraint $ buildConstraint $
  \x ->
    if Text.length x == 21 && Text.all (`Text.elem` allowed) x then
      Just (NanoID (encodeUtf8 x))
    else
      Nothing
  where
    allowed = asText $ BSChar.unpack $ unAlphabet defaultAlphabet

asNonNegInt :: Constraint Int
asNonNegInt = Constraint $ buildConstraint $ \x -> (readMaybe (asString x) :: Maybe Int) |>
  (>>= (\n -> if n < 0 then Nothing else Just n))

asInt :: Constraint Int
asInt = Constraint $ buildConstraint (asString &> readMaybe :: Text -> Maybe Int)

asBool :: Constraint Bool
asBool = Constraint $ buildConstraint $ Text.toLower &> decoder
  where
    decoder "true"  = Just True
    decoder "false" = Just False
    decoder _       = Nothing

asToken :: Constraint SecureToken
asToken = Constraint $ buildConstraint tokenFromText

asUUID :: Constraint UUID
asUUID = Constraint $ buildConstraint UUID.fromText

asBytes :: Constraint ByteString
asBytes = Constraint $ const (_Success #)

free :: Constraint Text
free = Constraint $ const (decodeUtf8 &> (_Success #))

notEmpty :: Constraint Text
notEmpty =
  Constraint $ \paramName x ->
    case x of
      "" -> _Failure # [(decodeUtf8 paramName) <> " cannot be empty"]
      y  -> _Success # (decodeUtf8 y)

buildConstraint :: (Text -> Maybe a) -> ByteString -> ByteString -> Validation [Text] a
buildConstraint f paramName x =
  maybe (_Failure # [(decodeUtf8 paramName)]) (_Success #) (f $ decodeUtf8 x)

withFileUploads :: (Map Text ByteString -> Snap ()) -> Snap ()
withFileUploads f =
  do
    (formParams, formFiles) <- handleFormUploads uploadPolicy filePolicy handleRead
    let fileKVPairs          = formFiles <&> formFileValue
    paramKVPairs            <- liftIO $ traverse (processParamPair &> return) formParams
    (paramKVPairs <> fileKVPairs) |> Map.fromList &> f
  where
    uploadPolicy = setMaximumFormInputSize _20MB defaultUploadPolicy
    filePolicy   = setMaximumFileSize      _20MB defaultFileUploadPolicy
    _20MB        = 20 * 1024 * 1024

    processParamPair :: (ByteString, ByteString) -> (Text, ByteString)
    processParamPair (k, v) = processThem (sbsToLBS k) $ sbsToLBS v

    processThem :: LazyByteString.ByteString -> LazyByteString.ByteString -> (Text, ByteString)
    processThem key = readPossibleGZip &> (lbsToText key,)

    readPossibleGZip :: LazyByteString.ByteString -> ByteString
    readPossibleGZip input = foldDecompressStreamWithInput
                               (sbsToLBS &> LazyByteString.toStrict &> (<>))
                               LazyByteString.toStrict
                               (const $ input |> LazyByteString.toStrict)
                               (decompressST gzipFormat defaultDecompressParams)
                               input

    handleRead :: PartInfo -> InputStream ByteString -> IO (Text, ByteString)
    handleRead partInfo = storeAsLazyByteString &>= ((processThem extractedKey) &> return)
      where
        extractedKey = partInfo |> partFieldName &> sbsToLBS

    lbsToText = LazyTextEncoding.decodeUtf8 &> LazyText.toStrict

    sbsToLBS = LazyByteString.fromStrict
