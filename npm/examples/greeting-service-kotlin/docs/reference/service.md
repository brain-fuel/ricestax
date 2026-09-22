---
id: greeting.kotlin.service
kind: reference
title: Native kotlin HTTP service
---
# Greeting HTTP service

The server accepts GET /greet, trims the name and returns JSON. Missing or blank
names produce 400. Other paths and methods produce 404. Tests use real HTTP
connections against the same application on an ephemeral port.

## Implementation

The kotlin runtime owns routing, input validation, JSON encoding and HTTP transport.

```kotlin file=src/Greeting.kt part=implementation
import com.sun.net.httpserver.HttpServer
import java.net.InetSocketAddress
import java.net.URLDecoder
import java.nio.charset.StandardCharsets

fun jsonQuote(text: String): String {
    val out = StringBuilder("\"")
    for (c in text) {
        when (c) {
            '"' -> out.append("\\\"")
            '\\' -> out.append("\\\\")
            else -> if (c.code < 32) out.append("\\u%04x".format(c.code)) else out.append(c)
        }
    }
    return out.append('"').toString()
}

fun createGreetingServer(port: Int): HttpServer {
    val server = HttpServer.create(InetSocketAddress("127.0.0.1", port), 0)
    server.createContext("/") { exchange ->
        var status = 200
        val body: String
        if (exchange.requestMethod != "GET" || exchange.requestURI.path != "/greet") {
            status = 404
            body = "{\"error\":\"Not found\"}"
        } else {
            val pair = exchange.requestURI.rawQuery.orEmpty().split("&")
                .map { it.split("=", limit = 2) }
                .firstOrNull { URLDecoder.decode(it[0], StandardCharsets.UTF_8) == "name" }
            val name = URLDecoder.decode(pair?.getOrNull(1).orEmpty(), StandardCharsets.UTF_8).trim()
            if (name.isEmpty()) {
                status = 400
                body = "{\"error\":\"A nonempty name is required\"}"
            } else {
                body = "{\"greeting\":" + jsonQuote("Hello, $name!") + "}"
            }
        }
        val bytes = body.toByteArray(StandardCharsets.UTF_8)
        exchange.responseHeaders.set("Content-Type", "application/json; charset=utf-8")
        exchange.sendResponseHeaders(status, bytes.size.toLong())
        exchange.responseBody.use { it.write(bytes) }
    }
    return server
}

fun main() {
    createGreetingServer(8097).start()
    println("http://127.0.0.1:8097/greet?name=Ada")
}

```
