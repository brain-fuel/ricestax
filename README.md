# Rice's Tax

Rice's Tax is the ledger of everything a machine raised about a codebase and
cannot decide, and the tooling that raises those items, shows each kind to a
person on its own page, and records the sign-off. By Rice's theorem
(ref `rice-1953` in `canonical_refs.yaml`) every non-trivial semantic property
of a program is undecidable, so what remains after the compiler, property
tests, and mutation testing have done what they can is a tax a person pays.
This project names that tax and collects it in one place.

It generalises two projects. `canon` vets the Why of canonical comments,
decisions, and references, and reads the sign-off from git blame. wavelet's
mutation review asks a person whether a surviving mutant is logically
equivalent to the code it changed and writes the answer into a record beside
the specification. Both already do the same thing without naming it. Rice's
Tax depends on `canon` for units, languages, and the sign-off, and absorbs
wavelet's review server and page as its first review surface and first
runtime adapter.

## Standards

This project follows `canon`'s nine documentation rules and is checked by
`canon`. The rules are stated once, under "Documentation rules" in canon's
`README.md` (ref `canon` in `canonical_refs.yaml`), and are not restated here
so that they cannot drift. Decisions live in `canonical_decisions.yaml`, references in
`canonical_refs.yaml`, and verdicts on both in `canonical_vetting.yaml`.
Nothing outside the repository is trusted. Anything that has no canonical
place yet lives in `to_be_removed/` until it does, and is then deleted.

## The obligation

An obligation is a fact a machine detected and cannot decide. Every obligation
has:

| Field | Meaning |
|-------|---------|
| kind | Which queue it belongs to and which words may answer it |
| identity | A stable key, namespaced by kind, so the same item is the same row across runs |
| subject | The code it concerns, by `canon` unit key, with room for a content address later |
| judged | The digest of the material a person read, and where the kind says so the digest of the code beneath it, so an edit to either side makes the verdict stale |
| verdict | One word from the kind's own closed set, or none for a work item |
| argument | Optional prose, everywhere |
| sign-off | Never stored. Read from git blame of the verdict line: the author, the time, the commit, and the co-authors it names. Recorded, not judged |

Every verdict word maps to one of four dispositions: open, closed, work, or
deferred. That is the only vocabulary the combined page and the check need.
`RicesTax.Model` states all of this in types.

## The six questions

| Question | Answered by | Queue |
|----------|-------------|-------|
| Who | git | none, derived |
| What | the name and the signature | What: the name and signature together state, in full words, the fact the unit establishes. Stale when name, signature, or body changes |
| When | git and increasing version numbers | none, derived |
| Where | package, file, and the chain of enclosing units | none, derived |
| Why | canonical comments, the decisions ledger, the registry | Why: `canon`'s vetting |
| How | bodies, verified by tests | How: whether the tests can observe the body, whether blind spots exist, and every surviving mutant. Mutation review is a subset |

Why, What, and How are reviewed apart from one another, each on its own page,
and a combined page shows all three grouped by disposition.

## Kinds

| Kind | Question | Subject | Material judged | Words and dispositions |
|------|----------|---------|-----------------|------------------------|
| comment | Why | a unit with a canonical comment | the Why text; the body too if `DEC-why-digest-scope` says so | pending open, good closed, bad work, deferred deferred |
| ledger | Why | a decision entry | the whole entry | the same four |
| registry | Why | a reference | kind, title, locator | the same four |
| name | What | a unit | name and signature, with the body as the second side | the same four |
| mutant | How | a unit with a surviving mutant | the mutant's context: binding, operator, before, after | unreviewed open, logical-equivalency closed, inadequate-testing work, unnecessary-code work, needs-research deferred |
| observability | How | a unit whose tests never made an expression take both outcomes | the observation | none: a work item |
| blind-spot | How | provisional, see `DEC-how-subkinds` | | |

## Where each part comes from

