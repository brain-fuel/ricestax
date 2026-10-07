---
id: ricestax.reference.example-properties
kind: reference
title: HTTP example property domains and evidence
---
# HTTP example property domains and evidence

The seven service examples use the following native test stacks. Each tutorial
walks through construction, a failure, replay, repair, and mutation review.

| Language | Property framework | Tutorial |
| --- | --- | --- |
| JavaScript | fast-check | [Build and test](../tutorials/http-javascript.md) |
| TypeScript | fast-check | [Build and test](../tutorials/http-typescript.md) |
| Python | Hypothesis | [Build and test](../tutorials/http-python.md) |
| Go | Rapid | [Build and test](../tutorials/http-go.md) |
| Haskell | Hedgehog with Hspec | [Build and test](../tutorials/http-haskell.md) |
| Java | JetCheck | [Build and test](../tutorials/http-java.md) |
| Kotlin | Kotest Property | [Build and test](../tutorials/http-kotlin.md) |

The HTTP properties generate an interior of 0–64 tokens drawn from letters,
digits, space, tab, CR, LF, NUL, quote, backslash, `&`, `+`, `%`, `/`, `é`, `λ`,
`界`, and `😀`. An `A` prefix and `Z` suffix preserve a nonblank core during
shrinking. Independent left/right padding contains 0–12 ASCII whitespace
characters (space, tab, CR, LF). The blank-name property uses that same padding
alphabet, including the empty string. URL encoding is performed by the client;
JSON is decoded before comparison with an independently constructed expected object.

Unknown paths start with `/missing-` and a generated alphanumeric suffix, so they
cannot shrink into `/greet`. Generated unsupported methods are POST, PUT, DELETE,
PATCH and OPTIONS. HEAD is excluded from the JSON-body property because HTTP HEAD
responses have no body. Missing names are covered by fixed cases.

Each framework runs 100 generated cases by default. Haskell has four separate
properties; the other six test a tuple with four HTTP requests. These counts are
sampling budgets, not coverage percentages. Random generation is combined with
fixed regression cases; replay requires retaining the generator and dependency
versions, not only a seed.

Go additionally supplies a native HTTP fuzz target for valid UTF-8 interiors up to
256 bytes. Its seed corpus runs in ordinary tests; active fuzzing is opt-in as
described in the Go tutorial.

These tests do not define universal Unicode whitespace normalization, duplicate
query-parameter policy, malformed percent/UTF-8 behavior, maximum request lengths,
authentication, TLS, concurrency correctness, or production resource limits. The
runtime implementations can differ outside the tested domain. Extending a claim
requires specifying that behavior and adding independent assertions and generators.

The seven catalog faults challenge blank rejection, path rejection, method rejection,
trimming, greeting punctuation, error status, and literal-plus preservation. The
last fault specifically targets generated inputs absent from the original fixed
regression examples. Inspect the test output to distinguish a failing property from
a missing dependency, compile error or timeout. Catalog mutations are hand selected;
Rice’s Tax does not automatically discover all possible source mutations.

ANTLR4’s [expression-language tutorial](../tutorials/expression-language.md) covers
a grammar and Java evaluator, and CALM’s [architecture tutorial](../tutorials/checkout-architecture.md)
covers graph policies. They are separate artifacts, not HTTP implementations.

For diagnosis, use [replaying property failures](../how-to/replay-property-failures.md).
For the reasoning behind the assertions, read [independent test oracles](../explanation/property-test-oracles.md).
