{-# LANGUAGE TemplateHaskell #-}
module Zocalo.Gallery.GitSHA(gitSHA) where

import Language.Haskell.TH(Exp, Q, runIO, stringE)
import Language.Haskell.TH.Syntax(addDependentFile)

import System.Directory(doesFileExist)
import System.IO(readFile)
import System.Process(readProcess)

import qualified Data.List as List


gitSHA :: Q Exp
gitSHA =
  do
    let shaFile  = "git-sha.txt" :: FilePath
    hasFile     <- runIO $ doesFileExist shaFile
    sha         <- if hasFile then
                     addDependentFile shaFile *> (runIO $ readFile shaFile)
                   else
                     runIO $ readProcess "git" ["rev-parse", "--short", "HEAD"] ""
    stringE $ List.takeWhile (/= '\n') sha
