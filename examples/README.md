# Worked examples by language

Each example is a standalone project included in the npm package under
`examples/`. Change into its directory before following its README. Use Rice’s
Tax 0.3.1 and Node 22+.

| Target | Example | Role | Additional tools |
| --- | --- | --- | --- |
| JavaScript | [Greeting service](greeting-service/README.md) | Policy and Node HTTP server | None |
| Java | [Greeting service](greeting-service-java/README.md) | Policy process, Node HTTP adapter | JDK |
| TypeScript | [Greeting service](greeting-service-typescript/README.md) | Typed policy, Node HTTP adapter | tsc |
| Python | [Greeting service](greeting-service-python/README.md) | PEP-8 style policy process, Node HTTP adapter | Python 3 |
| Go | [Greeting service](greeting-service-go/README.md) | Policy process, Node HTTP adapter | Go |
| Haskell | [Greeting service](greeting-service-haskell/README.md) | Policy process, Node HTTP adapter | GHC |
| Kotlin | [Greeting service](greeting-service-kotlin/README.md) | Policy process, Node HTTP adapter | kotlinc and JDK |
| ANTLR4 | [Integer expression language](expression-language-antlr4/README.md) | Grammar, generated parser and Java evaluator | JDK, ANTLR_JAR |
| CALM | [Checkout architecture](checkout-architecture-calm/README.md) | Actors, services, storage and access boundaries | None |

The seven general-purpose languages share the greeting contract: GET
`/greet?name=Ada` returns a JSON greeting; missing/blank names return 400 and other
routes or methods return 404. The process adapters are synchronous teaching
implementations, not production transports. Runtime Unicode whitespace sets can
differ. The target languages execute the policy; Node provides transport.

ANTLR4 demonstrates syntax and parsing rather than pretending to be an HTTP
application language. CALM demonstrates architecture and policy assertions rather
than pretending to execute services. Each has its own walkthrough, tests and
mutation catalog. All examples generate their central artifact from documented
blocks and make the distinction between generated material and handwritten test
or integration code explicit.

Mutation tests never retangle the changed source: that would erase the fault.
The explicit catalogs are bounded evidence, not exhaustive mutation coverage.
See the [service tutorial](../docs/tutorials/architecture-to-service.md),
[ANTLR tutorial](../docs/tutorials/expression-language.md), and
[CALM tutorial](../docs/tutorials/checkout-architecture.md).
