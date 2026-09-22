---
id: greeting.python.service
kind: reference
title: Greeting service (python)
---
# Greeting policy

Reject an empty or whitespace-only name, trim surrounding whitespace, and greet the caller.
The Node HTTP adapter maps rejection to 400, routes other requests to 404, and
JSON-encodes successful text. The python implementation below owns validation
and greeting construction.

```python file=src/greeting.py part=implementation
import sys


def greeting_for(value):
    """Return a greeting, rejecting names without visible content."""
    name = value.strip()
    if not name:
        raise ValueError("A nonempty name is required")
    return "Hello, " + name + "!"


if __name__ == "__main__":
    try:
        print(greeting_for(sys.argv[1]))
    except ValueError:
        sys.exit(2)

```
