---
id: ricestax.reference.core
kind: reference
title: The core
---
# The core

## 1. The module RicesTax.Core

Everything the three verbs do, apart from talking to a network or a terminal: gathering the
project through canon, raising every obligation, assessing, auditing, deciding, and exempting.
It lives in the library so the native executable and the WebAssembly module export the same
code, and the wire types get their aeson instances here rather than beside their definition
because the page gives them miso's instances. ref:DEC-three-verbs ref:DEC-wasm-toolchain

```haskell file=src/RicesTax/Core.hs part=header
{-# OPTIONS_GHC -Wno-orphans #-}
module RicesTax.Core
  ( Gathered (..)
  , withLoaded
  , gather
  , assemble
  , applyDecision
  , assess
  , audit
  , decideWith
  , writeExemption
  , reExempt
  , ingestHow
  , ingestWhat
  , importRecord
  , queueCounts
  , auditExit
  , undecidedItem
  , changeHistory
  , lifecycleOf
  , wholeOf
  ) where

import Canon.Config (Config (..), Runtime (..))
import Canon.Antlr4.Interpret (Interpreter)
import Canon.Highlight (Classifier, Piece (..), classifierFor, highlightLines)
import Canon.Profile (Profile (..), profileForPath)
import RicesTax.Marks (classLetter, renderRuns)
import Canon.Exemptions (Exemption (..), Exemptions (..), exemptionFor)
import Canon.Model.Finding (Finding (..), Severity (..), findingSeverity, renderFinding)
import RicesTax.Model (Outcome (..))
import RicesTax.Sydtest
import Data.Char (isHexDigit)
import Canon.Decisions (DecisionEntry (..), Ledger (..), statusText)
import Canon.Extract.Grammar (Extraction (..))
import Canon.Git.Shell (runGit)
import Canon.Git.Commit (CommitHash (..), Person (..))
import Canon.Model
import Canon.Project
import Canon.Tangle (Origin (..), Tangled (..), originOf)
import Canon.Registry (Reference (..), Registry (..))
import Canon.Span (Position (..), Span (..))
import Canon.Version (parseVersion, renderVersion)
import Canon.Vetting hiding (assess, entryRevisit)
import qualified Canon.Vetting as V
import Control.Exception (SomeException, try, bracket)
import Data.Aeson (FromJSON, ToJSON, Value (String), encode, eitherDecode, toJSON)
import RicesTax.Fnv (fnv1aHex)
import Data.Time.Clock (getCurrentTime)
import qualified Crypto.Hash.SHA256 as SHA256
import qualified Data.ByteString as BS
import Numeric (showHex)
import Data.List (nub)
import qualified Data.ByteString.Lazy as LBS
import Data.List (findIndex, isPrefixOf, sortOn)
import qualified Data.Set as Set
import qualified Data.List.NonEmpty as NE
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe, mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.Text.IO as TIO
import qualified Data.Yaml as Yaml
import RicesTax.What (whatMaterials)
import RicesTax.Wire
import System.Directory (createDirectory, removeDirectory, renameFile, createDirectoryIfMissing, doesFileExist, getCurrentDirectory)
import System.FilePath (normalise, takeDirectory, takeFileName, (</>))
import System.IO (openTempFile, hClose)
```

```haskell file=src/RicesTax/Core.hs part=instance-1
instance ToJSON s => ToJSON (Payload s)
```

```haskell file=src/RicesTax/Core.hs part=instance-2
instance ToJSON s => ToJSON (Subject s)
```

```haskell file=src/RicesTax/Core.hs part=instance-3
instance ToJSON s => ToJSON (Item s)
```

```haskell file=src/RicesTax/Core.hs part=instance-4
instance ToJSON s => ToJSON (Ref s)
```

```haskell file=src/RicesTax/Core.hs part=instance-5
instance ToJSON s => ToJSON (Signer s)
```

```haskell file=src/RicesTax/Core.hs part=instance-6
instance FromJSON s => FromJSON (Decide s)
```

```haskell file=src/RicesTax/Core.hs part=instance-7
instance ToJSON s => ToJSON (Facts s)

instance ToJSON s => ToJSON (Mutation s)

instance FromJSON s => FromJSON (Mutation s)
```

```haskell file=src/RicesTax/Core.hs part=instance-8
instance ToJSON s => ToJSON (MutantView s)
```

```haskell file=src/RicesTax/Core.hs part=instance-9
instance ToJSON s => ToJSON (RuleSource s)
```

```haskell file=src/RicesTax/Core.hs part=instance-10
instance ToJSON s => ToJSON (Observed s)
```

```haskell file=src/RicesTax/Core.hs part=instance-11
instance ToJSON s => ToJSON (Count s)
```

```haskell file=src/RicesTax/Core.hs part=instance-12
instance ToJSON s => ToJSON (Bound s)
```

```haskell file=src/RicesTax/Core.hs part=instance-13
instance ToJSON s => ToJSON (Whole s)
```

```haskell file=src/RicesTax/Core.hs part=instance-14
instance FromJSON s => FromJSON (ExemptRequest s)
```

## 2a. languageOf

The language of a path, by the profile that owns its extension; a Folio page has none, since its
own lexer reads lines, not code. ref:DEC-highlighting

```haskell file=src/RicesTax/Core.hs def=languageOf
languageOf :: Gathered -> FilePath -> Maybe Text
languageOf g path = case profileForPath (configLanguages (projectConfig (gProject g))) path of
  Just (lang, p) | Map.null (profileEmbeds p) -> Just lang
  _ -> Nothing
```

## 2b. marksOf

The marks of some lines of a file, from the language's lexer over those lines as a fragment; no
marks when no language owns the path. ref:DEC-highlighting

```haskell file=src/RicesTax/Core.hs def=marksOf
marksOf :: Gathered -> FilePath -> [Text] -> [Text]
marksOf g path ls = case languageOf g path >>= \lang -> Map.lookup lang (gHighlight g) of
  Nothing -> []
  Just (classifier, interpreter) -> map encodeLine (take (length ls) (highlightLines classifier interpreter (T.unlines ls) ++ repeat []))
  where
    encodeLine pieces = T.pack (renderRuns [(classLetter (T.unpack (pieceClass piece)), T.length (pieceText piece)) | piece <- pieces])
```

## 2. wholeOf

The whole definition around a mutant, for the zoom and the copy. ref:DEC-how-card

```haskell file=src/RicesTax/Core.hs def=wholeOf
wholeOf :: Gathered -> Text -> Text -> Maybe (Whole Text)
wholeOf g kindT i = case gRun g of
  Just run | kindT `elem` ["mutant", "observability"], (m : _) <- [m | m <- liveMutants run, mutantId m == i] ->
    let (from, ls) = fromMaybe (0, []) (Map.lookup (mutantFile m, mutantBinding m) (runBindings run))
     in Just (Whole ls from (marksOf g (mutantFile m) ls))
  _ -> Nothing
```

## 3. applyDecision

A decision changes one row, so the cached payload is patched rather than gathered again,

which on a large project is the difference between a click and a forty-second wait. The

signer is unknown until the person commits, which is what the page says. ref:DEC-ui-commit

```haskell file=src/RicesTax/Core.hs def=applyDecision
applyDecision :: Decide Text -> Payload Text -> Payload Text
applyDecision d p =
  let word = T.strip (decideVerdict d)
      patched = map patch (items p)
      patch i
        | key i /= decideKey d = i
        | otherwise = i {state = word, verdict = word, note = T.strip (decideNote d), revisit = T.strip (decideRevisit d), signer = Nothing}
      grouped = Map.fromListWith (++) [(subject i, [i]) | i <- patched]
   in p
        { items = patched
        , subjects = [Subject (file first) sName (length (filter undecidedItem is)) (length is) | (sName, is@(first : _)) <- sortOn fst (Map.toList grouped)]
        }
```

