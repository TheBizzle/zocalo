{-# LANGUAGE TemplateHaskell #-}
module Zocalo.Gallery.RandGen(generate6Digit, generateLongName, generateName) where

import Data.ByteString.Char8(split)
import Data.FileEmbed(embedFile)
import Data.List((!!), filter)
import Data.Text.Encoding(decodeUtf8)

import System.Random(randomRIO)

import qualified Data.ByteString as BS

generate6Digit :: IO Int32
generate6Digit = randomRIO (0, 999999)

generateName :: IO Text
generateName = (\x y -> x <> " " <> y) <$> (randomOneOf adjectives) <*> (randomOneOf animals)

generateLongName :: IO Text
generateLongName = (\x y z a -> x <> " " <> y <> " " <> z <> " " <> a) <$> (randomOneOf adjectives) <*> (randomOneOf adjectives) <*> (randomOneOf adjectives) <*> (randomOneOf animals)

randomOneOf :: [a] -> IO a
randomOneOf xs =
  do
    index <- randomRIO (0, (length xs) - 1)
    return $ xs !! (fromIntegral index)

adjectives :: [Text]
adjectives = format $(embedFile "adjectives.txt")

animals :: [Text]
animals = format $(embedFile "animals.txt")

format :: ByteString -> [Text]
format = (split '\n') &> (filter $ not . BS.null) &> (map decodeUtf8)
