---
id: greeting.haskell.service
kind: reference
title: Native haskell HTTP service
---
# Greeting HTTP service

The server accepts GET /greet, trims the name and returns JSON. Missing or blank
names produce 400. Other paths and methods produce 404. Tests use real HTTP
connections against the same application on an ephemeral port.

## Implementation

The haskell runtime owns routing, input validation, JSON encoding and HTTP transport.

```haskell file=src/Greeting.hs part=implementation
{-# LANGUAGE OverloadedStrings #-}
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

```
