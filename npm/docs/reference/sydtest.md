---
id: ricestax.reference.sydtest
kind: reference
title: The sydtest-mutation adapter
---
# The sydtest-mutation adapter

## 1. The module RicesTax.Sydtest

The first runtime adapter: it reads what wavelet's sydtest-mutation run leaves on disk and
turns it into mutants a person can judge, with the readings that say what the corpus made each
expression do. Nothing here runs the mutation; the run stays with the runtime.
ref:DEC-runtime-first ref:DEC-mutant-location ref:DEC-how-queue

```haskell file=src/RicesTax/Sydtest.hs part=header
module RicesTax.Sydtest
  ( Mutant (..)
  , Reading (..)
  , Run (..)
  , readRun
  , liveMutants
  , effectiveReading
  , coverageOf
  , gapOf
  , sidedOf
  , contextOf
  , chunksOf
  , headWord
    , bindingLines
    , blockOf
    , isCommentChunk
    , ruleSourcesIn
  ) where

import Control.Exception (SomeException, try)
import Control.Monad (forM)
import Data.Aeson (FromJSON (..), Value (..), eitherDecode, withObject, (.:), (.:?), (.!=))
import Data.Scientific (floatingOrInteger)
import qualified Data.Aeson.KeyMap as KM
import qualified Data.Aeson.Key as Key
import qualified Data.ByteString.Lazy as LBS
import Data.Char (isAlphaNum, isSpace)
import Data.List (isSuffixOf, nub, sort, sortOn)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe, listToMaybe, mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Canon.Config (Runtime (..))
import RicesTax.Fnv (fnv1aHex)
import RicesTax.Model (Outcome (..))
import qualified Crypto.Hash.SHA256 as SHA256
import qualified Data.ByteString as BS
import Numeric (showHex)
import System.FilePath (isRelative, splitDirectories)
import System.Directory (doesDirectoryExist, doesFileExist, listDirectory)
import System.FilePath (normalise, (</>))
```

## 2. Mutant

One mutant as the page and the ledger see it: wavelet's twelve-hex name, its anchor, where

it sits in the project, what it changed, what happened, and who looked. ref:DEC-mutant-location

```haskell file=src/RicesTax/Sydtest.hs def=Mutant
data Mutant = Mutant
  { mutantId :: Text
  , mutantModule :: Text
  , mutantBinding :: Text
  , mutantOperator :: Text
  , mutantWas :: Text
  , mutantBecame :: Text
  , mutantOutcome :: Outcome
  , mutantFile :: FilePath
  , mutantLine :: Int
  , mutantEndLine :: Int
  , mutantColStart :: Int
  , mutantColEnd :: Int
  , mutantSourceLines :: [Text]
  , mutantMutatedLines :: [Text]
  , mutantBefore :: [Text]
  , mutantAfter :: [Text]
  , mutantCovering :: [Text]
  , mutantContext :: Text
  , mutantStaleFile :: Bool
  }
  deriving (Eq, Show)
```

## 3. Reading

What the probe recorded at a mutant's site, or why it could not. ref:DEC-how-queue

```haskell file=src/RicesTax/Sydtest.hs def=Reading
data Reading = Reading
  { readingStatus :: Text
  , readingTotal :: Int
  , readingDistinct :: [(Text, Int)]
  , readingBound :: [(Text, [(Text, Int)])]
  }
  deriving (Eq, Show)
```

## 4. Run

Everything one run left behind, joined and resolved against the sources as they are now,

named by its driver, seed, and a digest of its report so a verdict can say which run it was

decided against. ref:DEC-mutant-provenance

```haskell file=src/RicesTax/Sydtest.hs def=Run
data Run = Run
  { runId :: Text
  , runFacts :: [(Text, Text)]
  , runCorpusOk :: Bool
  , runMutants :: [Mutant]
  , runReadings :: Map Text Reading
  , runStaleFiles :: [FilePath]
  , runRuleSources :: Map Text [Text]
  , runBindings :: Map (FilePath, Text) (Int, [Text])
  , runSpanReadings :: Map (FilePath, Int, Int, Int, Int) [(Text, Reading)]
  , runBindingReadings :: Map (Text, Text) [Reading]
  }
  deriving (Eq, Show)
```

