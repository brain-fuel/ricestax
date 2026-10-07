import test from 'node:test';
import fc from 'fast-check';
import assert from 'node:assert/strict';
import { createGreetingServer } from '../src/server.mjs';

test('native JavaScript HTTP contract', async () => {
  const server = createGreetingServer();
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const base = `http://127.0.0.1:${server.address().port}`;
    for (const [name, expected] of [['Ada', 'Ada'], ['  Ada Lovelace  ', 'Ada Lovelace'], ['A"B', 'A"B'], ['Zoë', 'Zoë']]) {
      const response = await fetch(base + '/greet?name=' + encodeURIComponent(name));
      assert.equal(response.status, 200);
      assert.match(response.headers.get('content-type') ?? '', /^application\/json/);
      assert.deepEqual(await response.json(), { greeting: `Hello, ${expected}!` });
    }
    for (const query of ['', '?name=', '?name=%20%20']) {
      const response = await fetch(base + '/greet' + query);
      assert.equal(response.status, 400);
      assert.deepEqual(await response.json(), { error: 'A nonempty name is required' });
    }
    for (const [path, method] of [['/other', 'GET'], ['/greet?name=Ada', 'POST']]) {
      const response = await fetch(base + path, { method });
      assert.equal(response.status, 404);
      assert.deepEqual(await response.json(), { error: 'Not found' });
    }

    // Construct the expected name before adding padding; never call app trimming.
    const padding = fc.array(fc.constantFrom(' ', '\t', '\r', '\n'), {maxLength: 12}).map(xs => xs.join(''));
    const middle = fc.array(fc.constantFrom('a', 'Z', '0', ' ', '\t', '\r', '\n', '\0', '"', '\\', '&', '+', '%', '/', 'é', 'λ', '界', '😀'), {maxLength: 64}).map(xs => xs.join(''));
    const suffix = fc.array(fc.constantFrom('a', 'b', '0', '9'), {maxLength: 32}).map(xs => xs.join(''));
    await fc.assert(fc.asyncProperty(middle, padding, padding, suffix,
      fc.constantFrom('POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'),
      async (inside, left, right, route, method) => {
        const core = 'A' + inside + 'Z';
        const ok = await fetch(base + '/greet?name=' + encodeURIComponent(left + core + right));
        assert.equal(ok.status, 200);
        assert.match(ok.headers.get('content-type') ?? '', /^application\/json/);
        assert.deepEqual(await ok.json(), {greeting: `Hello, ${core}!`});
        const blank = await fetch(base + '/greet?name=' + encodeURIComponent(left));
        assert.equal(blank.status, 400);
        assert.match(blank.headers.get('content-type') ?? '', /^application\/json/);
        assert.deepEqual(await blank.json(), {error: 'A nonempty name is required'});
        for (const [path, verb] of [['/missing-' + route + '?name=Ada', 'GET'], ['/greet?name=Ada', method]]) {
          const missing = await fetch(base + path, {method: verb});
          assert.equal(missing.status, 404);
          assert.match(missing.headers.get('content-type') ?? '', /^application\/json/);
          assert.deepEqual(await missing.json(), {error: 'Not found'});
        }
      }), {
        numRuns: 100,
        ...(process.env.FC_SEED ? {seed: Number(process.env.FC_SEED)} : {}),
        ...(process.env.FC_PATH ? {path: process.env.FC_PATH} : {}),
      });
  } finally {
    await new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
  }
});
