# Rice’s Tax 0.3.0 release

Published to the public npm registry on 22 September 2026 as ricestax@0.3.0,
with the latest tag. Public registry integrity matches the tested artifact.
A clean registry installation passed the CLI check and includes all nine examples;
see publication-verification.json. Offscript’s global installation was not changed.

Artifact: `ricestax-0.3.0.tgz` (3763108 bytes; 392 files).
SHA-256: `73dcc3c890aaf0f90f035f64cbebb12c9ae3bc8f938a1b4e18504e719586a966`
Integrity: `sha512-nosoNquD8r0IQ7Nt5h7AXuWzrv3J7HQt7EYGmboqKjKOgvnyXkR+u2dA6y+mghrtsdOuTOQSLJIa+IDznzuxhw==`

## Delivered

- Bundled ingestion profiles for Java, JavaScript, TypeScript, Python, Go,
  Haskell, Kotlin, CALM 1.2 and ANTLR4; Folio supports code and documentation-only projects.
- `ricestax languages` and safe `init --languages ...` project setup.
- CALM nodes, relationships and flows with stable IDs, source spans, descriptions,
  duplicate/reference checks and stale review detection. Full schema validation remains separate.
- Python first-statement module/class/function docstrings; PEP 8 is documented as
  a style convention, not falsely claimed as an implemented linter.
- Folio tangling for all nine targets, including closed block comments and valid
  comment-free JSON, deterministic output, and stale generated-file checks.
- CALM-derived starters with executable service-boundary tests for all nine targets.
  These are bounded starters, not inferred business applications or deployments.
- A language-independent explicit-catalog mutation runner with isolated inputs,
  green controls, distinct outcomes, test evidence, timeouts, source hashes,
  compile/test regeneration detection and retained reports. No coverage probes
  or exhaustive automatic mutation discovery are claimed.
- Worked greeting-service examples for all nine targets, including generated policy,
  real HTTP tests and catalog faults. JavaScript owns its HTTP server; other code
  targets use a Node process adapter. ANTLR4 supplies a Java-backed name parser,
  and CALM supplies architecture alongside the JavaScript service.
- Diátaxis tutorials, migration/generation/mutation how-to guides, nine language
  references, command reference, and explanations of evidence and future scope.
- Ingestion failures are visible in every viewer tab and cannot display a green
  complete-review state. Core ingestion improvements also live in the Canon dependency.

## Verification

- Canon dependency: 150 tests passed.
- Rice’s Tax native corpus: 34 tests passed.
- npm regression tests: 13 passed, including malformed source in every code
  profile, CALM identity/reference checks, docstrings, stale reviews, setup safety,
  deterministic scaffolding, docs-only projects, regeneration and runner failures.
- A fresh tarball installation passed all nine language acceptance runs using
  real installed compilers/tests: model, attached documentation, baseline tests,
  a confirmed mutation kill, and the review adapter. CALM uses JSON parsing and
  architecture/inventory assertions; ANTLR4 generates and compiles a Java recognizer.
- All nine packed targets also passed deterministic documentation-to-code output,
  execution of generated code/data, and detection of an edited generated output.
- All nine worked greeting-service examples passed from a fresh tarball install:
  documentation generation/check, source ingestion, real HTTP assertions, a killed
  catalog fault, and loading the resulting report through the review API.
  Reproduce with tools/check-greeting-examples.mjs <installed-package-directory>.
  Evidence: /var/folders/rn/mnys6xcs59ncglx33n22717h0000gn/T/ricestax-greeting-zYVN7q.
- Brave rendered the incomplete-review warning; mobile layout fit at 390px and
  no JavaScript errors were observed.
- Native tangling check passed. Local documentation links resolve. Installed
  package contents matched the packaged source/assets byte-for-byte.

## Outstanding audit

The self-audit recorded before the expanded examples was failing: 861 failing findings,
168 stale entries, 2715 uncommitted verdict findings,
and 0 unrecorded runs. Categories overlap. New language/documentation
scope raises additional review obligations; no verdicts were automatically approved.
There were no remaining source parse failures in the final self-audit.

The owner's 0.2.0 audit exception applied to that exact artifact. The owner subsequently instructed “publish” after disclosure of the failing audit.
That instruction authorizes publication of the exact SHA-256 artifact above
despite this audit gate; it does not approve any underlying review verdict.
The publication-time audit is retained in audit-at-publication.log. This release has not run a new complete
self-mutation campaign; the language acceptance mutations are bounded catalogs.
The working checkout retains pre-existing uncommitted work and has no Git remote;
no source tag or source push was made.

## Reproduce

Run `stack test`, `node --test test/npm/*.test.mjs`, and `./tools/wasm.sh`.
Package with `npm pack ./npm`, install into a clean prefix, then run:

```
node tools/check-language-release.mjs /absolute/path/to/installed/ricestax
node tools/check-tangling-release.mjs /absolute/path/to/installed/ricestax
```

The language acceptance command requires the language compilers on PATH,
a working JDK selection, and ANTLR_JAR pointing to the ANTLR 4.13.2 complete JAR.
It fails when a required toolchain is missing instead of silently skipping it.
The second command uses the isolated fixtures created by the first.
