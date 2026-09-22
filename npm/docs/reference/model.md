---
id: ricestax.reference.model
kind: reference
title: The model
---
# The model

## 1. The module RicesTax.Model

Rice's Tax reviews what a machine raised and cannot decide, so the model names the
obligation first and the code it concerns second. ref:DEC-obligation

```haskell file=src/RicesTax/Model.hs part=header
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
```

## 2. Question

Who, When, and Where are derived from git and from location and raise nothing, so all six

are named only so that a kind can say which three have queues. ref:DEC-queues

```haskell file=src/RicesTax/Model.hs def=Question
data Question = Who | What | When | Where | Why | How
  deriving (Eq, Ord, Show, Enum, Bounded)
```

## 3. Kind

Each kind keeps its own identity scheme, digest scheme, and verdict words, because canon's

vetting and wavelet's mutation review must keep their vocabularies while sharing one ledger.

The How kinds beyond the mutant are provisional. ref:DEC-obligation ref:DEC-how-queue

ref:DEC-how-subkinds

```haskell file=src/RicesTax/Model.hs def=Kind
data Kind
  = CommentWhy
  | LedgerWhy
  | RegistryWhy
  | NameWhat
  | MutantHow
  | ObservabilityHow
  | BlindSpotHow
  deriving (Eq, Ord, Show, Enum, Bounded)
```

## 4. kindQuestion

The combined page groups by question and each queue's page filters by it, so the mapping

lives in one place rather than in each page. ref:DEC-ui-shape

```haskell file=src/RicesTax/Model.hs def=kindQuestion
kindQuestion :: Kind -> Question
kindQuestion k = case k of
  CommentWhy -> Why
  LedgerWhy -> Why
  RegistryWhy -> Why
  NameWhat -> What
  MutantHow -> How
  ObservabilityHow -> How
  BlindSpotHow -> How
```

## 5. Disposition

A verdict word means something only within its kind, so what the combined page and the

check need is the word's effect on the obligation, never the word. ref:DEC-obligation

ref:DEC-work-items

```haskell file=src/RicesTax/Model.hs def=Disposition
data Disposition = Open | Closed | Work | Deferred
  deriving (Eq, Ord, Show, Enum, Bounded)
```

## 6. SubjectKey

The unit key is canon's so that every queue joins on one identity, and the second

constructor exists so a content address can be chosen later without reshaping the ledger.

ref:DEC-join-key

```haskell file=src/RicesTax/Model.hs def=SubjectKey
data SubjectKey
  = UnitKey Text
  | ContentAddress Text
  deriving (Eq, Ord, Show)
```

## 7. Digest

Algorithm and hex travel together because canon and the sydtest driver already digest

differently, and a bare hex string would hide which one a row was judged under.

ref:DEC-obligation

```haskell file=src/RicesTax/Model.hs def=Digest
data Digest = Digest
  { digestAlgorithm :: Text
  , digestHex :: Text
  }
  deriving (Eq, Ord, Show)
```

## 8. Judged

A verdict applies to the material a person read and, where the kind says so, to the code

beneath it, so an edit to either side makes it stale. Whether Why gets the second side is

open. ref:DEC-what-queue ref:DEC-why-digest-scope

```haskell file=src/RicesTax/Model.hs def=Judged
data Judged = Judged
  { judgedMaterial :: Digest
  , judgedSubject :: Maybe Digest
  }
  deriving (Eq, Ord, Show)
```

## 9. Verdict

The word is the kind's own and the disposition is what it does, kept together so a ledger

row can be read without the kind's table. ref:DEC-obligation

```haskell file=src/RicesTax/Model.hs def=Verdict
data Verdict = Verdict
  { verdictWord :: Text
  , verdictDisposition :: Disposition
  }
  deriving (Eq, Ord, Show)
```

## 10. verdicts

The closed set per kind, canon's four words and wavelet's five, so a page offers exactly

