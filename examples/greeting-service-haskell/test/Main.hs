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
import Hedgehog (evalIO)
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range
import Test.Hspec.Hedgehog (hedgehog, forAll)

main :: IO ()
main = hspec $ around (\action -> testWithApplication (pure application) (\port ->
  newManager defaultManagerSettings >>= \manager -> action (port, manager))) $ do
  it "serves greetings, trims, preserves Unicode and escapes JSON" $ \(port, manager) -> do
    mapM_ (\(name, expected) -> do
      let query = B.unpack (renderQuery True [("name", Just (encodeUtf8 name))])
      checkResponse manager port methodGet ("/greet" ++ query) status200
        (object ["greeting" .= ("Hello, " <> expected <> "!" :: T.Text)]))
      [("Ada", "Ada"), ("  Ada Lovelace  ", "Ada Lovelace"), ("A\"B", "A\"B"), ("Zoë", "Zoë")]
  it "rejects missing or blank names and separates route and method failures" $ \(port, manager) -> do
    mapM_ (\query -> checkResponse manager port methodGet ("/greet" ++ query) status400
      (object ["error" .= ("A nonempty name is required" :: T.Text)])) ["", "?name=", "?name=%20%20"]
    checkResponse manager port methodGet "/other" status404 (object ["error" .= ("Not found" :: T.Text)])
    checkResponse manager port methodPost "/greet?name=Ada" status404 (object ["error" .= ("Not found" :: T.Text)])


  it "preserves generated names across URL and JSON encoding" $ \(port, manager) -> hedgehog $ do
      middle <- forAll $ Gen.text (Range.linear 0 64)
        (Gen.element ['a', 'Z', '0', ' ', '\t', '\n', '\r', '\0', '"', '\\', '&', '+', '%', '/', 'é', 'λ', '界', '😀'])
      left <- forAll padding
      right <- forAll padding
      -- Known non-whitespace boundaries make the oracle independent of T.strip.
      let core = "A" <> middle <> "Z"
          query = B.unpack (renderQuery True [("name", Just (encodeUtf8 (left <> core <> right)))])
      evalIO $ checkResponse manager port methodGet ("/greet" ++ query) status200
        (object ["greeting" .= ("Hello, " <> core <> "!")])
  it "rejects generated ASCII whitespace-only names" $ \(port, manager) -> hedgehog $ do
      blank <- forAll padding
      let query = B.unpack (renderQuery True [("name", Just (encodeUtf8 blank))])
      evalIO $ checkResponse manager port methodGet ("/greet" ++ query) status400
        (object ["error" .= ("A nonempty name is required" :: T.Text)])
  it "rejects generated unknown routes" $ \(port, manager) -> hedgehog $ do
      suffix <- forAll $ Gen.string (Range.linear 0 32) Gen.alphaNum
      evalIO $ checkResponse manager port methodGet ("/missing-" ++ suffix ++ "?name=Ada") status404
        (object ["error" .= ("Not found" :: T.Text)])
  it "rejects unsupported methods over HTTP" $ \(port, manager) -> hedgehog $ do
      verb <- forAll $ Gen.element [methodPost, methodPut, methodDelete, methodPatch, methodOptions]
      evalIO $ checkResponse manager port verb "/greet?name=Ada" status404
        (object ["error" .= ("Not found" :: T.Text)])

padding = Gen.text (Range.linear 0 12) (Gen.element [' ', '\t', '\r', '\n'])

checkResponse :: Manager -> Int -> Method -> String -> Status -> Value -> IO ()
checkResponse manager port verb path expectedStatus expectedBody = do
  request <- parseRequest ("http://127.0.0.1:" ++ show port ++ path)
  response <- httpLbs (request { method = verb, responseTimeout = responseTimeoutMicro 5000000 }) manager
  responseStatus response `shouldBe` expectedStatus
  (eitherDecode (responseBody response) :: Either String Value) `shouldBe` Right expectedBody
  lookup hContentType (responseHeaders response) `shouldBe` Just "application/json; charset=utf-8"
