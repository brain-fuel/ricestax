// Tangled from service.md.
// Edit the specification, not this file.
// Every comment below is generated from the prose there.

/** Reject an empty or whitespace-only name, trim surrounding whitespace, and greet the caller.
 * The Node HTTP adapter maps rejection to 400, routes other requests to 404, and
 * JSON-encodes successful text. The go implementation below owns validation
 * and greeting construction.
 *
 * Specified by service.
 */
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
