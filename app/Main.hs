module Main(main) where

import GHC.Conc(newTVarIO)

import Snap.Core(dir, route)
import Snap.Http.Server(quickHttpServe)
import Snap.Util.FileServe(serveDirectory, serveFile)

import qualified Data.Map                      as Map
import qualified Zocalo.BadgerState.Controller as BadgerState
import qualified Zocalo.Gallery.Controller     as Gallery


main :: IO ()
main =
  do
    Gallery.runMigrations
    moderators <- newTVarIO Map.empty
    students   <- newTVarIO Map.empty
    quickHttpServe $
      route (BadgerState.routes <> (Gallery.routes moderators students)) <|>
        dir "gallery" (serveDirectory "gallery") <|>
        dir "html" (serveDirectory "html") <|>
        serveFile "frontend/dist/index.html" -- Needed for Vue to use `createWebHistory` --Jason B. (3/15/26)
