-- Tangled from marks.md.
-- Edit the specification, not this file.
-- Every comment below is generated from the prose there.

-- | The run-length form the wire carries beside every code line, read and cut on the page and
-- written
-- on the server, in plain strings so the page's string and the server's text both reach it by
-- unpacking. A run is a class letter and a count of characters; the runs of a line cover it in
-- order
-- and an empty string is a plain line. It is compiled into the page and the library alike, so
-- the
-- corpus can check it. ref:DEC-highlighting
--
-- Specified by marks S1.
module RicesTax.Marks
  ( Run
  , parseRuns
  , renderRuns
  , classLetter
  , classWord
  , cutRuns
  , padRuns
  ) where

import Data.Char (isDigit)

-- | A class letter and how many characters it covers.
--
-- Specified by marks S2.
type Run = (Char, Int)

-- | The runs of a mark: each a letter followed by digits; anything malformed ends the runs, and
-- what
-- is not covered is plain.
--
-- Specified by marks S3.
parseRuns :: String -> [Run]
parseRuns s = case s of
  (c : rest) | not (isDigit c) ->
    let (digits, more) = span isDigit rest
     in if null digits then [] else (c, read digits) : parseRuns more
  _ -> []

-- | The mark of a line from its runs, empty when every run is plain, so a plain line costs
-- nothing.
--
-- Specified by marks S4.
renderRuns :: [Run] -> String
renderRuns runs
  | all ((== 'p') . fst) runs = ""
  | otherwise = concat [c : show n | (c, n) <- runs, n > 0]

-- | The letter of a class word and the word of a letter; a word or letter not known is plain.
--
-- Specified by marks S5.
classLetter :: String -> Char
classLetter w = case w of
  "keyword" -> 'k'
  "comment" -> 'c'
  "string" -> 's'
  "number" -> 'n'
  "type" -> 't'
  "meta" -> 'm'
  "name" -> 'd'
  _ -> 'p'

classWord :: Char -> String
classWord c = case c of
  'k' -> "keyword"
  'c' -> "comment"
  's' -> "string"
  'n' -> "number"
  't' -> "type"
  'm' -> "meta"
  'd' -> "name"
  _ -> "plain"

-- | The runs before and from a character offset, the run at the offset halved, so the changed run
-- of
-- a line can be tinted without losing its colours.
--
-- Specified by marks S6.
cutRuns :: Int -> [Run] -> ([Run], [Run])
cutRuns k runs = case runs of
  [] -> ([], [])
  ((c, n) : rest)
    | k <= 0 -> ([], runs)
    | n <= k -> let (a, b) = cutRuns (k - n) rest in ((c, n) : a, b)
    | otherwise -> ([(c, k)], (c, n - k) : rest)

-- | The runs padded with plain to a line's length, or cut to it, so a mark and its line always
-- agree.
--
-- Specified by marks S7.
padRuns :: Int -> [Run] -> [Run]
padRuns len runs =
  let (kept, _) = cutRuns len runs
      total = sum (map snd kept)
   in kept ++ [('p', len - total) | len > total]
