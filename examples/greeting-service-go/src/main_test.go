package main

import (
    "encoding/json"
    "net/http"
    "net/http/httptest"
    "net/url"
    "reflect"
    "strings"
    "testing"
    "time"
)

func TestHTTPContract(t *testing.T) {
    server := httptest.NewServer(http.HandlerFunc(greetingHandler))
    defer server.Close()
    client := &http.Client{Timeout: 5 * time.Second}
    check := func(method, path string, status int, body map[string]string) {
        t.Helper()
        req, err := http.NewRequest(method, server.URL+path, nil)
        if err != nil { t.Fatal(err) }
        response, err := client.Do(req)
        if err != nil { t.Fatal(err) }
        defer response.Body.Close()
        if response.StatusCode != status { t.Fatalf("%s: status %d, want %d",path,response.StatusCode,status) }
        if !strings.HasPrefix(response.Header.Get("Content-Type"), "application/json") { t.Fatal("content type") }
        var actual map[string]string
        if err := json.NewDecoder(response.Body).Decode(&actual); err != nil { t.Fatal(err) }
        if !reflect.DeepEqual(actual,body) { t.Fatalf("%s: body %#v, want %#v",path,actual,body) }
    }
    for _, name := range []string{"Ada", "  Ada Lovelace  ", "A\"B", "Zoë"} {
        check("GET", "/greet?name="+url.QueryEscape(name),200,map[string]string{"greeting":"Hello, "+strings.TrimSpace(name)+"!"})
    }
    for _, query := range []string{"", "?name=", "?name=%20%20"} {
        check("GET","/greet"+query,400,map[string]string{"error":"A nonempty name is required"})
    }
    check("GET","/other",404,map[string]string{"error":"Not found"})
    check("POST","/greet?name=Ada",404,map[string]string{"error":"Not found"})
}
