---
id: greeting.go.service
kind: reference
title: Greeting service (go)
---
# Greeting policy

Reject an empty or whitespace-only name, trim surrounding whitespace, and greet the caller.
The Node HTTP adapter maps rejection to 400, routes other requests to 404, and
JSON-encodes successful text. The go implementation below owns validation
and greeting construction.

```go file=src/main.go part=implementation
package main

import (
    "fmt"
    "os"
    "strings"
)

func main() {
    name := strings.TrimSpace(os.Args[1])
    if len(name) == 0 {
        os.Exit(2)
    }
    fmt.Println("Hello, " + name + "!")
}

```
