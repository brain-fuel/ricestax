---
id: ricestax.reference.api
kind: reference
title: The export table and its generator
---
# The export table and its generator

## 1. The module RicesTax.Api

The public API of Rice's Tax as one table: every export with what it takes and returns, so
the WebAssembly entry module, the JavaScript wrappers, and their types are generated from it
and cannot drift, and one dispatcher answers every call with JSON. ref:DEC-npm-packaging
ref:DEC-wasm-toolchain

```haskell file=src/RicesTax/Api.hs part=header
module RicesTax.Api
  ( Export (..)
  , Verb (..)
  , verbs
  , usageText
  , exports
  , Session
  , newSession
  , call
  ) where

import Canon.Project (Project (..), extractFile)
import Canon.Extract.Grammar (Extraction (..))
import Data.Aeson (FromJSON (..), ToJSON (..), Value (..), eitherDecode, encode, object, withObject, (.:), (.:?), (.!=), (.=))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KM
import qualified Data.ByteString.Lazy as LBS
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T
import Canon.Model (VettingKey)
import Canon.Vetting (Vetting (..), VettingEntry)
import qualified Canon
import RicesTax.Core
import RicesTax.Site (renderSites)
import System.Exit (ExitCode (..))
import System.IO (hFlush, stderr, stdout)
import RicesTax.Wire
import System.Directory (withCurrentDirectory)
```

## 2. Export

One export: its name, what it does, and its input and output as TypeScript types, which the

generator copies into the declarations. ref:DEC-npm-packaging

```haskell file=src/RicesTax/Api.hs def=Export
data Export = Export
  { exportName :: Text
  , exportDoc :: Text
  , exportInput :: Text
  , exportOutput :: Text
  }
  deriving (Eq, Show)
```

## 3. Verb

One verb of the command line: its spelling with its arguments, what it does, and the export

it runs, or none for a verb the Node binary serves itself or that only the native binary has.

The usage text and the Node binary's table are generated from this, so a verb cannot exist in

one and not the other. ref:DEC-umbrella-surface

```haskell file=src/RicesTax/Api.hs def=Verb
data Verb = Verb
  { verbName :: Text
  , verbArgs :: Text
  , verbDoc :: Text
  , verbExport :: Maybe Text
  , verbNative :: Bool
  }
  deriving (Eq, Show)
```

## 4. verbs

The verbs: the three moments of the tax, then the tooling around it.

```haskell file=src/RicesTax/Api.hs def=verbs
verbs :: [Verb]
verbs =
  [ Verb "assess" "[--upgrade-canon]" "determine what is owed: write every missing row, record the run, report the totals; --upgrade-canon re-ingests a project canon.yaml says another canon assessed" (Just "assess") False
  , Verb "pay" "[port] [page directory]" "serve the review page" Nothing False
  , Verb "audit" "[--json]" "prove the tax is paid: fail on open, stale, uncommitted, unrecorded, untangled, or expired rows" (Just "audit") False
  , Verb "import-records" "<MUT-*.md>..." "read the decided headings of wavelet records into the ledger" (Just "importRecords") False
  , Verb "canon" "<command>..." "run a canon command at the root: check, ingest, vet, tangle, site, and the rest" (Just "canon") False
  , Verb "site" "<out> [<root>...]" "render every root's pages to a static site under out, with the pay page over a snapshot" (Just "site") False
  , Verb "gen" "" "write the wasm entry module, its cabal file, and the Node wrappers from the export table" Nothing True
  ]
```

## 5. usageText

The usage text, generated from the verbs.

```haskell file=src/RicesTax/Api.hs def=usageText
usageText :: Text
usageText =
  T.unlines
    ( ["usage: ricestax <verb> ...", "", "the tax:"]
        ++ [line v | v <- verbs, verbName v `elem` ["assess", "pay", "audit"]]
        ++ ["", "tooling:"]
        ++ [line v | v <- verbs, verbName v `notElem` ["assess", "pay", "audit"]]
        ++ ["", "run at the root of the project; the page directory is web/public of rices-tax, or RICES_TAX_SITE"]
    )
  where
    line v = "  " <> T.justifyLeft 34 ' ' (T.strip (verbName v <> " " <> verbArgs v)) <> verbDoc v <> (if verbNative v then " (native only)" else "")
```

