-- Tangled from corpus.md.
-- Edit the specification, not this file.
-- Every comment below is generated from the prose there.

-- | The corpus is what the mutation tester runs against this project's own code, so the tax is
-- paid here before anywhere else; every rule is named for the property it verifies and cites
-- the requirement that wants it. ref:DEC-own-tests-sydtest ref:REQ-self-taxed
--
-- Specified by corpus S1.
module Main (main) where

import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T
import RicesTax.Fnv (fnv1aHex)
import RicesTax.Model
import qualified Canon.Model as C
import Canon.Span (Position (..), Span (..))
import Canon.Vetting (Material (..))
import qualified Data.List.NonEmpty as NE
import RicesTax.Sydtest (Mutant (..), Reading (..), bindingLines, chunksOf, contextOf, coverageOf, gapOf, headWord, ruleSourcesIn)
import qualified RicesTax.Sydtest as Syd
import RicesTax.What
import RicesTax.Api (Export (..), Session, Verb (..), call, exports, newSession, verbs)
import RicesTax.Core (auditExit, audit, gather)
import qualified RicesTax.Core as Core
import RicesTax.Diff (Edit (..), goneLines, lineDiff)
import RicesTax.Marks (Run, cutRuns, parseRuns, renderRuns)
import RicesTax.Wire (Mutation (..))
import qualified RicesTax.Wire as W
import qualified Canon
import Canon.Folio (Block (..))
import Canon.Profile (CommentSyntax (..), DocStyle (..), Embedding (..))
import Canon.Project (loadProject)
import Canon.Tangle (Origin (..), Tangled (..), assemble, originOf)
import Canon.Weave (embedOf, pagePath)
import Control.Exception (bracket)
import qualified Data.ByteString.Lazy as LBS
import Data.Aeson (Value (..), decode, encode)
import qualified Data.Aeson.KeyMap as KM
import Data.List (nub, sort)
import qualified Data.Text.IO as TIO
import System.Directory (createDirectoryIfMissing, doesFileExist, removeFile, getCurrentDirectory, getTemporaryDirectory, listDirectory, removeDirectoryRecursive, withCurrentDirectory)
import Data.Maybe (fromMaybe)
import System.Environment (lookupEnv)
import System.FilePath ((</>))
import System.Process (getCurrentPid)
import Test.QuickCheck (Gen, Property, choose, elements, forAll, listOf, property, (.&&.), (===))
import Test.Syd

-- | Runs the corpus. ref:REQ-self-taxed
--
-- Specified by corpus S2.
main :: IO ()
main = sydTest spec

-- | The rules run under a describe path of corpus, subject, and rule name, which is what the
-- mutation
-- driver joins on. The umbrella's scratch rules change the working directory, so that group
-- runs one
-- rule at a time. ref:REQ-self-taxed
--
-- Specified by corpus S3.
spec :: Spec
spec = describe "rices-tax" $ do
  describe "identity" $ do
    it "fnv.matches-wavelet-vectors" prop_fnvMatchesWaveletVectors
    it "fnv.newline-terminates-each-line" prop_fnvNewlineTerminatesEachLine
  describe "adapter" $ do
    it "chunks.start-at-column-one" prop_chunksStartAtColumnOne
    it "chunks.head-word-names-the-binding" prop_headWordNamesTheBinding
    it "coverage.words-follow-the-reading" prop_coverageWordsFollowTheReading
    it "gap.uncovered-is-always-a-gap" prop_uncoveredIsAlwaysAGap
    it "gap.one-outcome-names-the-value" prop_oneOutcomeNamesTheValue
  describe "model" $ do
    it "disposition.work-kinds-have-no-words" prop_workKindsHaveNoWords
    it "disposition.a-word-decides" prop_aWordDecides
    it "kinds.every-kind-has-a-question" prop_everyKindHasAQuestion
  describe "what" $ do
    it "raised.for-required-units-only" prop_whatRaisedForRequiredUnitsOnly
    it "digest.follows-name-signature-and-body" prop_whatDigestFollowsNameSignatureAndBody
    it "text.is-the-signature" prop_whatTextIsTheSignature
  describe "marks" $ do
    it "runs.render-and-parse-tile-the-line" prop_runsTileTheLine
    it "cut.keeps-order-and-totals" prop_cutRunsKeepsTotals
  describe "diff" $ do
    it "lines.shared-lines-are-context" prop_lineDiffKeepsSharedLines
  describe "mutation" $ do
    it "state.round-trips-the-wire" prop_mutationStateRoundTrips
  sequential $ describe "umbrella" $ do
    it "history.round-trip-stale-write-and-retained-evidence" prop_historyLifecycle
    it "history.requires-positive-run-evidence" prop_historyEvidence
    it "marks.parallel-to-code" prop_marksParallelToCode
    it "exports.names-are-unique-and-verbs-too" prop_exportsAndVerbsAreOneTable
    it "exports.unknown-name-is-an-error-object" prop_unknownExportIsAnError
    it "canon.arguments-reach-canon-unchanged" prop_canonArgumentsReachCanon
    it "audit.exit-code-contract" prop_auditExitCodes
    it "site.page-path-follows-diataxis" prop_pagePathFollowsDiataxis
    it "site.youtube-locator-embeds" prop_youtubeLocatorEmbeds
    it "site.two-renders-are-one-byte-string" prop_siteIsDeterministic
    it "audit.fails-on-a-stale-tangled-fixture" prop_auditFailsOnStaleTangle
    it "mutant.lands-through-the-line-map" prop_mutantLandsThroughTheLineMap
  describe "block" $ do
    it "binding.carries-its-comments" prop_bindingBlockCarriesItsComments
    it "binding.stops-at-a-blank-line" prop_bindingBlockStopsAtABlankLine
    it "rule.source-carries-its-requirement" prop_ruleSourceCarriesItsRequirement
    it "context.ignores-comments" prop_contextIgnoresComments
    it "context.foreign-source-edits-stale-verdicts" prop_foreignContextChanges

