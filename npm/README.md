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

## 0.3 project workflows

The 0.3 working release adds packaged ingestion profiles for Java, JavaScript,
TypeScript, Python, Go, Haskell, Kotlin, CALM 1.2, and ANTLR4. It also provides
Folio documentation-to-code generation, CALM-derived project starters, and an
explicit-catalog mutation runner using each project's compile/test toolchain.

```sh
ricestax languages
ricestax init --languages java,calm,folio
ricestax canon model src/Example.java
ricestax assess
ricestax pay 8091
```

Ingestion and the viewer require Node.js 22+ through npm; they do not require
Go, Haskell, or parser-generator executables. Compiling and mutation-testing a
project requires that project's language toolchain. The starter generators
create a tested service-membership boundary, not a complete domain application.

- [Start a new project](docs/tutorials/new-project.md)
- [Build a documented HTTP service from architecture](docs/tutorials/architecture-to-service.md)
- [Migrate an existing project](docs/how-to/adopt-existing-project.md)
- [Generate sources from documentation](docs/how-to/generate-from-documentation.md)
- [Run mutations](docs/how-to/run-mutations.md)
- [Language support and limits](docs/reference/languages.md)
- [Commands and generated files](docs/reference/project-commands.md)
- [What the evidence establishes](docs/explanation/ingestion-generation-evidence.md)
- [0.3 acceptance and later work](docs/explanation/release-0.3.md)

## Standards

This project follows `canon`'s ten documentation rules and is checked by
`canon`. The rules are stated once, under "Documentation rules" in canon's
`README.md` (ref `canon` in `canonical_refs.yaml`), and are not restated here
so that they cannot drift. Decisions live in `canonical_decisions.yaml`, references in
`canonical_refs.yaml`, and verdicts on both, and on every comment, page, name, and mutant, under
`canonical_vetting/`.
Nothing outside the repository is trusted. Anything that has no canonical
place yet lives in `to_be_removed/` until it does, and is then deleted.

## The pages

The rest of what this README used to say is now pages under `docs/`, in the
Folio, split by Diátaxis:

| Quadrant | Pages |
|----------|-------|
| `docs/tutorials/` | `first-audit.md`, from an empty project to a passing audit |
| `docs/how-to/` | `pay-your-tax.md`, `audit-in-ci.md`, `build-for-webassembly.md`, `publish-to-npm.md` |
| `docs/reference/` | one page per module, tangling to `src/`, `app/`, and `test/`: `model`, `wire`, `sydtest`, `what`, `core`, `api`, `site`, `cli`, `corpus` |
| `docs/explanation/` | `design.md`: the obligation, the six questions, the kinds, the flow, and where each part comes from |

Code windows use the configured language lexers for highlighting; unsupported
fence languages remain plain text (`DEC-highlighting`).

The reference pages are the sources: `ricestax canon tangle` writes
`src/RicesTax/*.hs`, `app/Main.hs`, and `test/Corpus.hs` from them, the
tangled files stay committed, and a tangled file that differs from its page
fails the check (`DEC-self-folio`, `DEC-tangling`). The review page under
`web/app/Main.hs` is still hand-written. `ricestax site _site` renders every
page to a static site, which is what ricestax.org serves (`DEC-site`).

## The verbs

`ricestax assess`, `ricestax pay`, and `ricestax audit` are the three moments
of the tax, after its three actors: the office that works out what is owed,
the taxpayer, and the auditor (`DEC-three-verbs`). Around them is tooling:
`ricestax canon <command>` runs any canon command at the root, so one npm
package carries canon too and tangling is `ricestax canon tangle`;
`ricestax site <out> [<root>...]` renders the pages; and `ricestax gen`,
native only, writes the wasm entry and the Node wrappers from the export
table. The verbs are a table in `RicesTax.Api` beside the exports, and the
usage text and the Node binary's table are generated from it
(`DEC-umbrella-surface`). `ricestax` with no arguments prints them.

All three verbs run at the root of the project and read and write only
canon's files: `canon.yaml` for the languages, the kinds, and the runtime;
`canonical_refs.yaml`, `canonical_decisions.yaml`, `canonical_exemptions.yaml`,
`canonical_runs.yaml`, `canonical_vetting/`, and `canonical_history/`
(`DEC-canon-is-the-format`).
audit exits 0 when the tax is paid within its exemptions, 1 when it is not,
and 2 when it could not run; `--json` writes the same report whatever the
code, and says whether a runtime was present.

## The queues

Why is canon's vetting: comments, decisions, references, and pages. What is
one card per unit that requires a canonical comment: the name and the
signature, with the body beneath them as the second side, judged Good when
they state, in full words, the fact the unit establishes; a project that
cannot pay yet quiets the queue with an exemption for the kind `name`, so the
debt stays counted (`DEC-what-raised`). How is wavelet's mutation review,
whole: each surviving mutant is a card with the diff, the rules that looked
and missed with their sources, what the probe recorded, and wavelet's four
verdicts; coverage gaps are work; the whole definition and each rule's source
carry their comments (`DEC-whole-block`). The review adapter reads sydtest-compatible mutation reports, including the
explicit-catalog npm runner and Refine reports; `tools/mutate.sh` runs it on this
project, which pays its own tax first (`DEC-own-tests-sydtest`).

## Layout

```
rices-tax/
├── README.md, CHANGELOG.md
├── canon.yaml                  # languages, kinds, and the runtime
├── canonical_refs.yaml, canonical_decisions.yaml, canonical_exemptions.yaml, canonical_runs.yaml
├── canonical_vetting/          # a directory per kind, a file per subject
├── docs/                       # the pages: tutorials, how-to, reference (the sources), explanation
├── src/RicesTax/, app/, test/  # tangled from docs/reference/, committed
├── web/                        # the review page, Haskell compiled to WebAssembly with miso
├── wasm/                       # the core's cabal project and the vendored parser
├── npm/                        # the package: launcher, pay server, bin, generated api and types
├── grammars/                   # the Haskell dialect and the Folio, vendored from canon
├── tools/                      # mutate.sh and wasm.sh
├── .github/workflows/audit.yml # the umbrella audits itself
└── to_be_removed/              # material awaiting a canonical place
```

## Building

`make` lists the targets: build, test, mutate, assess, pay, audit, check,
tangle, site, wasm, gen, and clean, each a canonically commented rule of the
Makefile, which canon checks like any other source (`DEC-make-dialect` in
canon's ledger). Underneath they are Stack commands:

```
stack build
stack test
stack exec -- ricestax pay 8080 web/public
stack exec -- ricestax canon check
```

`canon` is built from its checkout beside this project, `../canon`, as
`stack.yaml` explains. The WebAssembly halves and the npm package are built
with `stack build --exec tools/wasm.sh`; the how-to page on building for
WebAssembly says what that needs.

### Mutation decision history (0.2.0)

The How page separates Needs attention, Decisions, and History. An explicit kill
resolves an earlier testing-gap verdict; a missing entry remains unverified.
Archive resolved decisions individually or together, undo or restore them, and
retire obsolete decisions with a reason. Original verdicts remain unchanged.

`canonical_history/mutations.yaml` retains versioned lifecycle events, mutation
and decision snapshots, run evidence, source digests, and SHA-256 checksums.
Commit that file to record authorship. An archived mutant returning as a survivor
reappears for attention, and history changes never waive the audit gate.
See [the review guide](docs/how-to/pay-your-tax.md).

The [worked examples](examples/README.md) include greeting services in seven
general-purpose languages, an ANTLR4 expression language and a CALM checkout
architecture. Each has appropriate assertions and mutation checks.
