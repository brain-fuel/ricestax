-- Tangled from cli.md.
-- Edit the specification, not this file.
-- Every comment below is generated from the prose there.

-- | The native executable: the three verbs on the command line and the pay server under Warp.
-- All the work is in RicesTax.Core, so that the WebAssembly module does the same work from
-- Node.
-- ref:DEC-three-verbs ref:DEC-wasm-toolchain
--
-- Specified by cli S1.
module Main (main) where

import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Data.Time.Clock (diffUTCTime, getCurrentTime)
import Canon.Config (Runtime (..))
import Canon.Project
import Canon.Vetting hiding (assess, entryRevisit)
import Data.Aeson (ToJSON, eitherDecode, encode)
import qualified Data.ByteString.Lazy as LBS
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.Text.IO as TIO
import Network.HTTP.Types (Status, status200, status400, status404, status405, status409, status500)
import Network.Wai (Application, Response, pathInfo, requestMethod, responseFile, responseLBS, strictRequestBody)
import qualified Network.Wai.Handler.Warp as Warp
import Network.Wai.Middleware.Gzip (defaultGzipSettings, gzip)
import RicesTax.Wire
import System.Directory (doesFileExist)
import System.Environment (getArgs, lookupEnv)
import System.Exit (ExitCode (..), exitFailure, exitWith)
import System.FilePath (takeExtension, (</>))
import Control.Concurrent (forkIO)
import System.IO (IOMode (..), hClose, hPutStrLn, openFile, stderr)
import System.Process (CreateProcess (..), StdStream (..), createProcess, shell, waitForProcess)
import Text.Read (readMaybe)
import RicesTax.Core
import qualified Canon
import RicesTax.Api (usageText)
import RicesTax.Gen (generate)
import RicesTax.Site (renderSites)

-- | The three verbs of the tax, run at the root of the project like canon: assess what is owed,
--
-- pay it, and audit that it was paid. ref:DEC-three-verbs
--
-- Could not audit is its own code, apart from not paid, so a pipeline can tell them apart.
--
-- Specified by cli S2.
main :: IO ()
main = do
  args <- getArgs
  case args of
    ["assess"] -> do
      result <- withLoaded (\project -> gather project >>= \g -> Right <$> assess g)
      case result of
        Left err -> hPutStrLn stderr (T.unpack err) >> exitFailure
        Right report -> TIO.putStr report
    ("audit" : flags) -> do
      result <- withLoaded (\project -> gather project >>= \g -> Right <$> audit g)
      case result of
        Left err -> hPutStrLn stderr (T.unpack err)
        Right (_, textReport, jsonReport) -> if "--json" `elem` flags then LBS.putStr jsonReport >> putStrLn "" else TIO.putStr textReport
      case auditExit (fmap (\(ok, _, _) -> ok) result) of
        0 -> pure ()
        n -> exitWith (ExitFailure n)
    ["gen"] -> generate "." >> putStrLn "generated wasm/app/Exports.hs, wasm/ricestax-wasm.cabal, npm/api.mjs, npm/index.d.ts"
    ("pay" : rest) -> do
      fromEnv <- lookupEnv "RICES_TAX_SITE"
      let port = fromMaybe 8080 (portArg rest)
          site = fromMaybe (fromMaybe "web/public" fromEnv) (siteArg rest)
      hPutStrLn stderr ("pay at http://localhost:" ++ show port ++ "  (ctrl-c to stop), pages from " ++ site)
      cache <- newIORef Nothing
      mutating <- newIORef (Mutation "idle" "" "" 0 [])
      refresh cache
      Warp.run port (gzip defaultGzipSettings (application site cache mutating))
    ("canon" : rest) -> Canon.runCommand (Canon.parseCommand rest) >>= exitWith
    ("site" : out : roots) -> do
      fromEnv <- lookupEnv "RICES_TAX_SITE"
      result <- renderSites out (if null roots then ["."] else roots) (Just (fromMaybe "web/public" fromEnv))
      case result of
        Left err -> hPutStrLn stderr (T.unpack err) >> exitWith (ExitFailure 2)
        Right n -> putStrLn (show n ++ " pages under " ++ out)
    ("import-records" : paths) | not (null paths) -> do
      result <- withLoaded (\project -> gather project >>= \g -> Right <$> mapM (importRecord g) paths)
      case result of
        Left err -> hPutStrLn stderr (T.unpack err) >> exitFailure
        Right counts -> mapM_ (\(p, matched, missed) -> putStrLn (p ++ ": " ++ show matched ++ " verdicts imported, " ++ show missed ++ " not in the current run")) (zip3 paths (map fst counts) (map snd counts))
    _ -> hPutStrLn stderr (T.unpack usageText) >> exitWith (ExitFailure 2)
  where
    portArg rest = case rest of
      (p : _) | Just n <- readMaybe p -> Just n
      _ -> Nothing
    siteArg rest = case rest of
      (_ : s : _) -> Just s
      _ -> Nothing

