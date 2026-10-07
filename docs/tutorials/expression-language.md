---
id: ricestax.tutorial.expression-language
kind: tutorial
title: Build and test an expression language with ANTLR4
---
# Build and test an expression language with ANTLR4

Use [the complete example](../../examples/expression-language-antlr4/README.md).
Copy it from the source checkout or installed npm package into a working directory.
Install JDK 17+ and Maven and set `ANTLR_JAR` to the absolute ANTLR4 complete JAR path.

## 1. Read the grammar as a specification

Open `docs/reference/grammar.md`. The input rule requires EOF, expression combines
terms with addition/subtraction, term combines atoms with multiplication/division,
and atom accepts a literal or parenthesized expression. That layering establishes
precedence. Every rule has prose and an attributed block; the prose becomes the
canonical comment of the generated rule.

## 2. Generate and execute

Run `ricestax canon tangle`, then `node tools/build.mjs`. The first command writes
`src/Expression.g4`; the second invokes ANTLR and compiles the generated Java
classes plus the handwritten evaluator. Run `java -cp "build:$ANTLR_JAR" Evaluate '2+3*4'`
and expect 14. Run it with `'(2+3)*4'` and expect 20. `2+` must exit 2 without a result.

## 3. Challenge the assertions

Run `java -cp 'build:build/dependency/*' ExpressionTest`, then
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

The evaluator and assertion runner are both Java. `test/ExpressionTest.java`
launches the Java CLI, asserts its output and rejection exit codes, and runs
unchanged against both grammar mutations. Node is used only by the build helper
and Rice’s Tax.

The Java tests also use JetCheck to generate 100 expression trees of depth three.
Leaves are integers from 0 through 100; division uses a positive literal denominator
from 1 through 9. The generator calculates an expected value before rendering the
fully parenthesized expression. The evaluator runs in a separate Java process and
must produce that value; appending an extra literal or adding an unmatched opening parenthesis
must fail with exit 2 and no result. Fixed cases separately check precedence,
associativity, division by zero and literal overflow. This is bounded sampling, not
proof for arbitrary expression depth or all overflow behavior.

The build helper uses Maven to fetch JetCheck 0.3.0. Set `JETCHECK_SEED` to replay a
seed or `JETCHECK_RECHECK` to the minimized serialized case printed by JetCheck.
For example, run `JETCHECK_SEED=123 java -cp 'build:build/dependency/*' ExpressionTest`.
The catalog now contains five faults: two grammar changes and three wrong arithmetic
operations in the Java evaluator. Every fault must compile and then fail an assertion.