```haskell file=src/RicesTax/Sydtest.hs def=Entry
data Entry = Entry
  { entryOutcome :: Text
  , entryDriverId :: [Text]
  , entryModule :: Text
  , entryOperator :: Text
  , entryOriginal :: Text
  , entryReplacement :: Text
  , entryFile :: FilePath
  , entryLine :: Int
  , entryEndLine :: Int
  , entryColStart :: Int
  , entryColEnd :: Int
  , entrySource :: [Text]
  , entryMutated :: [Text]
  }
```

```haskell file=src/RicesTax/Sydtest.hs part=instance-1
instance FromJSON Entry where
  parseJSON = withObject "Entry" $ \o -> do
    m <- o .: "mutation"
    result <- o .:? "status"
    fallback <- o .: "outcome"
    Entry
      <$> pure (fromMaybe fallback result)
      <*> m .: "id"
      <*> m .: "module"
      <*> m .: "operator"
      <*> m .:? "original" .!= ""
      <*> m .:? "replacement" .!= ""
      <*> m .: "source_file"
      <*> m .: "line"
      <*> m .:? "end_line" .!= 0
      <*> m .:? "col_start" .!= 1
      <*> m .:? "col_end" .!= 1
      <*> m .:? "source_lines" .!= []
      <*> m .:? "mutated_lines" .!= []
```

```haskell file=src/RicesTax/Sydtest.hs def=Report
data Report = Report
  { reportGroups :: [[Entry]]
  , reportControls :: (Int, Int)
  }
```

```haskell file=src/RicesTax/Sydtest.hs part=instance-2
instance FromJSON Report where
  parseJSON = withObject "Report" $ \o -> do
    groups <- o .: "groups"
    controls <- o .:? "controls"
    passed <- maybe (pure 0) (.: "passed") controls
    failed <- maybe (pure 0) (.: "failed") controls
    pure (Report groups (passed, failed))
```

```haskell file=src/RicesTax/Sydtest.hs def=Aug
data Aug = Aug
  { augDriverId :: [Text]
  , augBinding :: Text
  , augCovering :: [Text]
  , augBefore :: [Text]
  , augAfter :: [Text]
  }
```

```haskell file=src/RicesTax/Sydtest.hs part=instance-3
instance FromJSON Aug where
  parseJSON = withObject "Aug" $ \o -> do
    covering <- o .:? "covering_tests" .!= (Map.empty :: Map Text [Text])
    Aug <$> o .: "id" <*> o .:? "binding" .!= "" <*> pure (concat (Map.elems covering)) <*> o .:? "context_before" .!= [] <*> o .:? "context_after" .!= []
```

```haskell file=src/RicesTax/Sydtest.hs def=RunFacts
data RunFacts = RunFacts Text Text Text Text Text Text
```

```haskell file=src/RicesTax/Sydtest.hs part=instance-4
instance FromJSON RunFacts where
  parseJSON = withObject "RunFacts" $ \o -> RunFacts <$> (scalar <$> o .:? "seed") <*> (scalar <$> o .:? "driver") <*> (scalar <$> o .:? "toolchain") <*> (scalar <$> o .:? "commit") <*> (scalar <$> o .:? "date") <*> (scalar <$> o .:? "scope")
    where
      scalar v = case v of
        Just (String t) -> t
        Just (Number n) -> T.pack (either (show :: Double -> String) (show :: Integer -> String) (floatingOrInteger n))
        _ -> ""
```

## 5. readRun

Reads the report, the augmented manifest, the run facts, and the observations, then joins them

on the driver's id and resolves each mutant against the file as it is now. ref:DEC-runtime-first

Equal anchors are numbered in reading order; grouping once keeps this linear in the
number of mutants rather than quadratic, which was two minutes on wavelet's run.
The text before the change comes from the lines the report recorded, never from the file
as it is now, so an edit after the run moves line numbers without changing identities.