-- | The payload is computed once at start and after every decision, not per request, because
--
-- gathering a large project takes minutes and the page must not wait for it each time it asks;
--
-- GET /reload recomputes it after an edit made outside the page. ref:DEC-ui-shape
--
-- Specified by cli S3.
type Cache = IORef (Maybe (Either Text (Gathered, Payload Text)))

refresh :: Cache -> IO ()
refresh cache = do
  started <- getCurrentTime
  built <- withLoaded (\project -> gather project >>= \g -> Right . (,) g <$> assemble g)
  finished <- getCurrentTime
  hPutStrLn stderr ("gathered in " ++ show (diffUTCTime finished started) ++ either (("; failed: " ++) . T.unpack) (\(_, p) -> ": " ++ show (length (items p)) ++ " obligations") built)
  writeIORef cache (Just built)

-- | The cached ledger learns the row it just wrote, so the next decision in the
-- same file merges with this one instead of overwriting it.
-- Only the changed row goes back; the page already knows the rest.
--
-- Specified by cli S4.
application :: FilePath -> Cache -> Mutating -> Application
application site cache mutating request respond = case (requestMethod request, pathInfo request) of
  ("GET", []) -> static "index.html"
  ("GET", ["obligations"]) -> cachedResponse cache >>= respond
  ("GET", ["reload"]) -> do
    mu <- readIORef mutating
    if mutationState mu == "running"
      then respond (textResponse status409 "the mutation is running; the project is re-read when it ends")
      else refresh cache >> cachedResponse cache >>= respond
  ("GET", ["mutation"]) -> mutationStatus mutating >>= respond . jsonResponse
  ("POST", ["mutate"]) -> startMutation cache mutating >>= respond
  ("POST", ["history"]) -> do
    mu <- readIORef mutating
    if mutationState mu `elem` ["running", "failed"]
      then respond (textResponse status409 "The latest mutation attempt is running or failed. Complete a successful run before changing history.")
      else do
        body <- strictRequestBody request
        case eitherDecode body of
          Left err -> respond (textResponse status400 (T.pack err))
          Right d -> do
            result <- changeHistory d
            case result of
              Left err -> respond (textResponse status409 err)
              Right p -> refresh cache >> respond (jsonResponse p)
  ("POST", ["exempt"]) -> exemptionRoute True
  ("POST", ["lift"]) -> exemptionRoute False
  ("GET", ["whole", kindT, i]) -> do
    held <- readIORef cache
    respond $ case held of
      Just (Right (g, _)) | Just w <- wholeOf g kindT i -> responseLBS status200 [("Content-Type", "application/json"), ("Cache-Control", "no-store")] (encode w)
      _ -> textResponse status404 ("no definition for " <> kindT <> "/" <> i)
  ("POST", ["decide"]) -> do
    body <- strictRequestBody request
    case eitherDecode body of
      Left err -> respond (textResponse status400 (T.pack ("unreadable decision: " ++ err)))
      Right d -> do
        hPutStrLn stderr ("decide " ++ T.unpack (decideKey d) ++ " -> " ++ T.unpack (decideVerdict d) ++ (if T.null (T.strip (decideNote d)) then "" else " with a note") ++ (if T.null (T.strip (decideRevisit d)) then "" else " revisit " ++ T.unpack (decideRevisit d)))
        held <- readIORef cache
        case held of
          Just (Right (g, _)) -> do
            result <- decideWith g d
            case result of
              Left err -> respond (textResponse status400 err)
              Right (shard, k, e) -> do
                let g' = g {gVetting = Vetting (Map.insertWith Map.union shard (Map.singleton k e) (vettingFiles (gVetting g)))}
                p' <- assemble g'
                writeIORef cache (Just (Right (g', p')))
                respond $ case [i | i <- items p', key i == decideKey d] of
                  (i : _) -> responseLBS status200 [("Content-Type", "application/json"), ("Cache-Control", "no-store")] (encode i)
                  [] -> textResponse status404 "decided, but the row is not in the payload"
          _ -> respond (textResponse status500 "not gathered yet")
  ("GET", segments) -> static (T.unpack (T.intercalate "/" segments))
  _ -> respond (textResponse status405 "method not allowed")
  where
    exemptionRoute adding = do
      body <- strictRequestBody request
      case eitherDecode body of
        Left err -> respond (textResponse status400 (T.pack ("unreadable exemption: " ++ err)))
        Right (x :: ExemptRequest Text) -> do
          held <- readIORef cache
          case held of
            Just (Right (g, p)) -> do
              result <- writeExemption g adding x
              case result of
                Left err -> respond (textResponse status400 err)
                Right exemptions -> do
                  let g' = g {gProject = (gProject g) {projectExemptions = exemptions}}
                      p' = p {items = map (reExempt g') (items p)}
                  hPutStrLn stderr ((if adding then "exempt " else "lift ") ++ T.unpack (exemptSubject x))
                  writeIORef cache (Just (Right (g', p')))
                  cachedResponse cache >>= respond
            _ -> respond (textResponse status500 "not gathered yet")
    static rel = do
      let path = site </> rel
      present <- doesFileExist path
      if present && not (".." `T.isInfixOf` T.pack rel)
        then respond (responseFile status200 [("Content-Type", LBS.toStrict (mime path)), ("Cache-Control", "no-store")] path Nothing)
        else respond (textResponse status404 ("not found: " <> T.pack rel))