## 2a. withLoaded

Every verb loads the project at the current directory the same way, so the one error a caller
sees for a missing or unreadable canon.yaml is canon's own. ref:DEC-three-verbs

```haskell file=src/RicesTax/Core.hs def=withLoaded
withLoaded :: (Project -> IO (Either Text a)) -> IO (Either Text a)
withLoaded continue = do
  loaded <- loadProject "."
  case loaded of
    Left err -> pure (Left (renderProjectError err))
    Right project -> continue project
```

## 4. Gathered

Everything one request needs from the project, read once so the page and a decision agree

on the material and its digests.

```haskell file=src/RicesTax/Core.hs def=Gathered
data Gathered = Gathered
  { gProject :: Project
  , gMaterials :: [Material]
  , gVetting :: Vetting
  , gAssessments :: Map.Map VettingKey (Answer Assessment Evidence)
  , gDecisions :: Map.Map VettingKey (Decision Evidence)
  , gUnits :: Map.Map UnitId (CodeUnit Evidence)
  , gUnitsByFile :: Map.Map FilePath [CodeUnit Evidence]
  , gRuntime :: Maybe Runtime
  , gRun :: Maybe Run
  , gRunIssue :: Text
  , gIngestionIssues :: [Text]
  , gTangles :: [Tangled]
  , gHighlight :: Map.Map Text (Classifier, Interpreter)
  }
```

## 5. gather

The tangled files, so a mutant reported at a line of one lands on the unit whose page holds
that line. ref:DEC-tangling
The one classifier and interpreter per language are loaded here too, for the marks beside every
code line. ref:DEC-highlighting

```haskell file=src/RicesTax/Core.hs def=gather
gather :: Project -> IO Gathered
gather project = do
  walked <- projectFiles project Nothing
  extracted <- extractAll project walked
  assessments <- projectAssessments project
  let models = [extractionModel e | (_, Right e) <- extracted]
      decisions = concatMap modelDecisions models
      units = concatMap (concatMap allUnits . modelUnits) models
  tangles <- if null (folioProfiles project) then pure [] else either (const []) (\(_, ts, _) -> ts) <$> tangleProject project []
  interpreters <- projectInterpreters project
  let highlighters = Map.fromList [(lang, (classifierFor (profileHighlight p) i, i)) | (lang, p) <- Map.toList (configLanguages (projectConfig project)), Just (Right i) <- [Map.lookup lang interpreters]]
  let runtime = configRuntime (projectConfig project)
  (run, runError) <- case runtime of
    Nothing -> pure (Nothing, "")
    Just rt -> do
      loaded <- readRun "." rt
      case loaded of
        Left err -> pure (Nothing, "Cannot read current mutation run: " <> err)
        Right r -> pure (Just r, "")
  pure
    Gathered
      { gProject = project
      , gMaterials = projectMaterials project decisions ++ whatMaterials units
      , gVetting = fromMaybe emptyVetting (projectVetting project)
      , gAssessments = assessments
      , gDecisions = Map.fromList [(decisionKey d, d) | d <- decisions]
      , gUnits = Map.fromList [(unitId u, u) | u <- units]
      , gUnitsByFile = Map.fromListWith (++) ([(normalise (wherePath (answerValue (unitWhere u))), [u]) | u <- units] ++ [(normalise (wherePath (answerValue (unitWhere root))), allUnits root) | m <- models, root <- modelUnits m])
      , gRuntime = runtime
      , gRun = run
      , gRunIssue = runError
      , gIngestionIssues = [T.pack path <> ": " <> message | (path, Left message) <- extracted]
      , gTangles = tangles
      , gHighlight = highlighters
      }
```

## 6. assemble

A What row whose unit is gone, or no longer requires a comment, is an orphan of its own queue.

```haskell file=src/RicesTax/Core.hs def=assemble
assemble :: Gathered -> IO (Payload Text)
assemble g = do
  here <- getCurrentDirectory
  historyResult <- readHistory
  attemptIssue <- readAttemptIssue
  raised <- mapM (itemOf g) (gMaterials g)
  let known = Map.fromList [(materialKey m, ()) | m <- gMaterials g]
      how = howItems g
      howKeys = Set.fromList (map key how)
      orphans = [orphanItem g k e | (k, e) <- Map.toList (vettingEntries (gVetting g)), not (Map.member k known), not (isKindKey k), not (Set.member (renderVettingKey k) howKeys)]
      whatOrphans = [(orphanItem g k e) {question = "What"} | (k, e) <- Map.toList (vettingEntries (gVetting g)), isNameKey k, not (Map.member k known)]
      liveIds = Set.fromList (map (T.drop 1 . T.dropWhile (/= '/') . key) how)
      gone = [goneItem g k e (Set.member (idOf k) liveIds) | (k, e) <- Map.toList (vettingEntries (gVetting g)), isKindKey k, not (isNameKey k), not (Set.member (renderVettingKey k) howKeys)]
      idOf k = case k of
        KindKey _ i -> i
        _ -> ""
      historyLog = either (const (HistoryLog 1 [])) id historyResult
      issue = T.intercalate "; " (filter (not . T.null) [attemptIssue, gRunIssue g, either id (const "") historyResult, case gRun g of
        Just r | not (runCorpusOk r) -> "Run controls failed or are missing; results are unverified."
               | not (null (runStaleFiles r)) -> "Sources changed since this run. Run mutation again."
               | any (\m -> mutantOutcome m `elem` [Skipped, TimedOut, Invalid, InfrastructureError, Unknown]) (runMutants r) -> "Run contains inconclusive mutations. Inspect the report and rerun."
        _ -> ""])
      all' = raised ++ orphans ++ whatOrphans ++ how ++ gone
      life = lifecycleOf g issue historyLog (how ++ gone)
      revision = fnv1aHex [T.pack (show [(f, renderVetting entries) | (f, entries) <- Map.toList (vettingFiles (gVetting g))]), TE.decodeUtf8 (LBS.toStrict (encode historyLog)), T.pack (show (gRun g)), issue]
      grouped = Map.fromListWith (++) [(subject i, [i]) | i <- all']
  pure
    Payload
      { project = T.pack (takeFileName here)
      , subjects = [Subject (file first) s (length (filter undecidedItem is)) (length is) | (s, is@(first : _)) <- sortOn fst (Map.toList grouped)]
      , items = all'
      , facts = case (gRuntime g, gRun g) of
          (Just rt, Just run) -> Just (Facts (runtimeName rt) (runId run) (runFacts run) (runCorpusOk run) (map T.pack (runStaleFiles run)) (fromMaybe "" (runtimeCommand rt)))
          _ -> Nothing
      , lifecycle = life
      , historyRevision = revision
      , runIssue = issue
      , ingestionIssues = gIngestionIssues g
      , rules = maybe [] (\run -> [RuleSource r src (marksOf g (maybe "rule.hs" (\rt -> runtimeTests rt </> "rule.hs") (gRuntime g)) src) | (r, src) <- Map.toList (runRuleSources run)]) (gRun g)
      }
```

```haskell file=src/RicesTax/Core.hs def=isKindKey
isKindKey :: VettingKey -> Bool
isKindKey k = case k of
  KindKey _ _ -> True
  _ -> False
```

```haskell file=src/RicesTax/Core.hs def=isNameKey
isNameKey :: VettingKey -> Bool
isNameKey k = case k of
  KindKey "name" _ -> True
  _ -> False
```

