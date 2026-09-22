# Rice’s Tax 0.3.2

Published to the public npm registry as ricestax@0.3.2 on 22 September 2026.
Public registry and clean-install verification is recorded in publication-verification.json.
Artifact: ricestax-0.3.2.tgz (3769375 bytes; 388 files).
SHA-256: a9d012a90fe1b9c139d0f1b9de0b64df0648649d221f99be5e360aa50674df3a
Integrity: sha512-WzFdoGBObugBzitOyt9XgdqRRVOfKJOLZsG9K3akFpY64C090JS6anrxTPTjwoV1fmi1nR/qJNeagymBoyVlBw==

## Changes

All seven general-purpose examples are HTTP applications with tests in the same
language. Java and Kotlin use JDK HttpServer/HttpClient, Python uses http.server
and unittest, Go uses net/http and testing, Haskell uses WAI/Warp and Hspec,
and JavaScript/TypeScript use Node HTTP and node:test in their respective source
languages. All tests send real HTTP requests to the application on ephemeral ports.
The Node process adapters are removed. TypeScript compiles its server and tests
with pinned dependencies. Haskell uses a pinned Stack snapshot.

ANTLR’s evaluator and CLI assertions are Java; CALM remains a separate model
with JavaScript architecture-policy assertions. Tutorials, example READMEs and
the language matrix now explain these roles. Every HTTP example has separate
input-validation and path-rejection mutants.

## Verification

- Native: 150 Canon tests and 34 Rice’s Tax tests passed.
- npm regression suite: 13 tests passed on the rebuilt 0.3.2 core.
- Final tarball, installed with an empty npm cache: all 9 projects passed
  generation/check, compilation, native tests, source ingestion with no errors,
  and review-report loading. All 18 catalog mutants were killed.
- Package check requires native test sources and rejects legacy server adapters.
- Tangling drift check and local documentation links passed.
- Both WebAssembly components rebuilt; caches and example build outputs excluded.
- See example-acceptance.log and tools/check-examples-release.mjs for reproduction.

## Audit and release instruction

The audit did not pass: 869 failing findings, 168 stale entries,
0 uncommitted verdict findings and 0 unrecorded runs.
Categories overlap; full output is retained in audit.json.

In the ongoing publication workflow, after disclosure of this audit debt, the
owner directed: “Let's fix them in v0.3.2”. Publication follows that specific
owner direction despite the repository audit gate. It does not approve underlying
review findings or create a standing exception for subsequent releases.

## Limits

These are teaching servers without authentication, TLS or persistence. Runtime
Unicode whitespace sets can differ. The mutation catalogs are bounded, not
exhaustive coverage. CALM assertions concern model intent, not deployed enforcement
or full schema conformance. The ANTLR evaluator uses signed 64-bit arithmetic.
Node is still required for Rice’s Tax/build helpers, and for JS/TS applications.
The native Rice’s Tax build uses the sibling Canon checkout.
