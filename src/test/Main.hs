module Main(main) where

import Test.Framework(defaultMain)

import qualified Zocalo.Common.ConfigTemplateSpec     as ConfigTemplate
import qualified Zocalo.Common.ContentDispositionSpec as ContentDisposition
import qualified Zocalo.Common.SecureTokenSpec        as SecureToken
import qualified Zocalo.Common.SnapHelpersSpec        as SnapHelpers
import qualified Zocalo.Gallery.AuthSpec              as Auth
import qualified Zocalo.Gallery.DBNamingSpec          as DBNaming
import qualified Zocalo.Gallery.RoutesSpec            as Routes
import qualified Zocalo.Gallery.ZipMakerSpec          as ZipMaker

main :: IO ()
main =
  defaultMain
    [ SecureToken.tests, SnapHelpers.tests, Auth.tests, ConfigTemplate.tests, ContentDisposition.tests
    , DBNaming.tests, Routes.tests, ZipMaker.tests
    ]
