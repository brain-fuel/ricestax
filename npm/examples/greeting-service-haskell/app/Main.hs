{-# LANGUAGE OverloadedStrings #-}
module Main where
import Greeting (application)
import Network.Wai.Handler.Warp (runSettings, setHost, setPort, defaultSettings)
main :: IO ()
main = runSettings (setHost "127.0.0.1" (setPort 8097 defaultSettings)) application