## 6. exports

The table. Every input carries root, the project directory; the session holds what was

gathered there. ref:DEC-npm-packaging

```haskell file=src/RicesTax/Api.hs def=exports
exports :: [Export]
exports =
  [ Export "gather" "Reads the project at root through canon and the runtime and holds it; the other calls use what is held, so this runs once and after edits made outside the page." "{ root: string }" "{ obligations: number }"
  , Export "model" "Extracts a source file into its canonical model, with explicit parse errors." "{ root: string; path: string }" "unknown"
  , Export "reload" "Reads the project again and returns the fresh payload." "{ root: string }" "Payload"
  , Export "payload" "The page's payload: every obligation, the subjects, each rule's source once, and the run's facts." "{ root: string }" "Payload"
  , Export "assess" "Determines what is owed: writes every missing row, records the run, and reports the totals per queue." "{ root: string }" "{ report: string }"
  , Export "audit" "Proves the tax is paid, deciding nothing: fails on open, stale, uncommitted, unrecorded, or expired rows." "{ root: string }" "{ ok: boolean; text: string; json: unknown }"
  , Export "decide" "Writes one verdict into its ledger file and returns the changed row." "{ root: string } & Decide" "Item"
  , Export "history" "Archives, restores, or retires decisions with retained evidence and optimistic revision checking." "{ root: string } & HistoryRequest" "Payload"
  , Export "exempt" "Declares a subject not owed until a version and returns the payload with the exemption applied." "{ root: string } & ExemptRequest" "Payload"
  , Export "lift" "Lifts the exemption over a subject, for the kinds given or all, narrowing a wider one to the rest of what it covered, and returns the payload." "{ root: string; exemptSubject: string; exemptKinds?: string[] }" "Payload"
  , Export "whole" "The whole definition around a mutant, for the zoom and the copy." "{ root: string; kind: string; id: string }" "Whole"
  , Export "importRecords" "Reads the decided headings of wavelet MUT- records into the ledger." "{ root: string; paths: string[] }" "{ imported: number; missed: number }[]"
  , Export "canon" "Runs one canon command at root, its output going to the terminal, and returns its exit code." "{ root: string; args: string[] }" "{ exit: number }"
  , Export "site" "Renders the pages of each root to a static site under out, the first root's obligations as the pay page's snapshot when pages names the page directory." "{ root: string; out: string; roots: string[]; pages?: string }" "{ pages: number }"
  ]
```

## 7. Session

What is held per project between calls: the gathered project and its payload.

```haskell file=src/RicesTax/Api.hs def=Session
newtype Session = Session (IORef (Map FilePath (Gathered, Payload Text)))
```

## 8. newSession

A fresh session holding nothing.

```haskell file=src/RicesTax/Api.hs def=newSession
newSession :: IO Session
newSession = Session <$> newIORef Map.empty
```

## 9. call

Answers one export by name with JSON in and JSON out; an unknown name or a failure is an

object with an error field, never an exception across the boundary. ref:DEC-npm-packaging