what the ledger accepts and nothing else. ref:DEC-obligation ref:DEC-how-subkinds

```haskell file=src/RicesTax/Model.hs def=verdicts
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
```

## 11. disposition

A work item has no verdict line and is work by its kind alone, which is how a coverage gap

sits in the ledger without anyone signing it. ref:DEC-work-items

```haskell file=src/RicesTax/Model.hs def=disposition
disposition :: Kind -> Maybe Verdict -> Disposition
disposition k v = case v of
  Just verdict -> verdictDisposition verdict
  Nothing
    | null (verdicts k) -> Work
    | otherwise -> Open
```

## 12. Signer

Who signed is read from git blame of the verdict line and never stored, as canon does, and

the co-authors are kept because the tool records the signer rather than judging them.

ref:DEC-signer

```haskell file=src/RicesTax/Model.hs def=Signer
data Signer = Signer
  { signerName :: Text
  , signerTime :: Text
  , signerCommit :: Text
  , signerCoAuthors :: [Text]
  }
  deriving (Eq, Ord, Show)
```

## 13. SignOff

An uncommitted verdict is distinct from a missing one, because the page writes the

working tree and the person commits. ref:DEC-ui-commit

```haskell file=src/RicesTax/Model.hs def=SignOff
data SignOff
  = Unsigned
  | NotCommitted
  | Signed Signer
  deriving (Eq, Ord, Show)
```

## 14. Obligation

One row of the ledger, with the argument optional everywhere and the sign-off absent

because it is derived. ref:DEC-obligation ref:DEC-argument-optional ref:DEC-ledger-shape

```haskell file=src/RicesTax/Model.hs def=Obligation
data Obligation = Obligation
  { obligationKind :: Kind
  , obligationId :: Text
  , obligationSubject :: SubjectKey
  , obligationJudged :: Judged
  , obligationVerdict :: Maybe Verdict
  , obligationArgument :: Maybe Text
  }
  deriving (Eq, Ord, Show)
```

## 15. Outcome

The outcomes are the sydtest driver's, since that is the first adapter, and a later runtime

maps its own onto these. ref:DEC-runtime-first

```haskell file=src/RicesTax/Model.hs def=Outcome
data Outcome = Killed | Survived | Uncovered | Skipped | TimedOut | Invalid | InfrastructureError | Unknown
  deriving (Eq, Ord, Show, Enum, Bounded)
```

## 16. TestRun

A runtime names its tests in its own way, so the subject is resolved by the adapter and

may be unknown. ref:DEC-join-key ref:DEC-mutant-location

```haskell file=src/RicesTax/Model.hs def=TestRun
data TestRun = TestRun
  { testId :: Text
  , testSubject :: Maybe SubjectKey
  , testPassed :: Bool
  }
  deriving (Eq, Ord, Show)
```

## 17. MutantRun

The covering tests are kept by name because a surviving mutant is judged against what ran

and missed, and the before and after text is what the person reads. ref:DEC-how-queue

ref:DEC-mutant-location

```haskell file=src/RicesTax/Model.hs def=MutantRun
data MutantRun = MutantRun
  { mutantId :: Text
  , mutantSubject :: Maybe SubjectKey
  , mutantOutcome :: Outcome
  , mutantCovering :: [Text]
  , mutantWas :: Text
  , mutantBecame :: Text
  }
  deriving (Eq, Ord, Show)
```

## 18. RuntimeReport

Every adapter produces this and nothing else, so a language and runtime are ingested by

writing one reader. The facts carry seed, driver, and toolchain, which wavelet reprints on

every record. ref:DEC-runtime-first ref:DEC-home

```haskell file=src/RicesTax/Model.hs def=RuntimeReport
data RuntimeReport = RuntimeReport
  { reportRuntime :: Text
  , reportFacts :: [(Text, Text)]
  , reportTests :: [TestRun]
  , reportMutants :: [MutantRun]
  }
  deriving (Eq, Ord, Show)
```
