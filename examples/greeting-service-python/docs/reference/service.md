---
id: greeting.python.service
kind: reference
title: Native python HTTP service
---
# Greeting HTTP service

The server accepts GET /greet, trims the name and returns JSON. Missing or blank
names produce 400. Other paths and methods produce 404. Tests use real HTTP
connections against the same application on an ephemeral port.

## Implementation

The python runtime owns routing, input validation, JSON encoding and HTTP transport.

```python file=src/greeting.py part=implementation
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit


class GreetingHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = urlsplit(self.path)
        if url.path != "/greet":
            self.reply(404, {"error": "Not found"})
            return
        name = parse_qs(url.query, keep_blank_values=True).get("name", [""])[0].strip()
        if not name:
            self.reply(400, {"error": "A nonempty name is required"})
            return
        self.reply(200, {"greeting": "Hello, " + name + "!"})

    def do_POST(self):
        self.reply(404, {"error": "Not found"})

    do_PUT = do_POST
    do_DELETE = do_POST
    do_PATCH = do_POST
    do_HEAD = do_POST
    do_OPTIONS = do_POST

    def reply(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def log_message(self, format, *args):
        pass


def create_server(port=0):
    return ThreadingHTTPServer(("127.0.0.1", port), GreetingHandler)


if __name__ == "__main__":
    with create_server(8097) as server:
        print("http://127.0.0.1:8097/greet?name=Ada", flush=True)
        server.serve_forever()

```
