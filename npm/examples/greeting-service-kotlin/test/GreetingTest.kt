import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.time.Duration

fun assertContract(condition: Boolean, message: String) {
    if (!condition) throw AssertionError(message)
}

fun main() {
    val server = createGreetingServer(0)
    server.start()
    val base = "http://127.0.0.1:${server.address.port}"
    val client = HttpClient.newHttpClient()
    try {
        val cases = listOf(
            Triple("/greet?name=Ada", 200, "{\"greeting\":\"Hello, Ada!\"}"),
            Triple("/greet?name=%20Ada%20Lovelace%20", 200, "{\"greeting\":\"Hello, Ada Lovelace!\"}"),
            Triple("/greet?name=A%22B", 200, "{\"greeting\":\"Hello, A\\\"B!\"}"),
            Triple("/greet?name=Zo%C3%AB", 200, "{\"greeting\":\"Hello, Zoë!\"}"),
            Triple("/greet", 400, "{\"error\":\"A nonempty name is required\"}"),
            Triple("/greet?name=", 400, "{\"error\":\"A nonempty name is required\"}"),
            Triple("/greet?name=%20%20", 400, "{\"error\":\"A nonempty name is required\"}"),
            Triple("/other", 404, "{\"error\":\"Not found\"}")
        )
        for ((path, status, body) in cases) {
            val response = client.send(HttpRequest.newBuilder(URI.create(base+path)).timeout(Duration.ofSeconds(5)).build(), HttpResponse.BodyHandlers.ofString())
            assertContract(response.statusCode() == status, "$path status")
            assertContract(response.body() == body, "$path body: ${response.body()}")
            assertContract(response.headers().firstValue("content-type").orElse("").startsWith("application/json"), "content type")
        }
        val response = client.send(HttpRequest.newBuilder(URI.create(base+"/greet?name=Ada")).POST(HttpRequest.BodyPublishers.noBody()).build(), HttpResponse.BodyHandlers.ofString())
        assertContract(response.statusCode() == 404, "wrong method")
        println("TESTS_PASSED: HTTP contract")
    } finally { server.stop(0) }
}
