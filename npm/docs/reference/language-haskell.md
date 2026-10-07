---
id: ricestax.reference.language.haskell
kind: reference
title: Haskell
---
# Haskell

Ingest with `ricestax init --languages haskell,folio`. Add `calm` when architecture
belongs in the same project. Existing configuration requires a deliberate merge;
see [migration](../how-to/adopt-existing-project.md).

The dialect joins type signatures to their equation bodies and handles export requirements. A signature is not a substitute for the implementation when computing stale review material. The starter uses only base.

## Generate and exercise a starter

Prerequisites: GHC on PATH for the starter; use Stack/Cabal for an established project.

```sh
ricestax scaffold architecture.calm.json --language haskell --out haskell-starter
cd haskell-starter
node tools/build.mjs compile
node tools/build.mjs test
ricestax canon model src/Topology.hs
ricestax mutate
ricestax assess
ricestax pay 8091
```

The source and expected behaviour come from the architecture’s service identities.
The catalog injects one boundary fault. Review its generated tests and add domain
tests before interpreting this as evidence about an application.

For documentation-to-code, enable `haskell` in the Folio embeddings and declare a
fenced block with `file=` and `def=` (or `part=` for scaffolding). Run
`ricestax canon tangle`, the compiler/tests above, and
`ricestax canon tangle --check`. The profile supplies the comment style for generated prose.

See [the language matrix](languages.md) for extraction boundaries, and
[the mutation guide](../how-to/run-mutations.md) for input manifests, evidence
patterns, outcomes, and retained reports.

## Worked service example

The [haskell greeting service](../../examples/greeting-service-haskell/README.md) includes
documented generation, executable tests, an explicit mutation catalog and review
commands. See the [example matrix](../../examples/README.md) for transport and
architecture roles and required tools.

For a complete worked example, follow the [Haskell HTTP property-testing tutorial](../tutorials/http-haskell.md).