```haskell file=src/RicesTax/Api.hs def=call
call :: Session -> Text -> LBS.ByteString -> IO LBS.ByteString
call (Session held) name input = case eitherDecode input of
  Left err -> pure (failure ("unreadable input: " <> T.pack err))
  Right v -> do
    let root = T.unpack (field "root" "." v)
    withCurrentDirectory root $ do
      result <- run root v
      pure (either failure id result)
  where
    failure :: Text -> LBS.ByteString
    failure e = encode (object ["error" .= e])
    run root v = case name of
      "gather" -> gathered root >>= \r -> pure (fmap (\(_, p) -> encode (object ["obligations" .= length (items p)])) r)
      "model" -> withLoaded (\project -> fmap (fmap (encode . extractionModel)) (extractFile project (T.unpack (field "path" "" v))))
      "reload" -> regather root >>= \r -> pure (fmap (encode . snd) r)
      "payload" -> gathered root >>= \r -> pure (fmap (encode . snd) r)
      "assess" -> withLoaded (\project -> gather project >>= fmap Right . assess) >>= \r -> do
        _ <- regather root
        pure (fmap (\t -> encode (object ["report" .= t])) r)
      "audit" -> withLoaded (\project -> gather project >>= fmap Right . audit) >>= \r ->
        pure (fmap (\(ok, t, j) -> encode (object ["ok" .= ok, "text" .= t, "json" .= decodeOr j])) r)
      "decide" -> case eitherDecode input of
        Left err -> pure (Left (T.pack err))
        Right d -> gathered root >>= either (pure . Left) (decideHeld root d)
      "history" -> case eitherDecode input of
        Left err -> pure (Left (T.pack err))
        Right request -> do
          result <- changeHistory request
          case result of
            Left err -> pure (Left err)
            Right _ -> regather root >>= pure . fmap (encode . snd)
      "exempt" -> exemptionCall True
      "lift" -> exemptionCall False
      "whole" -> gathered root >>= \r -> pure (r >>= \(g, _) -> maybe (Left ("no definition for " <> field "kind" "" v <> "/" <> field "id" "" v)) (Right . encode) (wholeOf g (field "kind" "" v) (field "id" "" v)))
      "importRecords" -> case eitherDecode input of
        Left err -> pure (Left (T.pack err))
        Right (Paths ps) -> withLoaded (\project -> gather project >>= \g -> Right <$> mapM (importRecord g) ps) >>= \r ->
          pure (fmap (\cs -> encode [object ["imported" .= a, "missed" .= b] | (a, b) <- cs]) r)
      "canon" -> case eitherDecode input of
        Left err -> pure (Left (T.pack err))
        Right (Args as) -> do
          code <- Canon.runCommand (Canon.parseCommand (map T.unpack as))
          hFlush stdout
          hFlush stderr
          pure (Right (encode (object ["exit" .= exitNumber code])))
      "site" -> case eitherDecode input of
        Left err -> pure (Left (T.pack err))
        Right (SiteRequest out roots pages) -> do
          result <- renderSites out (if null roots then ["."] else roots) pages
          pure (fmap (\n -> encode (object ["pages" .= n])) result)
      other -> pure (Left ("no such export: " <> other))
    decideHeld root d (g, p) = do
      result <- decideWith g d
      case result of
        Left err -> pure (Left err)
        Right (shard, k, e) -> do
          let g' = g {gVetting = insertRow shard k e (gVetting g)}
          p' <- redecide g' p (decideKey d)
          remember root (g', p')
          pure (Right (maybe (failure "decided, but the row is not in the payload") encode (rowOf (decideKey d) p')))
    exemptionCall adding = case (eitherDecode input, eitherDecode input) of
      (Left err, _) -> pure (Left (T.pack err))
      (Right x, rootValue) -> do
        let root = T.unpack (field "root" "." (either (const (object [])) id rootValue))
        gathered root >>= either (pure . Left) (exemptHeld root adding x)
    exemptHeld root adding x (g, p) = do
      result <- writeExemption g adding x
      case result of
        Left err -> pure (Left err)
        Right exemptions -> do
          let g' = g {gProject = (gProject g) {projectExemptions = exemptions}}
              p' = p {items = map (reExempt g') (items p)}
          remember root (g', p')
          pure (Right (encode p'))
    gathered root = do
      m <- readIORef held
      case Map.lookup root m of
        Just hit -> pure (Right hit)
        Nothing -> regather root
    regather root = do
      r <- withLoaded (\project -> gather project >>= \g -> Right . (,) g <$> assemble g)
      either (const (pure ())) (remember root) r
      pure r
    remember root pair = readIORef held >>= writeIORef held . Map.insert root pair
    rowOf k p = case [i | i <- items p, key i == k] of
      (i : _) -> Just i
      [] -> Nothing
    decodeOr :: LBS.ByteString -> Value
    decodeOr j = either (const (toJSON (T.pack "unreadable"))) id (eitherDecode j)
```

## 10. field

A text field of a call's input, or a default.