```haskell file=src/RicesTax/Sydtest.hs def=readRun
readRun :: FilePath -> Runtime -> IO (Either Text Run)
readRun root runtime = do
  let art = root </> runtimeArtefacts runtime
      pkg = root </> runtimePackage runtime
  reportBytes <- readMaybeFile (art </> "out/report.json")
  augBytes <- readMaybeFile (art </> "augmented/manifest-augmented.json")
  factsBytes <- readMaybeFile (art </> "run.json")
  obsBytes <- readMaybeFile (art </> "out/observations.json")
  (hashStale, hashFacts) <- checkSourceHashes art pkg
  case (reportBytes >>= decodeE, augBytes >>= decodeE) of
    (Left e, _) -> pure (Left ("report: " <> e))
    (_, Left e) -> pure (Left ("augmented manifest: " <> e))
    (Right report, Right augGroups) -> do
      let entries = [e | e <- concat (reportGroups report), entryOperator e /= "Control", entryOutcome e /= "control_passed", entryOutcome e /= "control_failed"]
          augs = Map.fromList [(augDriverId a, a) | a <- concat (augGroups :: [[Aug]])]
          files = nub (map entryFile entries)
      sources <- Map.fromList <$> forM files (\f -> (,) f <$> readLines (pkg </> f))
      let sorted = sortOn (\e -> (entryFile e, entryLine e, entryColStart e)) entries
          bare e = (entryModule e, bindingOf augs e, entryOperator e, wasOf sources e, normalise' (entryReplacement e))
          keyOf e = (entryFile e, entryLine e, entryColStart e)
          groups = Map.fromListWith (flip (++)) [(bare e, [keyOf e]) | e <- sorted]
          ordinalOf e = length (takeWhile (/= keyOf e) (Map.findWithDefault [] (bare e) groups))
          stale = nub [entryFile e | e <- entries, Just ls <- [Map.lookup (entryFile e) sources], null ls || slice (entryLine e) (max (entryLine e) (entryEndLine e)) ls /= entrySource e]
          mutants =
            [ Mutant
                { mutantId = T.take 12 (fnv1aHex [entryModule e, b, entryOperator e, w, became, T.pack (show (ordinalOf e))])
                , mutantModule = entryModule e
                , mutantBinding = b
                , mutantOperator = entryOperator e
                , mutantWas = w
                , mutantBecame = became
                , mutantOutcome = outcomeOf (entryOutcome e)
                , mutantFile = normalise (runtimePackage runtime </> entryFile e)
                , mutantLine = entryLine e
                , mutantEndLine = max (entryLine e) (entryEndLine e)
                , mutantColStart = entryColStart e
                , mutantColEnd = entryColEnd e
                , mutantSourceLines = entrySource e
                , mutantMutatedLines = entryMutated e
                , mutantBefore = maybe [] augBefore aug
                , mutantAfter = maybe [] augAfter aug
                , mutantCovering = sort (nub (map ruleNameOf (maybe [] augCovering aug)))
                , mutantContext = contextOf (Map.findWithDefault [] (entryFile e) sources) b
                , mutantStaleFile = entryFile e `elem` stale
                }
            | e <- entries
            , let aug = Map.lookup (entryDriverId e) augs
            , let b = bindingOf augs e
            , let w = wasOf sources e
            , let became = normalise' (entryReplacement e)
            ]
          (facts, ok) = case obsBytes >>= decodeE of
            Right (Object o) -> (Map.fromList [(Key.toText k, v) | (k, v) <- KM.toList o], runOk (KM.lookup "$run" o))
            _ -> (Map.empty, True)
          readings = Map.fromList (mapMaybe readingOf (Map.toList facts))
          runJson = case factsBytes >>= decodeE of
            Right (RunFacts seed driver toolchain commit date scope) -> [("seed", seed), ("driver", driver), ("toolchain", toolchain)] ++ [("commit", commit) | not (T.null commit)] ++ [("date", date) | not (T.null date)] ++ [("scope", scope) | not (T.null scope)]
            Left _ -> []
          (passed, failed) = reportControls report
          reportDigest = T.take 6 (fnv1aHex (sort [mutantId m <> " " <> entryOutcome e | (m, e) <- zip mutants entries]))
          ident = T.intercalate "-" (filter (not . T.null) [T.replace " " "-" (fromMaybe (runtimeName runtime) (lookup "driver" runJson)), maybe "" ("seed" <>) (lookup "seed" runJson), reportDigest])
      ruleSources <- ruleSourcesFor (root </> runtimeTests runtime) (nub (concatMap mutantCovering mutants))
      let bindings =
            Map.fromList
              [ ((entryFile e, b), whole)
              | e <- entries
              , let b = bindingOf augs e
              , not (entryFile e `elem` stale)
              , Just ls <- [Map.lookup (entryFile e) sources]
              , Just whole <- [bindingLines ls b]
              ]
      let readOf m = Map.lookup (mutantId m) readings
          spanKey m = (mutantFile m, mutantLine m, mutantColStart m, mutantEndLine m, mutantColEnd m)
      pure
        ( Right
            Run
              { runId = ident
              , runFacts = runJson ++ hashFacts ++ [("controls", T.pack (show passed) <> " passed, " <> T.pack (show failed) <> " failed"), ("mutants", T.pack (show (length entries))), ("killed", T.pack (show (length [m | m <- mutants, mutantOutcome m == Killed]))), ("survived", T.pack (show (length [m | m <- mutants, mutantOutcome m == Survived])))]
              , runCorpusOk = ok && passed > 0 && failed == 0
              , runMutants = mutants
              , runReadings = readings
              , runStaleFiles = map (normalise . (runtimePackage runtime </>)) (nub (stale ++ hashStale))
              , runRuleSources = ruleSources
              , runBindings = Map.mapKeys (\(f, b) -> (normalise (runtimePackage runtime </> f), b)) bindings
              , runSpanReadings = Map.fromListWith (flip (++)) [(spanKey m, [(mutantId m, r)]) | m <- mutants, Just r <- [readOf m], readingTotal r > 0]
              , runBindingReadings = Map.fromListWith (flip (++)) [((mutantModule m, mutantBinding m), [r]) | m <- mutants, Just r <- [readOf m], readingTotal r > 0]
              }
        )
  where
    decodeE :: FromJSON a => LBS.ByteString -> Either Text a
    decodeE = either (Left . T.pack) Right . eitherDecode
    bindingOf augs e = maybe "" augBinding (Map.lookup (entryDriverId e) augs)
    wasOf _ e = case spanText (entrySource e) 1 (entryColStart e) (max 1 (entryEndLine e - entryLine e + 1)) (entryColEnd e) of
      Just t | not (T.null (T.strip t)) -> normalise' t
      _ -> normalise' (entryOriginal e)
    runOk v = case v of
      Just (Object o) -> case KM.lookup "corpusOk" o of
        Just (Bool b) -> b
        _ -> True
      _ -> True
```

