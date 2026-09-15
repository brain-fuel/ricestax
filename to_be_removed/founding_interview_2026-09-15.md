# Founding interview

Source material: the project owner's answers, given on 2026-09-15 in a Claude
Code session, to the questions that founded Rice's Tax. Each answer is
recorded as a decision in `canonical_decisions.yaml`.

Waiting for: confirmation that `README.md` and the ledger capture every
statement below, after which this file is deleted.

Date: 2026-09-15

## The request, in the owner's words

> I want there to be a generalization of "Mutation Review" + "Canon" called
> "Rice's Tax", where not only mutations are reviewed, but also the 5w's and
> h. I want those reviews to be distinct from each-other, and be supported
> each via separate UI's (and for there to be a common UI for dealing with
> both of them, too). I want to have a means of arbitrarily ingesting a
> language + testing/property-based testing/parameterized testing/mutation
> testing runtime and then having this entire thing conducted under the
> umbrella of "Rice's Tax".

> consider also any diffs between this and what actually needs to happen to
> make the flow work; ask questions of me as necessary to confirm; do not
> make any unfounded assumptions.

> I want to make sure the data model and abstractions map with what needs to
> exist across everything

## Answers

| Question | Answer |
|----------|--------|
| Where should Rice's Tax live? | New project depending on canon |
| Which of the six questions get their own review queue and UI? | Why, What, How as separate queues |
| What shape should the ledger take on disk? | Per kind and per subject |
| Must a closing verdict carry a written argument? | Optional everywhere |
| What is the master identity of a subject? | Canon unit key, but allow for the abstraction to exist if we decide to do content-addressing or essence-hashing |
| What does a What verdict decide? | Rule 8 plus signature |
| Who may sign a verdict? | Record only, as canon does |
| Where should this design be recorded? | Create the new project now |
| Which runtime is the first adapter? | sydtest-mutation, then tasty |
| How does the How queue relate to mutation review? | Mutation review is a subset of the How queue, How tests have/lack observability; how blind spots do/do not exist -- with surviving mutants. |
| Do work items belong in the ledger? | Yes, as disposition work without a verdict |
| Should the UI commit a verdict? | Write the working tree only |

## Stated assumption, not yet confirmed

Tangling stays in wavelet, since canon reads source directly and the runtime
adapter would consume whatever wavelet tangles. Recorded as the open decision
`DEC-tangling`.

## Facts established from the two codebases on 2026-09-15

- canon's comment digest covers only the text of the Why, not the code beneath
  it, so a verdict survives an edit to that code. Recorded as the open
  decision `DEC-why-digest-scope`.
- canon declares four verification kinds, property test, unit test, mutation
  run, and decision coverage, and produces none of them.
- wavelet's mutation review records no signer; its own specification leaves
  that open, and its founding attestation ledger was written by a model.
- wavelet's mutation tooling is Haskell and sydtest only, and canon's own tests
  use tasty and hedgehog, so canon cannot be mutation-tested by wavelet's
  driver as it stands.
- Both projects build on GHC 9.10.3, canon on Stackage LTS 24.58 and wavelet
  on 24.57.
- No join exists between a runtime's test identity, a canon test unit, and a
  mutant's binding. Recorded as the open decision `DEC-mutant-location`.
