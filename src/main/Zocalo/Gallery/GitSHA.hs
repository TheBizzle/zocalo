{-# LANGUAGE TemplateHaskell #-}
module Zocalo.Gallery.GitSHA(gitSHA) where

import Language.Haskell.TH(Exp, Q, runIO, stringE)
import Language.Haskell.TH.Syntax(addDependentFile)

import Control.Exception(SomeException, try)

import System.Directory(doesFileExist)
import System.IO(readFile)
import System.Process(readProcess)

import qualified Data.List as List


type Result = IO (Either SomeException String)

gitSHA :: Q Exp
gitSHA =
  do
    let shaFile  = "git-sha.txt" :: FilePath
    hasFile     <- runIO $ doesFileExist shaFile
    sha         <- if hasFile then
                     addDependentFile shaFile *> (runIO $ readFile shaFile)
                   else
                     runIO $ do
                       result <- try $ readProcess "git" ["rev-parse", "--short", "HEAD"] "" :: Result
                       return $ either (const fallback) id result
    let firstLine = List.takeWhile (/= '\n') sha
    stringE $ if List.null firstLine then fallback else firstLine
  where
    fallback = "unknown"
