{-# LANGUAGE TemplateHaskell #-}
module Zocalo.Gallery.GitSHA(gitSHA) where

import Language.Haskell.TH(Exp, Q, runIO, stringE)
import System.Process(readProcess)

import qualified Data.List as List


gitSHA :: Q Exp
gitSHA =
  do
    sha <- runIO $ readProcess "git" ["rev-parse", "--short", "HEAD"] ""
    stringE $ List.takeWhile (/= '\n') sha
