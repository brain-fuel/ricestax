---
id: ricestax.tutorial.http-javascript
kind: tutorial
title: Build and property-test a JavaScript HTTP service
---
# Build and property-test a JavaScript HTTP service

This tutorial takes the [JavaScript example](../../examples/greeting-service/README.md)
from architecture and documented code through a running server, generated HTTP
checks, a deliberately broken implementation, and mutation review. Use the example
from the same source checkout as this tutorial; earlier npm releases do not contain
these property tests. You need Node.js 22+ and npm.

## 1. Establish the project and its contract

From the repository root, enter `examples/greeting-service`. For a separate project,
copy this entire directory first, including `.ricestax`, lockfiles and configuration.
Read `architecture.calm.json`: it records the caller and service boundary. Read
`docs/reference/service.md`: its attributed code blocks generate `src/greeting.mjs`.
Rice’s Tax tangles the code you write in those blocks; it does not invent application
behavior from prose or CALM relationships.

The contract is GET `/greet?name=Ada` returning status 200 and the JSON object
`{"greeting":"Hello, Ada!"}`. Missing and blank names return 400. Unsupported
paths and the tested unsupported methods return 404. Read the
[property domain and limits](../reference/example-properties.md) before extending it.

## 2. Build, test and run the server

```sh
ricestax canon tangle
node tools/build.mjs
node --test --test-reporter=tap test/service.test.mjs
ricestax canon tangle --check
```

The build helper installs the example’s test dependencies when necessary and compiles
without retangling. A successful test command exits zero; a compiler or dependency
failure is not a test result. Run the command under `run` in `commands.json`, then
visit `http://127.0.0.1:8097/greet?name=Ada`. Stop it with Ctrl-C. Tests manage their
own ephemeral listener, so they do not require that manual server.

## 3. Understand the property and its oracle

Open `test/service.test.mjs`. Node’s `node:test` awaits `fc.assert(fc.asyncProperty(...))`. Every generated tuple sends four HTTP requests; a thrown assertion rejects the property and fails the Node test.

fast-check supplements fixed regression cases. Generated names have known
non-whitespace boundaries and separately generated padding. The expected greeting
uses the core constructed before padding; it never calls the application’s trimming
function. The property also checks blank rejection, unsupported routing and methods,
status codes, JSON content type, and the whole decoded JSON object.

## 4. Make a failure, shrink it and replay it

In the source block in `docs/reference/service.md`, temporarily replace
`${name.trim()}!` with `${name.trim()}`. Retangle and rebuild using step 2, then run the
test command. It must fail because the greeting lost its final exclamation mark.
This simple change can be caught by the fixed tests first.

For a failure that specifically exercises generation, use the final catalog mutation
in `ricestax.mutations.json`: it corrupts `+` inside a name. Apply its exact replacement
to the documented source block, retangle and rebuild. The generated property must
fail and print its counterexample. Inspect the minimized name rather than treating
a nonzero exit by itself as proof of an assertion failure.

Set `FC_SEED` and `FC_PATH` to the seed and shrink path printed by fast-check to replay the minimized case. Keep the generator and dependency lock unchanged. This command demonstrates deterministic generation with an example seed;
substitute the failure’s actual seed or replay data when diagnosing a failure:

```sh
FC_SEED=123 node --test test/service.test.mjs
```

Restore the documented implementation, retain the discovered case as an independent
fixed regression, retangle and rebuild. Re-run the tests and drift check. Do not
weaken an assertion to make the broken implementation pass.

## 5. Challenge and review the evidence

```sh
ricestax mutate
ricestax assess
ricestax pay 8091
```

The seven catalog faults remove blank rejection, path rejection, method rejection,
trimming, greeting punctuation, the error status, or preservation of `+`. Each
mutation is compiled and tested in isolation using the same test sources. Inspect
`.mut/current` for compile and test output: killed means a recognized test failure,
while a compiler failure or infrastructure error is a different outcome. The viewer
shows evidence for review; seven killed faults do not establish exhaustive coverage.

When migrating existing code, keep its tests independent and adapt `commands.json`
and the catalog’s input list to include its build manifests and dependency locks.
Follow [adopting an existing project](../how-to/adopt-existing-project.md), then extend
the contract and generators together when you introduce new application behavior.
