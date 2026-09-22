import test from 'node:test';
import assert from 'node:assert/strict';
import { type AddressInfo } from 'node:net';
import { createGreetingServer } from '../src/server.js';

test('native TypeScript HTTP contract', async () => {
  const server = createGreetingServer();
  await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
    for (const name of ['Ada', '  Ada Lovelace  ', 'A"B', 'Zoë']) {
      const response = await fetch(base + '/greet?name=' + encodeURIComponent(name));
      assert.equal(response.status, 200);
      assert.match(response.headers.get('content-type') ?? '', /^application\/json/);
      assert.deepEqual(await response.json(), { greeting: `Hello, ${name.trim()}!` });
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
  } finally {
    await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
  }
});
