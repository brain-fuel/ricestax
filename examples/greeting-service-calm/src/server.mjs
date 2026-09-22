// Tangled from service.md.
// Edit the specification, not this file.
// Every comment below is generated from the prose there.

/** The transport uses Node HTTP and the shared greeting policy.
 *
 * Specified by service S2.
 */
import { createServer } from 'node:http';
import { greetingFor } from './greeting.mjs';

/** Input errors return 400 while unknown routes return 404, keeping caller mistakes
 * distinguishable.
 *
 * Specified by service S3.
 */
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
