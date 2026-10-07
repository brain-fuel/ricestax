# Greeting HTTP server: JavaScript

The HTTP application and its tests are JavaScript, using Node HTTP and node:test.
Requires Node 22+ and Rice’s Tax 0.3.2. From this directory:

```sh
ricestax canon tangle
node tools/build.mjs
node --test --test-reporter=tap test/service.test.mjs
ricestax canon tangle --check
ricestax mutate
ricestax assess
ricestax pay 8091
node --input-type=module -e "import {createGreetingServer} from './src/server.mjs'; createGreetingServer().listen(8097,'127.0.0.1')"
```

Visit http://127.0.0.1:8097/greet?name=Ada . Stop with Ctrl-C. The source page owns
`src/greeting.mjs` and `src/server.mjs`; edit it, retangle and rerun the native HTTP
tests. The independent tests cover greetings, trimming, Unicode, JSON escaping,
missing/blank names, unknown routes and wrong methods. The input-validation and path-rejection
mutations must be killed by those same tests. No pre-approved verdicts are supplied.

Follow the [JavaScript property-testing tutorial](../../docs/tutorials/http-javascript.md) for fast-check, failure replay, and mutation review.
