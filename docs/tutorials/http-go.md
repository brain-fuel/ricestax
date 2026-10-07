---
id: ricestax.tutorial.http-go
kind: tutorial
title: Build and property-test a Go HTTP service
---
# Build and property-test a Go HTTP service

This tutorial takes the [Go example](../../examples/greeting-service-go/README.md)
from architecture and documented code through a running server, generated HTTP
checks, a deliberately broken implementation, and mutation review. Use the example
from the same source checkout as this tutorial; earlier npm releases do not contain
these property tests. You need Go 1.22+ and Node.js 22+ for Rice’s Tax.

## 1. Establish the project and its contract

From the repository root, enter `examples/greeting-service-go`. For a separate project,
copy this entire directory first, including `.ricestax`, lockfiles and configuration.
Read `architecture.calm.json`: it records the caller and service boundary. Read
`docs/reference/service.md`: its attributed code blocks generate `src/main.go`.
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
go test -count=1 -v ./src
ricestax canon tangle --check
```

The build helper installs the example’s test dependencies when necessary and compiles
without retangling. A successful test command exits zero; a compiler or dependency
failure is not a test result. Run the command under `run` in `commands.json`, then
visit `http://127.0.0.1:8097/greet?name=Ada`. Stop it with Ctrl-C. Tests manage their
own ephemeral listener, so they do not require that manual server.

## 3. Understand the property and its oracle

Open `src/main_test.go`. `rapid.Check` runs inside Go’s standard `testing` package. `httptest.NewServer` opens a real TCP listener; it is not a mocked response recorder. Generated rune slices include multibyte Unicode, controls, and URL punctuation. The client decodes JSON before comparing the complete response object.

Rapid supplements fixed regression cases. Generated names have known
non-whitespace boundaries and separately generated padding. The expected greeting
uses the core constructed before padding; it never calls the application’s trimming
function. The property also checks blank rejection, unsupported routing and methods,
status codes, JSON content type, and the whole decoded JSON object.

## 4. Make a failure, shrink it and replay it

In the source block in `docs/reference/service.md`, temporarily replace
`"Hello, " + name + "!"` with `"Hello, " + name`. Retangle and rebuild using step 2, then run the
test command. It must fail because the greeting lost its final exclamation mark.
This simple change can be caught by the fixed tests first.

For a failure that specifically exercises generation, use the final catalog mutation
in `ricestax.mutations.json`: it corrupts `+` inside a name. Apply its exact replacement
to the documented source block, retangle and rebuild. The generated property must
fail and print its counterexample. Inspect the minimized name rather than treating
a nonzero exit by itself as proof of an assertion failure.

Use the actual `-rapid.seed` or `-rapid.failfile` printed on failure. Failure files live under `src/testdata/rapid/` for this package. Preserve the file before deleting an isolated mutation run. This command demonstrates deterministic generation with an example seed;
substitute the failure’s actual seed or replay data when diagnosing a failure:

```sh
go test -count=1 -v ./src -run TestGeneratedHTTPContract -rapid.seed=123
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

## 6. Explore further with Go's native fuzzer

`FuzzHTTPGreeting` sends real HTTP requests for valid UTF-8 interiors up to 256
bytes, with known non-whitespace boundaries and ASCII padding. It skips invalid
UTF-8 and larger inputs rather than claiming a policy for them. Its fixed seed
corpus runs during ordinary `go test`; opt into coverage-guided exploration with:

```sh
go test ./src -run '^$' -fuzz '^FuzzHTTPGreeting$' -fuzztime=10s -parallel=2
```

A discovered failure is written under `src/testdata/fuzz/FuzzHTTPGreeting`. Keep it
as a regression and use the replay command printed by Go. This complements Rapid's
structured domain; it does not replace its blank-input and routing properties.
