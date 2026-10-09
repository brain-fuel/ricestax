-- Tangled from wire.md.
-- Edit the specification, not this file.
-- Every comment below is generated from the prose there.

-- | What the server sends the page and what the page sends back, kept apart from the model so
-- the wire form can change without touching what an obligation is, and parameterised over the
-- string type because the page's strings are JavaScript strings while the server's are Text.
-- Field names are the JSON keys, so no name repeats across these records. ref:DEC-ui-shape
-- ref:DEC-ui-frontend ref:DEC-page-first-queue
--
-- Specified by wire S1.
module RicesTax.Wire
  ( Payload (..)
  , Subject (..)
  , Item (..)
  , Ref (..)
  , Signer (..)
  , Decide (..)
  , Facts (..)
  , MutantView (..)
  , RuleSource (..)
  , Observed (..)
  , Count (..)
  , Bound (..)
  , Whole (..)
  , ExemptRequest (..)
  , HistoryEvent (..)
  , HistoryLog (..)
  , HistoryRequest (..)
  , Lifecycle (..)
  , Mutation (..)
  ) where

import GHC.Generics (Generic)

-- | One load of the page: the project, every obligation the server could raise, and each rule's
--
-- source once, so the page filters and groups on its own. found pairs each row canon reports on
-- with what canon check says of it, and canonRunning is the canon version that read the
-- project,
-- so the page shows canon's own words beside each card. ref:DEC-ui-shape ref:DEC-canon-lockstep
--
-- Specified by wire S2.
data Payload s = Payload
  { project :: s
  , subjects :: [Subject s]
  , items :: [Item s]
  , facts :: Maybe (Facts s)
  , rules :: [RuleSource s]
  , lifecycle :: [Lifecycle s]
  , historyRevision :: s
  , runIssue :: s
  , ingestionIssues :: [s]
  , found :: [(s, s)]
  , canonRunning :: s
  }
  deriving (Eq, Show, Generic)

-- | One file of the ledger with how much of it is undecided, which is what the switcher shows.
--
-- ref:DEC-ledger-shape
--
-- Specified by wire S3.
data Subject s = Subject
  { subjectFile :: s
  , subjectName :: s
  , undecided :: Int
  , total :: Int
  }
  deriving (Eq, Show, Generic)

-- | One obligation as the page shows it: what it is, where it is, the material a person reads,
--
-- with a decision's answer apart from its question, the verdict it carries, who signed, the
-- code
--
-- around it, and for a mutant the run its verdict was decided against. ref:DEC-obligation
--
-- ref:DEC-mutant-provenance
--
-- Specified by wire S4.
data Item s = Item
  { key :: s
  , kind :: s
  , question :: s
  , file :: s
  , subject :: s
  , unit :: s
  , unitKind :: s
  , path :: s
  , line :: Int
  , text :: s
  , answer :: s
  , refs :: [Ref s]
  , state :: s
  , verdict :: s
  , note :: s
  , revisit :: s
  , signer :: Maybe (Signer s)
  , code :: [s]
  , codeFrom :: Int
  , commentLines :: Int
  , marks :: [s]
  , mutant :: Maybe (MutantView s)
  , run :: s
  , exempt :: s
  , exemptReason :: s
  , exemptUntil :: s
  }
  deriving (Eq, Show, Generic)

-- | What the run was, so the page can say which seed, driver, and toolchain produced the mutants
--
-- it shows, and which files have changed since. ref:DEC-runtime-first
--
-- Specified by wire S5.
data Facts s = Facts
  { runtime :: s
  , runName :: s
  , factList :: [(s, s)]
  , corpusOk :: Bool
  , staleFiles :: [s]
  , command :: s
  }
  deriving (Eq, Show, Generic)

-- | A surviving mutant as wavelet's card shows it: the change, the code around it, the names of
--
-- what looked and missed, and what the probe recorded; the rules' sources travel once per
-- payload
--
-- and the whole definition on demand. ref:DEC-how-queue
--
-- Specified by wire S6.
data MutantView s = MutantView
  { operator :: s
  , was :: s
  , became :: s
  , outcome :: s
  , covering :: [s]
  , before :: [s]
  , source :: [s]
  , mutated :: [s]
  , after :: [s]
  , beforeMarks :: [s]
  , sourceMarks :: [s]
  , mutatedMarks :: [s]
  , afterMarks :: [s]
  , fromLine :: Int
  , fromCol :: Int
  , toLine :: Int
  , toCol :: Int
  , observed :: Maybe (Observed s)
  , coverage :: s
  , sided :: s
  , gap :: s
  , staleFile :: Bool
  }
  deriving (Eq, Show, Generic)

