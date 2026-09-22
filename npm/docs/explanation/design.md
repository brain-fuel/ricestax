---
id: ricestax.design
kind: explanation
title: The obligation, the six questions, and the flow
---
# The design of Rice's Tax

Whether two programs compute the same function is undecidable, so what remains after the compiler,
the property tests, and the mutation testing have done what they can is a tax a person pays. Rice's
Tax is the tool that determines what is owed, lets a person pay it, and proves it was paid, over the
files canon keeps. ref:DEC-obligation ref:DEC-three-verbs

## The obligation

An obligation is a fact a machine detected and cannot decide. Every obligation has a kind, which says
which queue it belongs to and which words may answer it; an identity, a stable key namespaced by kind,
so the same item is the same row across runs; a subject, the code it concerns, by canon unit key;
what was judged, the digest of the material a person read and, where the kind says so, of the code
beneath it, so an edit to either side makes the verdict stale; a verdict, one word from the kind's own
closed set, or none for a work item; an optional argument; and a sign-off that is never stored but
read from git blame of the verdict line. Every verdict word maps to one of four dispositions, open,
closed, work, or deferred, which is the only vocabulary the combined page and the check need.
`RicesTax.Model` states all of this in types. ref:DEC-obligation ref:DEC-ledger-shape ref:DEC-signer

## The six questions

| Question | Answered by | Queue |
|----------|-------------|-------|
| Who | git | none, derived |
| What | the name and the signature | What: the name and signature together state, in full words, the fact the unit establishes; stale when name, signature, or body changes |
| When | git and increasing version numbers | none, derived |
| Where | package, file, and the chain of enclosing units | none, derived |
| Why | canonical comments, the decisions ledger, the registry, and the pages | Why: canon's vetting |
| How | bodies, verified by tests | How: whether the tests can observe the body, whether blind spots exist, and every surviving mutant; mutation review is a subset |

Why, What, and How are reviewed apart from one another, each on its own page, and a combined page
shows all three grouped by disposition. The pages are Haskell compiled to WebAssembly, using miso on
the GHC wasm backend, so they share their wire types with the server. ref:DEC-queues
ref:DEC-what-queue ref:DEC-how-queue ref:DEC-ui-frontend

## The kinds

| Kind | Question | Subject | Material judged | Words and dispositions |
|------|----------|---------|-----------------|------------------------|
| comment | Why | a unit with a canonical comment | the Why text | pending open, good closed, bad work, deferred deferred |
| ledger | Why | a decision entry | the whole entry | the same four |
| registry | Why | a reference | kind, title, locator | the same four |
| doc | Why | a Folio page | all its prose and citations | the same four |
| name | What | a unit that requires a comment | name and signature, with the body as the second side | the same four |
| mutant | How | a unit with a surviving mutant | the mutant's context: binding, operator, before, after | unreviewed open, logical-equivalency closed, inadequate-testing work, unnecessary-code work, needs-research deferred |
| observability | How | a unit whose tests never made an expression take both outcomes | the observation | none: a work item |

ref:DEC-what-raised ref:DEC-why-digest-scope ref:DEC-how-subkinds ref:DEC-work-items

## The flow

1. **Raise.** canon extracts units, comments, and pages. A runtime adapter reads a test or mutation
   run into one report shape: facts such as seed, driver, and toolchain; tests with their outcome;
   mutants with their outcome, the tests that covered them, and the text before and after. Each kind
   raises its obligations against unit keys.
2. **Ledger.** Each obligation is a row in the file for its kind and subject. A verdict sits on its
   own line. A work item has no verdict line.
3. **Review.** A page per queue and a combined page. A decision rewrites the ledger file in the
   working tree and nothing else. The person commits.
4. **Sign-off.** Read from git blame of the verdict line. An uncommitted verdict is reported as not
   committed with its signer unknown.
5. **Stale.** A row whose judged digests no longer match is pending again.
6. **Report.** The report is invalid while anything is pending, and lists work items as work.

ref:DEC-ui-commit ref:DEC-verdict-carry-over ref:DEC-mutant-provenance

## Where each part comes from

Units, languages, comments, and pages come from canon, as do test units and the requirement each
cites, joined to the runtime's test ids by the adapter. Digests cover both sides wherever the kind
says so. Each kind keeps its own verdict words; dispositions unify them. Sign-off comes from canon,
for every kind. The ledger on disk is a directory per kind and a file per subject, one verdict per
line. Runtime evidence is one report shape an adapter produces; the first adapter reads what
wavelet's sydtest-mutation driver writes. The review surface is one page per queue and a combined
page, and the native server rewrites the ledger file; the person commits. ref:DEC-canon-is-the-format
ref:DEC-runtime-first ref:DEC-grammar-sharing ref:DEC-tangling
