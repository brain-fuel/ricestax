---
id: greeting.java.service
kind: reference
title: Greeting service (java)
---
# Greeting policy

Reject an empty or whitespace-only name, trim surrounding whitespace, and greet the caller.
The Node HTTP adapter maps rejection to 400, routes other requests to 404, and
JSON-encodes successful text. The java implementation below owns validation
and greeting construction.

```java file=src/Greeting.java part=implementation
public class Greeting {
  public static void main(String[] args) {
    String name = args[0].trim();
    if (name.isEmpty()) System.exit(2);
    System.out.println("Hello, " + name + "!");
  }
}
```
