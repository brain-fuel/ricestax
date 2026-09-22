# Worked examples by language

Each example is a standalone project included in the npm package under
`examples/`. Use Rice’s Tax 0.3.2; enter the project directory before its commands.

| Language | Example | HTTP implementation | Test implementation |
| --- | --- | --- | --- |
| JavaScript | [Greeting](greeting-service/README.md) | Node HTTP, JavaScript | node:test, JavaScript |
| Java | [Greeting](greeting-service-java/README.md) | JDK HttpServer, Java | JDK HttpClient and assertions, Java |
| TypeScript | [Greeting](greeting-service-typescript/README.md) | Node HTTP, TypeScript | node:test, TypeScript |
| Python | [Greeting](greeting-service-python/README.md) | http.server, Python | http.client and unittest, Python |
| Go | [Greeting](greeting-service-go/README.md) | net/http, Go | httptest and testing, Go |
| Haskell | [Greeting](greeting-service-haskell/README.md) | WAI/Warp, Haskell | http-client and Hspec, Haskell |
| Kotlin | [Greeting](greeting-service-kotlin/README.md) | JDK HttpServer, Kotlin | JDK HttpClient and assertions, Kotlin |

All seven applications are actual HTTP servers in their declared language, with
independent same-language tests against real HTTP requests on ephemeral ports.
TypeScript sources and tests compile to JavaScript in the normal way. There are
no Node process adapters around other languages. Node remains a dependency for
Rice’s Tax and its build helpers; it is the application runtime for JS and TS.

Their common contract is GET `/greet?name=Ada` returning a JSON greeting;
missing/blank names return 400, and unknown routes or wrong methods return 404.
Tests also exercise trimming, Unicode and quote escaping. These minimal servers
have no production deployment claim; Unicode whitespace sets can differ.

Two language-specific examples remain separate:

- [ANTLR4 expression language](expression-language-antlr4/README.md): a documented
  grammar, generated Java parser, Java evaluator and Java CLI tests.
- [CALM checkout architecture](checkout-architecture-calm/README.md): a documented
  architecture with JavaScript assertions over access and ownership boundaries.
  CALM itself has no executable application or test runtime.

Every example has document generation, an independent test suite, an explicit
mutation catalog and review commands. Mutation builds never retangle faults away.
The catalogs provide bounded evidence, not exhaustive mutation coverage.
See the [service tutorial](../docs/tutorials/architecture-to-service.md),
[ANTLR tutorial](../docs/tutorials/expression-language.md), and
[CALM tutorial](../docs/tutorials/checkout-architecture.md).
