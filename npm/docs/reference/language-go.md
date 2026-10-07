---
id: ricestax.reference.language.go
kind: reference
title: Go
---
# Go

Ingest with `ricestax init --languages go,folio`. Add `calm` when architecture
belongs in the same project. Existing configuration requires a deliberate merge;
see [migration](../how-to/adopt-existing-project.md).

Methods take their name from tokens outside the receiver so a receiver type is not mistaken for the method. Compilation uses go test with no selected tests, then the real test run disables the test cache. The review UI itself needs no Go compiler.

## Generate and exercise a starter

Prerequisites: Go 1.22 or newer on PATH for this starter.

```sh
ricestax scaffold architecture.calm.json --language go --out go-starter
cd go-starter
node tools/build.mjs compile
node tools/build.mjs test
ricestax canon model topology.go
ricestax mutate
ricestax assess
ricestax pay 8091
```

The source and expected behaviour come from the architecture’s service identities.
The catalog injects one boundary fault. Review its generated tests and add domain
tests before interpreting this as evidence about an application.

For documentation-to-code, enable `go` in the Folio embeddings and declare a
fenced block with `file=` and `def=` (or `part=` for scaffolding). Run
`ricestax canon tangle`, the compiler/tests above, and
`ricestax canon tangle --check`. The profile supplies the comment style for generated prose.

See [the language matrix](languages.md) for extraction boundaries, and
[the mutation guide](../how-to/run-mutations.md) for input manifests, evidence
patterns, outcomes, and retained reports.

## Worked service example

The [go greeting service](../../examples/greeting-service-go/README.md) includes
documented generation, executable tests, an explicit mutation catalog and review
commands. See the [example matrix](../../examples/README.md) for transport and
architecture roles and required tools.

For a complete worked example, follow the [Go HTTP property-testing tutorial](../tutorials/http-go.md).
