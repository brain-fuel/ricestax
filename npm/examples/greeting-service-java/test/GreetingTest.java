import java.net.URI;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Map;
import org.jetbrains.jetCheck.Generator;
import org.jetbrains.jetCheck.IntDistribution;
import org.jetbrains.jetCheck.PropertyChecker;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

public class GreetingTest {
    private static void check(boolean ok, String message) {
        if (!ok) throw new AssertionError(message);
    }
    public static void main(String[] args) throws Exception {
        var server = Greeting.create(0); server.start();
        String base = "http://127.0.0.1:" + server.getAddress().getPort();
        var client = HttpClient.newHttpClient();
        try {
            String[][] cases = {
                {"/greet?name=Ada", "200", "{\"greeting\":\"Hello, Ada!\"}"},
                {"/greet?name=%20Ada%20Lovelace%20", "200", "{\"greeting\":\"Hello, Ada Lovelace!\"}"},
                {"/greet?name=A%22B", "200", "{\"greeting\":\"Hello, A\\\"B!\"}"},
                {"/greet?name=Zo%C3%AB", "200", "{\"greeting\":\"Hello, Zoë!\"}"},
                {"/greet", "400", "{\"error\":\"A nonempty name is required\"}"},
                {"/greet?name=", "400", "{\"error\":\"A nonempty name is required\"}"},
                {"/greet?name=%20%20", "400", "{\"error\":\"A nonempty name is required\"}"},
                {"/other", "404", "{\"error\":\"Not found\"}"}
            };
            for (String[] c : cases) {
                var response = client.send(HttpRequest.newBuilder(URI.create(base+c[0])).timeout(Duration.ofSeconds(5)).build(), HttpResponse.BodyHandlers.ofString());
                check(response.statusCode() == Integer.parseInt(c[1]), c[0]+" status");
                check(response.body().equals(c[2]), c[0]+" body: "+response.body());
                check(response.headers().firstValue("content-type").orElse("").startsWith("application/json"), "content type");
            }
            var post = client.send(HttpRequest.newBuilder(URI.create(base+"/greet?name=Ada")).POST(HttpRequest.BodyPublishers.noBody()).build(), HttpResponse.BodyHandlers.ofString());
            check(post.statusCode()==404,"wrong method");
            generatedContract(client, base);
            System.out.println("TESTS_PASSED: HTTP contract");
        } finally { server.stop(0); }
    }

    record Case(String middle, String left, String right, String suffix, String method) {}

    private static Generator<String> text(int max, String... alphabet) {
        return Generator.listsOf(IntDistribution.uniform(0, max), Generator.sampledFrom(alphabet))
            .map(parts -> String.join("", parts));
    }

    private static void generatedContract(HttpClient client, String base) {
        var middle = text(64, "a", "Z", "0", " ", "\t", "\r", "\n", "\0", "\"", "\\", "&", "+", "%", "/", "é", "λ", "界", "😀");
        var padding = text(12, " ", "\t", "\r", "\n");
        var suffix = text(32, "a", "b", "0", "9");
        var method = Generator.sampledFrom("POST", "PUT", "DELETE", "PATCH", "OPTIONS");
        var cases = Generator.from(env -> new Case(env.generate(middle), env.generate(padding),
            env.generate(padding), env.generate(suffix), env.generate(method)));
        var parameters = PropertyChecker.customized().withIterationCount(100);
        if (System.getenv("JETCHECK_SEED") != null)
            parameters = parameters.withSeed(Long.parseLong(System.getenv("JETCHECK_SEED")));
        if (System.getenv("JETCHECK_RECHECK") != null)
            parameters = parameters.rechecking(System.getenv("JETCHECK_RECHECK"));
        parameters.forAll(cases, c -> {
            String core = "A" + c.middle() + "Z";
            try {
                checkGenerated(client, base, "GET", "/greet?name=" + encode(c.left()+core+c.right()), 200,
                    Map.of("greeting", "Hello, " + core + "!"));
                checkGenerated(client, base, "GET", "/greet?name=" + encode(c.left()), 400,
                    Map.of("error", "A nonempty name is required"));
                checkGenerated(client, base, "GET", "/missing-"+c.suffix()+"?name=Ada", 404, Map.of("error", "Not found"));
                checkGenerated(client, base, c.method(), "/greet?name=Ada", 404, Map.of("error", "Not found"));
            } catch (Exception e) { throw new AssertionError("HTTP property request failed", e); }
            return true; // Every generated case must reach all four assertion groups above.
        });
    }

    private static String encode(String text) { return URLEncoder.encode(text, StandardCharsets.UTF_8); }

    private static void checkGenerated(HttpClient client, String base, String method, String path,
                                      int status, Map<String, String> expected) throws Exception {
        var response = client.send(HttpRequest.newBuilder(URI.create(base + path))
            .timeout(Duration.ofSeconds(5)).method(method, HttpRequest.BodyPublishers.noBody()).build(),
            HttpResponse.BodyHandlers.ofString());
        check(response.statusCode() == status, "status: " + response.statusCode() + ", expected " + status);
        check(response.headers().firstValue("content-type").orElse("").startsWith("application/json"), "content type");
        var mapper = new ObjectMapper();
        check(mapper.readTree(response.body()).equals(mapper.valueToTree(expected)), "body: " + response.body());
    }

}
