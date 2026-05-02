module Zocalo.Gallery.DBSnakeCase(bizzleSnakeCase) where

import Language.Haskell.TH.Quote(QuasiQuoter)

import Database.Persist.TH(persistWith)
import Database.Persist.Quasi(lowerCaseSettings, setPsToDBName)

import qualified Data.Char as Char
import qualified Data.List as List
import qualified Data.Text as Text


bizzleSnakeCase :: QuasiQuoter
bizzleSnakeCase = persistWith $ setPsToDBName toSnakeCase lowerCaseSettings
  where
    -- For example, GalleryID => gallery_id --Jason B. (5/2/26)
    toSnakeCase :: Text -> Text
    toSnakeCase = Text.unpack &> groupedChars &> map segment &> Text.concat &> Text.dropWhile (== '_')
      where
        groupedChars []     = []
        groupedChars (c:cs) = (c:same) : groupedChars rest
          where
            (same, rest) = List.span (\x -> Char.isUpper c == Char.isUpper x) cs

        segment g@(c:_) | Char.isUpper c = Text.cons '_' $ Text.pack $ map Char.toLower g
        segment g                        = Text.pack g
