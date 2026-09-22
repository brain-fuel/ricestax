---
id: ricestax.reference.project-commands
kind: reference
title: Project creation and execution commands
---
# Project creation and execution commands

These npm-host commands supplement the shared native/WASM review core:

| Command | Result |
| --- | --- |
| `ricestax languages` | Lists packaged profile identifiers |
| `ricestax init --languages java,calm,folio` | Copies pinned grammars and creates configuration; refuses existing destinations |
| `ricestax scaffold architecture.calm.json --language java --out new-project` | Validates ingestion, creates a CALM-derived starter in a new directory |
| `ricestax mutate [config.json]` | Executes a bounded source-mutation catalog; defaults to `ricestax.mutations.json` |
| `ricestax canon model file` | Emits the canonical model and source locations |
| `ricestax canon tangle` | Writes source files named by Folio blocks |
| `ricestax canon tangle --check` | Checks those outputs without writing them |

`init`, `scaffold`, and `mutate` require the npm host. The native executable shares
ingestion, tangling, review, and audit, but does not implement these npm-host commands.

Scaffolding accepts Java, JavaScript, TypeScript, Python, Go, Haskell, Kotlin, CALM,
and ANTLR4 targets using the identifiers in the language reference. The CALM target
emits a JSON service inventory; ANTLR4 emits a grammar and Java parser test.
Other targets expose a service-membership function and executable boundary tests.
The architecture's service IDs are sorted for deterministic source generation.
At least one service is required. Starter service IDs are restricted to ASCII
letters followed by letters, digits, underscores, or hyphens; ingestion itself
accepts broader path-segment IDs.

The scaffold retains the architecture, a build/test script, mutation configuration,
review configuration, and grammar assets. It does not generate persistence,
authentication, transport, deployment, or domain behaviour from a diagram.
Implement those in the new project and keep them covered by tests. A repeated
scaffold refuses the existing directory; generate into a new directory and review
the difference when the architecture changes.

The `model` JavaScript API returns a canonical model or `{error: string}`. A parse
error is never represented as an empty valid model. The source path is interpreted
relative to the project root supplied to `connect`.
