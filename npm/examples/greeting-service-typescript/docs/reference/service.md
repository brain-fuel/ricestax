---
id: greeting.typescript.service
kind: reference
title: Native typescript HTTP service
---
# Greeting HTTP service

The server accepts GET /greet, trims the name and returns JSON. Missing or blank
names produce 400. Other paths and methods produce 404. Tests use real HTTP
connections against the same application on an ephemeral port.

## Implementation

The typescript runtime owns routing, input validation, JSON encoding and HTTP transport.

```typescript file=src/server.ts part=implementation
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

```
