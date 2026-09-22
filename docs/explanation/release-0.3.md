---
id: ricestax.explanation.release-0.3
kind: explanation
title: The 0.3 foundation and what follows it
---
# The 0.3 foundation and what follows it

0.3 is a foundation for adopting Rice’s Tax across existing and new projects.
It is not the final feature set. A supported input must produce reviewable material
with source locations, stable identity, explicit extraction failures, and stale
verdict detection. Finding a grammar file is not evidence that these work.

## Release acceptance

- Java, JavaScript, TypeScript, Python, Go, Haskell, Kotlin, CALM architecture JSON,
  and ANTLR4 have packaged profiles and executable positive and negative examples.
- A fresh npm installation can initialize a project without another source
  checkout, compiler, parser generator, or network grammar download.
- Existing projects keep their sources, configuration, and verdicts. Migration
  documents discovery, scope selection, review debt, exemptions, and CI adoption.
- Unsupported syntax and invalid inputs fail visibly. No parser failure becomes
  an empty, successful review queue.
- Python documentation describes PEP 8 style and PEP 257 docstrings separately.
  Ingestion does not claim to be a style checker or Python compiler.
- CALM elements retain explicit architecture identities and descriptions; changed
  structure invalidates the relevant review. Ingestion does not establish that
  deployed software conforms to its architecture.
- Diátaxis provides learning tutorials, task-oriented how-to guides, precise
  language/configuration references, and explanations of evidence and tradeoffs.
- Documentation-to-code generation covers the selected profiles; CALM JSON must
  remain valid JSON without generated comments.
- CALM project scaffolding preserves architecture identities and refuses to
  overwrite user-owned output.
- Mutation execution retains controls and separate compile/test evidence, with
  invalid mutations and infrastructure failures distinct from test kills.
- A runnable tutorial starts with requirements and architecture, implements an
  application, tests it, raises review obligations, and demonstrates changes
  making earlier decisions stale.
- Tests assert extracted names, locations, descriptions, failures, and stale
  decisions. Release checks exercise the packed npm artifact with an isolated
  installation. No unconditional success stubs count as evidence.

## Subsequent work

Compiler-level semantic analysis, deployed architecture conformance, additional
language syntax, richer cross-language links, and automatic mutation-site discovery
remain subsequent work. Version 0.3 includes explicit-catalog mutation execution,
documentation-to-code tangling, and CALM-to-project scaffolding as distinct tested
capabilities. A generated scaffold is not a completed domain implementation.

The 0.2 audit exception applied to the exact 0.2.0 artifact. It is not a standing
exception for 0.3. Documentation, test, package, and self-audit results must be
reported separately, including any remaining failures.
