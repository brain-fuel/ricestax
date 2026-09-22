---
id: greeting.calm.architecture
kind: reference
title: Greeting service architecture
---
# Service boundary

Greeting API is the service that owns greeting responses. This CALM model describes
that responsibility. JavaScript supplies its executable implementation.

```calm file=architecture.calm.json part=architecture
{
  "$schema": "https://calm.finos.org/release/1.2/meta/calm.json",
  "nodes": [
    {
      "unique-id": "greeting-api",
      "node-type": "service",
      "name": "Greeting API",
      "description": "Owns greeting responses."
    }
  ],
  "relationships": []
}
```
