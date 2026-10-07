import io.kotest.property.Arb
import io.kotest.property.PropTestConfig
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.map
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import com.fasterxml.jackson.databind.ObjectMapper
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
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
        generatedContract(client, base)
        println("TESTS_PASSED: HTTP contract")
    } finally { server.stop(0) }
}


@OptIn(io.kotest.common.ExperimentalKotest::class)
fun generatedContract(client: HttpClient, base: String) = runBlocking {
    val middle = Arb.list(Arb.element(listOf("a", "Z", "0", " ", "\t", "\r", "\n", "\u0000", "\"", "\\", "&", "+", "%", "/", "é", "λ", "界", "😀")), 0..64).map { it.joinToString("") }
    val padding = Arb.list(Arb.element(listOf(" ", "\t", "\r", "\n")), 0..12).map { it.joinToString("") }
    val suffix = Arb.list(Arb.element(listOf("a", "b", "0", "9")), 0..32).map { it.joinToString("") }
    val method = Arb.element(listOf("POST", "PUT", "DELETE", "PATCH", "OPTIONS"))
    val config = PropTestConfig(iterations = 100, seed = System.getenv("KOTEST_SEED")?.toLong())
    checkAll(config, middle, padding, padding, suffix, method) { inside, left, right, route, verb ->
        // Construct the oracle before adding padding; do not call trim here.
        val core = "A" + inside + "Z"
        checkGenerated(client, base, "GET", "/greet?name=" + encode(left + core + right), 200, mapOf("greeting" to "Hello, $core!"))
        checkGenerated(client, base, "GET", "/greet?name=" + encode(left), 400, mapOf("error" to "A nonempty name is required"))
        checkGenerated(client, base, "GET", "/missing-$route?name=Ada", 404, mapOf("error" to "Not found"))
        checkGenerated(client, base, verb, "/greet?name=Ada", 404, mapOf("error" to "Not found"))
    }
}

fun encode(text: String): String = URLEncoder.encode(text, StandardCharsets.UTF_8)

fun checkGenerated(client: HttpClient, base: String, method: String, path: String, status: Int, expected: Map<String, String>) {
    val response = client.send(HttpRequest.newBuilder(URI.create(base + path))
        .timeout(Duration.ofSeconds(5)).method(method, HttpRequest.BodyPublishers.noBody()).build(), HttpResponse.BodyHandlers.ofString())
    assertContract(response.statusCode() == status, "status ${response.statusCode()}, expected $status")
    assertContract(response.headers().firstValue("content-type").orElse("").startsWith("application/json"), "content type")
    val mapper = ObjectMapper()
    assertContract(mapper.readTree(response.body()) == mapper.valueToTree<com.fasterxml.jackson.databind.JsonNode>(expected), "body ${response.body()}")
}