```haskell file=src/RicesTax/Sydtest.hs def=readMaybeFile
readMaybeFile :: FilePath -> IO (Either Text LBS.ByteString)
readMaybeFile path = do
  present <- doesFileExist path
  if present then Right <$> LBS.readFile path else pure (Left ("missing " <> T.pack path))
```

```haskell file=src/RicesTax/Sydtest.hs def=readLines
readLines :: FilePath -> IO [Text]
readLines path = do
  result <- try (TIO.readFile path) :: IO (Either SomeException Text)
  pure (either (const []) T.lines result)
```

## 6. spanText

The text at a span as the file has it now, because the driver reports metavariables where

the person needs the expression. ref:DEC-mutant-location

```haskell file=src/RicesTax/Sydtest.hs def=spanText
spanText :: [Text] -> Int -> Int -> Int -> Int -> Maybe Text
spanText ls line colStart endLine colEnd
  | line < 1 || endLine > length ls || line > endLine = Nothing
  | line == endLine = Just (T.take (colEnd - colStart) (T.drop (colStart - 1) (ls !! (line - 1))))
  | otherwise =
      let first = T.drop (colStart - 1) (ls !! (line - 1))
          middle = take (endLine - line - 1) (drop line ls)
          final = T.take (colEnd - 1) (ls !! (endLine - 1))
       in Just (T.unwords (first : middle ++ [final]))
```