-- | The probe's observations are keyed by wavelet's hash, so the port must produce the same
--
-- digits for the same lines; the vectors were computed independently. ref:REQ-identity-joins
--
-- Specified by corpus S3.
prop_fnvMatchesWaveletVectors :: IO ()
prop_fnvMatchesWaveletVectors = do
  fnv1aHex [] `shouldBe` "cbf29ce484222325"
  fnv1aHex ["a"] `shouldBe` "089bdc07b544e7b2"
  fnv1aHex ["ab", "c"] `shouldBe` "55b7cb2f21b10c89"
  fnv1aHex ["\252n\239"] `shouldBe` "a770ba5cb87484fe"

-- | One line and the same text split across two differ only by the newline each line carries,
--
-- so the hash of two lines is never the hash of their concatenation. ref:REQ-identity-joins
--
-- Specified by corpus S4.
prop_fnvNewlineTerminatesEachLine :: IO ()
prop_fnvNewlineTerminatesEachLine = fnv1aHex ["ab", "c"] `shouldNotBe` fnv1aHex ["abc"]

-- | A definition's context is its top-level chunks, so a chunk begins exactly at a line whose
--
-- first character is not whitespace. ref:REQ-context-digest
--
-- Specified by corpus S5.
prop_chunksStartAtColumnOne :: IO ()
prop_chunksStartAtColumnOne = do
  let ls = ["f :: Int", "f = g", "  where", "    g = 1", "", "h = 2"]
  chunksOf ls `shouldBe` [["f :: Int"], ["f = g", "  where", "    g = 1", ""], ["h = 2"]]
  chunksOf [] `shouldBe` []

-- | The chunks of a binding are found by their first word, so the first word of a signature and
--
-- of an equation is the binding's name. ref:REQ-context-digest
--
-- Specified by corpus S6.
prop_headWordNamesTheBinding :: IO ()
prop_headWordNamesTheBinding = do
  headWord ["f' :: Int"] `shouldBe` "f'"
  headWord ["f_1 x = x"] `shouldBe` "f_1"
  headWord [] `shouldBe` ""

-- | wavelet's five coverage words, in wavelet's order of tests: a condition that only ever took
--
-- one value is told apart from an expression that is not a condition. ref:REQ-coverage-words
--
-- Specified by corpus S7.
prop_coverageWordsFollowTheReading :: IO ()
prop_coverageWordsFollowTheReading = do
  coverageOf Nothing `shouldBe` "unobserved"
  coverageOf (Just (reading [])) `shouldBe` "never-ran"
  coverageOf (Just (reading [("[]", 3)])) `shouldBe` "not-a-condition"
  coverageOf (Just (reading [("True", 3)])) `shouldBe` "one-outcome"
  coverageOf (Just (reading [("True", 3), ("False", 1)])) `shouldBe` "both-outcomes"

-- | Nothing reaches an uncovered mutant whatever the probe says, so it is work and not a
--
-- judgement. ref:REQ-coverage-words
--
-- Specified by corpus S8.
prop_uncoveredIsAlwaysAGap :: IO ()
prop_uncoveredIsAlwaysAGap = do
  gapOf (mutant Uncovered) (Just (reading [("True", 3), ("False", 1)])) `shouldBe` Just "nothing reaches it"
  gapOf (mutant Survived) (Just (reading [("True", 3), ("False", 1)])) `shouldBe` Nothing
  gapOf (mutant Survived) Nothing `shouldBe` Nothing

-- | A condition that went one way is a gap at that expression, named by the one value it took,
--
-- so the reviewer knows which way to widen the generator. ref:REQ-coverage-words
--
-- Specified by corpus S9.
prop_oneOutcomeNamesTheValue :: IO ()
prop_oneOutcomeNamesTheValue = do
  gapOf (mutant Survived) (Just (reading [("False", 7)])) `shouldBe` Just "only ever False"
  gapOf (mutant Survived) (Just (reading [])) `shouldBe` Just "nothing reaches it"

