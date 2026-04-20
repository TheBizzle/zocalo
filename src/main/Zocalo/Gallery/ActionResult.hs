module Zocalo.Gallery.ActionResult(
    ActionError(Duplicate, Expired, Incorrect, InternalError, Malformed, NotAuthorized, NotFound, Unconfirmed)
  , ActionResult
  ) where


type ActionResult a = Validation ActionError a

data ActionError
  = Duplicate
  | Expired
  | Incorrect
  | InternalError
  | Malformed
  | NotAuthorized
  | NotFound
  | Unconfirmed
  deriving (Show, Eq)

instance Semigroup ActionError where
  a <> _ = a