```haskell file=src/RicesTax/Api.hs def=field
field :: Text -> Text -> Value -> Text
field k def v = case v of
  Object o | Just (String t) <- KM.lookup (Key.fromText k) o -> t
  _ -> def
```

## 11. insertRow

Adds a written row to the held ledger so the next decision in the same file merges with it.

```haskell file=src/RicesTax/Api.hs def=insertRow
insertRow :: FilePath -> VettingKey -> VettingEntry -> Vetting -> Vetting
insertRow shard k e (Vetting files) = Vetting (Map.insertWith Map.union shard (Map.singleton k e) files)
```

```haskell file=src/RicesTax/Api.hs def=Paths
newtype Paths = Paths [FilePath]
```

```haskell file=src/RicesTax/Api.hs part=instance-1
instance FromJSON Paths where
  parseJSON = withObject "Paths" $ \o -> Paths <$> o .:? "paths" .!= []
```

```haskell file=src/RicesTax/Api.hs def=Args
exitNumber :: ExitCode -> Int
exitNumber code = case code of
  ExitSuccess -> 0
  ExitFailure n -> n

newtype Args = Args [Text]
```

```haskell file=src/RicesTax/Api.hs part=instance-2
instance FromJSON Args where
  parseJSON = withObject "Args" $ \o -> Args <$> o .:? "args" .!= []
```

```haskell file=src/RicesTax/Api.hs def=SiteRequest
data SiteRequest = SiteRequest FilePath [FilePath] (Maybe FilePath)
```

```haskell file=src/RicesTax/Api.hs part=instance-3
instance FromJSON SiteRequest where
  parseJSON = withObject "SiteRequest" $ \o -> SiteRequest <$> o .: "out" <*> (o .:? "roots" .!= []) <*> o .:? "pages"
```

## 12. The module RicesTax.Gen

Writes what the export table determines: the WebAssembly entry module with its one export
and the host's git, the cabal file that links it, the JavaScript API with one function per
export, and the TypeScript declarations. Run by ricestax gen before the wasm build, so the
three sides are the same table. ref:DEC-npm-packaging ref:DEC-wasm-toolchain

```haskell file=src/RicesTax/Gen.hs part=header
module RicesTax.Gen
  ( generate
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import RicesTax.Api (Export (..), Verb (..), exports, usageText, verbs)
import System.Directory (createDirectoryIfMissing)
import System.FilePath ((</>))
```

## 13. generate

Writes the four generated files under the repository root.

```haskell file=src/RicesTax/Gen.hs def=generate
generate :: FilePath -> IO ()
generate root = do
  createDirectoryIfMissing True (root </> "wasm" </> "app")
  createDirectoryIfMissing True (root </> "npm")
  TIO.writeFile (root </> "wasm" </> "app" </> "Exports.hs") exportsModule
  TIO.writeFile (root </> "wasm" </> "ricestax-wasm.cabal") cabalFile
  TIO.writeFile (root </> "npm" </> "api.mjs") apiModule
  TIO.writeFile (root </> "npm" </> "index.d.ts") declarations
```

```haskell file=src/RicesTax/Gen.hs def=banner
banner :: Text
banner = "-- Generated by ricestax gen from RicesTax.Api. Do not edit; edit the table.\n"
```