-- | A kind with no words is work by that fact alone, so a coverage gap sits in the ledger without
--
-- anyone signing it. ref:REQ-dispositions
--
-- Specified by corpus S10.
prop_workKindsHaveNoWords :: IO ()
prop_workKindsHaveNoWords = do
  disposition ObservabilityHow Nothing `shouldBe` Work
  disposition BlindSpotHow Nothing `shouldBe` Work
  disposition MutantHow Nothing `shouldBe` Open
  disposition CommentWhy Nothing `shouldBe` Open

-- | A word carries its own disposition, so the combined page reads a row without the kind's
--
-- table. ref:REQ-dispositions
--
-- Specified by corpus S11.
prop_aWordDecides :: Property
prop_aWordDecides = property $ \kindIndex wordIndex ->
  let kinds = [minBound .. maxBound] :: [Kind]
      k = kinds !! (abs kindIndex `mod` length kinds)
      ws = verdicts k
   in case ws of
        [] -> disposition k Nothing === Work
        _ -> let v = ws !! (abs wordIndex `mod` length ws) in disposition k (Just v) === verdictDisposition v

-- | Every kind answers one of the six questions, and the mapping is total. ref:REQ-dispositions
--
-- Specified by corpus S12.
prop_everyKindHasAQuestion :: IO ()
prop_everyKindHasAQuestion = do
  let qs = Map.fromListWith (+) [(kindQuestion k, 1 :: Int) | k <- [minBound .. maxBound]]
  Map.keys qs `shouldBe` [What, Why, How]
  sum (Map.elems qs) `shouldBe` length ([minBound .. maxBound] :: [Kind])

reading :: [(T.Text, Int)] -> Reading
reading distinct = Reading "read" (sum (map snd distinct)) distinct []

mutant :: Outcome -> Mutant
mutant o = Mutant "id" "M" "f" "ConstBool" "x" "True" o "src/F.hs" 1 1 1 2 [] [] [] [] [] "" False

-- | A unit of a fixture module, with its requirement and an optional signature.
--
-- Specified by corpus S13.
unitOf :: Text -> Text -> Maybe Text -> Text -> C.CommentRequirement -> C.CodeUnit ()
unitOf kind name sig body requirement =
  C.CodeUnit
    { C.unitId = C.UnitId (NE.fromList ["haskell", "a.hs", "module", "A", kind, name])
    , C.unitWhat = C.Answer (C.What name (C.UnitKind kind) sig) ()
    , C.unitHow = C.Answer (C.HowText body) ()
    , C.unitWhere = C.Answer (C.Where "a.hs" (Span (Position 1 1) (Position 2 1)) ["A"] Nothing) ()
    , C.unitWho = Nothing
    , C.unitWhen = Nothing
    , C.unitRequirement = requirement
    , C.unitTest = False
    , C.unitChildren = []
    }

-- | Only a unit that requires a comment owes a What, keyed by its unit id in the file of its
--
-- source. ref:REQ-what-raised
--
-- Specified by corpus S14.
prop_whatRaisedForRequiredUnitsOnly :: IO ()
prop_whatRaisedForRequiredUnitsOnly = do
  let f = unitOf "function" "f" (Just "Int") "f = 1" C.Required
      g = unitOf "function" "g" (Just "Int") "g = 2" C.Optional
      ms = whatMaterials [f, g]
  map materialKey ms `shouldBe` [C.KindKey "name" "haskell/a.hs/module/A/function/f"]
  map materialFile ms `shouldBe` ["name/a.hs.yaml"]
  map materialText ms `shouldBe` ["f :: Int"]

