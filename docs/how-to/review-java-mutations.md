---
id: ricestax.how-to.review-java-mutations
kind: how-to
title: Review Offscript's Java mutations
---
# Review Offscript's Java mutations

Offscript, in the sibling `../offscript` checkout, runs a bounded source mutation
catalog using Java 25 and its Maven wrapper. Build this checkout with `stack build`,
then run from Offscript:

```sh
./mvnw refine:mutate
RICES_TAX_BIN="$(cd ../rices-tax && stack path --local-install-root)/bin/ricestax"
"$RICES_TAX_BIN" assess
"$RICES_TAX_BIN" audit --json
"$RICES_TAX_BIN" pay 8091 ../rices-tax/web/public
```

A nonzero mutation exit means a survivor or inconclusive result remains. Continue to
assessment to see survivors; do not turn that exit into a passing CI status. The
baseline must pass before any mutant runs. Each mutant is compiled into an isolated
copy and tested against both generated properties and application JUnit tests, with
no regeneration step that could erase the fault.

Offscript's `canon.yaml` points the runtime at `.mut/current`. The runner writes the
existing adapter's `out/report.json`, `augmented/manifest-augmented.json`, `run.json`,
and `out/observations.json` layouts. The driver is named `refine-source-mutation`,
not sydtest. Compilation failures and infrastructure failures are mapped to the
adapter's `skipped` outcome, while `status` in the JSON preserves their distinct
causes. The mutation command fails on either; a ledger audit alone is insufficient.
Timeouts remain timeouts. There are no coverage observations or claimed covering
rules. The two test-layer results, logs, source snapshots and SHA-256 hashes remain
in `.mut/runs/` for inspection.

Only survivors enter the review queue. A killed mutant is not a proof of every
property; a survivor is not automatically equivalent. Review the original and
replacement, then inspect the tests and logs. Java has no method parser in this
adapter. When the Haskell binding lookup finds no definition, the context digest
covers the entire source file, so any file edit conservatively stales its review.
The existing npm/WASM bundle must be rebuilt to acquire that fallback; use the
newly built native binary for this checkout until then.

Offscript configures mutation review only, with no language grammar. This makes no
claim about Java names, comments, or documentation. Its build uses Refine 0.4.0 Maven artifacts from Maven Central. The eight-fault
catalog now has no survivors under the improved generated checks; a later survivor
will appear in this same review workflow.
