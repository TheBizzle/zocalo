module Zocalo.Gallery.Auth.AuthorizedUser(
    AuthorizedStudent(AStudent, studentID, studentName)
  , AuthorizedTeacher(ATeacher, teacherAddr)
  , AuthorizedUser(readUser)
  ) where

import Zocalo.Gallery.Entity.LowerText(asLowerText, LowerText)

import qualified Data.Text      as Text
import qualified Data.Text.Read as Read


class AuthorizedUser a where
  readUser :: Text -> Maybe a

instance AuthorizedUser AuthorizedStudent where
  readUser text =
      case (Read.decimal sid, Text.uncons rest) of
        (Right (n, ""), Just ('|', name)) -> Just $ AStudent n name
        _                                 -> Nothing
    where
      (sid, rest) = Text.breakOn "|" text

instance AuthorizedUser AuthorizedTeacher where
  readUser = asLowerText &> ATeacher &> Just

data AuthorizedStudent =
  AStudent { studentID :: Word64, studentName :: Text }
  deriving (Eq, Ord, Show)

newtype AuthorizedTeacher =
  ATeacher { teacherAddr :: LowerText }
  deriving (Eq, Ord, Show)
