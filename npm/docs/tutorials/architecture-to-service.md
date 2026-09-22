---
id: ricestax.tutorial.architecture-to-service
kind: tutorial
title: From architecture to a running documented service
---
# From architecture to a running documented service

Continue from the JavaScript project in [the starter tutorial](new-project.md).
The complete working counterpart lives at `examples/greeting-service` in the
source distribution. This tutorial supplies the application behaviour explicitly:
CALM describes the boundary, and the documentation supplies executable code.

## Choose a language

The [example matrix](../../examples/README.md) links service counterparts in
Java, JavaScript, TypeScript, Python, Go, Haskell and Kotlin. The detailed
walkthrough below uses JavaScript. Other variants implement policy in their target
language behind a Node HTTP adapter.

ANTLR4 has a separate [expression-language tutorial](expression-language.md).
CALM has a separate [checkout architecture tutorial](checkout-architecture.md).
These demonstrate parsing and architectural policy, respectively.

## 1. State the behaviour

The service accepts `GET /greet?name=...`, returns a JSON greeting, rejects empty
names with HTTP 400, and returns HTTP 404 for other paths. This keeps input failure
distinct from an unknown route. It uses no database or remote API.

Create `docs/reference/service.md` with front matter `id: greeting.reference.service`,
`kind: reference`, and `title: Greeting service`. Add the following numbered sections,
prose, and code blocks. The `file=` and `def=` attributes make these blocks inputs
to tangling; ordinary unannotated examples do not become production code.

### 1.1 Greeting policy

Write a section headed `## 1. Greeting policy` explaining that empty names are
rejected so callers never receive a misleading successful greeting. Follow it with:

````markdown
```javascript file=src/greeting.mjs def=greetingFor
export function greetingFor(name) {
  if (typeof name !== 'string' || name.trim().length === 0) {
    throw new Error('A nonempty name is required');
  }
  return { greeting: `Hello, ${name.trim()}!` };
}
```
````

### 1.2 HTTP boundary

Under `## 2. HTTP boundary`, explain that the transport converts input errors to
400 responses while keeping routing failures separate. Add:

````markdown
```javascript file=src/server.mjs part=imports
import { createServer } from 'node:http';
import { greetingFor } from './greeting.mjs';
```
````

````markdown
```javascript file=src/server.mjs def=createGreetingServer
export function createGreetingServer() {
  return createServer((request, response) => {
    const url = new URL(request.url, 'http://localhost');
    response.setHeader('content-type', 'application/json');
    if (request.method !== 'GET' || url.pathname !== '/greet') {
      response.writeHead(404).end(JSON.stringify({ error: 'Not found' }));
      return;
    }
    try {
      response.end(JSON.stringify(greetingFor(url.searchParams.get('name'))));
    } catch (error) {
      response.writeHead(400).end(JSON.stringify({ error: error.message }));
    }
  });
}
```
````

The function returns a server without binding a fixed port. Tests can bind an
available port, and production startup owns its lifecycle.

## 2. Generate and test the actual service

Run `ricestax canon tangle`. Create `test/service.test.mjs`:

```javascript
import test from 'node:test';
import assert from 'node:assert/strict';
import { createGreetingServer } from '../src/server.mjs';

test('serves greetings and distinguishes invalid input from unknown routes', async () => {
  const server = createGreetingServer();
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const base = `http://127.0.0.1:${server.address().port}`;
    const good = await fetch(`${base}/greet?name=Ada`);
    assert.equal(good.status, 200);
    assert.deepEqual(await good.json(), { greeting: 'Hello, Ada!' });
    assert.equal((await fetch(`${base}/greet?name=`)).status, 400);
    assert.equal((await fetch(`${base}/other`)).status, 404);
  } finally {
    await new Promise(resolve => server.close(resolve));
  }
});
```

Run:

```sh
node --test --test-reporter=tap test/service.test.mjs
ricestax canon tangle --check
node --input-type=module -e "import { createGreetingServer } from './src/server.mjs'; createGreetingServer().listen(8097, '127.0.0.1')"
```

Visit `http://localhost:8097/greet?name=Ada`; stop the process with Ctrl-C.
This executes generated application code, not a mocked transport.

## 3. Test whether the assertions notice a fault

Extend `ricestax.mutations.json` inputs to include `src`, `test`, `docs`,
`tools/build.mjs`, `package.json`, `canon.yaml`, and `architecture.calm.json`.
Set compile to `["node", "--check", "src/server.mjs"]`, test to
`["node", "--test", "--test-reporter=tap", "test/service.test.mjs"]`, and evidence to
`{"passed":"# pass 1","failed":"not ok"}`. Replace the starter mutation catalog
with the following application fault:

```json
[
  {
    "file": "src/greeting.mjs",
    "original": "name.trim().length === 0",
    "replacement": "false"
  }
]
```

Run `ricestax mutate`. The original code passes; the mutant lets an empty name
through and the HTTP 400 assertion kills it. The mutation build must not run
`tangle`, which would regenerate the fault away. Normal CI checks tangling before
mutation; each mutant is compiled/tested from its copied generated sources.

## 4. Review, change, and revisit

Run `ricestax assess` and `ricestax pay 8091`. Review the architecture and reference
page as well as the generated unit names. Record and commit only decisions you
actually reached. Then change a reviewed description or implementation in its
source page, retangle, and reload the viewer: the old review must no longer stand
as approval of the changed material.

Commit generated sources and their source pages together. CI runs tangling in
check mode, ordinary tests, mutation, and audit as separate steps. A functioning
service with a killed catalog mutant still has no automatic claim to deployment
security, complete mutation coverage, or a fully reviewed architecture.
