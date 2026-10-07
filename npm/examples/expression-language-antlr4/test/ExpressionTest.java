import java.io.File;
import org.jetbrains.jetCheck.Generator;
import org.jetbrains.jetCheck.PropertyChecker;
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
        generatedExpressions();
        System.out.println("TESTS_PASSED: expression contract");
    }

    record Expression(String text, long value) {}

    private static Generator<Expression> expressions(int depth) {
        if (depth == 0) return Generator.integers(0, 100).map(n -> new Expression(n.toString(), n));
        return Generator.from(env -> {
            Expression left = env.generate(expressions(depth - 1));
            String operator = env.generate(Generator.sampledFrom("+", "-", "*", "/"));
            Expression right = operator.equals("/")
                ? env.generate(Generator.integers(1, 9).map(n -> new Expression(n.toString(), n)))
                : env.generate(expressions(depth - 1));
            long expected = switch (operator) {
                case "+" -> left.value() + right.value();
                case "-" -> left.value() - right.value();
                case "*" -> left.value() * right.value();
                default -> left.value() / right.value();
            };
            return new Expression("(" + left.text() + operator + right.text() + ")", expected);
        });
    }

    private static void generatedExpressions() {
        var parameters = PropertyChecker.customized().withIterationCount(100);
        if (System.getenv("JETCHECK_SEED") != null)
            parameters = parameters.withSeed(Long.parseLong(System.getenv("JETCHECK_SEED")));
        if (System.getenv("JETCHECK_RECHECK") != null)
            parameters = parameters.rechecking(System.getenv("JETCHECK_RECHECK"));
        parameters.forAll(expressions(3), expression -> {
            try {
                String[] valid = evaluate(expression.text());
                check(valid[0].equals("0"), "generated expression rejected: " + expression);
                check(valid[1].trim().equals(Long.toString(expression.value())), "wrong generated result: " + expression + " got " + valid[1]);
                for (String invalid : new String[]{expression.text()+" 0", "("+expression.text()}) {
                    String[] rejected = evaluate(invalid);
                    check(rejected[0].equals("2") && rejected[1].isEmpty(), "accepted malformed expression: " + invalid);
                }
            } catch (Exception e) { throw new AssertionError("expression process failed", e); }
            return true; // Success is conditional on every assertion above.
        });
    }

}