-- | An exemption the page adds or lifts: the subject, the kinds it covers, why, and the version
--
-- to revisit by; lifting sends the subject alone. ref:DEC-exemptions
--
-- Specified by wire S7.
data ExemptRequest s = ExemptRequest
  { exemptSubject :: s
  , exemptKinds :: [s]
  , exemptWhy :: s
  , exemptRevisit :: s
  }
  deriving (Eq, Show, Generic)

-- | The whole definition around a mutant, fetched only when a zoom opens, because it is a third
--
-- of the payload and read once in a hundred cards. ref:DEC-how-card
--
-- Specified by wire S8.
data Whole s = Whole
  { wholeLines :: [s]
  , wholeStart :: Int
  , wholeMarks :: [s]
  }
  deriving (Eq, Show, Generic)

-- | A rule that ran against the mutant and missed, with its source when it could be found.
--
-- Specified by wire S9.
data RuleSource s = RuleSource
  { ruleName :: s
  , ruleSource :: [s]
  , ruleMarks :: [s]
  }
  deriving (Eq, Show, Generic)

-- | What the probe recorded at the site, or the status that says why it could not.
--
-- Specified by wire S10.
data Observed s = Observed
  { obsStatus :: s
  , obsTotal :: Int
  , obsDistinct :: [Count s]
  , obsBound :: [Bound s]
  }
  deriving (Eq, Show, Generic)

-- | One value and how often it was seen.
--
-- Specified by wire S11.
data Count s = Count
  { value :: s
  , count :: Int
  }
  deriving (Eq, Show, Generic)

-- | A bound variable and the values it took.
--
-- Specified by wire S12.
data Bound s = Bound
  { boundName :: s
  , boundValues :: [Count s]
  }
  deriving (Eq, Show, Generic)

-- | A citation with what it points at, so the page shows a reference's title and a decision's
--
-- question and answer, never only the key.
--
-- Specified by wire S13.
data Ref s = Ref
  { refKey :: s
  , refKind :: s
  , refTitle :: s
  , refAnswer :: s
  , refLocator :: s
  }
  deriving (Eq, Show, Generic)

-- | Who signed, read by the server from git blame and shown by the page, never stored.
--
-- ref:DEC-signer
--
-- Specified by wire S14.
data Signer s = Signer
  { signerName :: s
  , signedAt :: s
  , signedIn :: s
  , coAuthors :: [s]
  }
  deriving (Eq, Show, Generic)

-- | A decision the page posts: the key, the verdict word, and the optional note and revisit
--
-- version, which the server writes into the ledger file. ref:DEC-ui-commit
--
-- Specified by wire S15.
data Decide s = Decide
  { decideKey :: s
  , decideVerdict :: s
  , decideNote :: s
  , decideRevisit :: s
  }
  deriving (Eq, Show, Generic)

-- | The state of the mutation run the page can start: idle, running, finished, or failed; the
-- command
-- it runs; when it started; its exit code once it ended; and the last lines it printed. The
-- servers
-- keep it and the page polls it, so a person keeps deciding while the suite runs.
-- ref:DEC-mutation-rerun
--
-- Specified by wire S15.
data Mutation s = Mutation
  { mutationState :: s
  , mutationCommand :: s
  , mutationSince :: s
  , mutationExit :: Int
  , mutationLog :: [s]
  }
  deriving (Eq, Show, Generic)

-- | Decision lifecycle evidence is independent of a verdict. ref:DEC-verdict-carry-over
--
-- Specified by wire.
data HistoryEvent s = HistoryEvent
  { eventId :: s
  , eventAction :: s
  , eventTime :: s
  , eventReason :: s
  , eventSnapshot :: Item s
  , eventFacts :: Maybe (Facts s)
  , eventDecisionDigest :: s
  , eventEvidenceDigest :: s
  , eventPrevious :: s
  } deriving (Eq, Show, Generic)

data HistoryLog s = HistoryLog
  { historySchema :: Int
  , historyEvents :: [HistoryEvent s]
  } deriving (Eq, Show, Generic)

data Lifecycle s = Lifecycle
  { lifeKey :: s
  , lifeStatus :: s
  , lifeMessage :: s
  , lifeArchived :: Bool
  , lifeItem :: Item s
  , lifeEvents :: [HistoryEvent s]
  } deriving (Eq, Show, Generic)

data HistoryRequest s = HistoryRequest
  { historyAction :: s
  , historyKeys :: [s]
  , historyReason :: s
  , expectedRevision :: s
  } deriving (Eq, Show, Generic)
