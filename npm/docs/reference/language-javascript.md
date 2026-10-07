---
id: ricestax.reference.language.javascript
kind: reference
title: JavaScript
---
# JavaScript

Ingest with `ricestax init --languages javascript,folio`. Add `calm` when architecture
belongs in the same project. Existing configuration requires a deliberate merge;
see [migration](../how-to/adopt-existing-project.md).

Named declarations and bindings are extracted. Arrow functions assigned to variables are reviewed as bindings. JSX is outside this profile. Run application tests as well as the generated topology boundary test.

## Generate and exercise a starter

Prerequisites: Node.js 22 or newer.

```sh
ricestax scaffold architecture.calm.json --language javascript --out javascript-starter
cd javascript-starter
node tools/build.mjs compile
node tools/build.mjs test
ricestax canon model src/topology.mjs
ricestax mutate
ricestax assess
ricestax pay 8091
```

The source and expected behaviour come from the architecture’s service identities.
The catalog injects one boundary fault. Review its generated tests and add domain
tests before interpreting this as evidence about an application.

For documentation-to-code, enable `javascript` in the Folio embeddings and declare a
fenced block with `file=` and `def=` (or `part=` for scaffolding). Run
`ricestax canon tangle`, the compiler/tests above, and
`ricestax canon tangle --check`. The profile supplies the comment style for generated prose.

See [the language matrix](languages.md) for extraction boundaries, and
[the mutation guide](../how-to/run-mutations.md) for input manifests, evidence
patterns, outcomes, and retained reports.

## Worked service example

The [javascript greeting service](../../examples/greeting-service/README.md) includes
documented generation, executable tests, an explicit mutation catalog and review
commands. See the [example matrix](../../examples/README.md) for transport and
architecture roles and required tools.

For a complete worked example, follow the [JavaScript HTTP property-testing tutorial](../tutorials/http-javascript.md).