## 4a. undecidedItem

A subject's count of what is still owed: an item is undecided while its state is open and no
exemption covers it, which is the number the page's switcher shows. ref:DEC-obligation

```haskell file=src/RicesTax/Core.hs def=undecidedItem
undecidedItem :: Item Text -> Bool
undecidedItem i = state i `elem` ["pending", "stale", "unreviewed", "needs-research"] && T.null (exempt i)
```

```haskell file=src/RicesTax/Core.hs def=itemOf
itemOf :: Gathered -> Material -> IO (Item Text)
itemOf g m = case materialKey m of
  CommentKey did -> commentItem g m did
  LedgerKey rk -> ledgerItem g m rk
  RegistryKey rk -> registryItem g m rk
  KindKey "name" uid -> whatItem g m uid
  KindKey _ _ -> pure (orphanItem g (materialKey m) (VettingEntry Pending (materialDigest m) Nothing Nothing Nothing))
  DocKey path -> docItem g m path
```

## 7. docItem

A page's row in the Why queue: the page's prose as the text, with what it cites, and the page

itself as the code window from its first line. ref:DEC-doc-kind ref:DEC-tangling

```haskell file=src/RicesTax/Core.hs def=docItem
docItem :: Gathered -> Material -> FilePath -> IO (Item Text)
docItem g m path = case Map.lookup (materialKey m) (gDecisions g) of
  Nothing -> pure (base g m "doc" "Why" (T.pack path) (T.pack (takeFileName path)) "doc" (T.pack path) 1 (materialText m) [] [] [] 0 0)
  Just d -> do
    let why = answerValue (decisionWhy d)
        cited = mapMaybe (refOf g) (whyReferences why ++ whyLicenses why)
        name = case decisionUnits d of
          (UnitId segments NE.:| _) -> NE.last segments
    ls <- sourceLines path 1 60
    pure (base g m "doc" "Why" (T.pack path) name "doc" (T.pack path) 1 (whyText why) cited ls [] 1 0)
```

## 8. whatItem

A What row: the name and signature as the text, the signature and body as the code window

starting on the line after the unit's comment, so the person sees what the name must state.

ref:DEC-what-queue

```haskell file=src/RicesTax/Core.hs def=whatItem
whatItem :: Gathered -> Material -> Text -> IO (Item Text)
whatItem g m uidT = case parseUnitId uidT >>= \uid -> Map.lookup uid (gUnits g) of
  Nothing -> pure (base g m "name" "What" "" uidT "" "" 0 (materialText m) [] [] [] 0 0)
  Just u -> do
    let w = answerValue (unitWhere u)
        what = answerValue (unitWhat u)
        source = T.pack (normalise (wherePath w))
        startL = positionLine (spanStart (whereSpan w))
        endL = positionLine (spanEnd (whereSpan w))
        commentEnd = case Map.lookup (CommentKey (decisionIdFor (unitId u))) (gDecisions g) of
          Just d -> positionLine (spanEnd (whereSpan (decisionWhere d)))
          Nothing -> startL - 1
        from = max startL (commentEnd + 1)
    ls <- sourceLines (wherePath w) from (min endL (from + 40))
    pure (base g m "name" "What" source (whatName what) (unitKindText (whatKind what)) source from (materialText m) [] ls (marksOf g (wherePath w) ls) from 0)
```

```haskell file=src/RicesTax/Core.hs def=commentItem
commentItem :: Gathered -> Material -> DecisionId -> IO (Item Text)
commentItem g m did = case Map.lookup (materialKey m) (gDecisions g) of
  Nothing -> pure (base g m "comment" "Why" "" (lastSegment did) "" "" 0 (materialText m) [] [] [] 0 0)
  Just d -> do
    let w = decisionWhere d
        from = positionLine (spanStart (whereSpan w))
        unitOf = Map.lookup (NE.head (decisionUnits d)) (gUnits g)
        (name, ukind, codeStart, codeEnd) = case unitOf of
          Nothing -> (lastSegment did, "", from, positionLine (spanEnd (whereSpan w)))
          Just u ->
            let uw = whereSpan (answerValue (unitWhere u))
                what = answerValue (unitWhat u)
             in (whatName what, unitKindText (whatKind what), positionLine (spanStart uw), positionLine (spanEnd uw))
        commentEnd = positionLine (spanEnd (whereSpan w))
        end = max commentEnd (min (max codeEnd codeStart) (commentEnd + 30))
        why = answerValue (decisionWhy d)
        cited = mapMaybe (refOf g) (whyReferences why ++ whyLicenses why)
        source = T.pack (normalise (wherePath w))
    ls <- sourceLines (wherePath w) from end
    pure (base g m "comment" "Why" source name ukind source from (whyText why) cited ls (marksOf g (wherePath w) ls) from (commentEnd - from + 1))
```

```haskell file=src/RicesTax/Core.hs def=ledgerItem
ledgerItem :: Gathered -> Material -> ReferenceKey -> IO (Item Text)
ledgerItem g m rk = do
  let config = projectConfig (gProject g)
      ledgerPath = configDecisions config
      entry = Map.lookup rk (ledgerEntries (projectLedger (gProject g)))
      txt = maybe (materialText m) entryQuestion entry
      answerT = fromMaybe "" (entry >>= entryAnswer)
      cited = maybe [] (mapMaybe (refOf g) . entryRefs) entry
  ln <- lineOfKey ledgerPath (referenceKeyText rk)
  pure (base g m "ledger" "Why" "ledger" (referenceKeyText rk) (maybe "" (statusText . entryStatus) entry) (T.pack ledgerPath) ln txt cited [] [] 0 0) {answer = answerT}
```

```haskell file=src/RicesTax/Core.hs def=registryItem
registryItem :: Gathered -> Material -> ReferenceKey -> IO (Item Text)
registryItem g m rk = do
  let config = projectConfig (gProject g)
      entry = Map.lookup rk (registryEntries (projectRegistry (gProject g)))
      txt = maybe (materialText m) (\r -> referenceTitle r <> "\n" <> referenceLocator r) entry
  ln <- lineOfKey (configRegistry config) (referenceKeyText rk)
  pure (base g m "registry" "Why" "registry" (referenceKeyText rk) (maybe "" (kindText . referenceKind) entry) (T.pack (configRegistry config)) ln txt [] [] [] 0 0)
```

```haskell file=src/RicesTax/Core.hs def=orphanItem
orphanItem :: Gathered -> VettingKey -> VettingEntry -> Item Text
orphanItem g k e =
  Item
    { key = renderVettingKey k
    , kind = case k of
        CommentKey _ -> "comment"
        LedgerKey _ -> "ledger"
        RegistryKey _ -> "registry"
        KindKey kind' _ -> kind'
        DocKey _ -> "doc"
    , question = "Why"
    , file = T.pack (fromMaybe "" (fileOf (gVetting g) k))
    , subject = ""
    , unit = renderVettingKey k
    , unitKind = ""
    , path = ""
    , line = 0
    , text = "The material this verdict was about no longer exists, so the row can be deleted."
    , answer = ""
    , refs = []
    , state = "orphan"
    , verdict = verdictText (entryVerdict e)
    , note = fromMaybe "" (entryNote e)
    , revisit = maybe "" renderVersion (V.entryRevisit e)
    , signer = signerOf g k
    , code = []
    , codeFrom = 0
    , commentLines = 0
    , marks = []
    , mutant = Nothing
    , run = fromMaybe "" (entryRun e)
    , exempt = ""
    , exemptReason = ""
    , exemptUntil = ""
    }
```

## 9. exemptionOf

