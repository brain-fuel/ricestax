---
id: greeting.reference.service
kind: reference
title: Greeting service
---
# Greeting service

## 1. greetingFor

Empty names must fail so callers cannot mistake a missing identity for a successful greeting.

```javascript file=src/greeting.mjs def=greetingFor
export function greetingFor(name) {
  if (typeof name !== 'string' || name.trim().length === 0) {
    throw new Error('A nonempty name is required');
  }
  return { greeting: `Hello, ${name.trim()}!` };
}
```

## 2. imports

The transport uses Node HTTP and the shared greeting policy.

```javascript file=src/server.mjs part=imports
import { createServer } from 'node:http';
import { greetingFor } from './greeting.mjs';
```

## 3. createGreetingServer

Input errors return 400 while unknown routes return 404, keeping caller mistakes distinguishable.

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