```haskell file=src/RicesTax/Sydtest.hs def=slice
slice :: Int -> Int -> [Text] -> [Text]
slice from to ls = take (to - from + 1) (drop (from - 1) ls)
```

```haskell file=src/RicesTax/Sydtest.hs def=normalise'
normalise' :: Text -> Text
normalise' = T.unwords . T.words
```

```haskell file=src/RicesTax/Sydtest.hs def=outcomeOf
outcomeOf :: Text -> Outcome
outcomeOf t = case t of
  "killed" -> Killed
  "survived" -> Survived
  "uncovered" -> Uncovered
  "skipped" -> Skipped
  "timed_out" -> TimedOut
  "timeout" -> TimedOut
  "invalid" -> Invalid
  "infrastructure_error" -> InfrastructureError
  _ -> Unknown
```

```haskell file=src/RicesTax/Sydtest.hs def=readingOf
readingOf :: (Text, Value) -> Maybe (Text, Reading)
readingOf (k, v)
  | k == "$run" = Nothing
  | Object o <- v =
      Just
        ( k
        , Reading
            { readingStatus = textAt "status" o
            , readingTotal = intAt "total" o
            , readingDistinct = counts (KM.lookup "distinct" o)
            , readingBound = case KM.lookup "bound" o of
                Just (Array bs) -> [(textAt "name" b, counts (KM.lookup "values" b)) | Object b <- foldr (:) [] bs]
                _ -> []
            }
        )
  | otherwise = Nothing
  where
    textAt key o = case KM.lookup key o of
      Just (String s) -> s
      _ -> ""
    intAt key o = case KM.lookup key o of
      Just (Number n) -> truncate (toRational n)
      _ -> 0
    counts mv = case mv of
      Just (Array xs) -> [(textAt "value" c, intAt "count" c) | Object c <- foldr (:) [] xs]
      _ -> []
```

## 7. liveMutants

Only what survived or was never reached is a question for a person; the rest was killed or

never ran to completion. ref:DEC-how-queue

```haskell file=src/RicesTax/Sydtest.hs def=liveMutants
liveMutants :: Run -> [Mutant]
liveMutants run = [m | m <- runMutants run, mutantOutcome m `elem` [Survived, Uncovered]]
```

## 8. effectiveReading

A mutant's own reading when the probe recorded one, else the reading of another mutant on the

same span, since one probe site serves every mutant of that expression. ref:DEC-how-queue

```haskell file=src/RicesTax/Sydtest.hs def=effectiveReading
effectiveReading :: Run -> Mutant -> Maybe Reading
effectiveReading run m = case own of
  Just r | readingTotal r > 0 -> Just r
  _ -> listToMaybe [r | (i, r) <- Map.findWithDefault [] (mutantFile m, mutantLine m, mutantColStart m, mutantEndLine m, mutantColEnd m) (runSpanReadings run), i /= mutantId m]
  where
    own = Map.lookup (mutantId m) (runReadings run)
```

## 9. coverageOf

wavelet's five coverage words from a reading, in wavelet's order of tests, so a condition

that only ever took one value is told apart from an expression that is not a condition.

ref:DEC-how-subkinds

```haskell file=src/RicesTax/Sydtest.hs def=coverageOf
coverageOf :: Maybe Reading -> Text
coverageOf mr = case mr of
  Nothing -> "unobserved"
  Just r
    | readingTotal r == 0 -> "never-ran"
    | not (all (\(v, _) -> v == "True" || v == "False") (readingDistinct r)) -> "not-a-condition"
    | length (readingDistinct r) == 1 -> "one-outcome"
    | otherwise -> "both-outcomes"
```

## 10. gapOf

Why a mutant is work rather than a judgement: nothing reaches it, or the condition only ever

went one way. Nothing means it is a genuine question. ref:DEC-how-subkinds ref:DEC-work-items