The exemption covering an item, by its path for a comment or mutant and by its key for a

ledger or registry entry, rendered as the pattern that covers it. ref:DEC-exemptions

```haskell file=src/RicesTax/Core.hs def=exemptionOf
exemptionOf :: Gathered -> Text -> Text -> Text -> (Text, Text, Text)
exemptionOf g kindT pathT keyT = case exemptionFor (projectExemptions (gProject g)) (if kindT `elem` ["ledger", "registry"] then keyT else pathT) kindT of
  Just (pat, e) -> (pat, exemptionReason e, renderVersion (exemptionRevisit e))
  Nothing -> ("", "", "")
```

```haskell file=src/RicesTax/Core.hs def=base
base :: Gathered -> Material -> Text -> Text -> Text -> Text -> Text -> Text -> Int -> Text -> [Ref Text] -> [Text] -> [Text] -> Int -> Int -> Item Text
base g m kindT questionT subj name ukind pathT ln txt cited codeLs codeMarks from cl =
  let (pat, why, until') = exemptionOf g kindT pathT (renderVettingKey k)
   in Item
    { key = renderVettingKey k
    , kind = kindT
    , question = questionT
    , file = T.pack (materialFile m)
    , subject = subj
    , unit = name
    , unitKind = ukind
    , path = pathT
    , line = ln
    , text = txt
    , answer = ""
    , refs = cited
    , state = stateOf m entry
    , verdict = maybe "pending" (verdictText . entryVerdict) entry
    , note = fromMaybe "" (entry >>= entryNote)
    , revisit = maybe "" renderVersion (entry >>= V.entryRevisit)
    , signer = signerOf g k
    , code = codeLs
    , codeFrom = from
    , marks = codeMarks
    , commentLines = cl
    , mutant = Nothing
    , run = ""
    , exempt = pat
    , exemptReason = why
    , exemptUntil = until'
    }
  where
    k = materialKey m
    entry = Map.lookup k (vettingEntries (gVetting g))
```

## 10. howItems

Every live mutant of the run as an obligation: a surviving one is a judgement with wavelet's

words, a gap is work with the word gap, and both carry the card's evidence. ref:DEC-how-queue

ref:DEC-work-items

```haskell file=src/RicesTax/Core.hs def=howItems
howItems :: Gathered -> [Item Text]
howItems g = case gRun g of
  Nothing -> []
  Just run -> map (mutantItem g run) (liveMutants run)
```

```haskell file=src/RicesTax/Core.hs def=mutantItem
mutantItem :: Gathered -> Run -> Mutant -> Item Text
mutantItem g run m =
  let reading = effectiveReading run m
      gapWord = gapOf m reading
      isGap = gapWord /= Nothing
      kindT = if isGap then "observability" else "mutant" :: Text
      k = KindKey kindT (mutantId m)
      entry = Map.lookup k (vettingEntries (gVetting g))
      pathT = T.pack (mutantFile m)
      (name, ukind) = unitFor g (mutantFile m) (mutantLine m) (mutantBinding m)
      own = Map.lookup (mutantId m) (runReadings run)
      (pat, why, until') = exemptionOf g kindT pathT (renderVettingKey k)
      observedV = case reading of
        Just r -> Just (Observed (readingStatus r) (readingTotal r) [Count v c | (v, c) <- readingDistinct r] [Bound n [Count v c | (v, c) <- vs] | (n, vs) <- readingBound r])
        Nothing -> fmap (\r -> Observed (readingStatus r) 0 [] []) own
   in Item
        { key = renderVettingKey k
        , kind = kindT
        , question = "How"
        , file = kindT <> "/" <> T.pack (mutantFile m) <> ".yaml"
        , subject = pathT
        , unit = if T.null name then mutantBinding m else name
        , unitKind = ukind
        , path = pathT
        , line = mutantLine m
        , text = mutantWas m <> " becomes " <> mutantBecame m
        , answer = ""
        , refs = []
        , state =
            if isGap
              then "work"
              else case entry of
                Nothing -> "unreviewed"
                Just e
                  | entryDigest e /= mutantContext m -> "stale"
                  | otherwise -> verdictText (V.entryVerdict e)
        , verdict = if isGap then "gap" else maybe "unreviewed" (verdictText . V.entryVerdict) entry
        , note = fromMaybe "" (entry >>= entryNote)
        , revisit = ""
        , signer = signerOf g k
        , code = []
        , codeFrom = 0
        , commentLines = 0
        , marks = []
        , mutant =
            Just
              MutantView
                { operator = mutantOperator m
                , was = mutantWas m
                , became = mutantBecame m
                , outcome = T.pack (show (mutantOutcome m))
                , covering = mutantCovering m
                , before = mutantBefore m
                , source = mutantSourceLines m
                , mutated = mutantMutatedLines m
                , after = mutantAfter m
                , beforeMarks = marksOf g (mutantFile m) (mutantBefore m)
                , sourceMarks = marksOf g (mutantFile m) (mutantSourceLines m)
                , mutatedMarks = marksOf g (mutantFile m) (mutantMutatedLines m)
                , afterMarks = marksOf g (mutantFile m) (mutantAfter m)
                , fromLine = mutantLine m
                , fromCol = mutantColStart m
                , toLine = mutantEndLine m
                , toCol = mutantColEnd m
                , observed = observedV
                , coverage = coverageOf reading
                , sided = sidedOf run m
                , gap = fromMaybe "" gapWord
                , staleFile = mutantStaleFile m
                }
        , run = fromMaybe "" (entry >>= entryRun)
        , exempt = pat
        , exemptReason = why
        , exemptUntil = until'
        }
```

## 11. unitFor

The canon unit a mutant lands on: the unit of its file named like its binding, else the

innermost unit whose span holds its line, else nothing. ref:DEC-mutant-location

A line of a tangled file is a line of a page; the unit's span is in the page.

```haskell file=src/RicesTax/Core.hs def=unitFor
unitFor :: Gathered -> FilePath -> Int -> Text -> (Text, Text)
unitFor g path ln binding =
  let here = Map.findWithDefault [] (normalise path) (gUnitsByFile g)
      whatOf u = answerValue (unitWhat u)
      named = [u | u <- here, whatName (whatOf u) == binding]
      spanOf u = whereSpan (answerValue (unitWhere u))
      (docPath', docLine) = case [t | t <- gTangles g, normalise (tangledPath t) == normalise path] of
        (t : _) | Just (OriginBody doc line) <- originOf t ln -> (doc, line)
        _ -> (path, ln)
      holds u = normalise (wherePath (answerValue (unitWhere u))) == normalise docPath' && positionLine (spanStart (spanOf u)) <= docLine && docLine <= positionLine (spanEnd (spanOf u))
      holding = filter holds here
      innermost = sortOn (\u -> positionLine (spanStart (spanOf u)) - positionLine (spanEnd (spanOf u))) holding
   in case named ++ innermost of
        (u : _) -> (whatName (whatOf u), unitKindText (whatKind (whatOf u)))
        [] -> ("", "")
```

## 12. goneItem

A row of a declared kind whose material is not raised under that kind now: killed since the

run it was decided against, or reclassified, as when a judged mutant turns out to be a coverage

gap once the probe has read it. Shown so the person can delete or move it. ref:DEC-work-items

ref:DEC-verdict-carry-over

