---
id: ricestax.reference.marks
kind: reference
title: The marks
---
# The marks

## 1. The module RicesTax.Marks

The run-length form the wire carries beside every code line, read and cut on the page and written
on the server, in plain strings so the page's string and the server's text both reach it by
unpacking. A run is a class letter and a count of characters; the runs of a line cover it in order
and an empty string is a plain line. It is compiled into the page and the library alike, so the
corpus can check it. ref:DEC-highlighting

```haskell file=src/RicesTax/Marks.hs part=header
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
```

## 2. Run

A class letter and how many characters it covers.

```haskell file=src/RicesTax/Marks.hs def=Run
type Run = (Char, Int)
```

## 3. parseRuns

The runs of a mark: each a letter followed by digits; anything malformed ends the runs, and what
is not covered is plain.

```haskell file=src/RicesTax/Marks.hs def=parseRuns
parseRuns :: String -> [Run]
parseRuns s = case s of
  (c : rest) | not (isDigit c) ->
    let (digits, more) = span isDigit rest
     in if null digits then [] else (c, read digits) : parseRuns more
  _ -> []
```

## 4. renderRuns

The mark of a line from its runs, empty when every run is plain, so a plain line costs nothing.

```haskell file=src/RicesTax/Marks.hs def=renderRuns
renderRuns :: [Run] -> String
renderRuns runs
  | all ((== 'p') . fst) runs = ""
  | otherwise = concat [c : show n | (c, n) <- runs, n > 0]
```

## 5. classLetter and classWord

The letter of a class word and the word of a letter; a word or letter not known is plain.

```haskell file=src/RicesTax/Marks.hs def=classLetter
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
```

```haskell file=src/RicesTax/Marks.hs def=classWord
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
```

## 6. cutRuns

The runs before and from a character offset, the run at the offset halved, so the changed run of
a line can be tinted without losing its colours.

```haskell file=src/RicesTax/Marks.hs def=cutRuns
cutRuns :: Int -> [Run] -> ([Run], [Run])
cutRuns k runs = case runs of
  [] -> ([], [])
  ((c, n) : rest)
    | k <= 0 -> ([], runs)
    | n <= k -> let (a, b) = cutRuns (k - n) rest in ((c, n) : a, b)
    | otherwise -> ([(c, k)], (c, n - k) : rest)
```

## 7. padRuns

The runs padded with plain to a line's length, or cut to it, so a mark and its line always agree.

```haskell file=src/RicesTax/Marks.hs def=padRuns
padRuns :: Int -> [Run] -> [Run]
padRuns len runs =
  let (kept, _) = cutRuns len runs
      total = sum (map snd kept)
   in kept ++ [('p', len - total) | len > total]
```