mime :: FilePath -> LBS.ByteString
mime path = case takeExtension path of
  ".html" -> "text/html; charset=utf-8"
  ".js" -> "application/javascript"
  ".mjs" -> "application/javascript"
  ".wasm" -> "application/wasm"
  ".css" -> "text/css"
  ".json" -> "application/json"
  _ -> "application/octet-stream"

-- | The run is started from the page and watched from it, while decisions go on: the command is
-- the
-- one @canon.yaml@ names, its output goes to a log the page reads the tail of, and when it ends
-- the
-- project is re-read, so verdicts carry over to the mutants that are the same and the rest are
-- listed as not in the current run. A re-read asked for while it runs is refused, since the
-- artefacts are being replaced. ref:DEC-mutation-rerun
--
-- Specified by cli S4.
type Mutating = IORef (Mutation Text)

mutationLogFile :: FilePath
mutationLogFile = ".mut.log"

mutationStatus :: Mutating -> IO (Mutation Text)
mutationStatus mutating = do
  mu <- readIORef mutating
  present <- doesFileExist mutationLogFile
  logged <- if present then (reverse . take 30 . reverse . T.lines) <$> TIO.readFile mutationLogFile else pure []
  pure mu {mutationLog = logged}

startMutation :: Cache -> Mutating -> IO Response
startMutation cache mutating = do
  held <- readIORef cache
  mu <- readIORef mutating
  case held of
    Just (Right (g, _)) | Just command <- gRuntime g >>= runtimeCommand ->
      if mutationState mu == "running"
        then pure (textResponse status409 "the mutation is already running")
        else do
          now <- getCurrentTime
          h <- openFile mutationLogFile WriteMode
          (_, _, _, process) <- createProcess (shell (T.unpack command)) {std_out = UseHandle h, std_err = UseHandle h}
          hClose h
          let since = T.pack (show now)
          LBS.writeFile ".mut-attempt.json" (encode (Mutation "running" command since 0 [] :: Mutation Text))
          writeIORef mutating (Mutation "running" command since 0 [])
          hPutStrLn stderr ("mutation started: " ++ T.unpack command)
          _ <- forkIO $ do
            code <- waitForProcess process
            LBS.writeFile ".mut-attempt.json" (encode (Mutation (if code == ExitSuccess then "finished" else "failed") command since (exitNumber code) [] :: Mutation Text))
            refresh cache
            writeIORef mutating (Mutation (if code == ExitSuccess then "finished" else "failed") command since (exitNumber code) [])
            hPutStrLn stderr ("mutation ended with " ++ show code)
          jsonResponse <$> mutationStatus mutating
    Just (Right _) -> pure (textResponse status400 "canon.yaml names no runtime command, so the mutation cannot be started from the page")
    _ -> pure (textResponse status500 "not gathered yet")

exitNumber :: ExitCode -> Int
exitNumber code = case code of
  ExitSuccess -> 0
  ExitFailure n -> n

jsonResponse :: ToJSON a => a -> Response
jsonResponse = responseLBS status200 [("Content-Type", "application/json"), ("Cache-Control", "no-store")] . encode

textResponse :: Status -> Text -> Response
textResponse status message = responseLBS status [("Content-Type", "text/plain; charset=utf-8")] (LBS.fromStrict (TE.encodeUtf8 message))

cachedResponse :: Cache -> IO Response
cachedResponse cache = do
  held <- readIORef cache
  pure $ case held of
    Nothing -> textResponse status500 "not gathered yet"
    Just (Left err) -> textResponse status500 err
    Just (Right (_, p)) -> responseLBS status200 [("Content-Type", "application/json"), ("Cache-Control", "no-store")] (encode p)