```haskell file=src/RicesTax/Core.hs def=goneItem
goneItem :: Gathered -> VettingKey -> VettingEntry -> Bool -> Item Text
goneItem g k e stillLive =
  (orphanItem g k e)
    { kind = kindOfKey k
    , question = "How"
    , state = "gone"
    , text =
        if stillLive
          then "Still in the run, but now the other kind: a judged mutant that the probe shows to be a coverage gap, or a gap that became a judgement. The verdict is kept for the record; the live row is under the other kind."
          else "Not in the live queue. Consult decision history for the current outcome and retained evidence; absence alone does not prove a kill."
    }
  where
    kindOfKey key' = case key' of
      KindKey kind' _ -> kind'
      _ -> ""
```

## 13. assess

assess: the state of things. Every comment, ledger entry, and reference without a row gets

one through canon, every live mutant and gap gets one here, and the totals per queue follow,

with what is exempt counted apart. ref:DEC-three-verbs

The payload already shows an unrecorded item as open, so the counts need no second gather.

```haskell file=src/RicesTax/Core.hs def=assess
assess :: Gathered -> IO Text
assess g = do
  (_, total, files, fresh, failures) <- ingestProject (gProject g)
  (rows, howFiles) <- ingestHow g
  (names, nameFiles) <- ingestWhat g
  p <- assemble g
  let counts = queueCounts p
  pure
    ( T.unlines
        ( [ "assessed " <> project p
          , "  comments, decisions, and references: " <> T.pack (show (length fresh)) <> " new rows, " <> T.pack (show total) <> " in " <> T.pack (show files) <> " files"
          , "  names and signatures: " <> T.pack (show names) <> " new rows in " <> T.pack (show nameFiles) <> " files"
          , "  mutants and gaps: " <> T.pack (show rows) <> " new rows in " <> T.pack (show howFiles) <> " files"
          ]
            ++ map ("  not read: " <>) failures
            ++ ["  changed since the run, no rows written until it is repeated: " <> T.pack f | Just run <- [gRun g], f <- runStaleFiles run]
            ++ [""]
            ++ counts
        )
    )
```

## 14. auditExit

The exit code of an audit: paid, not paid, or could not audit, so a pipeline tells a failed

tax from a failed run. ref:DEC-umbrella-surface

```haskell file=src/RicesTax/Core.hs def=auditExit
auditExit :: Either Text Bool -> Int
auditExit result = case result of
  Left _ -> 2
  Right True -> 0
  Right False -> 1
```

## 15. queueCounts

One line per queue: open, exempt, decided, stale, and work.

```haskell file=src/RicesTax/Core.hs def=queueCounts
queueCounts :: Payload Text -> [Text]
queueCounts p =
  [ T.justifyLeft 6 ' ' q <> "open " <> n (\i -> state i `elem` ["pending", "unreviewed", "needs-research"]) <> "  stale " <> n (\i -> state i == "stale") <> "  exempt " <> n (\i -> not (T.null (exempt i))) <> "  decided " <> n (\i -> state i `elem` ["good", "bad", "deferred", "logical-equivalency", "inadequate-testing", "unnecessary-code"]) <> "  work " <> n (\i -> state i == "work")
  | q <- ["Why", "What", "How"]
  , let mine = [i | i <- items p, question i == q]
  , let n f = T.pack (show (length (filter (\i -> f i && (T.null (exempt i) || f i == (not (T.null (exempt i)))) ) mine)))
  ]
```

## 16. writeExemption

Adds or lifts an exemption in canonical_exemptions.yaml, one key per line so blame names who

exempted, and returns the exemptions as they now stand. ref:DEC-exemptions

```haskell file=src/RicesTax/Core.hs def=writeExemption
writeExemption :: Gathered -> Bool -> ExemptRequest Text -> IO (Either Text Exemptions)
writeExemption g adding x = do
  let subject = T.strip (exemptSubject x)
      path = resolvePath (gProject g) (configExemptions (projectConfig (gProject g)))
      existing = exemptionEntries (projectExemptions (gProject g))
  if T.null subject
    then pure (Left "an exemption needs a subject")
    else case (adding, parseVersion (T.strip (exemptRevisit x))) of
      (True, Nothing) -> pure (Left ("not a version to revisit by: " <> exemptRevisit x))
      (True, Just _) | T.null (T.strip (exemptWhy x)) -> pure (Left "an exemption needs a reason")
      (True, Just revisit) -> do
        let updated = Map.insert subject (Exemption (filter (not . T.null) (map T.strip (exemptKinds x))) (T.strip (exemptWhy x)) revisit) existing
        TIO.writeFile path (renderExemptions updated)
        pure (Right (Exemptions updated))
      (False, _) -> do
        let updated = Map.delete subject existing
        TIO.writeFile path (renderExemptions updated)
        pure (Right (Exemptions updated))
```

```haskell file=src/RicesTax/Core.hs def=renderExemptions
renderExemptions :: Map.Map Text Exemption -> Text
renderExemptions entries
  | Map.null entries = "{}\n"
  | otherwise = T.concat [render k e | (k, e) <- Map.toList entries]
  where
    render k e =
      T.concat
        ( [quotedKey k, ":\n"]
            ++ (if null (exemptionKinds e) then [] else ["  kinds: [", T.intercalate ", " (exemptionKinds e), "]\n"])
            ++ ["  reason: ", quotedText (exemptionReason e), "\n", "  revisit: ", renderVersion (exemptionRevisit e), "\n"]
        )
    quotedKey k = if T.any (`elem` (" *?[]{}:#,'\"" :: String)) k then quotedText k else k
    quotedText t = TE.decodeUtf8 (LBS.toStrict (encode t))
```

## 17. reExempt

Recomputes an item's exemption after the file changed. ref:DEC-exemptions

```haskell file=src/RicesTax/Core.hs def=reExempt
reExempt :: Gathered -> Item Text -> Item Text
reExempt g i =
  let (pat, why, until') = exemptionOf g (kind i) (path i) (key i)
   in i {exempt = pat, exemptReason = why, exemptUntil = until'}
```

## 18. audit

audit: the proof that the tax is paid, deciding nothing. It fails on any open row outside an

exemption, any stale digest, any decided row whose verdict line is not committed, any mutant

row naming a run the runs file does not record, and any exemption or deferral past its revisit

version, and reports the counts per queue. ref:DEC-audit

A ledger-only audit, with no run to read, says so: it re-digests no mutant.
canon judges the staleness of its own material only; every other kind's is judged here.

```haskell file=src/RicesTax/Core.hs def=audit
audit :: Gathered -> IO (Bool, Text, LBS.ByteString)
audit g = do
  findings <- checkProject (gProject g) Nothing
  historySigning <- historyAudit
  p <- assemble g
  runsPresent <- doesFileExist (resolvePath (gProject g) (configRuns (projectConfig (gProject g))))
  recorded <- if runsPresent then either (const Map.empty) id <$> Yaml.decodeFileEither (resolvePath (gProject g) (configRuns (projectConfig (gProject g)))) else pure (Map.empty :: Map.Map Text (Map.Map Text Text))
  let failing = [renderFinding f | f <- findings, findingSeverity f == Failing]
      uncommitted = [renderFinding f | f@(VerdictUncommitted _) <- findings]
      unrecorded = ["mutant " <> key i <> " names run " <> run i <> ", which " <> T.pack (configRuns (projectConfig (gProject g))) <> " does not record" | i <- items p, question i == "How", not (T.null (run i)), not (Map.member (run i) recorded)]
      exemptFindings = [renderFinding f | f@Exempt {} <- findings]
      runtimeState = maybe "absent" (const "present") (gRun g) :: Text
      stale = [key i <> " changed since its verdict" | i <- items p, state i == "stale", T.null (exempt i), kind i `notElem` ["comment", "ledger", "registry"]]
      historyProblems = [runIssue p | not (T.null (runIssue p))]
      problems = failing ++ uncommitted ++ unrecorded ++ stale ++ historyProblems ++ historySigning
      ok = null problems
      textReport =
        T.unlines
          ( [(if ok then "audit passed: " else "audit failed: ") <> project p]
              ++ queueCounts p
              ++ ["  exempt findings: " <> T.pack (show (length exemptFindings)), "  runtime: " <> runtimeState]
              ++ (if ok then [] else "" : map ("  " <>) (take 200 problems) ++ (if length problems > 200 then ["  ... " <> T.pack (show (length problems - 200)) <> " more"] else []))
          )
      jsonReport =
        encode
          ( Map.fromList
              [ ("ok" :: Text, toJSON ok)
              , ("project", toJSON (project p))
              , ("failing", toJSON failing)
              , ("uncommitted", toJSON uncommitted)
              , ("unrecordedRuns", toJSON unrecorded)
              , ("stale", toJSON stale)
              , ("runtime", toJSON runtimeState)
              , ("exempt", toJSON exemptFindings)
              , ("queues", toJSON (queueCounts p))
              ]
          )
  pure (ok, textReport, jsonReport)
```

