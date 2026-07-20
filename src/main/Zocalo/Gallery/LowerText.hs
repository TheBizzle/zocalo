module Zocalo.Gallery.LowerText(asLowerText, LowerText, lowText) where

import Database.Persist.Sql(
    PersistField(fromPersistValue, toPersistValue)
  , PersistFieldSql(sqlType)
  , PersistValue(PersistText)
  , SqlType(SqlString)
  )

import qualified Data.Text as Text


newtype LowerText =
  LowerText Text
  deriving (Eq, Ord, Show)

asLowerText :: Text -> LowerText
asLowerText = Text.toLower &> LowerText

lowText :: LowerText -> Text
lowText (LowerText t) = t

instance PersistField LowerText where
  fromPersistValue (PersistText t) = Right $ asLowerText t
  fromPersistValue x               = Left $ "Expected PersistText, got: " <> showText x

  toPersistValue (LowerText t) = PersistText t

instance PersistFieldSql LowerText where
  sqlType _ = SqlString