```haskell file=src/RicesTax/Sydtest.hs def=gapOf
gapOf :: Mutant -> Maybe Reading -> Maybe Text
gapOf m mr
  | mutantOutcome m == Uncovered = Just "nothing reaches it"
  | coverageOf mr == "never-ran" = Just "nothing reaches it"
  | coverageOf mr == "one-outcome", Just r <- mr, ((v, _) : _) <- readingDistinct r = Just ("only ever " <> v)
  | otherwise = Nothing
```

## 11. sidedOf

Whether every decision in the binding took one value, some varied, or nothing was observed,

which tells the reviewer whether the generator or the rule is what is missing. ref:DEC-how-subkinds

```haskell file=src/RicesTax/Sydtest.hs def=sidedOf
sidedOf :: Run -> Mutant -> Text
sidedOf run m =
  let own = Map.findWithDefault [] (mutantModule m, mutantBinding m) (runBindingReadings run)
   in if null own then "NothingObserved" else if all (\r -> length (readingDistinct r) == 1) own then "EveryDecisionConstant" else "SomeDecisionsVary"
```

## 12. contextOf

The digest a verdict is judged against: the whole definition of the binding as the file has
it now, so an edit anywhere in the definition makes the verdict stale. When the adapter cannot
find a Haskell binding (for example a Java method), it hashes the entire source file instead.
This conservative fallback prevents an empty digest from keeping a verdict current after edits. ref:DEC-mutant-location

```haskell file=src/RicesTax/Sydtest.hs def=contextOf
contextOf :: [Text] -> Text -> Text
contextOf ls binding = case concat [c | c <- chunksOf ls, headWord c == binding] of
  [] -> fnv1aHex ls
  chunk -> fnv1aHex chunk
```

## 13. chunksOf

Top-level chunks of a Haskell file: each starts at a line whose first character is not

whitespace and runs to the next such line. ref:DEC-mutant-location

```haskell file=src/RicesTax/Sydtest.hs def=chunksOf
chunksOf :: [Text] -> [[Text]]
chunksOf [] = []
chunksOf (l : rest) = let (body, more) = break starts rest in (l : body) : chunksOf more
  where
    starts t = case T.uncons t of
      Just (c, _) -> not (isSpace c)
      Nothing -> False
```

## 14. headWord

The first word of a chunk, which names the binding it belongs to.

```haskell file=src/RicesTax/Sydtest.hs def=headWord
headWord :: [Text] -> Text
headWord c = case c of
  (l : _) -> T.takeWhile (\ch -> isAlphaNum ch || ch == '_' || ch == '\'') l
  [] -> ""
```

## 15. isCommentChunk

A chunk that is a comment or a pragma: its first line opens one and every later line is

blank, indented, or closes it, so a doc comment, a plain comment, and a pragma above a binding

are each one chunk. ref:DEC-whole-block

```haskell file=src/RicesTax/Sydtest.hs def=isCommentChunk
isCommentChunk :: [Text] -> Bool
isCommentChunk c = case c of
  (l : rest) -> (("--" `T.isPrefixOf` l) || ("{-" `T.isPrefixOf` l)) && all inside rest
  [] -> False
  where
    inside t = T.null (T.strip t) || maybe False (isSpace . fst) (T.uncons t) || "-}" `T.isPrefixOf` t
```

## 16. endsBlank

A chunk whose last line is blank does not touch the chunk after it.

```haskell file=src/RicesTax/Sydtest.hs def=endsBlank
endsBlank :: [Text] -> Bool
endsBlank c = case reverse c of
  (l : _) -> T.null (T.strip l)
  [] -> False
```

## 17. isDocOpener

A documentation opener belongs to what follows it, never to what precedes it.

```haskell file=src/RicesTax/Sydtest.hs def=isDocOpener
isDocOpener :: [Text] -> Bool
isDocOpener c = case c of
  (l : _) -> any (`T.isPrefixOf` l) ["-- |", "-- $", "{-|"]
  [] -> False
```

## 18. blockOf

The chunk range of a binding's whole block: its own chunks from the first to the last, the

