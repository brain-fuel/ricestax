// Tangled from service.md.
// Edit the specification, not this file.
// Every comment below is generated from the prose there.

/** The go runtime owns routing, input validation, JSON encoding and HTTP transport.
 *
 * Specified by service.
 */
package main

import (
    "encoding/json"
    "fmt"
    "net/http"
    "strings"
)

func greetingHandler(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json; charset=utf-8")
    if r.Method != http.MethodGet || r.URL.Path != "/greet" {
        w.WriteHeader(http.StatusNotFound)
        json.NewEncoder(w).Encode(map[string]string{"error": "Not found"})
        return
    }
    name := strings.TrimSpace(r.URL.Query().Get("name"))
    if len(name) == 0 {
        w.WriteHeader(http.StatusBadRequest)
        json.NewEncoder(w).Encode(map[string]string{"error": "A nonempty name is required"})
        return
    }
    json.NewEncoder(w).Encode(map[string]string{"greeting": "Hello, " + name + "!"})
}

func main() {
    fmt.Println("http://127.0.0.1:8097/greet?name=Ada")
    if err := http.ListenAndServe("127.0.0.1:8097", http.HandlerFunc(greetingHandler)); err != nil {
        panic(err)
    }
}
