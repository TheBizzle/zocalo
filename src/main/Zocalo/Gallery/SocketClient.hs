module Zocalo.Gallery.SocketClient(
    GalleryObserverClient(GalleryObserverClient, gocConnection, gocGalleryID, gocStudent)
  , ModeratorClient(mcConnection, mcGalleryID, ModeratorClient, mcTeacher)
  ) where

import Data.NanoID(NanoID)

import Network.WebSockets(Connection)

import Zocalo.Gallery.Auth.AuthorizedUser(AuthorizedStudent, AuthorizedTeacher)


data GalleryObserverClient
  = GalleryObserverClient { gocStudent    :: AuthorizedStudent
                          , gocGalleryID  :: NanoID
                          , gocConnection :: Connection
                          }

data ModeratorClient
  = ModeratorClient { mcTeacher    :: AuthorizedTeacher
                    , mcGalleryID  :: NanoID
                    , mcConnection :: Connection
                    }
