---
id: greeting.kotlin.service
kind: reference
title: Greeting service (kotlin)
---
# Greeting policy

Reject an empty or whitespace-only name, trim surrounding whitespace, and greet the caller.
The Node HTTP adapter maps rejection to 400, routes other requests to 404, and
JSON-encodes successful text. The kotlin implementation below owns validation
and greeting construction.

```kotlin file=src/Greeting.kt part=implementation
fun main(args: Array<String>) {
    val name = args[0].trim()
    if (name.isEmpty()) kotlin.system.exitProcess(2)
    println("Hello, " + name + "!")
}

```
