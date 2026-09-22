---
id: greeting.java.service
kind: reference
title: Native java HTTP service
---
# Greeting HTTP service

The server accepts GET /greet, trims the name and returns JSON. Missing or blank
names produce 400. Other paths and methods produce 404. Tests use real HTTP
connections against the same application on an ephemeral port.

## Implementation

The java runtime owns routing, input validation, JSON encoding and HTTP transport.

```java file=src/Greeting.java part=implementation
import com.sun.net.httpserver.HttpServer;
import com.sun.net.httpserver.HttpExchange;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;

public class Greeting {
    public static String quote(String text) {
        StringBuilder out = new StringBuilder("\"");
        for (char c : text.toCharArray()) {
            switch (c) {
                case '"': out.append("\\\""); break;
                case '\\': out.append("\\\\"); break;
                default:
                    if (c < 32) out.append(String.format("\\u%04x", (int)c));
                    else out.append(c);
            }
        }
        return out.append('"').toString();
    }
    public static HttpServer create(int port) throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", port), 0);
        server.createContext("/", Greeting::handle);
        return server;
    }
    private static void handle(HttpExchange exchange) throws IOException {
        int status = 200;
        String body;
        if (!exchange.getRequestMethod().equals("GET") || !exchange.getRequestURI().getPath().equals("/greet")) {
            status = 404; body = "{\"error\":\"Not found\"}";
        } else {
            String name = "";
            String query = exchange.getRequestURI().getRawQuery();
            if (query != null) for (String pair : query.split("&")) {
                String[] parts = pair.split("=", 2);
                if (URLDecoder.decode(parts[0], StandardCharsets.UTF_8).equals("name")) {
                    name = parts.length == 2 ? URLDecoder.decode(parts[1], StandardCharsets.UTF_8) : "";
                    break;
                }
            }
            name = name.strip();
            if (name.isEmpty()) { status = 400; body = "{\"error\":\"A nonempty name is required\"}"; }
            else body = "{\"greeting\":" + quote("Hello, " + name + "!") + "}";
        }
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json; charset=utf-8");
        exchange.sendResponseHeaders(status, bytes.length);
        try (var output = exchange.getResponseBody()) { output.write(bytes); }
    }
    public static void main(String[] args) throws Exception {
        HttpServer server = create(8097); server.start();
        System.out.println("http://127.0.0.1:8097/greet?name=Ada");
    }
}

```