```haskell file=src/RicesTax/Gen.hs def=exportsModule
exportsModule :: Text
exportsModule =
  T.unlines
    [ "{-# LANGUAGE ForeignFunctionInterface #-}"
    , "{-# LANGUAGE OverloadedStrings #-}"
    , banner
    , "module Main (main) where"
    , ""
    , "import Canon.Git.Provider (GitError (..))"
    , "import Canon.Git.Shell (setGitRunner)"
    , "import Data.Aeson (FromJSON (..), eitherDecode, encode, withObject, (.:))"
    , "import qualified Data.ByteString.Lazy as LBS"
    , "import Data.IORef (IORef, newIORef, readIORef, writeIORef)"
    , "import qualified Data.Text as T"
    , "import qualified Data.Text.Encoding as TE"
    , "import GHC.Wasm.Prim (JSString (..), fromJSString, toJSString)"
    , "import RicesTax.Api (Session, call, newSession)"
    , "import System.IO.Unsafe (unsafePerformIO)"
    , ""
    , "foreign import javascript safe \"return await globalThis.__ricestax.git($1, $2)\" js_git :: JSString -> JSString -> IO JSString"
    , ""
    , "foreign export javascript \"ricestax_call\" ricestaxCall :: JSString -> JSString -> IO JSString"
    , ""
    , "data GitResult = GitResult Int T.Text T.Text"
    , ""
    , "instance FromJSON GitResult where"
    , "  parseJSON = withObject \"GitResult\" $ \\o -> GitResult <$> o .: \"code\" <*> o .: \"out\" <*> o .: \"err\""
    , ""
    , "session :: IORef (Maybe Session)"
    , "session = unsafePerformIO (newIORef Nothing)"
    , "{-# NOINLINE session #-}"
    , ""
    , "ricestaxCall :: JSString -> JSString -> IO JSString"
    , "ricestaxCall name input = do"
    , "  s <- readIORef session >>= maybe start pure"
    , "  out <- call s (T.pack (fromJSString name)) (LBS.fromStrict (TE.encodeUtf8 (T.pack (fromJSString input))))"
    , "  pure (toJSString (T.unpack (TE.decodeUtf8 (LBS.toStrict out))))"
    , "  where"
    , "    start = do"
    , "      setGitRunner hostGit"
    , "      s <- newSession"
    , "      writeIORef session (Just s)"
    , "      pure s"
    , "    hostGit dir args = do"
    , "      r <- js_git (toJSString dir) (toJSString (T.unpack (TE.decodeUtf8 (LBS.toStrict (encode (map T.pack args))))))"
    , "      pure $ case eitherDecode (LBS.fromStrict (TE.encodeUtf8 (T.pack (fromJSString r)))) of"
    , "        Right (GitResult 0 out _) -> Right out"
    , "        Right (GitResult (-1) _ _) -> Left GitNotFound"
    , "        Right (GitResult code _ err) -> Left (GitFailed code err)"
    , "        Left e -> Left (GitFailed 1 (T.pack e))"
    , ""
    , "-- | The entry point a reactor module needs and never runs; every call comes through ricestax_call."
    , "main :: IO ()"
    , "main = pure ()"
    ]
```

```haskell file=src/RicesTax/Gen.hs def=cabalFile
cabalFile :: Text
cabalFile =
  T.unlines
    [ "cabal-version:      3.0"
    , "-- Generated by ricestax gen. The one export is ricestax_call; the table names the rest."
    , "name:               ricestax-wasm"
    , "version:            0.4.0"
    , "synopsis:           The Rice's Tax core compiled to WebAssembly"
    , "license:            MIT"
    , "build-type:         Simple"
    , ""
    , "executable ricestax-wasm"
    , "  main-is:          Exports.hs"
    , "  hs-source-dirs:   app"
    , "  build-depends:    base < 5, aeson, bytestring, text, canon, rices-tax, ghc-experimental"
    , "  default-language: Haskell2010"
    , "  ghc-options:      -Wall -no-hs-main -optl-mexec-model=reactor \"-optl-Wl,--export=ricestax_call\""
    ]
```

```haskell file=src/RicesTax/Gen.hs def=apiModule
apiModule :: Text
apiModule =
  T.unlines
    ( [ "// Generated by ricestax gen from RicesTax.Api. Do not edit; edit the table."
      , "import { loadCore } from \"./launcher.mjs\";"
      , ""
      , "/** Loads the core for a project root and returns one function per export. */"
      , "export async function connect(root = process.cwd()) {"
      , "  const call = await loadCore(root);"
      , "  return {"
      ]
        ++ [ "    /** " <> exportDoc e <> " */\n    " <> exportName e <> ": (input) => call(\"" <> exportName e <> "\", { root, ...(input ?? {}) }),"
           | e <- exports
           ]
        ++ ["  };", "}"]
        ++ [ ""
           , "/** The verbs of the command line and the export each runs, null for one the binary serves itself. */"
           , "export const verbs = {" <> T.intercalate ", " [quote (verbName v) <> ": " <> maybe "null" quote (verbExport v) | v <- verbs, not (verbNative v)] <> "};"
           , ""
           , "/** The usage text, the same the native binary prints. */"
           , "export const usage = " <> quote usageText <> ";"
           ]
    )
  where
    quote t = "\"" <> T.concatMap quoteChar t <> "\""
    quoteChar c = case c of
      '"' -> "\\\""
      '\\' -> "\\\\"
      '\n' -> "\\n"
      _ -> T.singleton c
```

