# ANTLR4: an integer expression language

This example generates a Java lexer, parser and visitor from a documented ANTLR4
grammar, then evaluates expressions with a handwritten Java visitor. No HTTP
server is involved. Try `2+3*4` (14) and `(2+3)*4` (20).

Requires Node 22+, Rice’s Tax 0.3.2, a JDK, and `ANTLR_JAR` pointing to an absolute
ANTLR4 complete JAR path (tested with 4.13.2). From this directory:

```sh
ricestax canon tangle
ricestax canon tangle --check
node tools/build.mjs
java -cp "build:$ANTLR_JAR" Evaluate '2+3*4'
java -cp build ExpressionTest
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
