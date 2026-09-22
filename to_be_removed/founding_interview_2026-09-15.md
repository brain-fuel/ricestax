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
| Front end language and runtime (asked 2026-09-15, later in the session) | "I also want the front end UI to be done in Haskell/WASM using DOM bindings." |
| Which DOM binding layer? | miso on the wasm backend |
| May the wasm toolchain be installed? | Yes, via ghc-wasm-meta's installer |
| On the first page (a stub) | "when I served web/public it looked like shite and didn't do anything" |
| Next iteration of the page? | The Why queue over real data, "and take a look at the UI/UX of the existing stuff in wavelet because it doesn't suck." |
| Where does a Why verdict canon tracks live? | Move canon to the per-kind layout |
| On-disk layout? | Directory per kind, comment files mirror the source tree |
| Migration of canon's 2171 pending entries? | Regenerate with canon ingest |
| (2026-09-16) "ONe thing I cannot see on here is the paying of Rice's Tax as mutation testing is concerned. How can we get the reporting Wavelet had and integrate it into this?" | |
| Where do mutant verdicts live? | Canon's vetting learns kinds |
| Does wavelet become a canon project? | Yes, canon.yaml over spec-hs/src |
| wavelet's MUT- and COVERAGE- records? | Retire them: the page is the report |
| How much of wavelet's card in the first How page? | The whole card |
| (2026-09-16) "I think that mutation decisions should be recorded in mutation_decisions.yaml or something separate from the other decisions; and these decisions need to be somehow mapped to the (mutation tester, mutation tester version, seed, other relevant data/metadata)" | |
| Where does a mutant verdict's provenance live? | Row names its run; runs in mutation_runs.yaml |
| Does a verdict carry over to a later run? | "1. but ideally we keep the seed and driver version so as to not generate assloads of work when we update software; hopefully behavior of the mutator doesn't change but if it does we'll have to cross that bridge when we come to it because it's a lot of work." |
| Extend wavelet's mutate script to record commit and date? | Yes, add commit and date |
| (2026-09-18) "what if I want there to be ricestax.org \| ricestax.com (i bought both) /canon and /pay and /reconcile (names TBD actually) (canon for making the canonical stuff / pay for paying the tax / reconcile for proving the tax has been paid) and turn this whole thing into something that can be used in CI, as well as a diataxis-documented, youtube-video-mediated, way to expound upon the basics of the way we ought to develop software?" | Answered on 2026-09-19: the Folio, the docs/ tree, the doc kind, the optional video reference, and the site; see DEC-site, DEC-umbrella-surface, and canon's DEC-docs-tree and DEC-video-reference. |
| "so the 3 commands should be one to get the state of things, one to \"pay the tax\" and one to ensure the tax has been paid. canon, pay, and reconcile don't quite hit the mark." | assess, pay, audit |
| "I like assess, pay, and audit. I think that \"canon\" as the data format makes sense, but I think all 3 tools should be developed in parallel. \"canon\" files for all the different parameters should be used (so, for example, we can know that projects that are just being imported are going to be problematic, so we need to have an \"opt-out\" list; perhaps one that can be added to via the \"pay\" UI, or by modifying the configuration file... either way, the point is that all these files should play nicely with all the tools." | |
| How is an opt-out recorded? | canonical_exemptions.yaml, signed, with revisit |
| Where do the tools' parameters live? | All in canon.yaml and canonical_* files |
| How are the three tools packaged? | "I would like the thing to be `npm` installable as js wrappers and executors which are deterministically generated around the public API + executable code in haskell compiled to wasm. This way anyone in the node/bun ecosystem can use it without problem." |
| What does audit prove? | Open, stale, unsigned, or expired fails |
| "I want the tool chain to be the basic stack shit; nothing obscure" | |
| What happens to the page, given Stack cannot build for wasm? | "I expect you to research how to make something that is the most (1) promising, and (2) mature option for this. I am sure that there is a way of integrating other stuff into build tools, and I want to ensure that BOTH the front-end and back-end are compiled to WASM so that BOTH can be run out of the Node ecosystem." |
| Is this the toolchain: Stack for native, cabal for wasm, one hpack source, the wasm GHC from ghcup? | "Stack for native; figure out another build tool to plug into stack for wasm (ghc-wasm-meta; wasm32-wasi-cabal; ahc-cabal); figure that out" |
| How are the JavaScript wrappers generated? | From one Haskell export table |

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