comment and pragma chunks touching it above, and the comment chunks touching it below that do

not open the next definition's documentation, so the reviewer reads the code with its Why. The

digest a verdict is judged against is not this block, so a comment edit stales no verdict.

ref:DEC-whole-block

```haskell file=src/RicesTax/Sydtest.hs def=blockOf
blockOf :: [[Text]] -> Text -> Maybe (Int, Int)
blockOf chunks binding = case [i | (i, c) <- zip [0 ..] chunks, headWord c == binding] of
  [] -> Nothing
  (first : rest) -> Just (up first, down (last (first : rest)))
  where
    at i = chunks !! i
    up i
      | i > 0, isCommentChunk (at (i - 1)), not (endsBlank (at (i - 1))) = up (i - 1)
      | otherwise = i
    down i
      | i + 1 < length chunks, isCommentChunk (at (i + 1)), not (endsBlank (at i)), not (isDocOpener (at (i + 1))) = down (i + 1)
      | otherwise = i
```

## 19. bindingLines

The lines of a binding's whole block and the line it starts on. ref:DEC-whole-block

```haskell file=src/RicesTax/Sydtest.hs def=bindingLines
bindingLines :: [Text] -> Text -> Maybe (Int, [Text])
bindingLines ls binding = do
  (a, b) <- blockOf chunks binding
  let starts = scanl (+) 1 (map length chunks)
      from = starts !! a
      end = starts !! b + length (chunks !! b) - 1
  pure (from, slice from end ls)
  where
    chunks = chunksOf ls
```

## 20. ruleNameOf

sydtest reports a covering test as a dotted path with the rule name escaped inside; the

corpus and subject segments are dropped and the rule name recovered. ref:DEC-how-queue

```haskell file=src/RicesTax/Sydtest.hs def=ruleNameOf
ruleNameOf :: Text -> Text
ruleNameOf path = T.takeWhile (/= ' ') (T.filter (/= '\\') (T.intercalate "." (drop 2 (splitUnescaped (T.unpack path)))))
  where
    splitUnescaped s = case s of
      [] -> [""]
      ('\\' : c : rest) -> prepend ['\\', c] (splitUnescaped rest)
      ('.' : rest) -> "" : splitUnescaped rest
      (c : rest) -> prepend [c] (splitUnescaped rest)
    prepend p (x : xs) = (T.pack p <> x) : xs
    prepend p [] = [T.pack p]
```

## 21. ruleSourcesFor

A rule's source is the definition in the test directory whose text names the rule as a

quoted string, with every chunk of the same binding; when that line hands the rule to a

named property, as sydtest's it does, the property's own chunks are the source instead.

ref:DEC-how-queue ref:DEC-own-tests-sydtest

```haskell file=src/RicesTax/Sydtest.hs def=ruleSourcesFor
ruleSourcesFor :: FilePath -> [Text] -> IO (Map Text [Text])
ruleSourcesFor dir names = do
  present <- doesDirectoryExist dir
  files <- if present then filter (".hs" `isSuffixOf`) . sort <$> listDirectory dir else pure []
  chunkSets <- forM files (\f -> chunksOf <$> readLines (dir </> f))
  pure (ruleSourcesIn chunkSets names)
```

## 22. ruleSourcesIn

The rule sources over the chunks of each test file: a source is the whole block of the

binding, comments included, in the first file that has it. ref:DEC-whole-block

A rule's own definition names it as the argument of rule or it; a rule that only refers
to it names it elsewhere on the line, so the defining line is preferred wherever it is.

