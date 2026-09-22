-- Tangled from model.md.
-- Edit the specification, not this file.
-- Every comment below is generated from the prose there.

-- | Rice's Tax reviews what a machine raised and cannot decide, so the model names the
-- obligation first and the code it concerns second. ref:DEC-obligation
--
-- Specified by model S1.
module RicesTax.Model
  ( Question (..)
  , Kind (..)
  , kindQuestion
  , Disposition (..)
  , SubjectKey (..)
  , Digest (..)
  , Judged (..)
  , Verdict (..)
  , verdicts
  , disposition
  , Signer (..)
  , SignOff (..)
  , Obligation (..)
  , Outcome (..)
  , TestRun (..)
  , MutantRun (..)
  , RuntimeReport (..)
  ) where

import Data.Text (Text)

-- | Who, When, and Where are derived from git and from location and raise nothing, so all six
--
-- are named only so that a kind can say which three have queues. ref:DEC-queues
--
-- Specified by model S2.
data Question = Who | What | When | Where | Why | How
  deriving (Eq, Ord, Show, Enum, Bounded)

-- | Each kind keeps its own identity scheme, digest scheme, and verdict words, because canon's
--
-- vetting and wavelet's mutation review must keep their vocabularies while sharing one ledger.
--
-- The How kinds beyond the mutant are provisional. ref:DEC-obligation ref:DEC-how-queue
--
-- ref:DEC-how-subkinds
--
-- Specified by model S3.
data Kind
  = CommentWhy
  | LedgerWhy
  | RegistryWhy
  | NameWhat
  | MutantHow
  | ObservabilityHow
  | BlindSpotHow
  deriving (Eq, Ord, Show, Enum, Bounded)

-- | The combined page groups by question and each queue's page filters by it, so the mapping
--
-- lives in one place rather than in each page. ref:DEC-ui-shape
--
-- Specified by model S4.
kindQuestion :: Kind -> Question
kindQuestion k = case k of
  CommentWhy -> Why
  LedgerWhy -> Why
  RegistryWhy -> Why
  NameWhat -> What
  MutantHow -> How
  ObservabilityHow -> How
  BlindSpotHow -> How

-- | A verdict word means something only within its kind, so what the combined page and the
--
-- check need is the word's effect on the obligation, never the word. ref:DEC-obligation
--
-- ref:DEC-work-items
--
-- Specified by model S5.
data Disposition = Open | Closed | Work | Deferred
  deriving (Eq, Ord, Show, Enum, Bounded)

-- | The unit key is canon's so that every queue joins on one identity, and the second
--
-- constructor exists so a content address can be chosen later without reshaping the ledger.
--
-- ref:DEC-join-key
--
-- Specified by model S6.
data SubjectKey
  = UnitKey Text
  | ContentAddress Text
  deriving (Eq, Ord, Show)

-- | Algorithm and hex travel together because canon and the sydtest driver already digest
--
-- differently, and a bare hex string would hide which one a row was judged under.
--
-- ref:DEC-obligation
--
-- Specified by model S7.
data Digest = Digest
  { digestAlgorithm :: Text
  , digestHex :: Text
  }
  deriving (Eq, Ord, Show)

-- | A verdict applies to the material a person read and, where the kind says so, to the code
--
-- beneath it, so an edit to either side makes it stale. Whether Why gets the second side is
--
-- open. ref:DEC-what-queue ref:DEC-why-digest-scope
--
-- Specified by model S8.
data Judged = Judged
  { judgedMaterial :: Digest
  , judgedSubject :: Maybe Digest
  }
  deriving (Eq, Ord, Show)

-- | The word is the kind's own and the disposition is what it does, kept together so a ledger
--
-- row can be read without the kind's table. ref:DEC-obligation
--
-- Specified by model S9.
data Verdict = Verdict
  { verdictWord :: Text
  , verdictDisposition :: Disposition
  }
  deriving (Eq, Ord, Show)

