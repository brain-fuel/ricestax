---
id: ricestax.how-to.replay-property-failures
kind: how-to
title: Replay a property failure from an example mutation run
---
# Replay a property failure from an example mutation run

Use this when an example's mutation report contains a shrunk counterexample and
you want to reproduce it before deciding whether the tests or application need work.

1. Open the mutant's `test-result.json` under `.mut/current`. Confirm the compiler
   succeeded and the test output contains an assertion failure. Missing dependencies,
   timeouts and compiler errors need different repairs; they are not killed mutants.
2. Preserve the isolated mutant directory, including dependency manifests, locks,
   test sources and any failure cache. Replay depends on the generator as well as
   the seed. The files in this directory contain the deliberate fault.
3. Enter that directory and use the matching command below. Substitute the actual
   failure values; the placeholders are not runnable seeds.
4. Confirm the failure concerns the same behavior and inspect the minimized input.
   Add it as an explicit regression in your real project, restore or fix the
   implementation there, and rerun tests and mutations. Do not edit tests inside
   the saved evidence directory and then treat its old report as current evidence.

| Example | Replay |
| --- | --- |
| JavaScript | `FC_SEED=<seed> FC_PATH='<path>' node --test test/service.test.mjs` |
| TypeScript | `FC_SEED=<seed> FC_PATH='<path>' node --test build/test/service.test.js` |
| Python | `build/venv/bin/python3 -m unittest discover -s test -v` retries cached Hypothesis failures in `.hypothesis`; retain the printed arguments as an `@example` regression |
| Go | `go test -count=1 -v ./src -run TestGeneratedHTTPContract -rapid.seed=<seed>`; alternatively use the printed `-rapid.failfile` path |
| Haskell | `stack --no-terminal test --test-arguments='--no-color --seed=<seed>'`; add the reported `--match` to isolate one property |
| Java | `JETCHECK_RECHECK='<serialized case>' java -cp 'build:build/dependency/*' GreetingTest` |
| Kotlin | `KOTEST_SEED=<seed> java -cp 'build/greeting.jar:build/dependency/*' GreetingTestKt` |
| ANTLR4 | Set `ANTLR_JAR`, then `JETCHECK_RECHECK='<serialized case>' java -cp 'build:build/dependency/*' ExpressionTest` |
| CALM | `FC_SEED=<seed> FC_PATH='<path>' node --test test/architecture.test.mjs`; the failing test name identifies the property |

JetCheck also accepts `JETCHECK_SEED` in the Java and ANTLR examples to replay a
whole generation sequence. Go's native fuzz target has its own corpus and replay
commands; see the [Go tutorial](../tutorials/http-go.md). Commands shown here use
POSIX shell syntax and classpath separators.

A survivor is different: the current assertions did not reject the change. Review
its behavior and the [tested domain](../reference/example-properties.md), add a
missing independent property or regression when warranted, and run a fresh mutation
session before changing its verdict in the viewer.
