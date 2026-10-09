{-# OPTIONS_GHC -Wno-orphans #-}
-- | The Why and How queues and the shell of the combined page, in Haskell so it shares the wire
-- types with the server; its look follows wavelet's mutation review page, the reference for how a
-- review surface should feel. The wire types get miso's JSON instances here because the server
-- gives them aeson's, and neither side may depend on the other's JSON library.
-- ref:DEC-page-first-queue ref:DEC-ui-frontend ref:DEC-ui-shape ref:DEC-how-card
module Main (main) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe, isJust)
import Data.Set (Set)
import qualified Data.Set as Set
import Control.Concurrent (threadDelay)
import Miso
import Miso.Html.Element as H
import Miso.Navigator (copyClipboard)
import Miso.Html.Event as E
import Miso.Html.Property as P
import qualified Miso.Property as MP
import qualified Miso.Event as ME
import Miso.JSON (FromJSON, ToJSON)
import Miso.Lens
import qualified Miso.String as S
import GHC.Wasm.Prim (JSString, fromJSString)
import qualified RicesTax.Wire as W
import RicesTax.Diff (Edit (..), goneLines, lineDiff)
import RicesTax.Marks (Run, classWord, cutRuns, padRuns, parseRuns)

instance FromJSON s => FromJSON (W.HistoryEvent s)
instance FromJSON s => FromJSON (W.Lifecycle s)
instance ToJSON s => ToJSON (W.HistoryRequest s)
instance FromJSON s => FromJSON (W.Index s)
instance FromJSON s => FromJSON (W.Group s)
instance FromJSON s => FromJSON (W.Card s)
instance ToJSON s => ToJSON (W.CardsRequest s)
instance ToJSON s => ToJSON (W.GroupRequest s)

instance FromJSON s => FromJSON (W.Payload s)

instance FromJSON s => FromJSON (W.Subject s)

instance FromJSON s => FromJSON (W.Item s)

instance FromJSON s => FromJSON (W.Ref s)

instance FromJSON s => FromJSON (W.Signer s)

instance FromJSON s => FromJSON (W.Facts s)

instance FromJSON s => FromJSON (W.MutantView s)

instance FromJSON s => FromJSON (W.RuleSource s)

instance FromJSON s => FromJSON (W.Observed s)

instance FromJSON s => FromJSON (W.Count s)

instance FromJSON s => FromJSON (W.Bound s)

instance FromJSON s => FromJSON (W.Whole s)

instance ToJSON s => ToJSON (W.ExemptRequest s)

instance ToJSON s => ToJSON (W.Decide s)

instance FromJSON s => FromJSON (W.Mutation s)

instance ToJSON s => ToJSON (W.Mutation s)

foreign export javascript "hs_start" main :: IO ()

-- The URL's hash names the queue to open, so a queue has an address of its own (DEC-ui-shape).
-- A plain comment, because canon's Haskell grammar does not yet know a foreign import as a unit.
foreign import javascript unsafe "window.location.hash" js_hash :: IO JSString

type Str = MisoString

type Payload = W.Payload Str

type Item = W.Item Str

type Mut = W.MutantView Str

-- | One page per queue and one over all of them, as DEC-ui-shape asks. ref:DEC-ui-shape
data Tab = WhyTab | WhatTab | HowTab | AllTab
  deriving (Eq, Show)

-- | Half-written reasoning is the most expensive thing on the page, so a draft survives every
-- re-render until its decision is posted. ref:DEC-page-first-queue
data Draft = Draft
  { draftNote :: Str
  , draftRevisit :: Str
  }
  deriving (Eq, Show)

-- | The zoom shows the whole definition or the rules that looked, larger, for one card.
-- ref:DEC-how-card
data Zoom = ZoomCode | ZoomTests
  deriving (Eq, Show)

-- | What the page knows: the last payload, the chosen tab and subject, drafts by key, the keys
-- that were already decided when the page loaded so this session's work stands apart, an open
-- zoom, and whether a decision is in flight. ref:DEC-page-first-queue
data Model = Model
  { loaded :: Maybe Payload
  , failure :: Maybe Str
  , tab :: Tab
  , chosen :: Maybe Str
  , drafts :: Map Str Draft
  , prior :: Set Str
  , started :: Bool
  , busy :: Bool
  , zoom :: Maybe (Str, Zoom)
  , zoomWhole :: Maybe (W.Whole Str)
  , expanded :: Set Str
  , limit :: Int
  , inflight :: Map Str Item
  , copied :: Maybe Str
  , exemptForm :: Maybe ExemptForm
  , mutation :: Maybe (W.Mutation Str)
  , reviewView :: Str
  , historySearch :: Str
  , historyNotice :: Str
  , undoHistory :: Maybe (Str, [Str])
  , pendingHistory :: Maybe (Str, [Str])
  , retiring :: Maybe Str
  , retirementReason :: Str
  , findings :: Map Str Str
  , details :: Map Str Item
  , requested :: Set Str
  , groups :: [W.Group Str]
  , groupRows :: Map Str [Item]
  }
  deriving (Eq, Show)

-- | The form that adds an exemption for the chosen subject: the kinds, the reason, and the
-- version to revisit by. ref:DEC-exemptions
data ExemptForm = ExemptForm
  { formSubject :: Str
  , formKinds :: Str
  , formWhy :: Str
  , formRevisit :: Str
  }
  deriving (Eq, Show)

-- | Cards are shown a page at a time, because a queue of two thousand rendered at once is what
-- made a click take seconds. ref:DEC-how-card
pageSize :: Int
pageSize = 20

-- | Everything the page can be asked to do. ref:DEC-page-first-queue
data Action
  = PickReview Str
  | SearchHistory Str
  | ChangeHistory Str [Str]
  | HistoryChanged Payload
  | Retire Str
  | RetirementReason Str
  | CancelRetirement
  | Load
  | Loaded Payload
  | Failed Str
  | Pick Tab
  | Choose (Maybe Str)
  | EditNote Str Str
  | EditRevisit Str Str
  | Decide Str Str Str Str
  | Decided Str Item
  | Reload
  | OpenZoom Str Zoom
  | WholeLoaded (W.Whole Str)
  | CloseZoom
  | Toggle Str
  | ShowMore
  | Copy Str
  | CopyWith Str (W.Whole Str)
  | Copied Str
  | Uncopied Str
  | OpenExempt Str
  | EditExempt ExemptForm
  | CancelExempt
  | SubmitExempt
  | Lift Str
  | LiftKinds Str [Str]
  | Exempted Payload
  | RunMutation
  | MutationLoaded (W.Mutation Str)
  | PollMutation
  | Indexed (W.Index Str)
  | Need Str
  | CardsLoaded [W.Card Str]
  | GroupLoaded Str [Item]
  deriving (Eq, Show)

-- | Starts the page on the queue the URL names and asks the server for the obligations at once.
-- ref:DEC-ui-frontend
main :: IO ()
main = do
  h <- js_hash
  startApp defaultEvents (app (tabFromHash (ms (fromJSString h))))

app :: Tab -> App Model Action
app t = (component (initial t) updateModel viewModel) {mount = Just Load}

tabFromHash :: Str -> Tab
tabFromHash h = case h of
  "#how" -> HowTab
  "#what" -> WhatTab
  "#all" -> AllTab
  _ -> WhyTab

initial :: Tab -> Model
initial t = Model Nothing Nothing t Nothing Map.empty Set.empty False False Nothing Nothing Set.empty pageSize Map.empty Nothing Nothing Nothing "attention" "" "" Nothing Nothing Nothing "" Map.empty Map.empty Set.empty [] Map.empty

emptyDraft :: Draft
emptyDraft = Draft "" ""

