# Changelog for `rices-tax`

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).

## 0.3.2 — 22 September 2026

- Replace process adapters with HTTP servers native to Java, Python, Go, Haskell,
  Kotlin and TypeScript; keep JavaScript's native HTTP implementation.
- Test each HTTP application in its own language over real network connections.
- Move ANTLR's evaluator assertions to Java and preserve CALM's separate model tests.
- Update dependencies, generation pages, mutation catalogs and docs to match.

## 0.3.1 — 22 September 2026

- Replace the ANTLR greeting example with a documented integer-expression grammar,
  generated Java parser, evaluator, positive/negative tests and two grammar mutations.
- Replace the CALM greeting example with a checkout architecture and independent
  gateway-access/database-ownership assertions, challenged by two architecture mutations.
- Separate language-specific tutorials and explain exactly what each example proves.
- Keep the seven general-purpose greeting examples and validate all packaged projects.

## 0.3.0 — 22 September 2026

- Package Java, JavaScript, TypeScript, Python, Go, Haskell, Kotlin, CALM 1.2,
  ANTLR4 and Folio ingestion profiles with project initialization and grammar provenance.
- Ingest CALM nodes, relationships and flows with stable IDs and source spans;
  reject malformed identities and references. Attach Python declaration/module docstrings.
- Generate code from Folio with block-comment and comment-free JSON output.
- Scaffold executable CALM-derived service-boundary starters for all nine targets.
- Execute explicit mutation catalogs in isolated copies with separate compilation,
  test evidence, timeout handling, source hashes and retained reports.
- Document migration, new projects, language boundaries and a complete generated
  HTTP-service tutorial across the four Diátaxis quadrants.
- Keep imported grammar changes and extraction revisions in cache invalidation.

## 0.2.0 — 22 September 2026

### Added
- Separate Needs attention, Decisions, and History views for mutation review.
- Verified kill classification, bulk/individual archive, restore/undo, and reasoned retirement.
- Atomic versioned YAML history with retained mutation/decision/run snapshots, source digests, SHA-256 checks, and stale-write rejection. Original verdicts remain unchanged.
- Archived mutants return to attention when they survive again or their context changes.
- Failed/interrupted UI mutation attempts persist across server restarts; history changes cannot waive audit failures.

### Fixed
- Missing reports and missing/failed controls no longer imply successful verification.
- Include the Node review server in the npm package.
- Missing per-rule coverage no longer claims that no tests exercised a mutant; killed and survived outcomes are shown independently.

## Earlier unreleased work

