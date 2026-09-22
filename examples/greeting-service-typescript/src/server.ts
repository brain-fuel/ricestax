// Tangled from service.md.
// Edit the specification, not this file.
// Every comment below is generated from the prose there.

/** The typescript runtime owns routing, input validation, JSON encoding and HTTP transport.
 *
 * Specified by service.
 */
import { createServer, type Server } from 'node:http';

export function createGreetingServer(): Server {
  return createServer((request, response) => {
    const url = new URL(request.url ?? '/', 'http://localhost');
    response.setHeader('content-type', 'application/json; charset=utf-8');
    if (request.method !== 'GET' || url.pathname !== '/greet') {
      response.writeHead(404).end(JSON.stringify({ error: 'Not found' }));
      return;
    }
    const name = (url.searchParams.get('name') ?? '').trim();
    if (name.length === 0) {
      response.writeHead(400).end(JSON.stringify({ error: 'A nonempty name is required' }));
      return;
    }
    response.end(JSON.stringify({ greeting: `Hello, ${name}!` }));
  });
}
