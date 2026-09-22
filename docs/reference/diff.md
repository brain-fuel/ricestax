---
id: ricestax.reference.diff
kind: reference
title: The line diff
---
# The line diff

## 1. The module RicesTax.Diff

A mutant is reported as the expression it changed, and a mutant that removes one alternative of a
thirty-line case is reported as thirty lines gone and twenty-nine come back. The person wants the
one line. This module finds the longest common subsequence of the lines on either side, so the
lines both sides share are context and only the lines that went and came are marked, on the card,
in the zoom, and in the copied text. It is compiled into the page and the library alike, so the
corpus can check it. ref:DEC-line-diff

```haskell file=src/RicesTax/Diff.hs part=header
module RicesTax.Diff
  ( Edit (..)
  , lineDiff
  , goneLines
  ) where
```

## 2. Edit

One line of a diff: kept on both sides at its line in the source, gone from the source at its
line, or come in the mutant at its line in the mutant's text.

```haskell file=src/RicesTax/Diff.hs def=Edit
data Edit s
  = Kept Int s
  | Gone Int s
  | Came Int s
  deriving (Eq, Show)
```

## 3. lineDiff

The diff of the source lines against the mutated lines, both numbered from the first line of the
span. The table holds, for every suffix of the source and every suffix of the mutant, the length
of their longest common subsequence, built from the last line back; the walk then keeps a line
both sides share, and otherwise drops the source line or takes the mutant line, whichever keeps
more in common ahead. Spans are short, so a list of lists is table enough.

```haskell file=src/RicesTax/Diff.hs def=lineDiff
lineDiff :: Eq s => Int -> [s] -> [s] -> [Edit s]
lineDiff from src mut = walk 0 0 src mut
  where
    rows = build src
    build [] = [replicate (length mut + 1) 0]
    build (a : as) =
      let below = build as
          row = foldr (\(b, dj, dj1) acc -> (if a == b then 1 + dj1 else max dj (headOr acc)) : acc) [0] (zip3 mut (headRow below) (drop 1 (headRow below)))
       in row : below
    headRow rs = case rs of
      (r : _) -> r
      [] -> []
    headOr xs = case xs of
      (x : _) -> x
      [] -> 0
    at i j = case drop i rows of
      (r : _) -> case drop j r of
        (v : _) -> v
        [] -> 0
      [] -> 0
    walk i j as bs = case (as, bs) of
      ([], _) -> [Came (from + j + k) b | (k, b) <- zip [0 ..] bs]
      (_, []) -> [Gone (from + i + k) a | (k, a) <- zip [0 ..] as]
      (a : as', b : bs')
        | a == b -> Kept (from + i) a : walk (i + 1) (j + 1) as' bs'
        | at (i + 1) j >= at i (j + 1) -> Gone (from + i) a : walk (i + 1) j as' bs
        | otherwise -> Came (from + j) b : walk i (j + 1) as bs'
```

## 4. goneLines

The source lines a diff removed, for marking them in the whole definition.

```haskell file=src/RicesTax/Diff.hs def=goneLines
goneLines :: [Edit s] -> [Int]
goneLines edits = [n | Gone n _ <- edits]
```
