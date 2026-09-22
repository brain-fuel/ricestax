{-# LANGUAGE OverloadedStrings #-}
module Main where

import Data.Aeson (Value, eitherDecode, object, (.=))
import qualified Data.ByteString.Char8 as B
import qualified Data.Text as T
import Data.Text.Encoding (encodeUtf8)
import Greeting (application)
import Network.HTTP.Client hiding (checkResponse)
import Network.HTTP.Types
import Network.Wai.Handler.Warp (testWithApplication)
import Test.Hspec

main :: IO ()
main = hspec $ around (testWithApplication (pure application)) $ do
  it "serves greetings, trims, preserves Unicode and escapes JSON" $ \port -> do
    manager <- newManager defaultManagerSettings
    mapM_ (\name -> do
      let query = B.unpack (renderQuery True [("name", Just (encodeUtf8 name))])
      checkResponse manager port methodGet ("/greet" ++ query) status200
        (object ["greeting" .= ("Hello, " <> T.strip name <> "!")]))
      ["Ada", "  Ada Lovelace  ", "A\"B", "Zoë"]
  it "rejects missing or blank names and separates route and method failures" $ \port -> do
    manager <- newManager defaultManagerSettings
    mapM_ (\query -> checkResponse manager port methodGet ("/greet" ++ query) status400
      (object ["error" .= ("A nonempty name is required" :: T.Text)])) ["", "?name=", "?name=%20%20"]
    checkResponse manager port methodGet "/other" status404 (object ["error" .= ("Not found" :: T.Text)])
    checkResponse manager port methodPost "/greet?name=Ada" status404 (object ["error" .= ("Not found" :: T.Text)])

checkResponse :: Manager -> Int -> Method -> String -> Status -> Value -> IO ()
checkResponse manager port verb path expectedStatus expectedBody = do
  request <- parseRequest ("http://127.0.0.1:" ++ show port ++ path)
  response <- httpLbs (request { method = verb, responseTimeout = responseTimeoutMicro 5000000 }) manager
  responseStatus response `shouldBe` expectedStatus
  (eitherDecode (responseBody response) :: Either String Value) `shouldBe` Right expectedBody
  lookup hContentType (responseHeaders response) `shouldBe` Just "application/json; charset=utf-8"
