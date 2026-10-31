module Zocalo.Gallery.Entity.ActionResult(
    ActionError( Duplicate, Expired, Incorrect, InternalError, Malformed, NotAuthorized, NotFound
               , TooManyRequests, Unconfirmed
               )
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
  | TooManyRequests
  | Unconfirmed
  deriving (Show, Eq)

instance Semigroup ActionError where
  a <> _ = a
