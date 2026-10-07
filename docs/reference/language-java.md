---
id: ricestax.reference.language.java
kind: reference
title: Java
---
# Java

Ingest with `ricestax init --languages java,folio`. Add `calm` when architecture
belongs in the same project. Existing configuration requires a deliberate merge;
see [migration](../how-to/adopt-existing-project.md).

Javadoc attaches through the Java dialect. Compile the source with javac or the project’s Maven/Gradle build; parsing alone is not Java type checking.

## Generate and exercise a starter

Prerequisites: JDK 17 or newer for the starter; use your application’s own Java target.

```sh
ricestax scaffold architecture.calm.json --language java --out java-starter
cd java-starter
node tools/build.mjs compile
node tools/build.mjs test
ricestax canon model src/Topology.java
ricestax mutate
ricestax assess
ricestax pay 8091
```

The source and expected behaviour come from the architecture’s service identities.
The catalog injects one boundary fault. Review its generated tests and add domain
tests before interpreting this as evidence about an application.

For documentation-to-code, enable `java` in the Folio embeddings and declare a
fenced block with `file=` and `def=` (or `part=` for scaffolding). Run
`ricestax canon tangle`, the compiler/tests above, and
`ricestax canon tangle --check`. The profile supplies the comment style for generated prose.

See [the language matrix](languages.md) for extraction boundaries, and
[the mutation guide](../how-to/run-mutations.md) for input manifests, evidence
patterns, outcomes, and retained reports.

## Worked service example

The [java greeting service](../../examples/greeting-service-java/README.md) includes
documented generation, executable tests, an explicit mutation catalog and review
commands. See the [example matrix](../../examples/README.md) for transport and
architecture roles and required tools.

For a complete worked example, follow the [Java HTTP property-testing tutorial](../tutorials/http-java.md).