```haskell file=src/RicesTax/Gen.hs def=declarations
declarations :: Text
declarations =
  T.unlines
    ( [ "// Generated by ricestax gen from RicesTax.Api. Do not edit; edit the table."
      , "export type Subject = { subjectFile: string; subjectName: string; undecided: number; total: number };"
      , "export type Ref = { refKey: string; refKind: string; refTitle: string; refAnswer: string; refLocator: string };"
      , "export type Signer = { signerName: string; signedAt: string; signedIn: string; coAuthors: string[] };"
      , "export type Count = { value: string; count: number };"
      , "export type Bound = { boundName: string; boundValues: Count[] };"
      , "export type Observed = { obsStatus: string; obsTotal: number; obsDistinct: Count[]; obsBound: Bound[] };"
      , "export type MutantView = { operator: string; was: string; became: string; outcome: string; covering: string[]; before: string[]; source: string[]; mutated: string[]; after: string[]; beforeMarks: string[]; sourceMarks: string[]; mutatedMarks: string[]; afterMarks: string[]; fromLine: number; fromCol: number; toLine: number; toCol: number; observed: Observed | null; coverage: string; sided: string; gap: string; staleFile: boolean };"
      , "export type Item = { key: string; kind: string; question: string; file: string; subject: string; unit: string; unitKind: string; path: string; line: number; text: string; answer: string; refs: Ref[]; state: string; verdict: string; note: string; revisit: string; signer: Signer | null; code: string[]; codeFrom: number; commentLines: number; marks: string[]; mutant: MutantView | null; run: string; exempt: string; exemptReason: string; exemptUntil: string };"
      , "export type Facts = { runtime: string; runName: string; factList: [string, string][]; corpusOk: boolean; staleFiles: string[]; command: string };"
      , "export type Mutation = { mutationState: string; mutationCommand: string; mutationSince: string; mutationExit: number; mutationLog: string[] };"
      , "export type RuleSource = { ruleName: string; ruleSource: string[]; ruleMarks: string[] };"
      , "export type HistoryRequest = { historyAction: 'archive' | 'restore' | 'retire'; historyKeys: string[]; historyReason: string; expectedRevision: string };"
      , "export type HistoryEvent = { eventId: string; eventAction: string; eventTime: string; eventReason: string; eventSnapshot: Item; eventFacts: Facts | null; eventDecisionDigest: string; eventEvidenceDigest: string; eventPrevious: string };"
      , "export type Lifecycle = { lifeKey: string; lifeStatus: string; lifeMessage: string; lifeArchived: boolean; lifeItem: Item; lifeEvents: HistoryEvent[] };"
      , "export type Payload = { project: string; subjects: Subject[]; items: Item[]; facts: Facts | null; rules: RuleSource[]; lifecycle: Lifecycle[]; historyRevision: string; runIssue: string; ingestionIssues: string[] };"
      , "export type Whole = { wholeLines: string[]; wholeStart: number; wholeMarks: string[] };"
      , "export type Decide = { decideKey: string; decideVerdict: string; decideNote: string; decideRevisit: string };"
      , "export type ExemptRequest = { exemptSubject: string; exemptKinds: string[]; exemptWhy: string; exemptRevisit: string };"
      , "export type Failure = { error: string };"
      , ""
      , "export type Api = {"
      ]
        ++ [ "  /** " <> exportDoc e <> " */\n  " <> exportName e <> "(input: " <> exportInput e <> "): Promise<" <> exportOutput e <> " | Failure>;"
           | e <- exports
           ]
        ++ ["};", "", "export function connect(root?: string): Promise<Api>;", "export const verbs: Record<string, keyof Api | null>;", "export const usage: string;"]
    )
```
