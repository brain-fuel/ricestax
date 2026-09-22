---
id: ricestax.tutorial.expression-language
kind: tutorial
title: Build and test an expression language with ANTLR4
---
# Build and test an expression language with ANTLR4

Use [the complete example](../../examples/expression-language-antlr4/README.md).
Copy it from the source checkout or installed npm package into a working directory.
Install the JDK and set `ANTLR_JAR` to the absolute ANTLR4 complete JAR path.

## 1. Read the grammar as a specification

Open `docs/reference/grammar.md`. The input rule requires EOF, expression combines
terms with addition/subtraction, term combines atoms with multiplication/division,
and atom accepts a literal or parenthesized expression. That layering establishes
precedence. Every rule has prose and an attributed block; the prose becomes the
canonical comment of the generated rule.

## 2. Generate and execute

Run `ricestax canon tangle`, then `node tools/build.mjs`. The first command writes
`src/Expression.g4`; the second invokes ANTLR and compiles the generated Java
classes plus the handwritten evaluator. Run `node tools/evaluate.mjs '2+3*4'`
and expect 14. Run it with `'(2+3)*4'` and expect 20. `2+` must exit 2 without a result.

## 3. Challenge the assertions

Run `node --test --test-reporter=tap test/expression.test.mjs`, then
`ricestax mutate`. The catalog removes EOF and changes multi-digit literals to
single digits. Both changed grammars still generate and compile, but the tests
must kill them: trailing input must not be accepted and `12` must remain valid.
The arithmetic assertions also check precedence, grouping and associativity.

## 4. Review and evolve

Run `ricestax assess` and `ricestax pay 8091`. Review grammar, prose and Java
semantics separately. Change a rule in the reference page, retangle and rerun the
tests. `ricestax canon tangle --check` catches drift between documentation and source.
For a real language extension, add acceptance/rejection examples and a visitor
implementation as needed; Rice’s Tax does not infer semantics from English prose.

Read the [ANTLR reference](../reference/language-antlr4.md) for ingestion limits,
the [generation how-to](../how-to/generate-from-documentation.md) for migration,
and [the explanation](../explanation/language-specific-examples.md) for why this
example differs from the service examples.
