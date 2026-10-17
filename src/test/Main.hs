module Main(main) where

import Test.Framework(defaultMain)

import qualified Zocalo.Common.SecureTokenSpec as SecureToken
import qualified Zocalo.Common.SnapHelpersSpec as SnapHelpers
import qualified Zocalo.Gallery.AuthSpec       as Auth

main :: IO ()
main = defaultMain [SecureToken.tests, SnapHelpers.tests, Auth.tests]