## 19. ingestHow

Writes a row for every live mutant the ledger lacks: unreviewed for a judgement, gap for a

coverage gap, each in the file of its kind and source. ref:DEC-work-items

A file that changed since the run gets no rows, as wavelet's record refused to write:
its mutants point at lines that are somewhere else now. Repeat the run.

```haskell file=src/RicesTax/Core.hs def=ingestHow
ingestHow :: Gathered -> IO (Int, Int)
ingestHow g = case gRun g of
  Nothing -> pure (0, 0)
  Just run -> do
    let existing = vettingEntries (gVetting g)
        rows =
          [ (materialShard i, (k, VettingEntry (Word (if kind i == "observability" then "gap" else "unreviewed")) (mutantContext m) Nothing Nothing (Just (runId run))))
          | m <- liveMutants run
          , not (mutantStaleFile m)
          , let i = mutantItem g run m
          , Just k <- [parseVettingKey (key i)]
          , not (Map.member k existing)
          ]
        materialShard i = T.unpack (file i)
        byShard = Map.fromListWith (++) [(s, [r]) | (s, r) <- rows]
    mapM_ (\(shard, rs) -> writeShard g shard (Map.fromList rs)) (Map.toList byShard)
    recordRun g run
    pure (length rows, Map.size byShard)
```

## 20. ingestWhat

Writes a pending row for every What material the ledger lacks, in the file of its source.

ref:DEC-what-raised

```haskell file=src/RicesTax/Core.hs def=ingestWhat
ingestWhat :: Gathered -> IO (Int, Int)
ingestWhat g = do
  let existing = vettingEntries (gVetting g)
      rows = [(materialFile m, (materialKey m, VettingEntry Pending (materialDigest m) Nothing Nothing Nothing)) | m <- gMaterials g, isNameKey (materialKey m), not (Map.member (materialKey m) existing)]
      byShard = Map.fromListWith (++) [(s, [r]) | (s, r) <- rows]
  mapM_ (\(shard, rs) -> writeShard g shard (Map.fromList rs)) (Map.toList byShard)
  pure (length rows, Map.size byShard)
```

## 21. recordRun

The runs a project has decided against, one entry per run id with the facts the runtime

reported, so a row's run field resolves to a tester, a version, a seed, and a date.

ref:DEC-mutant-provenance

```haskell file=src/RicesTax/Core.hs def=recordRun
recordRun :: Gathered -> Run -> IO ()
recordRun g run = do
  let path = resolvePath (gProject g) (configRuns (projectConfig (gProject g)))
  present <- doesFileExist path
  existing <- if present then either (const Map.empty) id <$> Yaml.decodeFileEither path else pure Map.empty
  let facts' = Map.fromList (runFacts run) :: Map.Map Text Text
      updated = Map.insert (runId run) facts' (existing :: Map.Map Text (Map.Map Text Text))
  LBS.writeFile path (LBS.fromStrict (Yaml.encode updated))
```

```haskell file=src/RicesTax/Core.hs def=writeShard
writeShard :: Gathered -> FilePath -> Map.Map VettingKey VettingEntry -> IO ()
writeShard g shard fresh = do
  let dir = resolvePath (gProject g) (configVetting (projectConfig (gProject g)))
      existing = Map.findWithDefault Map.empty shard (vettingFiles (gVetting g))
  createDirectoryIfMissing True (takeDirectory (dir </> shard))
  TIO.writeFile (dir </> shard) (renderVetting (Map.union fresh existing))
```

## 22. importRecord

Reads the decided headings of a wavelet MUT- record and writes each as a row, fresh where the

definition's context still matches and stale where it does not. ref:DEC-records-retired

```haskell file=src/RicesTax/Core.hs def=importRecord
importRecord :: Gathered -> FilePath -> IO (Int, Int)
importRecord g path = case gRun g of
  Nothing -> pure (0, 0)
  Just run -> do
    content <- TIO.readFile path
    let ls = T.lines content
        headings = [(n, h) | (n, l) <- zip [0 :: Int ..] ls, Just h <- [heading l]]
        argumentAfter n = T.strip (T.unlines (takeWhile (\l -> not ("### " `T.isPrefixOf` l) && not ("## " `T.isPrefixOf` l)) (drop (n + 1) ls)))
        byId = Map.fromList [(mutantId m, m) | m <- liveMutants run]
        rows =
          [ (T.unpack ("mutant/" <> T.pack (mutantFile m) <> ".yaml"), (KindKey "mutant" (mutantId m), VettingEntry (Word word) (if ctx == mutantContext m then ctx else "fnv:" <> ctx) Nothing (noteOf n) (Just (runId run))))
          | (n, (mid, ctx, word)) <- headings
          , Just m <- [Map.lookup mid byId]
          ]
        noteOf n =
          let arg = argumentAfter n
           in if T.null arg || arg == "*No description was given.*" then Nothing else Just arg
        missed = length [() | (_, (mid, _, _)) <- headings, not (Map.member mid byId)]
        byShard = Map.fromListWith (++) [(s, [r]) | (s, r) <- rows]
    mapM_ (\(shard, rs) -> writeShard g shard (Map.fromList rs)) (Map.toList byShard)
    recordRun g run
    pure (length rows, missed)
  where
    heading l = case T.words l of
      ("###" : i : c : w : _)
        | Just i' <- ticked i, Just c' <- ticked c, T.length i' == 12, T.all isHexDigit i', T.length c' == 16, T.all isHexDigit c' -> Just (i', c', w)
      _ -> Nothing
    ticked t = T.stripPrefix "`" t >>= T.stripSuffix "`"
```

```haskell file=src/RicesTax/Core.hs def=stateOf
stateOf :: Material -> Maybe VettingEntry -> Text
stateOf m entry = case entry of
  Nothing -> "pending"
  Just e
    | entryVerdict e == Pending -> "pending"
    | entryDigest e /= materialDigest m -> "stale"
    | otherwise -> verdictText (entryVerdict e)
```

```haskell file=src/RicesTax/Core.hs def=signerOf
signerOf :: Gathered -> VettingKey -> Maybe (Signer Text)
signerOf g k = case Map.lookup k (gAssessments g) of
  Just (Answer a _)
    | Just p <- assessmentBy a ->
        Just (Signer (personName p) (maybe "" (T.pack . show) (assessmentAt a)) (maybe "" (T.take 7 . commitHashText) (assessmentCommit a)) (map personName (assessmentCoAuthors a)))
  _ -> Nothing
```

## 23. refOf

A citation is a registry key or a ledger key, so both are looked up and a decision shows

