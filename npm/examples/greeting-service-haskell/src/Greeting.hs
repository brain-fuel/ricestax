-- Tangled from service.md.
-- Edit the specification, not this file.
-- Every comment below is generated from the prose there.

{-# LANGUAGE OverloadedStrings #-}
-- | The haskell runtime owns routing, input validation, JSON encoding and HTTP transport.
--
-- Specified by service.
module Greeting (application) where

import Data.Aeson (encode, object, (.=))
import qualified Data.Text as T
import Data.Text.Encoding (decodeUtf8With)
import Data.Text.Encoding.Error (lenientDecode)
import Network.HTTP.Types
import Network.Wai

application :: Application
application request respond
  | requestMethod request /= methodGet || pathInfo request /= ["greet"] =
      respond (reply status404 "error" "Not found")
  | T.null name = respond (reply status400 "error" "A nonempty name is required")
  | otherwise = respond (reply status200 "greeting" ("Hello, " <> name <> "!"))
  where
    name = T.strip (maybe "" (decodeUtf8With lenientDecode) (lookup "name" (queryString request) >>= id))
    reply status key value = responseLBS status [(hContentType, "application/json; charset=utf-8")]
      (encode (object [key .= (value :: T.Text)]))
