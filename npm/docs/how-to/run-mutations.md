---
id: ricestax.how-to.run-mutations
kind: how-to
title: Run mutation tests with the project toolchain
---
# Run mutation tests with the project toolchain

The npm runner executes explicit source replacements using your project's
compile and test commands. It applies to Java, JavaScript, TypeScript, Python,
Go, Haskell, Kotlin, CALM-derived data, and ANTLR4 sources. It does not discover
all possible mutations or supply every compiler. The scaffolder supplies one
executable boundary mutation and its commands for each starter target.

Create `ricestax.mutations.json`:

```json
{
  "schema": 1,
  "inputs": ["src", "test", "package.json"],
  "compile": ["node", "--check", "src/answer.mjs"],
  "test": ["node", "--test", "--test-reporter=tap", "test/answer.test.mjs"],
  "evidence": {"passed": "# pass 1", "failed": "not ok"},
  "timeoutMs": 180000,
  "mutations": [
    {"file": "src/answer.mjs", "original": "return true;", "replacement": "return false;"}
  ]
}
```

Use evidence patterns appropriate to the real test reporter. The example expects
one passing test; do not copy it onto a different suite without adjusting it.
Commands are argument arrays, not shell strings. Compilation must not run tests,
and test failure output must distinguish assertions from infrastructure errors.
Include source, tests, build files, lockfiles, generator inputs, and any scripts
in `inputs`. Missing inputs make the copied build incomplete. Symlinks are refused.

Run `ricestax mutate`. The runner copies only declared inputs into isolated run
directories, compiles and tests an unchanged control, then one mutation at a time.
Each original string must match exactly once. It verifies neither compilation nor testing
regenerated the mutated source. Subprocess timeouts terminate the process group
on Unix. Keep commands trusted: the copies isolate files but are not a security
sandbox, and commands inherit the environment and its toolchain.

Outcomes are `killed`, `survived`, `invalid`, `timeout`, and
`infrastructure_error`. A test kill requires a failing test process plus the
configured failure evidence. Exit zero without passing-test evidence is an
infrastructure error. No outcome is relabelled equivalent automatically.

Completed reports, source hashes, input copies, and command results live under
`.mut/runs/`; `.mut/current` points to the latest completed report. Baseline failure
keeps the previous report, with `.mut-attempt.json` marking it historical.
A completed run with survivors exits 1 but remains reviewable. Configuration or
baseline failure exits 2. All mutations killed exits 0; this says nothing about
faults outside the selected catalog.

Configure review in `canon.yaml`:

```yaml
runtime:
  name: ricestax-catalog
  artefacts: .mut/current
  package: .
  tests: test
  command: ricestax mutate
kinds:
  mutant:
    unreviewed: open
    logical-equivalency: closed
    inadequate-testing: work
    unnecessary-code: work
    needs-research: deferred
```

Then `ricestax assess` and `ricestax pay 8091`. The runner supplies no coverage
probes or covering-test attribution. Review the retained logs when deciding why
a fault survived. For a killed fault, the logs identify the configured suite,
not a claimed per-test coverage analysis.

If an interrupted process leaves `.mut/runner.lock`, inspect its `owner.json` and
confirm that process has stopped before removing that lock directory. Retained
attempt status keeps the previous report historical until a complete rerun.
