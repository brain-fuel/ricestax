import java.net.URI;
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
            System.out.println("TESTS_PASSED: HTTP contract");
        } finally { server.stop(0); }
    }
}