its question as the title. ref:DEC-page-first-queue

```haskell file=src/RicesTax/Core.hs def=refOf
refOf :: Gathered -> ReferenceKey -> Maybe (Ref Text)
refOf g rk = case Map.lookup rk (registryEntries (projectRegistry (gProject g))) of
  Just r -> Just (Ref (referenceKeyText rk) (kindText (referenceKind r)) (referenceTitle r) "" (referenceLocator r))
  Nothing -> do
    e <- Map.lookup rk (ledgerEntries (projectLedger (gProject g)))
    pure (Ref (referenceKeyText rk) ("decision, " <> statusText (entryStatus e)) (entryQuestion e) (fromMaybe "" (entryAnswer e)) (T.pack (configDecisions (projectConfig (gProject g)))))
```

```haskell file=src/RicesTax/Core.hs def=kindText
kindText :: ToJSON a => a -> Text
kindText k = case toJSON k of
  String t -> t
  _ -> ""
```

```haskell file=src/RicesTax/Core.hs def=lastSegment
lastSegment :: DecisionId -> Text
lastSegment (DecisionId (UnitId segments)) = NE.last segments
```

```haskell file=src/RicesTax/Core.hs def=sourceLines
sourceLines :: FilePath -> Int -> Int -> IO [Text]
sourceLines path from to = do
  result <- try (TIO.readFile path) :: IO (Either SomeException Text)
  pure $ case result of
    Left _ -> []
    Right content -> take (to - from + 1) (drop (max 0 (from - 1)) (T.lines content))
```

```haskell file=src/RicesTax/Core.hs def=lineOfKey
lineOfKey :: FilePath -> Text -> IO Int
lineOfKey path k = do
  result <- try (TIO.readFile path) :: IO (Either SomeException Text)
  pure $ case result of
    Left _ -> 0
    Right content -> maybe 0 (+ 1) (findIndex (\l -> T.unpack (k <> ":") `isPrefixOf` T.unpack l) (T.lines content))
```

## 24. decideWith

Writes the verdict into the one file that holds the key, with the digest of the material as

it is now, so a stale row decided today is fresh again. ref:DEC-ui-commit

A key with a material, whatever its kind, is decided as material; only a kind row without
one is a mutant of the run.

```haskell file=src/RicesTax/Core.hs def=decideWith
decideWith :: Gathered -> Decide Text -> IO (Either Text (FilePath, VettingKey, VettingEntry))
decideWith _ d = historyLocked $ withLoaded $ \project' -> gather project' >>= \g -> decideUnlocked g d

decideUnlocked :: Gathered -> Decide Text -> IO (Either Text (FilePath, VettingKey, VettingEntry))
decideUnlocked g (Decide k v n r) = case (parseVettingKey k, parseVerdict v) of
  (Nothing, _) -> pure (Left ("unknown key: " <> k))
  (_, Nothing) -> pure (Left ("unknown verdict: " <> v))
  (Just key@(KindKey kindT i), Just verdict) | null [m | m <- gMaterials g, materialKey m == key] -> case (gRun g, Map.lookup kindT (configKinds (projectConfig (gProject g)))) of
    (Nothing, _) -> pure (Left "no runtime is configured, so there is nothing of this kind to decide")
    (_, Nothing) -> pure (Left ("canon.yaml does not declare the kind " <> kindT))
    (Just run, Just declared)
      | not (Map.member (verdictText verdict) declared) -> pure (Left ("the kind " <> kindT <> " has no word " <> verdictText verdict))
      | otherwise -> case [m | m <- liveMutants run, mutantId m == i] of
          [] -> pure (Left ("not in the current run: " <> k))
          (m : _) -> do
            let trimmedN = T.strip n
                noteV = if T.null trimmedN then Nothing else Just trimmedN
                shard = T.unpack kindT ++ "/" ++ mutantFile m ++ ".yaml"
                e = VettingEntry verdict (mutantContext m) Nothing noteV (Just (runId run))
            writeShard g shard (Map.singleton key e)
            recordRun g run
            pure (Right (shard, key, e))
  (Just key, Just verdict) -> case [m | m <- gMaterials g, materialKey m == key] of
    [] -> pure (Left ("no material for " <> k))
    (m : _) -> do
      let trimmedR = T.strip r
          trimmedN = T.strip n
          revisitV = if T.null trimmedR then Nothing else parseVersion trimmedR
          noteV = if T.null trimmedN then Nothing else Just trimmedN
          vetting = gVetting g
          shard = fromMaybe (materialFile m) (fileOf vetting key)
          existing = Map.findWithDefault Map.empty shard (vettingFiles vetting)
          dir = resolvePath (gProject g) (configVetting (projectConfig (gProject g)))
      if not (T.null trimmedR) && revisitV == Nothing
        then pure (Left ("not a version: " <> trimmedR))
        else
          if verdict == Deferred && revisitV == Nothing
            then pure (Left "deferred needs the version to revisit by")
            else do
              let e = VettingEntry verdict (materialDigest m) revisitV noteV Nothing
              createDirectoryIfMissing True (takeDirectory (dir </> shard))
              TIO.writeFile (dir </> shard) (renderVetting (Map.insert key e existing))
              pure (Right (shard, key, e))
```

## history-instances

Decision lifecycle evidence is independent of a verdict. ref:DEC-verdict-carry-over

```haskell file=src/RicesTax/Core.hs part=history-instances
instance FromJSON s => FromJSON (Item s)
instance FromJSON s => FromJSON (Ref s)
instance FromJSON s => FromJSON (Signer s)
instance FromJSON s => FromJSON (Facts s)
instance FromJSON s => FromJSON (MutantView s)
instance FromJSON s => FromJSON (Observed s)
instance FromJSON s => FromJSON (Count s)
instance FromJSON s => FromJSON (Bound s)
instance FromJSON s => FromJSON (HistoryEvent s)
instance ToJSON s => ToJSON (HistoryEvent s)
instance FromJSON s => FromJSON (HistoryLog s)
instance ToJSON s => ToJSON (HistoryLog s)
instance ToJSON s => ToJSON (Lifecycle s)
instance FromJSON s => FromJSON (HistoryRequest s)
```

## history-storage

Decision lifecycle evidence is independent of a verdict. ref:DEC-verdict-carry-over