| Part | `canon` today | wavelet today | Rice's Tax |
|------|---------------|---------------|------------|
| Units, languages, comment extraction | interpreted ANTLR grammars, dialects and profiles | one tangling record, Haskell only | from `canon` |
| Test units and the requirement they cite | recognised per language, must cite a requirement | rule names are sydtest describe paths | from `canon`, joined to the runtime's test ids by the adapter |
| Digest and staleness | sha256 prefix of the Why only | a context digest per mutant; both sides of a prose-and-code pair in the attestation ledger | both sides wherever the kind says so |
| Verdict words | pending, good, bad, deferred | unreviewed, logical-equivalency, inadequate-testing, unnecessary-code, needs-research | each kind keeps its own; dispositions unify them |
| Sign-off | computed from blame and co-author trailers | not computed; left open in its specification | from `canon`, for every kind |
| Ledger on disk | one YAML file, one key per line | one markdown record per subject beside its specification | a directory per kind, a file per subject, one verdict per line |
| Runtime evidence | four verification kinds declared, none produced | the sydtest driver's report, augmented manifest, and run facts, read directly | a runtime adapter producing one report shape |
| Review surface | command line only | a small server and one page for mutants; a decision rewrites the record | one page per queue and a combined page; the server rewrites the ledger file |
| Commit | uncommitted verdict reported as not committed | the person commits | the same |

## The flow

1. **Raise.** `canon` extracts units and comments. A runtime adapter reads a
   test or mutation run into one report shape: facts such as seed, driver, and
   toolchain; tests with their outcome; mutants with their outcome, the tests
   that covered them, and the text before and after. Each kind raises its
   obligations against unit keys.
2. **Ledger.** Each obligation is a row in the file for its kind and subject.
   A verdict sits on its own line. A work item has no verdict line.
3. **Review.** A page per queue and a combined page. A decision rewrites the
   ledger file in the working tree and nothing else. The person commits.
4. **Sign-off.** Read from git blame of the verdict line. An uncommitted
   verdict is reported as not committed with its signer unknown.
5. **Stale.** A row whose judged digests no longer match is pending again.
6. **Report.** The report is invalid while anything is pending, and lists
   work items as work.

## Runtime adapters

An adapter is one reader from a runtime's own output to the report shape in
`RicesTax.Model`. The first is sydtest-mutation, reading what wavelet already
produces. The second is tasty and hedgehog, so `canon` and this project can
run under their own tax. Tangling stays in wavelet under the open decision
`DEC-tangling`.

## Languages

Languages come from `canon`: a dialect grammar or a profile per language. The
Haskell dialect is vendored under `grammars/haskell/` from `canon` at commit
`f639753` so `canon` can check this project's own source; how to stop that
copy drifting is the open decision `DEC-grammar-sharing`.

## Not yet decided

`canon decisions` lists the open entries first. At founding they are
`DEC-how-subkinds`, `DEC-why-digest-scope`, `DEC-subject-granularity`,
`DEC-grammar-sharing`, `DEC-mutant-location`, and `DEC-tangling`, each to be
revisited by 0.2.0.

## Layout

```
rices-tax/
├── README.md
├── CHANGELOG.md
├── LICENSE
├── canon.yaml                  # canon's configuration for this project
├── canonical_refs.yaml         # the reference registry
├── canonical_decisions.yaml    # the decisions ledger
├── canonical_vetting.yaml      # verdicts on comments, ledger, and registry
├── package.yaml
├── stack.yaml
├── grammars/haskell/           # the Haskell dialect, vendored from canon
├── src/RicesTax/Model.hs       # the obligation, the kinds, the report shape
└── to_be_removed/              # material awaiting a canonical place
```

## Building

```
stack build
```

`canon` is built from its checkout beside this project, `../canon`, as
`stack.yaml` explains: a git dependency would clone canon's sample submodules,
whose pinned commits their remotes do not serve. To check this project with
`canon`, run its binary at the project root:

```
canon check
canon vet
canon decisions
```