updateModel :: Action -> Effect parent props Model Action
updateModel = \case
  PickReview v -> this %= \m -> m {reviewView = v, limit = pageSize}
  SearchHistory v -> this %= \m -> m {historySearch = v}
  Retire k -> this %= \m -> m {retiring = Just k, retirementReason = ""}
  RetirementReason v -> this %= \m -> m {retirementReason = v}
  CancelRetirement -> this %= \m -> m {retiring = Nothing, retirementReason = ""}
  ChangeHistory action keys -> do
    m <- get
    case loaded m of
      Nothing -> pure ()
      Just p -> do
        this %= \m' -> m' {busy = True, failure = Nothing, pendingHistory = Just (action, keys)}
        postJSON' "history" (W.HistoryRequest action keys (retirementReason m) (W.historyRevision p)) [] (HistoryChanged . body) (Failed . describe)
  HistoryChanged p -> this %= \m -> m
    { loaded = Just p, busy = False, failure = Nothing, retiring = Nothing
    , historyNotice = maybe "History saved." (\(a, ks) -> ms (show (length ks)) <> " decision(s) " <> a <> " saved locally. Commit the history file to record authorship.") (pendingHistory m)
    , undoHistory = fmap (\(a, ks) -> (if a == "restore" then "archive" else "restore", ks)) (pendingHistory m)
    , pendingHistory = Nothing }
  Load -> do
    getJSON "index" [] (Indexed . body) (Failed . describe)
    getJSON "mutation" [] (MutationLoaded . body) (\r -> const (MutationLoaded (W.Mutation "idle" "" "" 0 [])) (r :: Response Str))
  -- The mutation runs while deciding goes on; the page polls until it ends, then re-reads.
  RunMutation -> do
    this %= \m -> m {failure = Nothing}
    postJSON' "mutate" (W.Mutation "start" "" "" 0 [] :: W.Mutation Str) [] (MutationLoaded . body) (Failed . describe)
  MutationLoaded mu -> do
    m <- get
    let was = fmap W.mutationState (mutation m)
    this %= \m' -> m' {mutation = Just mu}
    if W.mutationState mu == "running"
      then io (threadDelay 3000000 >> pure PollMutation)
      else if was == Just "running" then io (pure Reload) else pure ()
  PollMutation -> getJSON "mutation" [] (MutationLoaded . body) (Failed . describe)
  Loaded p ->
    this %= \m ->
      m
        { loaded = Just p
        , findings = Map.fromList (W.found p)
        , failure = Nothing
        , busy = False
        , prior = if started m then prior m else decidedKeys p
        , started = True
        }
  Failed e -> this %= \m -> m {failure = Just e, busy = False, loaded = fmap (restore (inflight m)) (loaded m), groupRows = Map.map (map (\i -> Map.findWithDefault i (W.key i) (inflight m))) (groupRows m), details = Map.union (inflight m) (details m), inflight = Map.empty}
  Pick t -> this %= \m -> m {tab = t, chosen = Nothing, limit = pageSize}
  Choose s -> this %= \m -> m {chosen = s, limit = pageSize}
  Toggle k -> do
    m <- get
    let opening = not (Set.member k (expanded m))
    this %= \m' -> m' {expanded = if opening then Set.insert k (expanded m') else Set.delete k (expanded m')}
    case S.stripPrefix "exempt:" k of
      Just gk | opening, not (Map.member gk (groupRows m)) -> case S.splitOn "\t" gk of
        [q, pat] -> postJSON' "group" (W.GroupRequest q pat) [] (GroupLoaded gk . body) (Failed . describe)
        _ -> pure ()
      Nothing | opening -> io (pure (Need k))
      _ -> pure ()
  ShowMore -> this %= \m -> m {limit = limit m + pageSize}
  WholeLoaded w -> this %= \m -> m {zoomWhole = Just w}
  -- The copy carries the whole definition too, so it is fetched first; a failure to fetch copies
  -- the block without it rather than nothing.
  Copy k -> getJSON ("whole/" <> k) [] (CopyWith k . body) (\r -> const (CopyWith k (W.Whole [] 0 [])) (r :: Response Str))
  CopyWith k w -> do
    m <- get
    case [i | Just p <- [loaded m], i <- W.items p, W.key i == k] of
      (i : _) | Just p <- loaded m -> copyClipboard (mutationReport p i w) (Copied k) (const (Failed "the browser refused the clipboard; copying needs a secure page or a click"))
      _ -> pure ()
  Copied k -> do
    this %= \m -> m {copied = Just k}
    io (threadDelay 1600000 >> pure (Uncopied k))
  Uncopied k -> this %= \m -> m {copied = if copied m == Just k then Nothing else copied m}
  OpenExempt subj -> this %= \m -> m {exemptForm = Just (ExemptForm subj (exemptKindsFor (tab m)) "" "")}
  EditExempt f -> this %= \m -> m {exemptForm = Just f}
  CancelExempt -> this %= \m -> m {exemptForm = Nothing}
  SubmitExempt -> do
    m <- get
    case exemptForm m of
      Nothing -> pure ()
      Just f -> do
        this %= \m' -> m' {busy = True, failure = Nothing}
        postJSON' "index/exempt" (W.ExemptRequest (formSubject f) (filter (not . S.null) (map S.strip (S.splitOn "," (formKinds f)))) (formWhy f) (formRevisit f)) [] (Indexed . body) (Failed . describe)
  Lift subj -> do
    this %= \m -> m {busy = True, failure = Nothing}
    postJSON' "index/lift" (W.ExemptRequest subj [] "" "") [] (Indexed . body) (Failed . describe)
  LiftKinds subj kinds -> do
    this %= \m -> m {busy = True, failure = Nothing}
    postJSON' "index/lift" (W.ExemptRequest subj kinds "" "") [] (Indexed . body) (Failed . describe)
  Exempted p -> this %= \m -> m {loaded = Just p, findings = Map.fromList (W.found p), busy = False, failure = Nothing, exemptForm = Nothing}
  EditNote k v -> this %= \m -> m {drafts = Map.alter (Just . (\d -> d {draftNote = v}) . fromMaybe emptyDraft) k (drafts m)}
  EditRevisit k v -> this %= \m -> m {drafts = Map.alter (Just . (\d -> d {draftRevisit = v}) . fromMaybe emptyDraft) k (drafts m)}
  Decide k v n r -> do
    -- The row changes on the click; the server's answer replaces it, or a failure restores it.
    this %= \m ->
      m
        { busy = True
        , failure = Nothing
        , inflight = Map.union (inflight m) (Map.fromList ([(W.key i, i) | Just p <- [loaded m], i <- W.items p, W.key i == k] ++ [(W.key i, i) | is <- Map.elems (groupRows m), i <- is, W.key i == k]))
        , loaded = fmap (patchItem k (\i -> i {W.state = v, W.verdict = v, W.note = n, W.revisit = r, W.signer = Nothing})) (loaded m)
        , groupRows = Map.map (map (\i -> if W.key i == k then i {W.state = v, W.verdict = v, W.note = n, W.revisit = r, W.signer = Nothing} else i)) (groupRows m)
        , details = Map.adjust (\i -> i {W.state = v, W.verdict = v, W.note = n, W.revisit = r, W.signer = Nothing}) k (details m)
        }
    postJSON' "decide" (W.Decide k v n r) [] (Decided k . body) (Failed . describe)
  -- The server answers with the row as written; the rest of the page already holds everything
  -- else, so the payload of thousands of rows is not fetched again for one click.
  Decided k i -> this %= \m ->
    let inGroup = [gk | (gk, is) <- Map.toList (groupRows m), any ((== k) . W.key) is]
        settled = not (open i)
        place p = if any ((== k) . W.key) (W.items p) then patchItem k (const i) p else p {W.items = W.items p ++ [i]}
        shrink g = if settled && (W.groupQuestion g <> "\t" <> W.groupPattern g) `elem` inGroup then g {W.groupCount = W.groupCount g - 1, W.groupSubjects = [(s', if s' == W.subject i then c - 1 else c) | (s', c) <- W.groupSubjects g]} else g
     in m
          { loaded = fmap (if settled || null inGroup then place else patchItem k (const i)) (loaded m)
          , groupRows = if settled then Map.map (filter ((/= k) . W.key)) (groupRows m) else Map.map (map (\x -> if W.key x == k then i else x)) (groupRows m)
          , groups = map shrink (groups m)
          , details = Map.insert k i (details m)
          , findings = Map.delete k (findings m)
          , busy = False
          , failure = Nothing
          , drafts = Map.delete k (drafts m)
          , inflight = Map.delete k (inflight m)
          }
  Reload -> do
    this %= \m -> m {busy = True, failure = Nothing}
    getJSON "index/reload" [] (Indexed . body) (Failed . describe)
  -- The page opens on the index: the rows not owed under an exemption, without their material,
  -- and the exempt ones as groups; a card's material, and a group's rows, are asked for when
  -- they are shown, so thousands of rows cost what is on screen. ref:DEC-light-index
  Indexed ix -> this %= \m ->
    let p = W.Payload (W.indexProject ix) [] (W.indexItems ix) (W.indexFacts ix) (W.indexRules ix) (W.indexLifecycle ix) (W.indexHistoryRevision ix) (W.indexRunIssue ix) (W.indexIngestionIssues ix) [] (W.indexCanon ix)
     in m
          { loaded = Just p
          , groups = W.indexGroups ix
          , groupRows = Map.empty
          , details = Map.empty
          , requested = Set.empty
          , failure = Nothing
          , busy = False
          , exemptForm = Nothing
          , prior = if started m then prior m else decidedKeys p
          , started = True
          }
  Need k -> do
    m <- get
    if Set.member k (requested m) || Map.member k (details m)
      then pure ()
      else do
        this %= \m' -> m' {requested = Set.insert k (requested m')}
        postJSON' "cards" (W.CardsRequest [k]) [] (CardsLoaded . body) (Failed . describe)
  CardsLoaded cs -> this %= \m ->
    m
      { details = Map.union (Map.fromList [(W.key (W.cardItem c), W.cardItem c) | c <- cs]) (details m)
      , findings = Map.union (Map.fromList [(W.key (W.cardItem c), W.cardFinding c) | c <- cs, not (S.null (W.cardFinding c))]) (findings m)
      , requested = foldr (Set.delete . W.key . W.cardItem) (requested m) cs
      }
  GroupLoaded gk is -> this %= \m -> m {groupRows = Map.insert gk is (groupRows m)}
  OpenZoom k z -> do
    this %= \m -> m {zoom = Just (k, z), zoomWhole = Nothing}
    case z of
      ZoomCode -> getJSON ("whole/" <> k) [] (WholeLoaded . body) (Failed . describe)
      ZoomTests -> pure ()
  CloseZoom -> this %= \m -> m {zoom = Nothing, zoomWhole = Nothing}

patchItem :: Str -> (Item -> Item) -> Payload -> Payload
patchItem k f p = p {W.items = [if W.key i == k then f i else i | i <- W.items p]}

restore :: Map Str Item -> Payload -> Payload
restore saved p = p {W.items = [Map.findWithDefault i (W.key i) saved | i <- W.items p]}

describe :: Response Str -> Str
describe r = fromMaybe "the server did not answer" (errorMessage r) <> maybe "" (\s -> " (status " <> ms (show s) <> ")") (status r) <> (if S.null (body r) then "" else ": " <> body r)

decidedKeys :: Payload -> Set Str
decidedKeys p = Set.fromList [W.key i | i <- W.items p, not (open i)]

-- | The kinds an exemption from a queue's tab covers by default.
exemptKindsFor :: Tab -> Str
exemptKindsFor t = case t of
  HowTab -> "mutant, observability"
  WhyTab -> "comment"
  WhatTab -> "name"
  AllTab -> ""

-- | The kinds a lift of one subject from a queue's tab lifts, so lifting a file from the Why
-- queue leaves an exemption of its names, or of its mutants, as it was. ref:DEC-exemption-lift
liftKindsFor :: Tab -> [Str]
liftKindsFor t = case t of
  WhyTab -> ["comment", "doc", "ledger", "registry"]
  WhatTab -> ["name"]
  HowTab -> ["mutant", "observability"]
  AllTab -> []

-- | Open means a person still owes a decision: pending or stale for Why, unreviewed, stale, or
-- parked as needs-research for How. ref:DEC-obligation
open :: Item -> Bool
open i = W.state i `elem` ["pending", "stale", "unreviewed", "needs-research"]

inTab :: Tab -> Item -> Bool
inTab t i = case t of
  WhyTab -> W.question i == "Why"
  WhatTab -> W.question i == "What"
  HowTab -> W.question i == "How"
  AllTab -> True

inTabQuestion :: Tab -> Str -> Bool
inTabQuestion t q = case t of
  WhyTab -> q == "Why"
  WhatTab -> q == "What"
  HowTab -> q == "How"
  AllTab -> True

isGapItem :: Item -> Bool
isGapItem i = W.kind i == "observability"

isGone :: Item -> Bool
isGone i = W.state i == "gone"

viewModel :: Model -> View context props Model Action
viewModel m = case loaded m of
  Nothing -> H.div_ [P.class_ "empty"] [text (maybe "Loading the obligations. The server gathers the project once at start, which takes a while for a large one; the page fills in when it answers." ("Could not load: " <>) (failure m))]
  Just p ->
    let everything = if tab m == HowTab then map W.lifeItem (W.lifecycle p) else [i | i <- W.items p, inTab (tab m) i]
        visible = [i | i <- everything, maybe True (== W.subject i) (chosen m)]
        tabGroups = [(g, n) | g <- groups m, inTabQuestion (tab m) (W.groupQuestion g), let n = maybe (W.groupCount g) (\s' -> sum [c | (x, c) <- W.groupSubjects g, x == s']) (chosen m), n > 0]
        exemptCount = sum (map snd tabGroups)
        judgements = [i | i <- visible, not (isGapItem i), not (isGone i), tab m /= AllTab || W.question i /= "How", S.null (W.exempt i) || not (open i)]
        gaps = [i | i <- visible, tab m /= AllTab || W.question i /= "How", isGapItem i, S.null (W.exempt i)]
        gone = [i | i <- visible, tab m /= AllTab || W.question i /= "How", isGone i]
        here = [i | i <- judgements, not (Set.member (W.key i) (prior m))]
        shut = [i | i <- judgements, Set.member (W.key i) (prior m)]
        left = length (filter open here)
        allJudgements = [i | i <- everything, not (isGapItem i), not (isGone i), tab m /= AllTab || W.question i /= "How", S.null (W.exempt i) || not (open i)]
        outstanding = if tab m == HowTab then length [l | l <- W.lifecycle p, lifeNeedsAttention l, not (W.lifeArchived l)] else length (filter open allJudgements)
        allGaps = length [i | i <- everything, isGapItem i, S.null (W.exempt i)]
        subjectsHere = Map.toList (Map.fromListWith (\(a, b) (c, d) -> (a + c, b + d)) ([(W.subject i, (if open i && S.null (W.exempt i) then 1 else 0 :: Int, 0 :: Int)) | i <- everything] ++ [(s', (0, c)) | g <- groups m, inTabQuestion (tab m) (W.groupQuestion g), (s', c) <- W.groupSubjects g, c > 0]))
        owedExempt = sum [W.groupCount g | g <- groups m, inTabQuestion (tab m) (W.groupQuestion g)]
        rulesMap = Map.fromList [(W.ruleName r, (W.ruleSource r, W.ruleMarks r)) | r <- W.rules p]
     in H.div_
          []
          [ H.header_
              []
              [ H.div_ [] [H.h1_ [] [text "Rice's Tax"], H.div_ [P.class_ "sub"] [text (W.project p <> " -- " <> subjectLabel m <> seedText p)]]
              , H.nav_ [P.class_ "tabs"] ([tabButton m t | t <- [WhyTab, WhatTab, HowTab, AllTab]] ++ [H.button_ [E.onClick Reload, P.title_ "Re-read the project: the ledger, the sources, and the run. Needed after an edit made outside this page.", disabledIf (busy m || mutationRunning m)] [text (if busy m then "…" else "re-read")]] ++ mutationButton m p)
              , H.div_
                  [P.classList_ [("counter", True), ("clear", outstanding == 0 && null (W.ingestionIssues p))]]
                  ( [H.b_ [] [text (if tab m == HowTab then ms (show outstanding) else ms (show outstanding) <> " / " <> ms (show (length allJudgements)))], H.span_ [] [text (if tab m == HowTab then "need attention" else "to decide")]]
                      ++ (if allGaps == 0 then [] else [H.b_ [P.class_ "gapcount"] [text (ms (show allGaps))], H.span_ [] [text "coverage gaps"]])
                      ++ (if owedExempt == 0 then [] else [H.b_ [P.class_ "exemptcount"] [text (ms (show owedExempt))], H.span_ [P.title_ "Owed, but under an exemption that is not yet due: review a group under Exempt, or lift it."] [text "owed under exemptions"]])
                  )
              ]
          , maybe (text "") (\e -> H.div_ [P.class_ "failure"] [text e]) (failure m)
          , if null (W.ingestionIssues p) then text "" else H.div_ [P.class_ "failure", textProp "role" "alert"]
              [ H.b_ [] [text "Review is incomplete: some source files could not be ingested."]
              , H.ul_ [] [H.li_ [] [text issue] | issue <- W.ingestionIssues p]
              ]
          , mutationBanner m
          , probeBanner m p
          , H.main_
              []
              [ H.nav_ [P.class_ "subjects"] (subjectButton m Nothing "All" (sum [o | (_, (o, _)) <- subjectsHere]) (sum [e | (_, (_, e)) <- subjectsHere]) : [subjectButton m (Just s) s o e | (s, (o, e)) <- subjectsHere] ++ exemptControl m exemptCount)
              , H.div_
                  []
                  ( case tab m of
                      HowTab -> historyView m p rulesMap
                      _ ->
                        [ H.h2_ [P.class_ "section"] [text ("This session -- " <> ms (show left) <> " of " <> ms (show (length here)) <> " still undecided")]
                        , if null here then H.div_ [P.class_ "empty"] [text (if not (null (W.ingestionIssues p)) then "Fix the ingestion errors above before treating this queue as complete." else if exemptCount == 0 then "Nothing undecided in " <> subjectLabel m <> "." else "Nothing due in " <> subjectLabel m <> ". " <> ms (show exemptCount) <> " more are owed under exemptions: open a group under Exempt below to decide them now, or lift its exemption.")] else paged m here (\n i -> if open i then card m rulesMap n (length here) i else done m rulesMap n (length here) i)
                        , if null gaps then text "" else H.h2_ [P.class_ "section"] [text ("Coverage gaps (" <> ms (show (length gaps)) <> ") -- work, not judgement")]
                        , if null gaps then text "" else gapNote
                        , paged m gaps (\n i -> gapRow m rulesMap n (length gaps) i)
                        , if null shut then text "" else H.h2_ [P.class_ "section"] [text ("Decided before this session (" <> ms (show (length shut)) <> ")")]
                        , paged m shut (\n i -> done m rulesMap n (length shut) i)
                        , if null gone then text "" else H.h2_ [P.class_ "section"] [text ("Not in the current run (" <> ms (show (length gone)) <> ")")]
                        , paged m gone (\n i -> done m rulesMap n (length gone) i)
                        , if exemptCount == 0 then text "" else H.h2_ [P.class_ "section"] [text ("Exempt (" <> ms (show exemptCount) <> ") -- owed, not yet due")]
                        , if exemptCount == 0 then text "" else exemptGroups m rulesMap tabGroups
                        ] ++ (if tab m == AllTab then historyView m p rulesMap else [])
                  )
              ]
          , zoomView m p
          ]

-- | The first page of a list and a button for the next, so a long queue costs what is on screen.
-- Each row is keyed, so a row drawn where another was is drawn afresh and asks for its card.
-- ref:DEC-how-card ref:DEC-light-index
paged :: Model -> [Item] -> (Int -> Item -> View context props Model Action) -> View context props Model Action
paged m xs render =
  let shown = take (limit m) (zip [1 :: Int ..] xs)
      rest = length xs - length shown
   in H.div_
        []
        ([H.div_ [MP.key_ (W.key i)] [render n i] | (n, i) <- shown] ++ [H.div_ [MP.key_ ("more-row" :: Str), P.class_ "more-row"] [H.button_ [E.onClick ShowMore] [text ("show " <> ms (show (min pageSize rest)) <> " more of " <> ms (show rest))]] | rest > 0])

type Rules = Map Str ([Str], [Str])

seedText :: Payload -> Str
seedText p = case W.facts p of
  Just f -> " -- run " <> W.runName f
  _ -> ""

probeBanner :: Model -> Payload -> View context props Model Action
probeBanner m p = case (tab m, W.facts p) of
  (HowTab, Just f)
    | not (null (W.staleFiles f)) ->
        H.div_ [P.class_ "probewarn"] ([H.b_ [] [text (ms (show (length (W.staleFiles f))) <> " file(s) changed since the run that found these mutants.")], text (" Their line numbers point somewhere else now, and the definition around a mutant is not shown for them, because the report and the file would be two different files spliced together. Re-run the mutation. Affected: " <> S.intercalate ", " (W.staleFiles f) <> " ")] ++ mutationButton m p)
    | not (W.corpusOk f) -> H.div_ [P.class_ "probewarn"] [text "The corpus ", H.b_ [] [text "failed"], text " under the probe that produced these readings, so they describe a run that did not pass. Forcing an expression changed an outcome."]
  _ -> text ""

-- | Whether the mutation the page started is still running.
mutationRunning :: Model -> Bool
mutationRunning m = maybe False ((== "running") . W.mutationState) (mutation m)

-- | The button that runs the mutation command canon.yaml names, when it names one; disabled while
-- a run is under way. ref:DEC-mutation-rerun
mutationButton :: Model -> Payload -> [View context props Model Action]
mutationButton m p = case W.facts p of
  Just f | not (S.null (W.command f)) ->
    [H.button_ [P.class_ "mutate", E.onClick RunMutation, P.title_ ("Run `" <> W.command f <> "` and re-read the run when it ends. Decisions made meanwhile carry over to every mutant that is the same; the rest are listed as not in the current run."), disabledIf (mutationRunning m || busy m)] [text (if mutationRunning m then "mutation running…" else "run mutation")]]
  _ -> []

-- | What the mutation is doing: running since when with its last line, or how it failed.
-- ref:DEC-mutation-rerun
mutationBanner :: Model -> View context props Model Action
mutationBanner m = case mutation m of
  Just mu
    | W.mutationState mu == "running" ->
        H.div_ [P.class_ "probewarn"] [H.b_ [] [text "The mutation is running"], text (" since " <> W.mutationSince mu <> ". Keep deciding: when it ends the project is re-read and every decision on a mutant that is the same carries over. " <> lastLine mu)]
    | W.mutationState mu == "failed" ->
        H.div_ [P.class_ "probewarn"] [H.b_ [] [text ("The mutation failed with exit code " <> ms (show (W.mutationExit mu)) <> ".")], text (" The previous run stands. " <> lastLine mu)]
  _ -> text ""
  where
    lastLine mu = case reverse (W.mutationLog mu) of
      (l : _) -> "Last line: " <> l
      [] -> ""

gapNote :: View context props Model Action
gapNote =
  H.p_
    [P.class_ "gapnote"]
    [ text "Nothing about these turns on whether two programs compute the same function. "
    , H.b_ [] [text "Nothing reaches it"]
    , text ": no rule exercises the code, so no test could tell the mutant from the original -- write a rule. "
    , H.b_ [] [text "Only ever X"]
    , text ": the code ran and the condition went one way -- widen a generator. Either way the row is gone after the next run. The same rows sit in the ledger's observability files, as work."
    ]

-- | The control under the switcher: exempt the chosen subject, or the form once opened.
-- ref:DEC-exemptions
exemptControl :: Model -> Int -> [View context props Model Action]
exemptControl m exemptHere = case (chosen m, exemptForm m) of
  (_, Just f) ->
    [ H.div_
        [P.class_ "exemptform"]
        [ H.div_ [P.class_ "lede"] [text ("Exempt " <> formSubject f)]
        , H.input_ [P.placeholder_ "kinds, e.g. mutant, observability", P.title_ "Which kinds the exemption covers; empty means all.", P.value_ (formKinds f), E.onInput (\v -> EditExempt f {formKinds = v})]
        , H.textarea_ [P.placeholder_ "why is this not owed yet?", P.value_ (formWhy f), E.onInput (\v -> EditExempt f {formWhy = v})]
        , H.input_ [P.placeholder_ "revisit by, e.g. 0.2.0", P.title_ "The version by which the exemption comes due; audit fails once the project reaches it.", P.value_ (formRevisit f), E.onInput (\v -> EditExempt f {formRevisit = v})]
        , H.div_ [P.class_ "row"] [H.button_ [E.onClick SubmitExempt, disabledIf (busy m)] [text "Exempt"], H.button_ [E.onClick CancelExempt] [text "Cancel"]]
        ]
    ]
  (Just subj, Nothing)
    | exemptHere > 0 ->
        [H.div_ [P.class_ "exemptrow"] [H.button_ [E.onClick (LiftKinds subj (liftKindsFor (tab m))), P.title_ ("Lift the exemption for " <> subj <> " alone: a wider exemption is narrowed to everything else it covered, so only this subject comes due, its missing comments included."), disabledIf (busy m)] [text ("Lift the exemption for this subject (" <> ms (show exemptHere) <> " rows)")]]]
    | otherwise -> [H.div_ [P.class_ "exemptrow"] [H.button_ [E.onClick (OpenExempt subj), P.title_ "Declare this subject not owed until a version, with a reason. The debt stays counted; audit passes until the version comes."] [text "Exempt this subject…"]]]
  (Nothing, Nothing) -> []

-- | Exempt items grouped by the pattern that covers them, each group with its reason, its
-- revisit version, and a button to lift it. ref:DEC-exemptions
exemptGroups :: Model -> Rules -> [(W.Group Str, Int)] -> View context props Model Action
exemptGroups m rs gs =
  H.div_
        []
        [ H.div_
            []
            ( H.div_
                [P.class_ "done exemptgroup"]
                [ H.div_
                    [P.class_ "summary"]
                    [ H.span_ [P.class_ "verdict gapword"] [text "exempt"]
                    , H.span_ [P.class_ "binding"] [text (W.groupPattern g)]
                    , H.span_ [P.class_ "mid"] [text (ms (show n) <> " rows" <> (if tab m == AllTab then " of " <> W.groupQuestion g else "") <> ", until " <> W.groupUntil g)]
                    , H.span_ [P.class_ "where"] [text (W.groupReason g)]
                    , H.button_ [P.class_ "copy", E.onClickWithOptions stopPropagation (Toggle ("exempt:" <> gk)), P.title_ "Decide these rows now, before the exemption comes due; each verdict is written like any other, and the exemption stays until you lift it."] [text (if reviewing then "Hide" else "Review")]
                    , H.button_ [P.class_ "copy", E.onClickWithOptions stopPropagation (Lift (W.groupPattern g)), P.title_ "Lift the whole exemption: every row it covers becomes due again at once.", disabledIf (busy m)] [text "Lift"]
                    ]
                ]
                : [ case Map.lookup gk (groupRows m) of
                      Nothing -> H.div_ [P.class_ "empty"] [text "Loading the rows of this exemption…"]
                      Just rows -> let is = [i | i <- rows, maybe True (== W.subject i) (chosen m)] in paged m is (\k i -> card m rs k (length is) i)
                  | reviewing
                  ]
            )
        | (g, n) <- gs
        , let gk = W.groupQuestion g <> "\t" <> W.groupPattern g
        , let reviewing = Set.member ("exempt:" <> gk) (expanded m)
        ]

subjectLabel :: Model -> Str
subjectLabel m = fromMaybe "every subject" (chosen m)

tabButton :: Model -> Tab -> View context props Model Action
tabButton m t = H.button_ [E.onClick (Pick t), textProp "aria-current" (if tab m == t then "true" else "false")] [text (tabName t)]

tabName :: Tab -> Str
tabName t = case t of
  WhyTab -> "Why"
  WhatTab -> "What"
  HowTab -> "How"
  AllTab -> "All"

subjectButton :: Model -> Maybe Str -> Str -> Int -> Int -> View context props Model Action
subjectButton m f name n e =
  H.button_
    [E.onClick (Choose f), textProp "aria-current" (if chosen m == f then "true" else "false")]
    ([H.span_ [] [text name], H.span_ [P.classList_ [("n", True), ("zero", n == 0 && e == 0)]] [text (ms (show n))]] ++ [H.span_ [P.class_ "n exemptn", P.title_ "owed under an exemption"] [text ("+" <> ms (show e))] | e > 0])

disabledIf :: Bool -> Attribute Model Action
disabledIf b = boolProp "disabled" b

whereText :: Item -> Str
whereText i = if W.line i > 0 then W.path i <> ":" <> ms (show (W.line i)) else W.path i

shortId :: Item -> Str
shortId i = S.pack (reverse (takeWhile (/= '/') (reverse (S.unpack (W.key i)))))

-- | A card is the Why card, the What card, or wavelet's mutant card, by what the item carries.
-- ref:DEC-how-card ref:DEC-what-queue
card :: Model -> Rules -> Int -> Int -> Item -> View context props Model Action
card m rs n total light = case W.mutant i of
  Just mv -> mutantCard m rs n total i mv
  Nothing
    | not (Map.member (W.key light) (details m)) -> pendingCard n total light
    | W.question i == "What" -> whatCard m n total i
    | otherwise -> whyCard m n total i
  where
    i = Map.findWithDefault light (W.key light) (details m)

-- | A card whose material has not come yet: its bar, and a request for the rest the moment it is
-- drawn; paged keys each row, so a card drawn in another's place asks for its own.
-- ref:DEC-light-index
pendingCard :: Int -> Int -> Item -> View context props Model Action
pendingCard n total i =
  H.div_
    [P.class_ "card", ME.onCreated (Need (W.key i)), textProp "data-state" (W.state i)]
    [ H.div_
        [P.class_ "top"]
        [ H.span_ [P.class_ "ordinal"] [text (ms (show n) <> " of " <> ms (show total))]
        , H.span_ [P.classList_ [("badge", True), (W.state i, True)]] [text (W.state i)]
        , H.span_ [P.class_ "badge kind"] [text (W.kind i)]
        , H.span_ [P.class_ "unit"] [text (W.unit i)]
        , H.span_ [P.class_ "where"] [text (whereText i)]
        ]
    , H.div_ [P.class_ "empty"] [H.button_ [E.onClick (Need (W.key i))] [text "Loading the card…"]]
    ]

-- | The What card: the name and the signature to judge, the body beside them as the second side,
-- and canon's three verdicts. Rule 8 plus signature, judged apart from the comment.
-- ref:DEC-what-queue
whatCard :: Model -> Int -> Int -> Item -> View context props Model Action
whatCard m n total i =
  let d = fromMaybe (Draft (W.note i) (W.revisit i)) (Map.lookup (W.key i) (drafts m))
      k = W.key i
      pressed v = textProp "aria-pressed" (if W.verdict i == v then "true" else "false")
      decideWith v = E.onClick (Decide k v (draftNote d) (draftRevisit d))
   in H.div_
        [P.class_ "card", textProp "data-state" (W.state i)]
        [ H.div_
            [P.class_ "top"]
            [ H.span_ [P.class_ "ordinal"] [text (ms (show n) <> " of " <> ms (show total))]
            , H.span_ [P.classList_ [("badge", True), (W.state i, True)]] [text (W.state i)]
            , H.span_ [P.class_ "badge kind"] [text (W.kind i)]
            , H.span_ [P.class_ "unit"] [text (W.unit i)]
            , H.span_ [P.class_ "mid"] [text (W.unitKind i)]
            , H.span_ [P.class_ "where"] [text (whereText i)]
            ]
        , findingLine m i
        , whatEvidence i
        , H.div_
            [P.class_ "decide"]
            [ H.textarea_
                [ P.placeholder_ "What would say it?"
                , P.title_ "Optional, and worth writing when the verdict is bad: what the name or the signature fails to say, or the name that would say it."
                , P.value_ (draftNote d)
                , E.onInput (EditNote k)
                ]
            , H.input_
                [ P.class_ "revisit"
                , P.placeholder_ "revisit by 0.2.0"
                , P.title_ "The version to revisit a deferred verdict by. canon fails the check once the project reaches it."
                , P.value_ (draftRevisit d)
                , E.onInput (EditRevisit k)
                ]
            , H.button_ [P.class_ "good", pressed "good", decideWith "good", P.title_ "The name and the signature state, in full words, the fact the unit establishes. Rule 8 plus signature, judged apart from the comment.", disabledIf (busy m)] [text "Good"]
            , H.button_ [P.class_ "bad", pressed "bad", decideWith "bad", P.title_ "The name or the signature does not say what the unit establishes. Say what would, in the note; rename or retype until it does.", disabledIf (busy m)] [text "Bad"]
            , H.button_ [P.class_ "deferred", pressed "deferred", decideWith "deferred", P.title_ "Not now. Give the version to revisit by; canon fails the check once the project reaches it.", disabledIf (busy m)] [text "Deferred"]
            ]
        ]

-- | The name and the signature on the left, the body beneath them numbered from its line, and
-- who signed on the right; a What cites nothing.
whatEvidence :: Item -> View context props Model Action
whatEvidence i =
  H.div_
    [P.class_ "split"]
    [ H.div_
        []
        ( [H.h3_ [] [text "The name and the signature"], H.pre_ [P.class_ "prose"] [text (W.text i)]]
            ++ (if null (W.code i) then [] else [H.h3_ [] [text "The body, the second side"], H.pre_ [] (zipWith codeLine [W.codeFrom i ..] (zip (W.code i) (W.marks i ++ repeat "")))])
        )
    , H.div_
        []
        [ H.h3_ [] [text "Signed"]
        , H.p_ [P.class_ "signed"] [text (signedText i)]
        ]
    ]
  where
    codeLine n (l, mk) = H.span_ [] (H.span_ [P.class_ "gutter"] [text (pad (ms (show n)))] : pieceViews mk l)

whyCard :: Model -> Int -> Int -> Item -> View context props Model Action
whyCard m n total i =
  let d = fromMaybe (Draft (W.note i) (W.revisit i)) (Map.lookup (W.key i) (drafts m))
      k = W.key i
      pressed v = textProp "aria-pressed" (if W.verdict i == v then "true" else "false")
      decideWith v = E.onClick (Decide k v (draftNote d) (draftRevisit d))
   in H.div_
        [P.class_ "card", textProp "data-state" (W.state i)]
        [ H.div_
            [P.class_ "top"]
            [ H.span_ [P.class_ "ordinal"] [text (ms (show n) <> " of " <> ms (show total))]
            , H.span_ [P.classList_ [("badge", True), (W.state i, True)]] [text (W.state i)]
            , H.span_ [P.class_ "badge kind"] [text (W.kind i)]
            , H.span_ [P.class_ "unit"] [text (W.unit i)]
            , H.span_ [P.class_ "mid"] [text (W.unitKind i)]
            , H.span_ [P.class_ "where"] [text (whereText i)]
            ]
        , findingLine m i
        , whyEvidence i
        , H.div_
            [P.class_ "decide"]
            [ H.textarea_
                [ P.placeholder_ "Why?"
                , P.title_ "Optional, and worth writing when the verdict is bad or deferred: what is wrong, or what to look at when revisiting."
                , P.value_ (draftNote d)
                , E.onInput (EditNote k)
                ]
            , H.input_
                [ P.class_ "revisit"
                , P.placeholder_ "revisit by 0.2.0"
                , P.title_ "The version to revisit a deferred verdict by. canon fails the check once the project reaches it."
                , P.value_ (draftRevisit d)
                , E.onInput (EditRevisit k)
                ]
            , H.button_ [P.class_ "good", pressed "good", decideWith "good", P.title_ "It says why, and the why holds. Rule 8: a comment that only restates the name is not good.", disabledIf (busy m)] [text "Good"]
            , H.button_ [P.class_ "bad", pressed "bad", decideWith "bad", P.title_ "It fulfils no purpose the name does not, or what it says is not so. Say what is wrong in the note; the comment changes until it is good.", disabledIf (busy m)] [text "Bad"]
            , H.button_ [P.class_ "deferred", pressed "deferred", decideWith "deferred", P.title_ "Not now. Give the version to revisit by; canon fails the check once the project reaches it.", disabledIf (busy m)] [text "Deferred"]
            ]
        ]

whyEvidence :: Item -> View context props Model Action
whyEvidence i =
  H.div_
    [P.class_ "split"]
    [ H.div_
        []
        ( [H.h3_ [] [text (leftTitle i)]]
            ++ [if null (W.code i) then H.pre_ [P.class_ "prose"] [text (W.text i)] else H.pre_ [] (zipWith codeLine [W.codeFrom i ..] (zip3 [0 :: Int ..] (W.code i) (W.marks i ++ repeat "")))]
            ++ (if S.null (W.answer i) then [] else [H.h3_ [] [text "The answer"], H.pre_ [P.class_ "prose"] [text (W.answer i)]])
        )
    , H.div_
        []
        [ H.h3_ [] [text "What it cites"]
        , if null (W.refs i)
            then H.p_ [P.class_ "none"] [text "Cites nothing."]
            else
              H.div_
                []
                [ H.div_
                    [P.class_ "cited"]
                    ( [H.div_ [P.class_ "chips"] [H.span_ [P.class_ "chip", P.title_ (W.refLocator r)] [text (W.refKey r)], H.span_ [P.class_ "reftitle"] [text (W.refKind r <> ": " <> W.refTitle r)]]]
                        ++ (if S.null (W.refAnswer r) then [] else [H.div_ [P.class_ "refanswer"] [text (W.refAnswer r)]])
                    )
                | r <- W.refs i
                ]
        , H.h3_ [] [text "Signed"]
        , H.p_ [P.class_ "signed"] [text (signedText i)]
        ]
    ]
  where
    codeLine n (k, l, mk) =
      H.span_
        [P.classList_ [("why", k < W.commentLines i)]]
        (H.span_ [P.class_ "gutter"] [text (pad (ms (show n)))] : pieceViews mk l)

-- | What canon check says of the row, in its own words, and the exemption over it when one is;
-- a row decided on this page since the project was read has no finding until it is read again.
-- ref:DEC-canon-lockstep
findingLine :: Model -> Item -> View context props Model Action
findingLine m i =
  H.div_
    [P.class_ "finding"]
    ( [H.span_ [P.class_ "lede"] [text "canon "], text (Map.findWithDefault "reports nothing on this row" (W.key i) (findings m))]
        ++ [H.span_ [P.class_ "exemptnote"] [text (" -- owed under " <> W.exempt i <> " until " <> W.exemptUntil i)] | not (S.null (W.exempt i))]
    )

pad :: Str -> Str
pad s = S.pack (replicate (max 0 (4 - length (S.unpack s))) ' ') <> s <> "  "

leftTitle :: Item -> Str
leftTitle i = case W.kind i of
  "comment" -> "The comment, and the code it explains"
  "ledger" -> "The question"
  "registry" -> "The reference"
  "name" -> "The name and the signature"
  _ -> "The material"

signedText :: Item -> Str
signedText i = case W.signer i of
  Just s -> W.signerName s <> " in " <> W.signedIn s <> (if null (W.coAuthors s) then "" else " with " <> S.intercalate ", " (W.coAuthors s))
  Nothing
    | W.verdict i `elem` ["pending", "unreviewed", "gap"] -> "Nobody yet."
    | otherwise -> "Saved locally · not committed."

-- | wavelet's card for a surviving mutant: the change and the code around it, what looked and
-- missed, what the probe recorded, and the four verdicts with their tooltips. ref:DEC-how-card
mutantCard :: Model -> Rules -> Int -> Int -> Item -> Mut -> View context props Model Action
mutantCard m rs n total i mv =
  let d = fromMaybe (Draft (W.note i) "") (Map.lookup (W.key i) (drafts m))
      k = W.key i
      pressed v = textProp "aria-pressed" (if W.verdict i == v then "true" else "false")
      decideWith v = E.onClick (Decide k v (draftNote d) "")
   in H.div_
        [P.class_ "card", textProp "data-state" (W.state i)]
        [ mutantTop m n total i mv
        , mutantEvidence rs i mv
        , H.div_
            [P.class_ "decide"]
            [ H.textarea_
                [ P.placeholder_ "Why?"
                , P.title_ "Optional, and worth writing: for a logical equivalency the argument is the entire content of the claim."
                , P.value_ (draftNote d)
                , E.onInput (EditNote k)
                ]
            , H.button_ [P.class_ "eq", pressed "logical-equivalency", decideWith "logical-equivalency", P.title_ "It computes the same function, so no test could ever kill it. This is the claim Rice's theorem reserves for a person: write the argument.", disabledIf (busy m)] [text "Logical Equivalency"]
            , H.button_ [P.class_ "bad", pressed "inadequate-testing", decideWith "inadequate-testing", P.title_ ("The effect matters and nothing checks it. The tests of " <> W.subject i <> " must improve until this mutant dies."), disabledIf (busy m)] [text "Inadequate Testing"]
            , H.button_ [P.class_ "dead", pressed "unnecessary-code", decideWith "unnecessary-code", P.title_ "There is no effect worth watching, so the code should go. A surviving mutant is evidence of code with no observable effect.", disabledIf (busy m)] [text "Unnecessary Code"]
            , H.button_ [P.class_ "ask", pressed "needs-research", decideWith "needs-research", P.title_ "You looked and cannot yet say. This is not a decision: it stays outstanding, and the note is what to find out.", disabledIf (busy m)] [text "Need To Research"]
            ]
        ]

mutantTop :: Model -> Int -> Int -> Item -> Mut -> View context props Model Action
mutantTop m n total i mv =
  H.div_
    [P.class_ "top"]
    ( [ H.span_ [P.class_ "ordinal"] [text (ms (show n) <> " of " <> ms (show total))]
      , H.span_ [P.classList_ [("badge", True), (W.outcome mv, True)]] [text (W.outcome mv)]
      ]
        ++ [H.span_ [P.class_ "badge Stale", P.title_ "the definition changed since this verdict"] [text "stale"] | W.state i == "stale"]
        ++ [H.span_ [P.class_ "badge stalefile", P.title_ "the file changed since the run"] [text "file changed"] | W.staleFile mv]
        ++ [ H.span_ [P.class_ "binding"] [text (W.unit i)]
           , H.span_ [P.class_ "mid"] [text (W.operator mv)]
           , H.span_ [P.class_ "mid"] [text (shortId i)]
           , H.span_ [P.class_ "where"] [text (whereText i)]
           , copyButton m i
           ]
    )

mutantEvidence :: Rules -> Item -> Mut -> View context props Model Action
mutantEvidence rs i mv =
  H.div_
    [P.class_ "split"]
    [ H.div_
        []
        [ H.h3_ [] [text "The code, and the mutant of it", H.button_ [P.class_ "more", P.title_ "show more, larger", E.onClick (OpenZoom (W.key i) ZoomCode)] [text "+"]]
        , diffView mv
        ]
    , H.div_
        []
        ( [H.h3_ [] [text "Test evidence", H.button_ [P.class_ "more", P.title_ "show more, larger", E.onClick (OpenZoom (W.key i) ZoomTests)] [text "+"]]]
            ++ testsView rs mv
            ++ recordedPanel mv
            ++ [H.h3_ [] [text "Signed"], H.p_ [P.class_ "signed"] [text (signedText i)]]
        )
    ]

-- | The diff as wavelet draws it: context, the source lines marked minus, the mutant's lines
-- marked plus with the same numbers, and the changed run highlighted. ref:DEC-how-card
diffView :: Mut -> View context props Model Action
diffView mv =
  let from = W.fromLine mv
      beforeN = length (W.before mv)
   in H.pre_
        []
        ( [plainLine n mk l | (n, l, mk) <- zip3 [from - beforeN ..] (W.before mv) (W.beforeMarks mv ++ repeat "")]
            ++ editViews (withMarks (W.sourceMarks mv) (W.mutatedMarks mv) (lineDiff from (W.source mv) (W.mutated mv)))
            ++ [plainLine n mk l | (n, l, mk) <- zip3 [W.toLine mv + 1 ..] (W.after mv) (W.afterMarks mv ++ repeat "")]
        )

-- | Each edit with the marks of its line: a kept or gone line's from the source side, a come
-- line's from the mutant side, counted along each side in turn. ref:DEC-highlighting
withMarks :: [Str] -> [Str] -> [Edit Str] -> [(Edit Str, Str)]
withMarks srcMarks mutMarks = go (srcMarks ++ repeat "") (mutMarks ++ repeat "")
  where
    go _ _ [] = []
    go (s : ss) (m : ms') (e : rest) = case e of
      Kept _ _ -> (e, s) : go ss ms' rest
      Gone _ _ -> (e, s) : go ss (m : ms') rest
      Came _ _ -> (e, m) : go (s : ss) ms' rest
    go _ _ _ = []

-- | The pieces of a line from its marks, each in a span of its class; plain runs are bare text.
-- ref:DEC-highlighting
pieceViews :: Str -> Str -> [View context props Model Action]
pieceViews mk line = piecesOf (padRuns (length s) (parseRuns (S.unpack mk))) s
  where
    s = S.unpack line

-- | The pieces of a string under some runs.
piecesOf :: [Run] -> String -> [View context props Model Action]
piecesOf runs s = case runs of
  [] -> [text (S.pack s) | not (null s)]
  ((c, n) : rest) ->
    let (chunk, more) = splitAt n s
     in (if c == 'p' then text (S.pack chunk) else H.span_ [P.class_ (S.pack (classWord c))] [text (S.pack chunk)]) : piecesOf rest more

-- | A context line of a diff.
plainLine :: Int -> Str -> Str -> View context props Model Action
plainLine n mk l = H.span_ [] (H.span_ [P.class_ "gutter"] [text (gutterText n " ")] : pieceViews mk l)

-- | A marked line of a diff, its content in pieces so a changed run can be tinted.
markedLine :: Str -> Str -> Int -> [View context props Model Action] -> View context props Model Action
markedLine cls mark n bits = H.span_ [P.class_ cls] (H.span_ [P.class_ "gutter mark"] [text (gutterText n mark)] : bits)

gutterText :: Int -> Str -> Str
gutterText n mark = S.pack (replicate (max 0 (4 - length (show n))) ' ') <> ms (show n) <> " " <> mark <> "  "

-- | The edits of a line diff rendered: shared lines as context, gone and come lines marked, and
-- where exactly one line went and one came the run within it tinted. ref:DEC-line-diff
editViews :: [(Edit Str, Str)] -> [View context props Model Action]
editViews edits = case edits of
  [] -> []
  (Gone n a, ma) : (Came m b, mb) : rest | not (isChange rest) ->
    let (srcBits, mutBits) = changedRuns (a, ma) (b, mb)
     in [markedLine "from" "-" n srcBits, markedLine "to" "+" m mutBits] ++ editViews rest
  (Kept n l, mk) : rest -> plainLine n mk l : editViews rest
  (Gone n l, mk) : rest -> markedLine "from" "-" n (pieceViews mk l) : editViews rest
  (Came n l, mk) : rest -> markedLine "to" "+" n (pieceViews mk l) : editViews rest
  where
    isChange rest = case rest of
      (Gone _ _, _) : _ -> True
      (Came _ _, _) : _ -> True
      _ -> False

-- | The common prefix and suffix of one source line and one mutant line, so only the run that
-- changed is tinted; several lines are marked whole. ref:DEC-how-card
changedRuns :: (Str, Str) -> (Str, Str) -> ([View context props Model Action], [View context props Model Action])
changedRuns (a, ma) (b, mb) =
  let sa = S.unpack a
      sb = S.unpack b
      pre = length (takeWhile id (zipWith (==) sa sb))
      rest = min (length sa) (length sb) - pre
      suf = length (takeWhile id (zipWith (==) (reverse (drop pre sa)) (reverse (drop pre sb))))
      suf' = min suf rest
      -- The runs are cut where the text is, so the tinted run keeps its colours.
      cut s mk =
        let runs = padRuns (length s) (parseRuns (S.unpack mk))
            midLen = length s - pre - suf'
            (p, r) = splitAt pre s
            (mid, q) = splitAt midLen r
            (runsP, runsR) = cutRuns pre runs
            (runsMid, runsQ) = cutRuns midLen runsR
         in piecesOf runsP p ++ (if null (dropWhile (== ' ') mid) then piecesOf runsMid mid else [H.span_ [P.class_ "bit"] (piecesOf runsMid mid)]) ++ piecesOf runsQ q
   in (cut sa ma, cut sb mb)

testsView :: Rules -> Mut -> [View context props Model Action]
testsView rs mv
  | null (W.covering mv) = [H.p_ [P.class_ "none"] [text (coverageMessage mv)]]
  | otherwise =
      [ H.div_
          [P.class_ "rule"]
          [ H.div_ [P.class_ "chips"] [H.span_ [P.class_ "chip"] [text r]]
          , ruleSourceView (Map.findWithDefault ([], []) r rs)
          ]
      | r <- W.covering mv
      ]

ruleSourceView :: ([Str], [Str]) -> View context props Model Action
ruleSourceView (src, marks)
  | null src = H.p_ [P.class_ "none"] [text "source not found"]
  | otherwise = H.pre_ [] [H.span_ [] (pieceViews mk l) | (l, mk) <- zip src (marks ++ repeat "")]

-- | What the probe recorded, with wavelet's caveats word for word, or why it could not.
-- ref:DEC-how-card
recordedPanel :: Mut -> [View context props Model Action]
recordedPanel mv = case W.observed mv of
  Nothing -> []
  Just o
    | W.obsStatus o /= "read" -> [H.p_ [P.class_ "caveat"] [text (probeStatusText (W.obsStatus o))]]
    | otherwise ->
        [ reading (W.sided mv)
        , H.div_
            [P.class_ "expr here"]
            ( [H.h4_ [] ([text (ms (show (W.obsTotal o)) <> " sampled evaluations")] ++ [H.span_ [P.class_ "flat"] [text " - one value only"] | W.obsTotal o > 0, length (W.obsDistinct o) == 1])]
                ++ [countsTable (W.obsDistinct o)]
                ++ concat [[H.div_ [P.class_ "var"] [text (W.boundName b)], countsTable (W.boundValues b)] | b <- W.obsBound o]
            )
        , H.p_ [P.class_ "caveat"] [text "Recorded by the run, from the first 4000 evaluations of each site. This is what the corpus happened to produce, not a proof."]
        ]
  where
    reading s = case s of
      "EveryDecisionConstant" -> H.p_ [P.class_ "reading EveryDecisionConstant"] [H.b_ [] [text "Every decision in this binding took one value."], text " Nothing the corpus generated ever reached a rejecting path here, so this is not a gap at one expression: the generator only ever produced input this binding was meant to accept. The repair is a rule that tests rejection, not a wider generator."]
      "SomeDecisionsVary" -> H.p_ [P.class_ "reading SomeDecisionsVary"] [H.b_ [] [text "Other decisions in this binding did vary."], text " So the corpus does produce input this binding rejects, and any expression below that took a single value is a gap at that expression -- the generator reaches this code both ways, and just not through here."]
      _ -> H.p_ [P.class_ "reading"] [text "Nothing in this binding was evaluated at all, so there is no reading either way."]
    countsTable cs = H.table_ [] [H.tr_ [] [H.td_ [P.class_ "n"] [text (ms (show (W.count c)))], H.td_ [] [text (W.value c)]] | c <- take 8 cs]

-- | The whole block as text, in the order the card shows it, so a person can paste one mutant
-- somewhere else and analyse it bit by bit. ref:DEC-how-card
mutationReport :: Payload -> Item -> W.Whole Str -> Str
mutationReport p i w = case W.mutant i of
  Nothing -> ""
  Just mv ->
    let rs = Map.fromList [(W.ruleName r, W.ruleSource r) | r <- W.rules p]
        line n = S.pack (replicate (max 0 (4 - length (show n))) ' ') <> ms (show n)
        gutter n mark l = line n <> " " <> mark <> "  " <> l
        beforeN = length (W.before mv)
        edits = lineDiff (W.fromLine mv) (W.source mv) (W.mutated mv)
        gone = goneLines edits
        diffLines =
          [gutter n " " l | (n, l) <- zip [W.fromLine mv - beforeN ..] (W.before mv)]
            ++ [ case e of
                   Kept n l -> gutter n " " l
                   Gone n l -> gutter n "-" l
                   Came n l -> gutter n "+" l
               | e <- edits
               ]
            ++ [gutter n " " l | (n, l) <- zip [W.toLine mv + 1 ..] (W.after mv)]
        ruleBlock r = ["rule " <> r] ++ (let src = Map.findWithDefault [] r rs in if null src then ["  (source not found)"] else map ("  " <>) src) ++ [""]
        probe = case W.observed mv of
          Nothing -> ["Not instrumented: the probe recorded nothing at this site."]
          Just o
            | W.obsStatus o /= "read" -> [probeStatusText (W.obsStatus o)]
            | otherwise ->
                [sidedText (W.sided mv), ""]
                  ++ [ms (show (W.obsTotal o)) <> " sampled evaluations" <> (if length (W.obsDistinct o) == 1 then " - one value only" else "")]
                  ++ ["  " <> S.pack (replicate (max 0 (7 - length (show (W.count c)))) ' ') <> ms (show (W.count c)) <> "  " <> W.value c | c <- take 8 (W.obsDistinct o)]
                  ++ concat [["  " <> W.boundName b] ++ ["    " <> ms (show (W.count c)) <> "  " <> W.value c | c <- take 8 (W.boundValues b)] | b <- W.obsBound o]
                  ++ ["", "Recorded by the run, from the first 4000 evaluations of each site. This is what the corpus happened to produce, not a proof."]
        run = case W.facts p of
          Just f -> W.runName f
          Nothing -> ""
        header =
          [ "Rice's Tax -- mutant " <> shortId i <> " (" <> W.outcome mv <> (if S.null (W.gap mv) then "" else ", coverage gap: " <> W.gap mv) <> ")"
          , "project: " <> W.project p <> (if S.null run then "" else "    run: " <> run)
          , "file: " <> whereText i <> "    binding: " <> W.unit i <> (if S.null (W.unitKind i) then "" else " (" <> W.unitKind i <> ")") <> "    operator: " <> W.operator mv
          , "change: `" <> W.was mv <> "` becomes `" <> W.became mv <> "`"
          , "verdict: " <> W.verdict i <> (if S.null (W.note i) then "" else "    note: " <> W.note i) <> (if S.null (W.run i) then "" else "    decided against run: " <> W.run i)
          , "ledger: " <> W.file i <> "    key: " <> W.key i
          ]
        whole = if null (W.wholeLines w) then ["(the definition could not be read: the file changed since the run)"] else [gutter n (if n `elem` gone then "-" else " ") l | (n, l) <- zip [W.wholeStart w ..] (W.wholeLines w)]
     in S.intercalate
          "\n"
          ( header
              ++ ["", "## The code, and the mutant of it", ""]
              ++ diffLines
              ++ ["", "## Test evidence", ""]
              ++ (if null (W.covering mv) then [coverageMessage mv] else concatMap ruleBlock (W.covering mv))
              ++ ["## What the probe recorded", ""]
              ++ probe
              ++ ["", "## The whole definition of " <> W.unit i <> " (mutated lines marked -)", ""]
              ++ whole
              ++ [""]
          )

probeStatusText :: Str -> Str
probeStatusText s = case s of
  "never-evaluated" -> "Instrumented, and nothing in the corpus ever evaluated it."
  "not-an-expression" -> "Not observable: the mutated span is not an expression on one line."
  "nested" -> "Not observed on its own: it sits inside another observed expression."
  "same-expression" -> "Another mutant sits on this same expression and carries its reading."
  "source-moved" -> "Not observed: this file changed after the run that found the mutant."
  "the-probe-itself" -> "Not observed: the probe cannot instrument its own module."
  "no-show" -> "Not observable: the value here has no Show instance."
  "polymorphic" -> "Not observed: the binding is polymorphic, so its values have no one Show."
  other -> "Not observed: " <> other <> "."

sidedText :: Str -> Str
sidedText s = case s of
  "EveryDecisionConstant" -> "Every decision in this binding took one value. Nothing the corpus generated ever reached a rejecting path here, so this is not a gap at one expression: the generator only ever produced input this binding was meant to accept. The repair is a rule that tests rejection, not a wider generator."
  "SomeDecisionsVary" -> "Other decisions in this binding did vary. So the corpus does produce input this binding rejects, and any expression below that took a single value is a gap at that expression -- the generator reaches this code both ways, and just not through here."
  _ -> "Nothing in this binding was evaluated at all, so there is no reading either way."

-- | The copy button, which says it copied for a moment and then says what it is again.
-- ref:DEC-how-card
copyButton :: Model -> Item -> View context props Model Action
copyButton m i =
  let done' = copied m == Just (W.key i)
   in H.button_
        [ P.classList_ [("copy", True), ("copied", done')]
        , P.title_ "Copy this whole block as text: the change with its code, what looked and missed with their sources, what the probe recorded, and the whole definition."
        , E.onClickWithOptions stopPropagation (Copy (W.key i))
        ]
        [text (if done' then "Copied" else "Copy mutation")]

verdictLabel :: Str -> Str
verdictLabel v = case v of
  "logical-equivalency" -> "Logical Equivalency"
  "inadequate-testing" -> "Inadequate Testing"
  "unnecessary-code" -> "Unnecessary Code"
  "needs-research" -> "Need To Research"
  other -> other

-- | A decided row, collapsed, for either queue; a mutant reopens to unreviewed and a comment to
-- pending. ref:DEC-how-card
done :: Model -> Rules -> Int -> Int -> Item -> View context props Model Action
done m rs n total light =
  let i = Map.findWithDefault light (W.key light) (details m) in doneRow m rs n total i

doneRow :: Model -> Rules -> Int -> Int -> Item -> View context props Model Action
doneRow m rs n total i =
  let reopenWord = if isJust (W.mutant i) then "unreviewed" else "pending"
      isOpen = Set.member (W.key i) (expanded m)
   in H.div_
        [P.classList_ [("done", True), (W.state i, True), ("open", isOpen)]]
        ( [ H.div_
              [P.class_ "summary", E.onClick (Toggle (W.key i))]
              ( [ H.span_ [P.class_ "ordinal"] [text (ms (show n) <> " of " <> ms (show total))]
                , H.span_ [P.classList_ [("verdict", True), (W.state i, True)]] [text (verdictLabel (W.state i))]
                ]
                  ++ [H.span_ [P.class_ "stamp undescribed"] [text "no description"] | isJust (W.mutant i), S.null (W.note i)]
                  ++ [H.span_ [P.class_ "badge kind"] [text (W.kind i)] | not (isJust (W.mutant i))]
                  ++ [H.span_ [P.class_ "unit"] [text (W.unit i)]]
                  ++ maybe [] (\mv -> [H.span_ [P.class_ "mid"] [text (W.operator mv)], H.span_ [P.class_ "mid"] [text (shortId i)]]) (W.mutant i)
                  ++ [H.span_ [P.class_ "badge Stale"] [text "stale"] | W.state i == "stale"]
                  ++ [H.span_ [P.class_ "where"] [text (whereText i)]]
                  ++ [copyButton m i | isJust (W.mutant i)]
              )
          ]
            ++ ( if not isOpen
                   then []
                   else
                     [ H.div_ [P.class_ "argument"] [text (if S.null (W.note i) then (if isJust (W.mutant i) then "No description was given." else "No note was given.") else W.note i)]
                     , if S.null (W.revisit i) then text "" else H.div_ [P.class_ "argument"] [text ("Revisit by " <> W.revisit i <> ".")]
                     , H.p_ [P.class_ "signed"] [text (if isGone i then W.text i else signedText i)]
                     , if S.null (W.run i) then text "" else H.p_ [P.class_ "signed"] [text ("Decided against run " <> W.run i <> ".")]
                     , maybe (if W.question i == "What" then whatEvidence i else whyEvidence i) (mutantEvidence rs i) (W.mutant i)
                     ]
                       ++ [H.div_ [P.class_ "reopen"] [H.button_ [E.onClick (Decide (W.key i) reopenWord "" ""), P.title_ "Back to undecided, so it counts again.", disabledIf (busy m)] [text "Reopen"]] | not (isGone i)]
               )
        )

-- | A coverage gap is work and not a judgement, so its row has the evidence and no decide bar.
-- ref:DEC-work-items
gapRow :: Model -> Rules -> Int -> Int -> Item -> View context props Model Action
gapRow m rs n total i = case W.mutant i of
  Nothing -> text ""
  Just mv ->
    let isOpen = Set.member (W.key i) (expanded m)
     in H.div_
          [P.classList_ [("done", True), ("gap", True), ("open", isOpen)]]
          ( [ H.div_
                [P.class_ "summary", E.onClick (Toggle (W.key i))]
                [ H.span_ [P.class_ "ordinal"] [text (ms (show n) <> " of " <> ms (show total))]
                , H.span_ [P.class_ "verdict gapword"] [text (W.gap mv)]
                , H.span_ [P.class_ "binding"] [text (W.unit i)]
                , H.span_ [P.class_ "mid"] [text (W.was mv)]
                , H.span_ [P.class_ "where"] [text (whereText i)]
                , copyButton m i
                ]
            ]
              ++ [mutantEvidence rs i mv | isOpen]
          )

-- | The zoom over one card: the whole definition with the mutant's lines marked, or every rule
-- that looked, larger. ref:DEC-how-card
zoomView :: Model -> Payload -> View context props Model Action
zoomView m p = case zoom m of
  Nothing -> text ""
  Just (k, z) -> case [i | i <- W.items p, W.key i == k, isJust (W.mutant i)] of
    (i : _) | Just mv <- W.mutant i ->
      H.div_
        [P.class_ "zoomback", E.onClick CloseZoom]
        [ H.div_
            [P.class_ "zoom"]
            [ H.div_ [P.class_ "zoomhead"] [H.span_ [P.class_ "zoomtitle"] [text (zoomTitle i mv z)], H.button_ [E.onClick CloseZoom] [text "close"]]
            , H.div_ [P.class_ "zoombody"] (zoomBody mv z)
            ]
        ]
    _ -> text ""
  where
    rs = Map.fromList [(W.ruleName r, (W.ruleSource r, W.ruleMarks r)) | r <- W.rules p]
    zoomBody mv z = case z of
      ZoomCode -> [maybe (H.p_ [P.class_ "none"] [text "Reading the definition…"]) (wholeView mv) (zoomWhole m)]
      ZoomTests
        | null (W.covering mv) -> [H.p_ [P.class_ "none"] [text (coverageMessage mv)]]
        | otherwise -> concat [[H.h4_ [] [text r], ruleSourceView (Map.findWithDefault ([], []) r rs)] | r <- W.covering mv]

zoomTitle :: Item -> Mut -> Zoom -> Str
zoomTitle i _ z = case z of
  ZoomCode -> W.unit i <> "  --  " <> whereText i
  ZoomTests -> "test evidence for " <> W.unit i

-- | The whole definition, with the mutant's lines marked as in the card; when the file has
-- changed since the run there is no definition to show, only the report's own lines.
wholeView :: Mut -> W.Whole Str -> View context props Model Action
wholeView mv w
  | null (W.wholeLines w) = diffView mv
  | otherwise =
      let from = W.wholeStart w
          numbered = zip3 [from ..] (W.wholeLines w) (W.wholeMarks w ++ repeat "")
          beforeLines = [(n, l, mk) | (n, l, mk) <- numbered, n < W.fromLine mv]
          afterLines = [(n, l, mk) | (n, l, mk) <- numbered, n > W.toLine mv]
       in H.pre_
            []
            ( [plainLine n mk l | (n, l, mk) <- beforeLines]
                ++ editViews (withMarks (W.sourceMarks mv) (W.mutatedMarks mv) (lineDiff (W.fromLine mv) (W.source mv) (W.mutated mv)))
                ++ [plainLine n mk l | (n, l, mk) <- afterLines]
            )


-- | Keep a human judgement separate from the latest observed outcome and history.
-- ref:DEC-verdict-carry-over
lifeNeedsAttention :: W.Lifecycle Str -> Bool
lifeNeedsAttention l = W.lifeStatus l `notElem` ["resolved", "decided", "reclassified"]

historyView :: Model -> Payload -> Rules -> [View context props Model Action]
historyView m p rs =
  let mine = [l | l <- W.lifecycle p, maybe True (== W.subject (W.lifeItem l)) (chosen m)]
      active = [l | l <- mine, not (W.lifeArchived l)]
      attention = filter lifeNeedsAttention active
      decisions = filter (not . lifeNeedsAttention) active
      history = filter W.lifeArchived mine
      selected = case reviewView m of "decisions" -> decisions; "history" -> history; _ -> attention
      matching = [l | l <- selected, reviewView m /= "history" || S.null (historySearch m) || S.toLower (historySearch m) `S.isInfixOf` S.toLower (W.lifeKey l <> " " <> W.path (W.lifeItem l) <> " " <> W.verdict (W.lifeItem l) <> " " <> maybe "" W.operator (W.mutant (W.lifeItem l)))]
      resolved = [W.lifeKey l | l <- decisions, W.lifeStatus l == "resolved", W.verdict (W.lifeItem l) `notElem` ["pending", "unreviewed", "gap"]]
      unsafe = mutationRunning m || maybe False ((== "failed") . W.mutationState) (mutation m) || not (S.null (W.runIssue p))
      title = case reviewView m of "decisions" -> "Decisions"; "history" -> "History"; _ -> "Needs attention"
      tabV v label count = H.button_ [E.onClick (PickReview v), textProp "aria-current" (if reviewView m == v then "true" else "false")] [text (label <> " (" <> ms (show count) <> ")")]
   in [ H.section_ [P.class_ "history-run"]
          [ H.h2_ [] [text (if unsafe then "Verification needed" else if isJust (W.facts p) then "Latest completed run" else "No current run available")]
          , H.p_ [] [text (W.runIssue p)]
          , case W.facts p of
              Nothing -> H.p_ [] [text "Load or run the configured mutation report before drawing conclusions."]
              Just f -> H.div_ [] [H.p_ [] [text ("Project run: " <> W.runName f)], H.p_ [P.class_ "history-meta"] [text (S.intercalate " · " [k <> ": " <> v | (k,v) <- W.factList f, k `elem` ["date", "controls", "mutants", "killed", "survived", "scope", "source-check"]])]]
          ]
      , H.nav_ [P.class_ "tabs history-tabs", textProp "aria-label" "Decision views"] [tabV "attention" "Needs attention" (length attention), tabV "decisions" "Decisions" (length decisions), tabV "history" "History" (length history)]
      , H.div_ [P.class_ "history-heading"] [H.h2_ [] [text title], if reviewView m == "decisions" && not (null resolved) then H.button_ [E.onClick (ChangeHistory "archive" resolved), disabledIf (busy m || unsafe)] [text ("Archive resolved decisions (" <> ms (show (length resolved)) <> ")")] else text ""]
      , if S.null (historyNotice m) then text "" else H.div_ [P.class_ "history-notice", textProp "role" "status", textProp "aria-live" "polite"] ([text (historyNotice m)] ++ [H.button_ [E.onClick (ChangeHistory a ks), disabledIf (busy m || unsafe)] [text "Undo"] | Just (a,ks) <- [undoHistory m]])
      , if reviewView m == "history" then H.input_ [P.type_ "search", P.class_ "history-search", textProp "aria-label" "Search history", P.placeholder_ "Search mutation, file, or verdict", P.value_ (historySearch m), E.onInput SearchHistory] else text ""
      , if null selected then H.div_ [P.class_ "empty"] [H.h3_ [] [text (if reviewView m == "attention" then if unsafe || not (isJust (W.facts p)) then "Run verification is needed" else "No decisions needed in this subject" else "No decisions in this view")], H.p_ [] [text "Review progress applies to the recorded mutation catalog. It does not establish coverage outside that catalog."]] else text ""
      , if reviewView m == "attention" && not (null resolved) then H.div_ [P.class_ "history-callout"] [text (ms (show (length resolved)) <> " earlier decisions are now resolved. Your original verdicts are preserved."), H.button_ [E.onClick (PickReview "decisions")] [text "Review resolved decisions"]] else text ""
      , if not (null selected) && null matching then H.p_ [] [text "No matching decisions."] else text ""
      , H.div_ [] [historyCard m p rs unsafe l | l <- take (limit m) matching]
      , if length matching > limit m then H.button_ [E.onClick ShowMore] [text "Show more"] else text ""
      , H.p_ [P.class_ "history-meta"] [text "Archiving changes visibility. It preserves the verdict and evidence and does not make the audit pass."]
      ]

historyCard :: Model -> Payload -> Rules -> Bool -> W.Lifecycle Str -> View context props Model Action
historyCard m _ rs unsafe l =
  let i = W.lifeItem l
      k = W.lifeKey l
      status = W.lifeStatus l
      label = case status of
        "resolved" -> "Resolved · now killed"
        "absent" -> "Absent · unverified"
        "unverified" -> "Verification needed"
        "changed" -> "Review again · source changed"
        "work" -> if null (W.lifeEvents l) then "Testing or code changes needed" else "Returned to attention"
        "reclassified" -> "Reclassified · see current obligation"
        "decided" -> "Survived · decision recorded"
        _ -> "Needs review"
      action a title = H.button_ [E.onClick (ChangeHistory a [k]), disabledIf (busy m || unsafe)] [text title]
      canJudge = status `elem` ["review", "changed", "work", "decided"] && not (W.lifeArchived l)
   in H.article_ [P.class_ "history-card"]
        [ H.div_ [P.class_ "history-heading"]
            [ H.div_ [] [H.h3_ [] [text (maybe (W.unit i) W.operator (W.mutant i))], H.span_ [P.class_ ("badge " <> if status == "resolved" then "history-resolved" else "history-unverified")] [text (if W.lifeArchived l then "Archived · " <> label else label)]]
            , if W.lifeArchived l then action "restore" "Restore decision" else if status == "resolved" && W.verdict i `notElem` ["unreviewed", "pending", "gap"] then action "archive" "Archive decision" else if status `elem` ["absent", "reclassified"] then H.button_ [E.onClick (Retire k), disabledIf (busy m || unsafe)] [text "Retire decision…"] else text ""
            ]
        , H.p_ [] [text ("Earlier decision: " <> W.verdict i)]
        , H.p_ [P.class_ "history-meta"] [text (W.path i)]
        , H.p_ [] [text (W.lifeMessage l)]
        , if retiring m == Just k then H.div_ [P.class_ "history-retire"]
            [ H.p_ [] [text "Retirement records an intentional scope change, not a kill. The reason and original decision stay in History."]
            , H.input_ [P.placeholder_ "Why is this mutation no longer applicable?", textProp "aria-label" "Retirement reason", P.value_ (retirementReason m), E.onInput RetirementReason]
            , H.button_ [E.onClick (ChangeHistory "retire" [k]), disabledIf (busy m || unsafe || S.null (S.strip (retirementReason m)))] [text "Retire with reason"]
            , H.button_ [E.onClick CancelRetirement] [text "Cancel"]
            ] else text ""
        , H.details_ []
            [ H.summary_ [] [text "Decision and run evidence"]
            , H.p_ [] [text ("Identity: " <> k)]
            , H.p_ [] [text ("Decided against run: " <> W.run i)]
            , H.p_ [] [text (if S.null (W.note i) then "No note recorded." else W.note i)]
            , H.p_ [] [text (signedText i)]
            , maybe (H.p_ [] [text "No retained mutation source is available for this older decision."]) (mutantEvidence rs i) (W.mutant i)
            , H.h3_ [] [text "Lifecycle history"]
            , H.div_ [] [H.details_ [] [H.summary_ [] [text (W.eventTime e <> " · " <> W.eventAction e <> " · " <> W.eventReason e)], H.p_ [] [text ("Evidence run: " <> maybe "unavailable" W.runName (W.eventFacts e))], H.p_ [] [text ("Recorded verdict: " <> W.verdict (W.eventSnapshot e))], H.pre_ [] [text (W.text (W.eventSnapshot e))]] | e <- reverse (W.lifeEvents l)]
            ]
        , if canJudge then H.details_ [] [H.summary_ [] [text "Review or revise decision"], card m rs 1 1 i] else text ""
        ]

-- | Missing per-rule coverage is not evidence that nothing executed.
-- ref:DEC-how-card
coverageMessage :: Mut -> Str
coverageMessage mv = case W.outcome mv of
  "Killed" -> "The run killed this mutation. The driver supplied no per-rule coverage details."
  "Survived" -> "The mutation survived. The driver supplied no per-rule coverage details."
  "Uncovered" -> "The driver reports that this mutation was not reached in this run."
  _ -> "The driver supplied no per-rule coverage details; reachability is unverified."