```haskell file=src/RicesTax/Sydtest.hs def=ruleSourcesIn
ruleSourcesIn :: [[[Text]]] -> [Text] -> Map Text [Text]
ruleSourcesIn chunkSets names = Map.fromList [(n, s) | n <- names, Just s <- [sourceOf n]]
  where
    allChunks = concat chunkSets
    quoted n = T.pack (show (T.unpack n))
    blockNamed w = case [(cs, r) | cs <- chunkSets, Just r <- [blockOf cs w]] of
      ((cs, (a, b)) : _) -> concat (take (b - a + 1) (drop a cs))
      [] -> []
    defines n l = any (\lead -> (lead <> quoted n) `T.isInfixOf` l) ["rule ", "it ", "prop ", "specify "]
    mentionsOf n = [(c, l) | c <- allChunks, l <- c, quoted n `T.isInfixOf` l]
    sourceOf n = case [m | m@(_, l) <- mentionsOf n, defines n l] ++ mentionsOf n of
      ((c, l) : _) ->
        let handed = case reverse (T.words l) of
              (w : _) | not (null (blockNamed w)), w /= headWord c -> Just (blockNamed w)
              _ -> Nothing
         in Just (fromMaybe (blockNamed (headWord c)) handed)
      [] -> Nothing
```

## 23. The module RicesTax.Fnv

wavelet names a mutant by an FNV-1a hash of its anchor, and the probe's observations are keyed
by that name, so the same hash is needed here to join them; nothing else in Rice's Tax hashes
this way. ref:DEC-mutant-location

```haskell file=src/RicesTax/Fnv.hs part=header
module RicesTax.Fnv
  ( fnv1a64
  , fnv1aHex
  ) where

import Data.Bits (xor)
import Data.Char (ord)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Word (Word64)
import Numeric (showHex)
```

## 24. fnv1a64

Each line gets a newline appended, as wavelet's hash does, and a character enters as its code

point modulo 256 rather than as UTF-8, because that is what the observations were keyed with.

ref:DEC-mutant-location

```haskell file=src/RicesTax/Fnv.hs def=fnv1a64
fnv1a64 :: [Text] -> Word64
fnv1a64 = foldl step 14695981039346656037 . concatMap (\l -> T.unpack l ++ "\n")
  where
    step h c = (h `xor` fromIntegral (ord c `mod` 256)) * 1099511628211
```

## 25. fnv1aHex

Sixteen lower-case hex digits, zero-padded, the form wavelet writes. ref:DEC-mutant-location

```haskell file=src/RicesTax/Fnv.hs def=fnv1aHex
fnv1aHex :: [Text] -> Text
fnv1aHex ls = let h = showHex (fnv1a64 ls) "" in T.pack (replicate (16 - length h) '0' ++ h)
```

## Source snapshot manifests

When a driver supplies SHA-256 hashes, compare every recorded input, including tests and build
configuration. A matching mutation span alone is not proof that the rest of the file is fresh.
Without such a manifest, report the narrower span-only check explicitly. ref:DEC-mutant-location

```haskell file=src/RicesTax/Sydtest.hs part=source-hashes
checkSourceHashes :: FilePath -> FilePath -> IO ([FilePath], [(Text, Text)])
checkSourceHashes art pkg = do
  let manifest = art </> "source-sha256.json"
  present <- doesFileExist manifest
  if not present then pure ([], [("source-check", "mutation spans only; driver supplied no source manifest")]) else do
    bytes <- readMaybeFile manifest
    case bytes >>= either (Left . T.pack) Right . eitherDecode of
      Left err -> pure ([manifest], [("source-check", "unreadable source manifest: " <> err)])
      Right hashes | Map.null hashes -> pure ([manifest], [("source-check", "empty source manifest")])
      Right (hashes :: Map FilePath Text) -> do
        changed <- forM (Map.toList hashes) $ \(path, expected) ->
          if not (isRelative path) || ".." `elem` splitDirectories path
            then pure [path]
            else do
              actual <- try (BS.readFile (pkg </> path))
              pure $ case actual of
                Left (_ :: SomeException) -> [path]
                Right content | digest content == expected -> []
                              | otherwise -> [path]
        pure (concat changed, [("source-check", "SHA-256 manifest: " <> T.pack (show (Map.size hashes)) <> " inputs"), ("source-manifest-sha256", either (const "") (digest . LBS.toStrict) bytes)])
  where
    digest bs = T.pack (concatMap (\b -> let x = showHex b "" in replicate (2 - length x) '0' ++ x) (BS.unpack (SHA256.hash bs)))
```
