module Zocalo.Gallery.RandGen(generate6Digit, randomOneOf) where

import Data.List((!!))

import System.Random(randomRIO)


generate6Digit :: IO Int32
generate6Digit = randomRIO (0, 999999)

randomOneOf :: [a] -> IO a
randomOneOf xs =
  do
    index <- randomRIO (0, (length xs) - 1)
    return $ xs !! (fromIntegral index)
