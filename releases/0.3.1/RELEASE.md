# Rice’s Tax 0.3.1

Published to the public npm registry as ricestax@0.3.1 on 22 September 2026.
Public metadata and a clean registry installation were verified; see publication-verification.json.

Artifact: ricestax-0.3.1.tgz (3763786 bytes; 389 files).
SHA-256: 0de93afef14a4f3156fc8efe2e5867b5b698cdaba8fb8d44d142c02f07492a01
Integrity: sha512-0NN/nFWtO542q1QMFwpX60QX3zt4VTMOB/uGQCFjSe0/UMCdnKDUeOPaBYDw/gBkasV/Ii+I5DNktNsccNgXLw==

## Changes

- Replace greeting-service-antlr4 with expression-language-antlr4: documented
  integer expression grammar, generated Java parser, handwritten evaluator and
  positive/negative syntax and evaluation assertions.
- Replace greeting-service-calm with checkout-architecture-calm: documented
  checkout nodes and relationships, independent gateway and persistence policies.
- Retain seven general-purpose greeting service examples.
- Update tutorials, references, example index and explanation to match their roles.
- Correct the generated WebAssembly package version to 0.3.1.

## Verification

- Native: 150 Canon tests and 34 Rice’s Tax tests passed.
- npm regression suite: 13 tests passed from the freshly installed tarball.
- Tangling drift check and local documentation links passed.
- Rebuilt both WebAssembly components.
- Fresh installed artifact: all nine projects passed document generation/check,
  compilation, independent tests, source ingestion with no ingestion issues, and
  review-report loading. All 11 explicit catalog mutants were killed.
  Evidence: /var/folders/rn/mnys6xcs59ncglx33n22717h0000gn/T/ricestax-greeting-SUGtdT.
  Reproduce: tools/check-examples-release.mjs <installed-package-directory>,
  with the listed compilers, JAVA_HOME and ANTLR_JAR configured.

## Audit exception

Self-audit is failing: 869 failing findings, 168 stale entries,
0 uncommitted verdict findings and 0 unrecorded runs.
Categories overlap. Full results are in audit.json.

The owner explicitly requested “Fix it, make the docs match, and release v0.3.1”
after the existing audit debt and prior release exceptions were disclosed. This
release-specific instruction authorizes publication of the exact artifact above
despite the audit gate. It does not approve review findings or create a standing
exception. No review verdicts were marked approved for publication.

## Limits

The catalog mutations are bounded evidence, not exhaustive coverage. CALM checks
model intent, not deployed policy or full schema conformance. ANTLR semantics
live in a Java visitor; signed 64-bit operations can overflow. Service adapters
remain teaching transports. The native build uses the sibling Canon checkout.
