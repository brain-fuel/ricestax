package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"pgregory.net/rapid"
	"reflect"
	"strings"
	"testing"
	"time"
	"unicode/utf8"
)

func TestHTTPContract(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(greetingHandler))
	defer server.Close()
	client := &http.Client{Timeout: 5 * time.Second}
	check := func(method, path string, status int, body map[string]string) {
		t.Helper()
		req, err := http.NewRequest(method, server.URL+path, nil)
		if err != nil {
			t.Fatal(err)
		}
		response, err := client.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		defer response.Body.Close()
		if response.StatusCode != status {
			t.Fatalf("%s: status %d, want %d", path, response.StatusCode, status)
		}
		if !strings.HasPrefix(response.Header.Get("Content-Type"), "application/json") {
			t.Fatal("content type")
		}
		var actual map[string]string
		if err := json.NewDecoder(response.Body).Decode(&actual); err != nil {
			t.Fatal(err)
		}
		if !reflect.DeepEqual(actual, body) {
			t.Fatalf("%s: body %#v, want %#v", path, actual, body)
		}
	}
	for _, pair := range [][2]string{{"Ada", "Ada"}, {"  Ada Lovelace  ", "Ada Lovelace"}, {"A\"B", "A\"B"}, {"Zoë", "Zoë"}} {
		name, expected := pair[0], pair[1]
		check("GET", "/greet?name="+url.QueryEscape(name), 200, map[string]string{"greeting": "Hello, " + expected + "!"})
	}
	for _, query := range []string{"", "?name=", "?name=%20%20"} {
		check("GET", "/greet"+query, 400, map[string]string{"error": "A nonempty name is required"})
	}
	check("GET", "/other", 404, map[string]string{"error": "Not found"})
	check("POST", "/greet?name=Ada", 404, map[string]string{"error": "Not found"})
}

func TestGeneratedHTTPContract(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(greetingHandler))
	defer server.Close()
	client := &http.Client{Timeout: 5 * time.Second}
	rapid.Check(t, func(rt *rapid.T) {
		middle := rapid.SliceOfN(rapid.SampledFrom([]rune("aZ0 \t\r\n\x00\"\\&+%/éλ界😀")), 0, 64).Draw(rt, "middle")
		left := rapid.SliceOfN(rapid.SampledFrom([]rune(" \t\r\n")), 0, 12).Draw(rt, "left")
		right := rapid.SliceOfN(rapid.SampledFrom([]rune(" \t\r\n")), 0, 12).Draw(rt, "right")
		suffix := rapid.SliceOfN(rapid.SampledFrom([]rune("ab09")), 0, 32).Draw(rt, "suffix")
		method := rapid.SampledFrom([]string{"POST", "PUT", "DELETE", "PATCH", "OPTIONS"}).Draw(rt, "method")
		// Build the expected core before padding, without reusing TrimSpace.
		core := "A" + string(middle) + "Z"
		cases := []struct {
			method, path string
			status       int
			body         map[string]string
		}{
			{"GET", "/greet?name=" + url.QueryEscape(string(left)+core+string(right)), 200, map[string]string{"greeting": "Hello, " + core + "!"}},
			{"GET", "/greet?name=" + url.QueryEscape(string(left)), 400, map[string]string{"error": "A nonempty name is required"}},
			{"GET", "/missing-" + string(suffix) + "?name=Ada", 404, map[string]string{"error": "Not found"}},
			{method, "/greet?name=Ada", 404, map[string]string{"error": "Not found"}},
		}
		for _, c := range cases {
			req, err := http.NewRequest(c.method, server.URL+c.path, nil)
			if err != nil {
				rt.Fatal(err)
			}
			response, err := client.Do(req)
			if err != nil {
				rt.Fatal(err)
			}
			var actual map[string]string
			err = json.NewDecoder(response.Body).Decode(&actual)
			response.Body.Close()
			if err != nil {
				rt.Fatal(err)
			}
			if response.StatusCode != c.status {
				rt.Fatalf("status %d, want %d", response.StatusCode, c.status)
			}
			if !strings.HasPrefix(response.Header.Get("Content-Type"), "application/json") {
				rt.Fatal("content type")
			}
			if !reflect.DeepEqual(actual, c.body) {
				rt.Fatalf("body %#v, want %#v", actual, c.body)
			}
		}
	})
}

// Fuzzing complements Rapid's structured cases with arbitrary valid UTF-8 interiors.
func FuzzHTTPGreeting(f *testing.F) {
	for _, seed := range []string{"", "+", "\"\\\x00", "Zoë界😀", "a\n\tb"} {
		f.Add(seed)
	}
	server := httptest.NewServer(http.HandlerFunc(greetingHandler))
	defer server.Close()
	client := &http.Client{Timeout: 5 * time.Second}
	f.Fuzz(func(t *testing.T, interior string) {
		if !utf8.ValidString(interior) || len(interior) > 256 {
			t.Skip()
		}
		core := "A" + interior + "Z"
		response, err := client.Get(server.URL + "/greet?name=" + url.QueryEscape(" \t"+core+"\r\n"))
		if err != nil {
			t.Fatal(err)
		}
		defer response.Body.Close()
		if response.StatusCode != http.StatusOK {
			t.Fatalf("status: %d", response.StatusCode)
		}
		if !strings.HasPrefix(response.Header.Get("Content-Type"), "application/json") {
			t.Fatal("content type")
		}
		var actual map[string]string
		if err := json.NewDecoder(response.Body).Decode(&actual); err != nil {
			t.Fatal(err)
		}
		expected := map[string]string{"greeting": "Hello, " + core + "!"}
		if !reflect.DeepEqual(actual, expected) {
			t.Fatalf("body %#v, want %#v", actual, expected)
		}
	})
}