### Added
- Syntax highlighting on every code window from canon's lexers: the wire carries a run-length mark beside every code line, the page paints spans in GitHub's light and dark colours, and the site's fenced blocks are painted the same way; `RicesTax.Marks` is shared by the page and the library
- A mutant's diff is a line diff: the lines both sides share are context and only the lines that went and came are marked, on the card, in the zoom, and in the copied text, so a mutant that removes one alternative of a long case shows one line; `RicesTax.Diff` is shared by the page and the library
- The mutation from the page: `canon.yaml`'s runtime names the `command`, the page shows "run mutation" and the stale-files banner offers it, both servers run it with its log on show and re-read the project when it ends, decisions go on meanwhile and carry over to every mutant that is the same, and `tools/mutate.sh` swaps the run in whole
- A Makefile as the front door: `make mutate`, `make assess`, `make pay`, `make audit`, `make check`, `make tangle`, `make site`, `make wasm`, and the rest, each rule canonically commented and checked by canon through its `make` dialect
- The umbrella: `ricestax canon <command>` runs any canon command, natively and from the npm package; `ricestax site` renders every root's pages to a static site with the pay page over a snapshot; the verbs are a table in `RicesTax.Api` from which the usage and the Node binary's table are generated; audit exits 2 when it could not run and says whether a runtime was present; `.github/workflows/audit.yml` audits the repository
- The sources are Folio pages: `docs/reference/` tangles to `src/`, `app/`, and `test/`, the design moves to `docs/explanation/design.md`, the procedures to `docs/how-to/`, and a tutorial takes a project to its first audit; a page is a row of the Why queue; a mutant reported at a line of a tangled file lands on the unit whose page holds that line; the page's URLs are relative so it can live under a site
- The What queue is raised: one row per unit that requires a canonical comment, keyed `name/<unit id>` under `canonical_vetting/name/`, pending with canon's four words, judged on the name and signature with the body as the second side of the digest, decided on its own card, counted by assess and failed by audit while open or stale; a project quiets it with an exemption for the kind `name`. canon's Haskell dialect now attaches a function's equations to its signature, so a function's How is its body and its What carries its signature
- The whole definition on a mutant card, in the zoom, and in "Copy mutation", and each rule's source, carry the doc comment and pragmas above the binding and any comment touching it below; the digest a verdict is judged against is unchanged. audit fails on any stale row of a kind canon does not judge itself
- WebAssembly for both halves under one build: the verbs' work moved into `RicesTax.Core`; `RicesTax.Api` is the export table and dispatcher; `ricestax gen` writes the wasm entry module, its cabal file, `npm/api.mjs`, and `npm/index.d.ts` from that table; `tools/wasm.sh` builds core and page with GHC's wasm backend through cabal, run as `stack build --exec tools/wasm.sh`; `npm/` carries the launcher on Node's own WASI, the pay server, and `ricestax` for Node. canon's git calls go through a replaceable runner the launcher supplies
- The three verbs: `ricestax assess` determines what is owed and records the run, `ricestax pay` is the page, and `ricestax audit` proves the tax is paid, failing on open, stale, uncommitted, unrecorded, or expired rows, with `--json` for CI. canon's files are the only format: the runtime moves into `canon.yaml`, the runs into `canonical_runs.yaml`, and `rices-tax.yaml` and `mutation_runs.yaml` are retired
- Exemptions: `canonical_exemptions.yaml` declares a subject not owed until a version, with reason and kinds; assess counts exempt rows apart, pay folds them into an Exempt section with an "Exempt this subject…" form and a Lift button, and audit honours them until they expire
- The wasm spike: canon's library compiles on the wasm32-wasi toolchain once grammatical-parsers is vendored under a plain build type, which is what the npm packaging of `DEC-npm-packaging` needs first
- assess refuses rows for a file that changed since the run, and a mutant's before-text comes from the report's recorded lines rather than the current file, so an edit after the run cannot change identities
- "Copy mutation" on every mutant card and row: the whole block as plain text, header, diff, rules with sources, probe reading, and the definition, with a moment's confirmation on the button
- Speed: the server gathers once and holds the payload, answers a decision with the changed row, serves definitions on demand and rule sources once, and gzips the wire; the adapter's ordinal, sibling-reading, and binding-reading lookups are indexed rather than scanned; the page applies a decision on the click, shows twenty cards at a time, and renders a collapsed row's body only when opened
- Rice's Tax mutates itself first: a sydtest corpus of ten rules over the identity hash, the adapter's chunking, coverage and gap words, and the model's dispositions, each citing a requirement; the `mutation` flag instruments the library with the sydtest-mutation plugin; `tools/mutate.sh` runs the driver natively and records the run; `rices-tax.yaml` names this project's own runtime
- The How queue: the sydtest-mutation adapter reads wavelet's report, augmented manifest, run facts, and probe observations, names each mutant as wavelet does, lands it on a canon unit, and classifies coverage gaps as work; `rices-tax ingest` writes the rows and `rices-tax import-records` migrates wavelet's decided headings; the page shows wavelet's mutant card whole, with the diff, the rules that looked and missed, the probe readings, gap rows, the zoom, and wavelet's four verdicts; `rices-tax.yaml` names a project's runtime; each row names the run it was decided against and `mutation_runs.yaml` records every run; a URL hash opens a queue
- `rices-tax review`, the native server over canon that serves the page, answers `GET /obligations`, and rewrites one vetting file on `POST /decide`, logging each decision it receives
- The Why queue as the first working page: cards with the comment tinted above its code, cited decisions and references by title, the signer from git blame, a sticky decide bar with note, revisit version, and the words good, bad, and deferred; a subject switcher per ledger file; rows for what was decided before the page loaded; the What and How tabs saying what they wait for. Its look follows wavelet's mutation review page
- `RicesTax.Wire`, the types both sides share, with aeson instances on the server and miso instances on the page
- The vetting ledger as canon's new directory layout, `canonical_vetting/`, decided as `DEC-subject-granularity` and `DEC-why-ledger-in-canon`
- The founding model: an obligation is what a machine raised and cannot decide, with a kind, an identity, a subject, the digests it was judged against, a verdict from the kind's own words, an optional argument, and a sign-off read from git; `RicesTax.Model` states it in types
- Three review queues, Why, What, and How, with Who, When, and Where derived and raising nothing; mutation review is a subset of How
- The decisions ledger recording every founding choice, and six open decisions with a revisit version
- The review pages are Haskell compiled to WebAssembly with miso on the GHC wasm backend, recorded as `DEC-ui-frontend`; the `web/` package builds a first page that renders the kinds and their words from `RicesTax.Model`
- The Haskell dialect vendored from canon at commit f639753 so canon checks this project's own source
