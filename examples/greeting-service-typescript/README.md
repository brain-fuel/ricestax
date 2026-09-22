# Greeting service: typescript

This is the same greeting service as the JavaScript worked tutorial. The policy
is implemented in typescript; a shared Node HTTP adapter invokes it as a process.
This deliberately small teaching transport is synchronous and starts one process
per request; it is not a production server architecture.

Requirements: Node 22+, Rice’s Tax 0.3.0 candidate, and tsc on PATH.

From this directory:

```sh
ricestax canon tangle
node tools/build.mjs
node --test --test-reporter=tap test/service.test.mjs
ricestax canon tangle --check
ricestax mutate
ricestax assess
ricestax pay 8091
```

Run `node tools/server.mjs`, then visit
http://localhost:8097/greet?name=Ada . Stop with Ctrl-C.

Edit `docs/reference/service.md` and retangle to change policy. Tests exercise
success, trimming, JSON escaping, Unicode, missing/empty/blank input, unknown
routes and wrong methods over real HTTP. The catalog removes input rejection;
the unchanged HTTP assertions must kill it. Mutation compilation never tangles.

CALM describes the service boundary, not generated business behaviour. Review
architecture, policy and transport separately. The included mutation is bounded
evidence, not exhaustive coverage.
