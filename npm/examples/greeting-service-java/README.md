# Greeting HTTP server: java

The HTTP application and its tests are written in java. They use JDK HttpServer and HttpClient.
There is no process bridge to another language's web server. Tests start the
actual server on an ephemeral port and send HTTP requests from the same language.

Requires Rice’s Tax 0.3.2, Node 22+ for Rice’s Tax and the build helper, and
JDK. From this directory:

```sh
ricestax canon tangle
node tools/build.mjs
java -cp build GreetingTest
ricestax canon tangle --check
ricestax mutate
ricestax assess
ricestax pay 8091
java -cp build Greeting
```

Visit http://127.0.0.1:8097/greet?name=Ada and stop the server with Ctrl-C.
The final command launches the java application directly. TypeScript is
compiled to JavaScript in its own example, as normal for that language.

Edit `docs/reference/service.md`, retangle, build, and rerun tests. The reference
page generates application code; the independently written test sources remain
handwritten. The tests assert successful JSON greetings, trimming, Unicode, quote
escaping, missing/blank input, unknown paths and wrong methods. The catalog
removes input rejection and path rejection in separate mutants; the unchanged
native HTTP assertions must kill both.
Mutation compilation never retangles and never replaces the application with a
mock. See `commands.json` and `ricestax.mutations.json` for exact commands.

This is a small teaching HTTP server, with no authentication, persistence or TLS.
It is not a production deployment template. Unicode whitespace normalization can
differ between runtimes. The [example index](../README.md) explains the separate
ANTLR language and CALM architecture examples.
