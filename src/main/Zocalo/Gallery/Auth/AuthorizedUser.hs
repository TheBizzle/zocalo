module Zocalo.Gallery.Auth.AuthorizedUser(
    AuthorizedStudent(AStudent, studentID, studentName)
  , AuthorizedTeacher(ATeacher, teacherAddr)
  , AuthorizedUser(readUser)
  ) where

import Zocalo.Gallery.LowerText(asLowerText, LowerText)

import qualified Data.Text      as Text
import qualified Data.Text.Read as Read


class AuthorizedUser a where
  readUser :: Text -> Maybe a

instance AuthorizedUser AuthorizedStudent where
  readUser text =
      case Read.decimal sid of
        Right (n, "") -> Just $ AStudent n $ Text.tail name
        _             -> Nothing
    where
      (sid, name) = Text.breakOn "|" text

instance AuthorizedUser AuthorizedTeacher where
  readUser = asLowerText &> ATeacher &> Just

data AuthorizedStudent =
  AStudent { studentID :: Word64, studentName :: Text }
  deriving (Eq, Ord, Show)

newtype AuthorizedTeacher =
  ATeacher { teacherAddr :: LowerText }
  deriving (Eq, Ord, Show)
