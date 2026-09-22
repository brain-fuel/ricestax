import org.antlr.v4.runtime.*;

public class Evaluate extends ExpressionBaseVisitor<Long> {
    @Override public Long visitExpression(ExpressionParser.ExpressionContext ctx) {
        long value = visit(ctx.term(0));
        for (int i = 1; i < ctx.term().size(); i++) {
            long right = visit(ctx.term(i));
            value = ctx.getChild(2*i-1).getText().equals("+") ? value + right : value - right;
        }
        return value;
    }
    @Override public Long visitTerm(ExpressionParser.TermContext ctx) {
        long value = visit(ctx.atom(0));
        for (int i = 1; i < ctx.atom().size(); i++) {
            long right = visit(ctx.atom(i));
            value = ctx.getChild(2*i-1).getText().equals("*") ? value * right : value / right;
        }
        return value;
    }
    @Override public Long visitAtom(ExpressionParser.AtomContext ctx) {
        return ctx.INT() == null ? visit(ctx.expression()) : Long.parseLong(ctx.INT().getText());
    }
    public static void main(String[] args) {
        if (args.length != 1) { System.err.println("Pass one expression"); System.exit(2); }
        final boolean[] invalid = {false};
        BaseErrorListener errors = new BaseErrorListener() {
            @Override public void syntaxError(Recognizer<?,?> r, Object s, int l, int c, String m, RecognitionException e) {
                invalid[0] = true;
            }
        };
        ExpressionLexer lexer = new ExpressionLexer(CharStreams.fromString(args[0]));
        lexer.removeErrorListeners(); lexer.addErrorListener(errors);
        ExpressionParser parser = new ExpressionParser(new CommonTokenStream(lexer));
        parser.removeErrorListeners(); parser.addErrorListener(errors);
        ExpressionParser.InputContext input = parser.input();
        if (invalid[0]) { System.err.println("Invalid expression"); System.exit(2); }
        try { System.out.println(new Evaluate().visit(input.expression())); }
        catch (ArithmeticException | NumberFormatException e) { System.err.println("Invalid arithmetic"); System.exit(2); }
    }
}
