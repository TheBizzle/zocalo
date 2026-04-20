module Main(main) where

import Snap.Core(dir, route)
import Snap.Http.Server(quickHttpServe)
import Snap.Util.FileServe(serveDirectory, serveFile)

import qualified Vandyland.BadgerState.Controller as BadgerState
import qualified Vandyland.Gallery.Controller     as Gallery

main :: IO ()
main =
  do
    Gallery.runMigrations
    quickHttpServe $
      route (BadgerState.routes <> Gallery.routes) <|>
        dir "gallery" (serveDirectory "gallery") <|>
        dir "html" (serveDirectory "html") <|>
        serveFile "frontend/dist/index.html" -- Needed for Vue to use `createWebHistory` --Jason B. (3/15/26)