-- | The closed set per kind, canon's four words and wavelet's five, so a page offers exactly
--
-- what the ledger accepts and nothing else. ref:DEC-obligation ref:DEC-how-subkinds
--
-- Specified by model S10.
verdicts :: Kind -> [Verdict]
verdicts k = case k of
  CommentWhy -> canonWords
  LedgerWhy -> canonWords
  RegistryWhy -> canonWords
  NameWhat -> canonWords
  MutantHow -> waveletWords
  ObservabilityHow -> []
  BlindSpotHow -> []
  where
    canonWords =
      [ Verdict "pending" Open
      , Verdict "good" Closed
      , Verdict "bad" Work
      , Verdict "deferred" Deferred
      ]
    waveletWords =
      [ Verdict "unreviewed" Open
      , Verdict "logical-equivalency" Closed
      , Verdict "inadequate-testing" Work
      , Verdict "unnecessary-code" Work
      , Verdict "needs-research" Deferred
      ]

-- | A work item has no verdict line and is work by its kind alone, which is how a coverage gap
--
-- sits in the ledger without anyone signing it. ref:DEC-work-items
--
-- Specified by model S11.
disposition :: Kind -> Maybe Verdict -> Disposition
disposition k v = case v of
  Just verdict -> verdictDisposition verdict
  Nothing
    | null (verdicts k) -> Work
    | otherwise -> Open

-- | Who signed is read from git blame of the verdict line and never stored, as canon does, and
--
-- the co-authors are kept because the tool records the signer rather than judging them.
--
-- ref:DEC-signer
--
-- Specified by model S12.
data Signer = Signer
  { signerName :: Text
  , signerTime :: Text
  , signerCommit :: Text
  , signerCoAuthors :: [Text]
  }
  deriving (Eq, Ord, Show)

-- | An uncommitted verdict is distinct from a missing one, because the page writes the
--
-- working tree and the person commits. ref:DEC-ui-commit
--
-- Specified by model S13.
data SignOff
  = Unsigned
  | NotCommitted
  | Signed Signer
  deriving (Eq, Ord, Show)

-- | One row of the ledger, with the argument optional everywhere and the sign-off absent
--
-- because it is derived. ref:DEC-obligation ref:DEC-argument-optional ref:DEC-ledger-shape
--
-- Specified by model S14.
data Obligation = Obligation
  { obligationKind :: Kind
  , obligationId :: Text
  , obligationSubject :: SubjectKey
  , obligationJudged :: Judged
  , obligationVerdict :: Maybe Verdict
  , obligationArgument :: Maybe Text
  }
  deriving (Eq, Ord, Show)

-- | The outcomes are the sydtest driver's, since that is the first adapter, and a later runtime
--
-- maps its own onto these. ref:DEC-runtime-first
--
-- Specified by model S15.
data Outcome = Killed | Survived | Uncovered | Skipped | TimedOut | Invalid | InfrastructureError | Unknown
  deriving (Eq, Ord, Show, Enum, Bounded)

-- | A runtime names its tests in its own way, so the subject is resolved by the adapter and
--
-- may be unknown. ref:DEC-join-key ref:DEC-mutant-location
--
-- Specified by model S16.
data TestRun = TestRun
  { testId :: Text
  , testSubject :: Maybe SubjectKey
  , testPassed :: Bool
  }
  deriving (Eq, Ord, Show)

-- | The covering tests are kept by name because a surviving mutant is judged against what ran
--
-- and missed, and the before and after text is what the person reads. ref:DEC-how-queue
--
-- ref:DEC-mutant-location
--
-- Specified by model S17.
data MutantRun = MutantRun
  { mutantId :: Text
  , mutantSubject :: Maybe SubjectKey
  , mutantOutcome :: Outcome
  , mutantCovering :: [Text]
  , mutantWas :: Text
  , mutantBecame :: Text
  }
  deriving (Eq, Ord, Show)

-- | Every adapter produces this and nothing else, so a language and runtime are ingested by
--
-- writing one reader. The facts carry seed, driver, and toolchain, which wavelet reprints on
--
-- every record. ref:DEC-runtime-first ref:DEC-home
--
-- Specified by model S18.
data RuntimeReport = RuntimeReport
  { reportRuntime :: Text
  , reportFacts :: [(Text, Text)]
  , reportTests :: [TestRun]
  , reportMutants :: [MutantRun]
  }
  deriving (Eq, Ord, Show)
