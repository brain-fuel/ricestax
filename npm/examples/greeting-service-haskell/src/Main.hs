-- Tangled from service.md.
-- Edit the specification, not this file.
-- Every comment below is generated from the prose there.

-- | Reject an empty or whitespace-only name, trim surrounding whitespace, and greet the caller.
-- The Node HTTP adapter maps rejection to 400, routes other requests to 404, and
-- JSON-encodes successful text. The haskell implementation below owns validation
-- and greeting construction.
--
-- Specified by service.
module Main where

import Data.Char (isSpace)
import Data.List (dropWhileEnd)
import System.Environment (getArgs)
import System.Exit (exitWith, ExitCode(ExitFailure))

main :: IO ()
main = do
  args <- getArgs
  let name = dropWhileEnd isSpace (dropWhile isSpace (head args))
  if null name
    then exitWith (ExitFailure 2)
    else putStrLn ("Hello, " ++ name ++ "!")
