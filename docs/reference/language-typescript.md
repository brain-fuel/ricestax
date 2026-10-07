---
id: ricestax.reference.language.typescript
kind: reference
title: TypeScript
---
# TypeScript

Ingest with `ricestax init --languages typescript,folio`. Add `calm` when architecture
belongs in the same project. Existing configuration requires a deliberate merge;
see [migration](../how-to/adopt-existing-project.md).

The starter compiles a typed module to JavaScript before testing it. The profile does not type-check; tsc does. TSX is outside the profile. Type-level declarations do not imply runtime mutation coverage.

## Generate and exercise a starter

Prerequisites: Node.js 22 or newer and tsc on PATH.

```sh
ricestax scaffold architecture.calm.json --language typescript --out typescript-starter
cd typescript-starter
node tools/build.mjs compile
node tools/build.mjs test
ricestax canon model src/topology.ts
ricestax mutate
ricestax assess
ricestax pay 8091
```

The source and expected behaviour come from the architecture’s service identities.
The catalog injects one boundary fault. Review its generated tests and add domain
tests before interpreting this as evidence about an application.

For documentation-to-code, enable `typescript` in the Folio embeddings and declare a
fenced block with `file=` and `def=` (or `part=` for scaffolding). Run
`ricestax canon tangle`, the compiler/tests above, and
`ricestax canon tangle --check`. The profile supplies the comment style for generated prose.

See [the language matrix](languages.md) for extraction boundaries, and
[the mutation guide](../how-to/run-mutations.md) for input manifests, evidence
patterns, outcomes, and retained reports.

## Worked service example

The [typescript greeting service](../../examples/greeting-service-typescript/README.md) includes
documented generation, executable tests, an explicit mutation catalog and review
commands. See the [example matrix](../../examples/README.md) for transport and
architecture roles and required tools.

For a complete worked example, follow the [TypeScript HTTP property-testing tutorial](../tutorials/http-typescript.md).
