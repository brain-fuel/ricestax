# ANTLR4: an integer expression language

This example generates a Java lexer, parser and visitor from a documented ANTLR4
grammar, then evaluates expressions with a handwritten Java visitor. No HTTP
server is involved. Try `2+3*4` (14) and `(2+3)*4` (20).

Requires Node 22+, Rice’s Tax 0.3.2, JDK 17+, Maven, and `ANTLR_JAR` pointing to an absolute
ANTLR4 complete JAR path (tested with 4.13.2). From this directory:

```sh
ricestax canon tangle
ricestax canon tangle --check
node tools/build.mjs
java -cp "build:$ANTLR_JAR" Evaluate '2+3*4'
java -cp 'build:build/dependency/*' ExpressionTest
ricestax mutate
ricestax assess
ricestax pay 8091
```

Edit `docs/reference/grammar.md` and retangle to change syntax. The evaluator is
`src/Evaluate.java`; generated ANTLR output goes to `build/` and is not maintained
by hand. The test cases have independently written expected values and rejection
cases. The mutation catalog removes full-input consumption and disallows
multi-digit literals; unchanged tests must kill both grammar faults.

The language supports nonnegative decimal literals, parentheses and binary
`+`, `-`, `*`, `/`. Operators associate left; multiplication/division bind tighter.
Division truncates toward zero. Unary operators, variables and assignments are
outside this example. Values use Java signed 64-bit arithmetic: arithmetic can
wrap on overflow; out-of-range literals and division by zero are rejected. Lexer
and parser errors return exit 2 and no result. This is a teaching language, not a
calculator for untrusted input or a numerical correctness library.

For a new language, start with the documented grammar, define acceptance and
rejection examples, and implement semantics in the visitor. For an existing
grammar, initialize `antlr4,java,javascript,folio` in a separate directory and merge the
configuration deliberately; move rules into documented blocks incrementally.
See [the walkthrough](../../docs/tutorials/expression-language.md),
[language reference](../../docs/reference/language-antlr4.md), and
[generation how-to](../../docs/how-to/generate-from-documentation.md).

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