```haskell file=src/RicesTax/Core.hs part=history-storage
historyPath :: FilePath
historyPath = "canonical_history/mutations.yaml"

readHistory :: IO (Either Text (HistoryLog Text))
readHistory = do
  present <- doesFileExist historyPath
  if not present then pure (Right (HistoryLog 1 [])) else do
    parsed <- Yaml.decodeFileEither historyPath
    pure $ case parsed of
      Left e -> Left ("Cannot read decision history: " <> T.pack (show e))
      Right h | historySchema h /= 1 -> Left "Unsupported decision history schema"
              | length (nub (map eventId (historyEvents h))) /= length (historyEvents h) -> Left "Duplicate history event identifiers"
              | any (\e -> eventAction e `notElem` ["archive", "restore", "retire"]) (historyEvents h) -> Left "Unknown history action"
              | any (\e -> eventEvidenceDigest e /= snapshotDigest (eventSnapshot e) (eventFacts e)) (historyEvents h) -> Left "Decision history evidence checksum does not match its snapshot"
              | not (validHistoryChain (historyEvents h)) -> Left "Decision history event chain is inconsistent"
              | otherwise -> Right h

lifecycleOf :: Gathered -> Text -> HistoryLog Text -> [Item Text] -> [Lifecycle Text]
lifecycleOf g issue h current = map classify candidates
  where
    recorded = historyEvents h
    candidates = current ++ [eventSnapshot e | (k, e) <- Map.toList latest, k `notElem` map key current]
    latest = Map.fromList [(key (eventSnapshot e), e) | e <- recorded]
    classify original =
      let k = key original
          ident = T.drop 1 (T.dropWhile (/= '/') k)
          history = [e | e <- recorded, key (eventSnapshot e) == k]
          lastEvent = Map.lookup k latest
          match = gRun g >>= \r -> case [m | m <- runMutants r, mutantId m == ident] of
            [m] -> Just (r, m)
            _ -> Nothing
          snapshot = case match of
            Just (r, m) -> (mutantItem g r m) {key = k, kind = kind original, verdict = verdict original, note = note original, run = run original, signer = signer original}
            Nothing -> maybe original eventSnapshot lastEvent
          (status, message) =
            if not (T.null issue) then ("unverified", issue) else case match of
              Nothing | gRun g == Nothing -> ("unverified", "No current run is available. Restore the report or configure and run mutation.")
                      | otherwise -> ("absent", "No matching entry in the current report. Absence does not prove a kill.")
              Just (r, m)
                | mutantStaleFile m -> ("unverified", "The source changed after the run. Rerun before resolving this decision.")
                | mutantOutcome m == Killed -> ("resolved", "The same mutation is explicitly killed in the current report.")
                | mutantOutcome m `elem` [Skipped, TimedOut, Invalid, InfrastructureError, Unknown] -> ("unverified", "This mutation did not produce a conclusive result.")
                | kind snapshot /= kind (mutantItem g r m) -> ("reclassified", "This entry is now raised under a different kind; review its current obligation.")
                | state snapshot == "stale" -> ("changed", "The source context changed. Review the mutation again.")
                | verdict snapshot `elem` ["unreviewed", "pending", "needs-research", "gap"] -> ("review", "This mutation needs review.")
                | verdict snapshot `elem` ["inadequate-testing", "unnecessary-code"] -> ("work", "This mutation still requires testing or code changes.")
                | otherwise -> ("decided", "The mutation survives with a recorded decision.")
          archived = case lastEvent of
            Just e | eventAction e == "archive" -> status == "resolved" && verdict (eventSnapshot e) == verdict snapshot && run (eventSnapshot e) == run snapshot
                   | eventAction e == "retire" -> status `elem` ["absent", "reclassified"]
            _ -> False
       in Lifecycle k status message archived snapshot history

changeHistory :: HistoryRequest Text -> IO (Either Text (Payload Text))
changeHistory request = historyLocked transact
  where
    transact = withLoaded $ \project' -> do
      g <- gather project'
      p <- assemble g
      old <- readHistory
      case old of
        Left e -> pure (Left e)
        Right h -> historyTransaction g p h request

historyLocked :: IO (Either Text a) -> IO (Either Text a)
historyLocked transact = do
  createDirectoryIfMissing True "canonical_history"
  locked <- try (bracket (createDirectory "canonical_history/.lock") (const (removeDirectory "canonical_history/.lock")) (const transact))
  pure $ case locked of
    Left (e :: SomeException) -> Left ("History was not saved: " <> T.pack (show e) <> ". Another writer may be active; reload before retrying.")
    Right result -> result

historyTransaction :: Gathered -> Payload Text -> HistoryLog Text -> HistoryRequest Text -> IO (Either Text (Payload Text))
historyTransaction g p h request = do
          let keys = historyKeys request
              selected = [l | l <- lifecycle p, lifeKey l `elem` keys]
              action = historyAction request
              eligible l = case action of
                "archive" -> lifeStatus l == "resolved" && not (lifeArchived l) && verdict (lifeItem l) `notElem` ["pending", "unreviewed", "gap"]
                "restore" -> lifeArchived l
                "retire" -> lifeStatus l `elem` ["absent", "reclassified"] && not (lifeArchived l) && not (T.null (T.strip (historyReason request)))
                _ -> False
          if expectedRevision request /= historyRevision p then pure (Left "Results or decisions changed. Reload before changing history.")
          else if null keys || length (nub keys) /= length keys || length selected /= length keys || not (all eligible selected)
            then pure (Left "No changes saved: every selected decision must be eligible. Retirement also requires a reason.")
          else do
            now <- T.pack . show <$> getCurrentTime
            let previous l = case reverse (lifeEvents l) of [] -> ""; e : _ -> eventId e
                makeEvent n l = HistoryEvent
                  (fnv1aHex [historyRevision p, now, lifeKey l, action, T.pack (show n)]) action now
                  (if action == "archive" then "verified-kill" else T.strip (historyReason request))
                  (lifeItem l) (facts p)
                  (maybe "" entryDigest (parseVettingKey (lifeKey l) >>= (\k -> Map.lookup k (vettingEntries (gVetting g)))))
                  (snapshotDigest (lifeItem l) (facts p)) (previous l)
                next = h {historyEvents = historyEvents h ++ zipWith makeEvent [0 :: Int ..] selected}
            (temp, handle) <- openTempFile "canonical_history" ".mutations.yaml.tmp"
            hClose handle
            Yaml.encodeFile temp next
            renameFile temp historyPath
            Right <$> assemble g
```

## Mutation attempt evidence

An interrupted or failed attempt survives restarting the review server. A later successful
UI run clears the warning; the last retained report is not silently called current.
ref:DEC-mutation-rerun

```haskell file=src/RicesTax/Core.hs part=attempt-evidence
readAttemptIssue :: IO Text
readAttemptIssue = do
  present <- doesFileExist ".mut-attempt.json"
  if not present then pure "" else do
    bytes <- LBS.readFile ".mut-attempt.json"
    pure $ case eitherDecode bytes :: Either String (Mutation Text) of
      Left _ -> "Cannot read the latest mutation attempt status. Run mutation again."
      Right m | mutationState m == "running" -> "A mutation attempt started but has not recorded completion. Run mutation again if the process has stopped."
              | mutationState m == "failed" -> "The latest mutation attempt failed. Retained results are historical; rerun before resolving decisions."
              | otherwise -> ""
```

## History integrity and authorship

Snapshots have SHA-256 integrity checks. Git records authorship independently; an archival
write does not approve itself or waive an audit finding. ref:DEC-signer ref:DEC-audit

```haskell file=src/RicesTax/Core.hs part=history-integrity
snapshotDigest :: Item Text -> Maybe (Facts Text) -> Text
snapshotDigest i f = "sha256:" <> T.pack (concatMap hex (BS.unpack (SHA256.hash (LBS.toStrict (encode (i,f))))))
  where hex b = let x = showHex b "" in replicate (2 - length x) '0' ++ x

validHistoryChain :: [HistoryEvent Text] -> Bool
validHistoryChain = go Map.empty
  where
    go _ [] = True
    go previous (e:es) =
      let k = key (eventSnapshot e)
       in eventPrevious e == Map.findWithDefault "" k previous && go (Map.insert k (eventId e) previous) es

historyAudit :: IO [Text]
historyAudit = do
  present <- doesFileExist historyPath
  tracked <- runGit "." ["ls-files", "--error-unmatch", "--", historyPath]
  case (present, tracked) of
    (False, Left _) -> pure []
    (False, Right _) -> pure ["Decision history was deleted; restore or commit the intentional change."]
    (True, Left _) -> pure ["Decision history is not committed, so its authorship is unverified."]
    (True, Right _) -> do
      changed <- runGit "." ["diff", "HEAD", "--", historyPath]
      pure $ case changed of
        Right t | T.null t -> []
        _ -> ["Decision history has uncommitted changes; its new events are not signed."]
```
