---
id: ricestax.reference.language.antlr4
kind: reference
title: ANTLR4
---
# ANTLR4

Ingest with `ricestax init --languages antlr4,folio`. Add `calm` when architecture
belongs in the same project. Existing configuration requires a deliberate merge;
see [migration](../how-to/adopt-existing-project.md).

Grammar ingestion is separate from executing generated parsers. The starter generates a Java-target recognizer, compiles it, and checks a declared service and an unknown service. Its mutation changes an accepted literal; lexer errors and parser errors both reject input. Other ANTLR target runtimes need their own build/test commands. ref:antlr4-tool

## Generate and exercise a starter

Prerequisites: A JDK and ANTLR 4.13.2 complete JAR, with ANTLR_JAR set to its absolute path.

```sh
ricestax scaffold architecture.calm.json --language antlr4 --out antlr4-starter
cd antlr4-starter
node tools/build.mjs compile
node tools/build.mjs test
ricestax canon model src/Topology.g4
ricestax mutate
ricestax assess
ricestax pay 8091
```

The source and expected behaviour come from the architecture’s service identities.
The catalog injects one boundary fault. Review its generated tests and add domain
tests before interpreting this as evidence about an application.

For documentation-to-code, enable `antlr4` in the Folio embeddings and declare a
fenced block with `file=` and `def=` (or `part=` for scaffolding). Run
`ricestax canon tangle`, the compiler/tests above, and
`ricestax canon tangle --check`. The profile supplies the comment style for generated prose.

See [the language matrix](languages.md) for extraction boundaries, and
[the mutation guide](../how-to/run-mutations.md) for input manifests, evidence
patterns, outcomes, and retained reports.

## Worked service example

The [antlr4 greeting service](../../examples/greeting-service-antlr4/README.md) includes
documented generation, executable tests, an explicit mutation catalog and review
commands. See the [example matrix](../../examples/README.md) for transport and
architecture roles and required tools.
