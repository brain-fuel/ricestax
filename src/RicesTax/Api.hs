-- Tangled from api.md.
-- Edit the specification, not this file.
-- Every comment below is generated from the prose there.

-- | The public API of Rice's Tax as one table: every export with what it takes and returns, so
-- the WebAssembly entry module, the JavaScript wrappers, and their types are generated from it
-- and cannot drift, and one dispatcher answers every call with JSON. ref:DEC-npm-packaging
-- ref:DEC-wasm-toolchain
--
-- Specified by api S1.
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

-- | One export: its name, what it does, and its input and output as TypeScript types, which the
--
-- generator copies into the declarations. ref:DEC-npm-packaging
--
-- Specified by api S2.
data Export = Export
  { exportName :: Text
  , exportDoc :: Text
  , exportInput :: Text
  , exportOutput :: Text
  }
  deriving (Eq, Show)

-- | One verb of the command line: its spelling with its arguments, what it does, and the export
--
-- it runs, or none for a verb the Node binary serves itself or that only the native binary has.
--
-- The usage text and the Node binary's table are generated from this, so a verb cannot exist in
--
-- one and not the other. ref:DEC-umbrella-surface
--
-- Specified by api S3.
data Verb = Verb
  { verbName :: Text
  , verbArgs :: Text
  , verbDoc :: Text
  , verbExport :: Maybe Text
  , verbNative :: Bool
  }
  deriving (Eq, Show)

-- | The verbs: the three moments of the tax, then the tooling around it.
--
-- Specified by api S4.
verbs :: [Verb]
verbs =
  [ Verb "assess" "" "determine what is owed: write every missing row, record the run, report the totals" (Just "assess") False
  , Verb "pay" "[port] [page directory]" "serve the review page" Nothing False
  , Verb "audit" "[--json]" "prove the tax is paid: fail on open, stale, uncommitted, unrecorded, untangled, or expired rows" (Just "audit") False
  , Verb "import-records" "<MUT-*.md>..." "read the decided headings of wavelet records into the ledger" (Just "importRecords") False
  , Verb "canon" "<command>..." "run a canon command at the root: check, ingest, vet, tangle, site, and the rest" (Just "canon") False
  , Verb "site" "<out> [<root>...]" "render every root's pages to a static site under out, with the pay page over a snapshot" (Just "site") False
  , Verb "gen" "" "write the wasm entry module, its cabal file, and the Node wrappers from the export table" Nothing True
  ]

-- | The usage text, generated from the verbs.
--
-- Specified by api S5.
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

-- | The table. Every input carries root, the project directory; the session holds what was
--
-- gathered there. ref:DEC-npm-packaging
--
-- Specified by api S6.
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
  , Export "lift" "Lifts an exemption and returns the payload." "{ root: string; exemptSubject: string }" "Payload"
  , Export "whole" "The whole definition around a mutant, for the zoom and the copy." "{ root: string; kind: string; id: string }" "Whole"
  , Export "importRecords" "Reads the decided headings of wavelet MUT- records into the ledger." "{ root: string; paths: string[] }" "{ imported: number; missed: number }[]"
  , Export "canon" "Runs one canon command at root, its output going to the terminal, and returns its exit code." "{ root: string; args: string[] }" "{ exit: number }"
  , Export "site" "Renders the pages of each root to a static site under out, the first root's obligations as the pay page's snapshot when pages names the page directory." "{ root: string; out: string; roots: string[]; pages?: string }" "{ pages: number }"
  ]

-- | What is held per project between calls: the gathered project and its payload.
--
-- Specified by api S7.
newtype Session = Session (IORef (Map FilePath (Gathered, Payload Text)))

-- | A fresh session holding nothing.
--
-- Specified by api S8.
newSession :: IO Session
newSession = Session <$> newIORef Map.empty

-- | Answers one export by name with JSON in and JSON out; an unknown name or a failure is an
--
-- object with an error field, never an exception across the boundary. ref:DEC-npm-packaging
--
-- Specified by api S9.
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
    decideHeld root d (g, _) = do
      result <- decideWith g d
      case result of
        Left err -> pure (Left err)
        Right (shard, k, e) -> do
          let g' = g {gVetting = insertRow shard k e (gVetting g)}
          p' <- assemble g'
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

-- | A text field of a call's input, or a default.
--
-- Specified by api S10.
field :: Text -> Text -> Value -> Text
field k def v = case v of
  Object o | Just (String t) <- KM.lookup (Key.fromText k) o -> t
  _ -> def

-- | Adds a written row to the held ledger so the next decision in the same file merges with it.
--
-- Specified by api S11.
insertRow :: FilePath -> VettingKey -> VettingEntry -> Vetting -> Vetting
insertRow shard k e (Vetting files) = Vetting (Map.insertWith Map.union shard (Map.singleton k e) files)

newtype Paths = Paths [FilePath]

instance FromJSON Paths where
  parseJSON = withObject "Paths" $ \o -> Paths <$> o .:? "paths" .!= []

exitNumber :: ExitCode -> Int
exitNumber code = case code of
  ExitSuccess -> 0
  ExitFailure n -> n

newtype Args = Args [Text]

instance FromJSON Args where
  parseJSON = withObject "Args" $ \o -> Args <$> o .:? "args" .!= []

data SiteRequest = SiteRequest FilePath [FilePath] (Maybe FilePath)

instance FromJSON SiteRequest where
  parseJSON = withObject "SiteRequest" $ \o -> SiteRequest <$> o .: "out" <*> (o .:? "roots" .!= []) <*> o .:? "pages"
