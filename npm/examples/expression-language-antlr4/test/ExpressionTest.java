import java.io.File;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.TimeUnit;

public class ExpressionTest {
    private static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }
    private static String[] evaluate(String input) throws Exception {
        String jar = System.getenv("ANTLR_JAR");
        if (jar == null) throw new IllegalStateException("Set ANTLR_JAR");
        Process process = new ProcessBuilder("java", "-cp", "build"+File.pathSeparator+jar, "Evaluate", input).start();
        if (!process.waitFor(10, TimeUnit.SECONDS)) { process.destroyForcibly(); throw new IllegalStateException("Evaluator timeout"); }
        return new String[]{Integer.toString(process.exitValue()), new String(process.getInputStream().readAllBytes(),StandardCharsets.UTF_8), new String(process.getErrorStream().readAllBytes(),StandardCharsets.UTF_8)};
    }
    public static void main(String[] args) throws Exception {
        String[][] valid = {{"2+3*4","14"},{"(2+3)*4","20"},{"20-5-3","12"},{"20/5/2","2"},{" 12 + 3 \n","15"},{"7/2","3"}};
        for (String[] c : valid) {
            String[] result = evaluate(c[0]);
            check(result[0].equals("0"),c[0]+": exit "+result[0]+" "+result[2]);
            check(result[1].trim().equals(c[1]),c[0]+": result "+result[1]);
        }
        for (String input : new String[]{"","2+","(2+3","1 2","2@3","2**3","-1","4/0","999999999999999999999999"}) {
            String[] result = evaluate(input);
            check(result[0].equals("2"),input+": must reject");
            check(result[1].isEmpty(),input+": must not return a value");
            check(result[2].contains("Invalid expression") || result[2].contains("Invalid arithmetic"),input+": wrong error");
        }
        System.out.println("TESTS_PASSED: expression contract");
    }
}
