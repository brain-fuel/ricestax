---
id: ricestax.reference.language.python
kind: reference
title: Python
---
# Python

Ingest with `ricestax init --languages python,folio`. Add `calm` when architecture
belongs in the same project. Existing configuration requires a deliberate merge;
see [migration](../how-to/adopt-existing-project.md).

Functions/classes and their first-statement docstrings become review material. PEP 8 is a style guide, not a Python dialect. The generated example uses snake_case and four-space indentation. Use a separate linter for style enforcement; py_compile and assertions check different things. ref:pep-8 ref:pep-257

## Generate and exercise a starter

Prerequisites: Python 3 on PATH in addition to Node.js.

```sh
ricestax scaffold architecture.calm.json --language python --out python-starter
cd python-starter
node tools/build.mjs compile
node tools/build.mjs test
ricestax canon model src/topology.py
ricestax mutate
ricestax assess
ricestax pay 8091
```

The source and expected behaviour come from the architecture’s service identities.
The catalog injects one boundary fault. Review its generated tests and add domain
tests before interpreting this as evidence about an application.

For documentation-to-code, enable `python` in the Folio embeddings and declare a
fenced block with `file=` and `def=` (or `part=` for scaffolding). Run
`ricestax canon tangle`, the compiler/tests above, and
`ricestax canon tangle --check`. The profile supplies the comment style for generated prose.

See [the language matrix](languages.md) for extraction boundaries, and
[the mutation guide](../how-to/run-mutations.md) for input manifests, evidence
patterns, outcomes, and retained reports.

## Worked service example

The [python greeting service](../../examples/greeting-service-python/README.md) includes
documented generation, executable tests, an explicit mutation catalog and review
commands. See the [example matrix](../../examples/README.md) for transport and
architecture roles and required tools.