-- | The digest changes with the name, the signature, or the body, and with nothing else, in
--
-- canon's form. ref:REQ-what-digest
--
-- Specified by corpus S15.
prop_whatDigestFollowsNameSignatureAndBody :: IO ()
prop_whatDigestFollowsNameSignatureAndBody = do
  let base' = whatDigest "f" (Just "Int") "f = 1"
  base' `shouldBe` whatDigest "f" (Just "Int") "f = 1"
  T.take 7 base' `shouldBe` "sha256:"
  (base' /= whatDigest "g" (Just "Int") "f = 1") `shouldBe` True
  (base' /= whatDigest "f" (Just "Bool") "f = 1") `shouldBe` True
  (base' /= whatDigest "f" (Just "Int") "f = 2") `shouldBe` True

-- | What the person reads is the name with its signature, or the kind and the name; a module has
--
-- no body side. ref:REQ-what-digest
--
-- Specified by corpus S16.
prop_whatTextIsTheSignature :: IO ()
prop_whatTextIsTheSignature = do
  signatureOf (unitOf "function" "f" (Just "Int") "f = 1" C.Required) `shouldBe` "f :: Int"
  signatureOf (unitOf "data" "Shape" Nothing "data Shape = S" C.Required) `shouldBe` "data Shape"
  bodyOf (unitOf "module" "A" Nothing "module A where" C.Required) `shouldBe` ""
  bodyOf (unitOf "function" "f" (Just "Int") "f = 1" C.Required) `shouldBe` "f = 1"

-- | A binding's block starts at the doc comment and pragmas above it and runs through a trailing
--
-- comment that touches it. ref:REQ-whole-block
--
-- Specified by corpus S17.
prop_bindingBlockCarriesItsComments :: IO ()
prop_bindingBlockCarriesItsComments = do
  let ls = ["-- | Doc.", "-- more.", "{-# INLINE f #-}", "f :: Int", "f = 1", "-- note", "", "g :: Int", "g = 2"]
  bindingLines ls "f" `shouldBe` Just (1, take 7 ls)
  bindingLines ls "g" `shouldBe` Just (8, ["g :: Int", "g = 2"])

-- | A blank line ends a block on either side, and the next definition's doc comment is never
--
-- swept in. ref:REQ-whole-block
--
-- Specified by corpus S18.
prop_bindingBlockStopsAtABlankLine :: IO ()
prop_bindingBlockStopsAtABlankLine = do
  let ls = ["-- stray", "", "f :: Int", "f = 1", "", "-- | g doc", "g :: Int", "g = 2"]
  bindingLines ls "f" `shouldBe` Just (3, ["f :: Int", "f = 1", ""])
  bindingLines ls "g" `shouldBe` Just (6, ["-- | g doc", "g :: Int", "g = 2"])
  let touching = ["f :: Int", "f = 1", "-- | g doc", "g :: Int", "g = 2"]
  bindingLines touching "f" `shouldBe` Just (1, ["f :: Int", "f = 1"])

-- | A rule handed to a property has the property's whole block as its source, so the comment
--
-- that cites its requirement leads it. ref:REQ-whole-block
--
-- Specified by corpus S19.
prop_ruleSourceCarriesItsRequirement :: IO ()
prop_ruleSourceCarriesItsRequirement = do
  let file = chunksOf ["-- | Checks x. ref:REQ-1", "prop_x :: IO ()", "prop_x = pure ()", "", "spec :: Spec", "spec = it \"rule.x\" prop_x"]
  Map.lookup "rule.x" (ruleSourcesIn [file] ["rule.x"]) `shouldBe` Just ["-- | Checks x. ref:REQ-1", "prop_x :: IO ()", "prop_x = pure ()", ""]

-- | The digest a verdict is judged against is the binding alone, so an edit to a comment stales
--
-- no verdict and an edit to the code does. ref:REQ-context-digest
--
-- Specified by corpus S20.
prop_contextIgnoresComments :: IO ()
prop_contextIgnoresComments = do
  let plain = ["f :: Int", "f = 1"]
      commented = ["-- | Doc.", "f :: Int", "f = 1", "-- note"]
      changed = ["f :: Int", "f = 2"]
  contextOf commented "f" `shouldBe` contextOf plain "f"
  (contextOf changed "f" /= contextOf plain "f") `shouldBe` True

-- | Every export and every verb has one name, every verb that runs an export names one that
--
-- exists, and gen is native only. ref:REQ-one-table
--
-- Specified by corpus S21.
prop_exportsAndVerbsAreOneTable :: IO ()
prop_exportsAndVerbsAreOneTable = do
  let names = map exportName exports
  nub names `shouldBe` names
  nub (map verbName verbs) `shouldBe` map verbName verbs
  filter (`notElem` names) [e | Just e <- map verbExport verbs] `shouldBe` []
  [verbName v | v <- verbs, verbNative v] `shouldBe` ["gen"]

-- | A name the table does not know is answered with an error object, never an exception.
--
-- ref:REQ-one-table
--
-- Specified by corpus S22.
prop_unknownExportIsAnError :: IO ()
prop_unknownExportIsAnError = do
  session <- newSession :: IO Session
  out <- call session "nope" "{\"root\":\".\"}"
  case decode out of
    Just (Object o) -> KM.member "error" o `shouldBe` True
    _ -> expectationFailure "not an object"

-- | The canon verb hands its arguments to canon's own parser. ref:REQ-canon-delegated
--
-- Specified by corpus S23.
prop_canonArgumentsReachCanon :: IO ()
prop_canonArgumentsReachCanon = do
  Canon.parseCommand ["check"] `shouldBe` Canon.CommandCheck Nothing
  Canon.parseCommand ["tangle", "--check"] `shouldBe` Canon.CommandTangle True False []
  Canon.dispatch ["version"] `shouldBe` Canon.version

-- | Paid, not paid, and could not audit are three exit codes. ref:REQ-exit-codes
--
-- Specified by corpus S24.
prop_auditExitCodes :: IO ()
prop_auditExitCodes = do
  auditExit (Right True) `shouldBe` 0
  auditExit (Right False) `shouldBe` 1
  auditExit (Left "no canon.yaml") `shouldBe` 2

-- | A page is published under its quadrant and its name; a Markdown file elsewhere is not a
--
-- page. ref:REQ-site-layout
--
-- Specified by corpus S25.
prop_pagePathFollowsDiataxis :: IO ()
prop_pagePathFollowsDiataxis = do
  pagePath "docs/how-to/audit-in-ci.md" `shouldBe` Just "how-to/audit-in-ci/index.html"
  pagePath "docs/tutorials/first-audit.md" `shouldBe` Just "tutorials/first-audit/index.html"
  pagePath "README.md" `shouldBe` Nothing

-- | YouTube in either spelling is embedded through the no-cookie host; anything else is only
--
-- linked. ref:REQ-video-embed
--
-- Specified by corpus S26.
prop_youtubeLocatorEmbeds :: IO ()
prop_youtubeLocatorEmbeds = do
  embedOf "https://www.youtube.com/watch?v=abc123&t=4" `shouldBe` Just "https://www.youtube-nocookie.com/embed/abc123"
  embedOf "https://youtu.be/abc123" `shouldBe` Just "https://www.youtube-nocookie.com/embed/abc123"
  embedOf "https://vimeo.com/1" `shouldBe` Nothing

-- | A scratch project with one page that tangles one module, and a tangled file that may or may
--
-- not match it.
--
-- Each rule has its own directory, since the corpus runs its rules at once, and each process
-- too,
-- since the mutation driver runs the corpus out of process and elsewhere; the project root,
-- where
-- the grammars are, is taken from the environment when it is given. A fresh scratch is tangled
-- first, so its tangled file matches its page.
--
-- Specified by corpus S27.
withScratch :: String -> Bool -> (FilePath -> IO a) -> IO a
withScratch name fresh action = do
  cwd <- getCurrentDirectory
  here <- fromMaybe cwd <$> lookupEnv "RICES_TAX_ROOT"
  base <- getTemporaryDirectory
  pid <- getCurrentPid
  let root = base </> ("ricestax-test-" ++ name ++ "-" ++ show pid)
      grammar file = here </> "grammars" </> file
  bracket (createDirectoryIfMissing True root >> pure root) removeDirectoryRecursive $ \dir -> do
    createDirectoryIfMissing True (dir </> "docs/reference")
    createDirectoryIfMissing True (dir </> "src")
    writeFile (dir </> "canon.yaml") (unlines
      [ "version: 0.1.0"
      , "ignore: [\"*.md\", \"!docs/**/*.md\"]"
      , "languages:"
      , "  folio:"
      , "    extensions: [.md]"
      , "    lexer: " ++ grammar "folio/FolioLexer.g4"
      , "    parser: " ++ grammar "folio/FolioParser.g4"
      , "    start: document"
      , "    embeds:"
      , "      haskell:"
      , "        language: haskell"
      , "        comments: {line: \"--\", blockOpen: \"{-\", blockClose: \"-}\"}"
      , "        doc: {open: \"-- | \", continue: \"-- \", blank: \"--\", banner: \"-- \", markup: haddock}"
      , "  haskell:"
      , "    extensions: [.hs]"
      , "    lexer: " ++ grammar "haskell/canonically_commented/HaskellLexer.g4"
      , "    parser: " ++ grammar "haskell/canonically_commented/HaskellParser.g4"
      , "    start: module"
      ])
    writeFile (dir </> "docs/reference/m.md") (unlines
      [ "---", "id: m", "kind: reference", "title: M", "---", "# 1. M", "", "The module.", ""
      , "```haskell file=src/M.hs part=header", "module M (one) where", "```", ""
      , "## 1.1 One", "", "One is one.", ""
      , "```haskell file=src/M.hs def=one", "one :: Int", "one = 1", "```"
      ])
    writeFile (dir </> "src/M.hs") (if fresh then "" else "module M (one) where\none = 2\n")
    withCurrentDirectory dir $ do
      loaded <- loadProject "."
      case loaded of
        Left _ -> pure ()
        Right project -> do
          if fresh then Canon.runCommand (Canon.CommandTangle False False []) >> pure () else pure ()
          let _ = project
          pure ()
    action dir

-- | Two renders of one tree are one directory. ref:REQ-site-deterministic
--
-- Specified by corpus S28.
prop_siteIsDeterministic :: IO ()
prop_siteIsDeterministic = withScratch "site" True $ \dir -> withCurrentDirectory dir $ do
  Right project <- loadProject "."
  _ <- Canon.renderSite project "scratch" (dir </> "_a")
  _ <- Canon.renderSite project "scratch" (dir </> "_b")
  a <- readTree (dir </> "_a")
  b <- readTree (dir </> "_b")
  a `shouldBe` b
  map fst a `shouldBe` ["index.html", "reference/m/index.html"]
  where
    readTree top = do
      paths <- walk top ""
      mapM (\p -> (,) p <$> TIO.readFile (top </> p)) (sort paths)
    walk top rel = do
      entries <- listDirectory (top </> rel)
      concat <$> mapM (visit top rel) entries
    visit top rel e = do
      let p = if null rel then e else rel </> e
      isFile <- doesFileExist (top </> p)
      if isFile then pure [p] else walk top p

-- | A tangled file that differs from its page fails the audit, and one that matches does not fail
--
-- for that reason. ref:REQ-tangle-audited
--
-- Specified by corpus S29.
prop_auditFailsOnStaleTangle :: IO ()
prop_auditFailsOnStaleTangle = do
  stale <- withScratch "stale" False $ \dir -> withCurrentDirectory dir $ do
    Right project <- loadProject "."
    (_, report, _) <- gather project >>= audit
    pure report
  T.isInfixOf "differs from what its pages tangle to" stale `shouldBe` True
  fresh <- withScratch "fresh" True $ \dir -> withCurrentDirectory dir $ do
    Right project <- loadProject "."
    (_, report, _) <- gather project >>= audit
    pure report
  T.isInfixOf "differs from what its pages tangle to" fresh `shouldBe` False

-- | A body line of a tangled file maps back to its line in the page, and a generated line to the
--
-- block. ref:REQ-mutant-lands-through-manifest
--
-- Specified by corpus S30.
prop_mutantLandsThroughTheLineMap :: IO ()
prop_mutantLandsThroughTheLineMap = do
  let embedding = Embedding "haskell" (CommentSyntax (Just "--") Nothing Nothing []) 98 (DocStyle "-- | " "-- " "--" "-- " "haddock")
      block = Block "docs/reference/m.md" 10 "haskell" "src/M.hs" "one" False True [(1, "1. M")] [(8, "One is one.")] ["one :: Int", "one = 1"]
  case assemble embedding [block] of
    [t] -> do
      originOf t 8 `shouldBe` Just (OriginBody "docs/reference/m.md" 11)
      originOf t 9 `shouldBe` Just (OriginBody "docs/reference/m.md" 12)
      originOf t 5 `shouldBe` Just (OriginDoc "docs/reference/m.md" 10)
      tangledRanges t `shouldBe` [(5, 9)]
    ts -> expectationFailure (show (length ts) ++ " tangled files")

-- | The page reads the mutation's state from either server, so the wire form must round-trip
-- through
-- aeson as the native server writes it. ref:REQ-mutation-rerun
--
-- Specified by corpus S32.
prop_mutationStateRoundTrips :: IO ()
prop_mutationStateRoundTrips = do
  let mu = Mutation "running" "make mutate" "2026-09-19" 0 ["== 1. instrumented build =="] :: Mutation T.Text
  decode (encode mu) `shouldBe` Just mu

-- | A mutant that removes one alternative of a case shows one line gone and the rest as context;
-- a
-- mutant that changes one line shows it gone and its replacement come, at the same line; and
-- lines
-- the mutant adds are numbered where they land. ref:REQ-line-diff
--
-- Specified by corpus S33.
prop_lineDiffKeepsSharedLines :: IO ()
prop_lineDiffKeepsSharedLines = do
  let src = ["case x of", "  A -> 1", "  B -> 2", "  C -> 3"] :: [T.Text]
  lineDiff 10 src ["case x of", "  B -> 2", "  C -> 3"] `shouldBe` [Kept 10 "case x of", Gone 11 "  A -> 1", Kept 12 "  B -> 2", Kept 13 "  C -> 3"]
  lineDiff 10 ["x = 1"] ["x = 2"] `shouldBe` [Gone 10 "x = 1", Came 10 "x = 2"]
  lineDiff 10 ["a", "b"] ["a", "new", "b"] `shouldBe` [Kept 10 "a", Came 11 "new", Kept 11 "b"]
  goneLines (lineDiff 10 src ["case x of"]) `shouldBe` [11, 12, 13]

-- | A line's runs render to a mark and parse back to the same runs, an all-plain line renders to
-- nothing, and a cut at any offset keeps the runs' order and their total. ref:REQ-marks
--
-- Specified by corpus S34.
prop_runsTileTheLine :: Property
prop_runsTileTheLine = forAll runsGen $ \runs ->
  let positive = [(c, n) | (c, n) <- runs, n > 0]
   in parseRuns (renderRuns positive) === (if all ((== 'p') . fst) positive then [] else positive)

runsGen :: Gen [Run]
runsGen = listOf ((,) <$> elements "kcsntmdp" <*> choose (1, 9))

prop_cutRunsKeepsTotals :: Property
prop_cutRunsKeepsTotals = forAll ((,) <$> runsGen <*> choose (0, 40)) $ \(runs, k) ->
  let (a, b) = cutRuns k runs
      total = sum (map snd runs)
   in sum (map snd a) === min k total .&&. sum (map snd a) + sum (map snd b) === total .&&. map fst (a ++ b) === concat [replicate (if n == 0 then 0 else 1) c | (c, n) <- a ++ b]

-- | Over this project, every mark travels beside a line of the same length, and there are never
-- more
-- marks than lines. ref:REQ-marks
--
-- Specified by corpus S35.
prop_marksParallelToCode :: IO ()
prop_marksParallelToCode = do
  Right project <- loadProject "."
  p <- gather project >>= Core.assemble
  let agrees ls ms = length ms <= length ls && and [T.null m || sum (map snd (parseRuns (T.unpack m))) == T.length l | (l, m) <- zip ls ms]
      views = [mv | i <- W.items p, Just mv <- [W.mutant i]]
  all (\i -> agrees (W.code i) (W.marks i)) (W.items p) `shouldBe` True
  all (\mv -> agrees (W.before mv) (W.beforeMarks mv) && agrees (W.source mv) (W.sourceMarks mv) && agrees (W.mutated mv) (W.mutatedMarks mv) && agrees (W.after mv) (W.afterMarks mv)) views `shouldBe` True
  all (\r -> agrees (W.ruleSource r) (W.ruleMarks r)) (W.rules p) `shouldBe` True
  any (\mv -> any (not . T.null) (W.sourceMarks mv)) views `shouldBe` True

-- | An adapter without a method parser must still stale a review when the source changes;
-- the whole file is a conservative boundary.
--
-- Specified by corpus.
prop_foreignContextChanges :: IO ()
prop_foreignContextChanges = do
  let before = ["package example;", "class Sample {", "  int answer() { return 1; }", "}"]
      after = ["package example;", "class Sample {", "  int answer() { return 2; }", "}"]
  (contextOf before "answer" /= "") `shouldBe` True
  (contextOf before "answer" /= contextOf after "answer") `shouldBe` True
  contextOf before "answer" `shouldBe` fnv1aHex before

-- | A temporary foreign-language project exercises the actual reader, classifier, file writer,
-- and reload. A kill must be reported, never inferred from the absence of a live obligation.
-- ref:DEC-verdict-carry-over
--
-- Specified by corpus.
withHistoryScratch :: (IO () -> IO WPayload -> IO ()) -> IO ()
withHistoryScratch action = do
  tmp <- getTemporaryDirectory
  pid <- getCurrentPid
  let dir = tmp </> ("rices-history-" ++ show pid)
  bracket (createDirectoryIfMissing True dir >> pure dir) removeDirectoryRecursive $ \root -> withCurrentDirectory root $ do
    writeFile "canon.yaml" $ unlines
      [ "version: 0.1.0", "languages: {}"
      , "runtime: {name: test, artefacts: .mut, package: ., tests: tests}"
      , "kinds:", "  mutant:", "    unreviewed: open", "    inadequate-testing: work", "    logical-equivalency: closed"
      , "  observability:", "    gap: work" ]
    createDirectoryIfMissing True ".mut/out"
    createDirectoryIfMissing True ".mut/augmented"
    writeFile "Sample.java" "return true;\n"
    writeFile ".mut/augmented/manifest-augmented.json" "[[{\"id\":[\"m1\"],\"binding\":\"answer\",\"covering_tests\":{}}]]"
    writeFile ".mut/run.json" "{\"driver\":\"test\",\"toolchain\":\"test\",\"date\":\"2026-09-21\"}"
    let reset = writeHistoryReport "killed" 1 0
        payload = do
          Right project' <- loadProject "."
          Core.gather project' >>= Core.assemble
    reset
    Right project' <- loadProject "."
    g <- Core.gather project'
    let Just run' = Core.gRun g
        [m] = Syd.runMutants run'
    createDirectoryIfMissing True "canonical_vetting/mutant"
    TIO.writeFile "canonical_vetting/mutant/Sample.java.yaml" $ T.unlines
      [ "mutant/" <> Syd.mutantId m <> ":", "  digest: \"" <> mutantContext m <> "\""
      , "  verdict: inadequate-testing", "  note: Keep this reasoning", "  run: old-run" ]
    action reset payload

type WPayload = W.Payload Text

writeHistoryReport :: Text -> Int -> Int -> IO ()
writeHistoryReport result passed failed = TIO.writeFile ".mut/out/report.json" $
  "{\"controls\":{\"passed\":" <> T.pack (show passed) <> ",\"failed\":" <> T.pack (show failed) <> "},\"groups\":[[{\"outcome\":\"" <> result <> "\",\"mutation\":{\"id\":[\"m1\"],\"module\":\"Sample\",\"operator\":\"constant\",\"source_file\":\"Sample.java\",\"line\":1,\"end_line\":1,\"col_start\":8,\"col_end\":12,\"original\":\"true\",\"replacement\":\"false\",\"source_lines\":[\"return true;\"],\"mutated_lines\":[\"return false;\"]}}]]}"

prop_historyLifecycle :: IO ()
prop_historyLifecycle = withHistoryScratch $ \reset payload -> do
  before <- TIO.readFile "canonical_vetting/mutant/Sample.java.yaml"
  p <- payload
  map W.lifeStatus (W.lifecycle p) `shouldBe` ["resolved"]
  let [l] = W.lifecycle p
      request action p' = W.HistoryRequest action [W.lifeKey l] "" (W.historyRevision p')
  Right archived <- Core.changeHistory (request "archive" p)
  map W.lifeArchived (W.lifecycle archived) `shouldBe` [True]
  let [event] = W.lifeEvents (head (W.lifecycle archived))
  W.note (W.eventSnapshot event) `shouldBe` "Keep this reasoning"
  W.verdict (W.eventSnapshot event) `shouldBe` "inadequate-testing"
  W.run (W.eventSnapshot event) `shouldBe` "old-run"
  W.eventFacts event `shouldBe` W.facts p
  (not (T.null (W.eventDecisionDigest event))) `shouldBe` True
  T.isPrefixOf "sha256:" (W.eventEvidenceDigest event) `shouldBe` True
  (not (T.null (W.eventEvidenceDigest event))) `shouldBe` True
  stale <- Core.changeHistory (request "archive" p)
  either (T.isInfixOf "changed") (const False) stale `shouldBe` True
  reloaded <- payload
  W.lifecycle reloaded `shouldBe` W.lifecycle archived
  Right restored <- Core.changeHistory (request "restore" reloaded)
  map W.lifeArchived (W.lifecycle restored) `shouldBe` [False]
  map W.eventAction (W.lifeEvents (head (W.lifecycle restored))) `shouldBe` ["archive", "restore"]
  Right archivedAgain <- Core.changeHistory (request "archive" restored)
  writeHistoryReport "survived" 1 0
  returned <- payload
  map W.lifeArchived (W.lifecycle returned) `shouldBe` [False]
  map W.lifeStatus (W.lifecycle returned) `shouldBe` ["work"]
  reset
  removeFile ".mut/out/report.json"
  missing <- payload
  map W.lifeStatus (W.lifecycle missing) `shouldBe` ["unverified"]
  let lastSnapshot = W.eventSnapshot (last (W.lifeEvents (head (W.lifecycle missing))))
  W.mutant lastSnapshot `shouldBe` W.mutant (W.lifeItem (head (W.lifecycle archivedAgain)))
  TIO.readFile "canonical_vetting/mutant/Sample.java.yaml" >>= (`shouldBe` before)

prop_historyEvidence :: IO ()
prop_historyEvidence = withHistoryScratch $ \reset payload -> do
  let refuse = do
        p <- payload
        let [l] = W.lifecycle p
        result <- Core.changeHistory (W.HistoryRequest "archive" [W.lifeKey l] "" (W.historyRevision p))
        either (const True) (const False) result `shouldBe` True
  mapM_ (\(result, passed, failed) -> writeHistoryReport result passed failed >> refuse)
    [("killed",0,0),("killed",1,1),("skipped",1,0),("timed_out",1,0)]
  reset
  LBS.writeFile ".mut-attempt.json" (encode (W.Mutation "failed" "test" "today" 1 [] :: W.Mutation Text))
  refuse
  removeFile ".mut-attempt.json"
  writeFile "Sample.java" "return false;\n"
  refuse
  writeFile "Sample.java" "return true;\n"
  writeFile ".mut/out/report.json" "{\"controls\":{\"passed\":1,\"failed\":0},\"groups\":[]}"
  p <- payload
  map W.lifeStatus (W.lifecycle p) `shouldBe` ["absent"]
  refuse
  let [l] = W.lifecycle p
  badRetire <- Core.changeHistory (W.HistoryRequest "retire" [W.lifeKey l] "" (W.historyRevision p))
  either (const True) (const False) badRetire `shouldBe` True
  Right retired <- Core.changeHistory (W.HistoryRequest "retire" [W.lifeKey l] "Removed obsolete contract" (W.historyRevision p))
  map W.lifeArchived (W.lifecycle retired) `shouldBe` [True]
  map W.lifeStatus (W.lifecycle retired) `shouldBe` ["absent"]
  reset
  before <- payload
  atomic <- Core.changeHistory (W.HistoryRequest "archive" [W.lifeKey l, "mutant/missing"] "" (W.historyRevision before))
  either (const True) (const False) atomic `shouldBe` True
  after <- payload
  W.historyRevision after `shouldBe` W.historyRevision before
  Right project' <- loadProject "."
  (_, auditText, _) <- Core.gather project' >>= Core.audit
  T.isInfixOf "Decision history is not committed" auditText `shouldBe` True
  saved <- TIO.readFile "canonical_history/mutations.yaml"
  TIO.writeFile "canonical_history/mutations.yaml" (T.replace "Keep this reasoning" "Tampered reasoning" saved)
  tampered <- payload
  T.isInfixOf "checksum" (W.runIssue tampered) `shouldBe` True
  writeFile "canonical_history/mutations.yaml" "not: [valid"
  broken <- payload
  (not (T.null (W.runIssue broken))) `shouldBe` True
