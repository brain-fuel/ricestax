---
id: ricestax.reference.languages
kind: reference
title: Language support and boundaries
---
# Language support and boundaries

Version 0.3 packages profiles and grammar assets. `ricestax init --languages ...`
copies them into `.ricestax/` and writes `canon.yaml`. Commit these inputs so
updating an npm executable does not silently change a project's grammar.

| Profile | Files | Review units |
| --- | --- | --- |
| `java` | `.java` | Classes, interfaces, methods, constructors and other units labelled by the Java dialect |
| `javascript` | `.js`, `.mjs`, `.cjs` | Named functions, classes, methods, variable bindings including arrow initializers |
| `typescript` | `.ts`, `.mts`, `.cts` | Functions, classes, interfaces, aliases, enums, members and variable bindings |
| `python` | `.py` | Functions, classes, module/function/class docstrings |
| `go` | `.go` | Functions, receiver methods, type definitions and aliases |
| `haskell` | `.hs` | Dialect-labelled modules, types, signatures and attached equation bodies |
| `kotlin` | `.kt` | Functions, classes, objects, aliases and properties |
| `calm` | `.calm.json` | CALM 1.2 nodes, relationships and flows |
| `antlr4` | `.g4` | Grammar definitions, parser rules and lexer rules |
| `folio` | `.md` | Documentation pages and explicitly declared tangled blocks |

These are source parsers and review extractors, not replacements for compilers,
type checkers, linters, or full schema validators. JSX/TSX, Kotlin scripts,
compiler plugins, macro expansion, generated declarations, and every newest
language construct are not promised. A named binding is reviewable even when it
holds a value rather than a function. Destructured names and anonymous expressions
are not a complete symbol-table analysis. Overload identities use occurrence
suffixes: reordering overloads can invalidate their earlier review.

Python uses PEP 8 conventions in examples, while PEP 257 describes docstrings.
The tool ingests a single string-literal first statement in a declaration suite
or module. It does not enforce all PEP 8/257 rules or evaluate string expressions.
Run your Python linter separately. ref:pep-8 ref:pep-257

CALM ingestion requires the 1.2 `$schema`, `nodes`, and `relationships` arrays;
`flows` is optional. It checks required identity/name fields, duplicate identities,
relationship variants, and node/flow relationship references. Descriptions become
Why material. The other fields remain in each element's body so structural changes
stale its What verdict. Interfaces, controls, decorators, and full JSON Schema
constraints require the official CALM validator. No deployed conformance is inferred.
ref:calm-1.2

For each profile, see its individual reference page for setup, generation,
mutation prerequisites, and limitations. Language-specific toolchains are needed
only when compiling/testing that language, not for ingestion or the review UI.

[Java](language-java.md), [JavaScript](language-javascript.md), [TypeScript](language-typescript.md), [Python](language-python.md), [Go](language-go.md), [Haskell](language-haskell.md), [Kotlin](language-kotlin.md), [CALM architecture](language-calm.md), [ANTLR4](language-antlr4.md).
