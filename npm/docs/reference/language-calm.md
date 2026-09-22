---
id: ricestax.reference.language.calm
kind: reference
title: CALM architecture
---
# CALM architecture

Ingest with `ricestax init --languages calm,folio`. Add `calm` when architecture
belongs in the same project. Existing configuration requires a deliberate merge;
see [migration](../how-to/adopt-existing-project.md).

The profile selects .calm.json, preventing arbitrary JSON from being treated as architecture. It accepts the CALM 1.2 schema URI. Its scaffold target emits a JSON service inventory with executable boundary checks. These checks do not prove deployment or full schema conformance. ref:calm-1.2

## Generate and exercise a starter

Prerequisites: Node.js 22 or newer; use the official CALM validator for full schema validation.

```sh
ricestax scaffold architecture.calm.json --language calm --out calm-starter
cd calm-starter
node tools/build.mjs compile
node tools/build.mjs test
ricestax canon model architecture.calm.json
ricestax mutate
ricestax assess
ricestax pay 8091
```

The source and expected behaviour come from the architecture’s service identities.
The catalog injects one boundary fault. Review its generated tests and add domain
tests before interpreting this as evidence about an application.

For documentation-to-code, enable `calm` in the Folio embeddings and declare a
fenced block with `file=` and `def=` (or `part=` for scaffolding). Run
`ricestax canon tangle`, the compiler/tests above, and
`ricestax canon tangle --check`. CALM uses comment-free output; descriptions belong in JSON fields.

See [the language matrix](languages.md) for extraction boundaries, and
[the mutation guide](../how-to/run-mutations.md) for input manifests, evidence
patterns, outcomes, and retained reports.

## Worked service example

The [calm greeting service](../../examples/greeting-service-calm/README.md) includes
documented generation, executable tests, an explicit mutation catalog and review
commands. See the [example matrix](../../examples/README.md) for transport and
architecture roles and required tools.
