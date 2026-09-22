# Greeting service in every supported target

Each example is a standalone project: change into its directory before running
commands. All are included in the npm package under examples/. Use the 0.3.0
candidate CLI; the publicly released 0.2 CLI lacks these generation profiles.

| Target | Directory | Application role | Additional tools |
| --- | --- | --- | --- |
| JavaScript | [greeting-service](greeting-service/README.md) | Policy and native Node HTTP server | Node |
| Java | [greeting-service-java](greeting-service-java/README.md) | Policy process, Node HTTP adapter | JDK |
| TypeScript | [greeting-service-typescript](greeting-service-typescript/README.md) | Typed policy, Node HTTP adapter | tsc |
| Python | [greeting-service-python](greeting-service-python/README.md) | PEP-8 style policy process, Node HTTP adapter | Python 3 |
| Go | [greeting-service-go](greeting-service-go/README.md) | Policy process, Node HTTP adapter | Go |
| Haskell | [greeting-service-haskell](greeting-service-haskell/README.md) | Policy process, Node HTTP adapter | GHC |
| Kotlin | [greeting-service-kotlin](greeting-service-kotlin/README.md) | Policy process, Node HTTP adapter | kotlinc and JDK |
| CALM | [greeting-service-calm](greeting-service-calm/README.md) | Document-generated architecture with JavaScript service | Node |
| ANTLR4 | [greeting-service-antlr4](greeting-service-antlr4/README.md) | Name grammar, generated Java parser, Node HTTP adapter | JDK and ANTLR_JAR |

All examples need Node 22+ for Rice’s Tax and HTTP tests. The process adapters
are deliberately small synchronous teaching implementations, not production
transports. They execute real compiled/interpreted target code, not a JavaScript
reimplementation of the policy. CALM describes structure, not executable business
logic. ANTLR defines accepted name syntax; its Java driver constructs the greeting.

The shared contract is GET /greet?name=Ada producing JSON greeting Hello, Ada!,
400 for missing/empty/blank names, and 404 for another path or method. Names are
trimmed; JSON encoding belongs to the adapter. Runtime Unicode whitespace sets
can differ; this example does not promise identical normalization for all Unicode.
ANTLR accepts words separated by spaces/tabs, so embedded newlines are rejected.

Each README gives generation, build, test, mutation, review, and launch commands.
Change the annotated documentation, retangle, build, and test. Mutation runs use
the generated source without tangling again. The CALM catalog reclassifies the
service as an actor; other catalogs disable input rejection. Each fault must be
killed by independent assertions. These are bounded catalogs, not a coverage claim.

For a new project, use ricestax scaffold with the chosen language, then use the
matching example’s reference page, transport and tests to implement behaviour.
For an existing project, retain its transport and bring over only the policy,
document generation pattern and explicit mutation configuration that fit it.
See the Diátaxis docs for the walkthrough, migration how-to, command reference
and explanation of evidence.
