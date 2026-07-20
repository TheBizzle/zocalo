module Zocalo.Gallery.SocketClient(ModeratorClient(connection, galleryID, ModeratorClient, teacher)) where

import Data.NanoID(NanoID)

import Network.WebSockets(Connection)

import Zocalo.Gallery.Auth.AuthorizedUser(AuthorizedTeacher)


data ModeratorClient
  = ModeratorClient { teacher    :: AuthorizedTeacher
                    , galleryID  :: NanoID
                    , connection :: Connection
                    }
