import org.antlr.v4.runtime.*;
public class GreetingMain {
 public static void main(String[] args) {
  String name=args[0].trim();
  GreetingLexer lexer=new GreetingLexer(CharStreams.fromString(name));
  final boolean[] bad={false};
  BaseErrorListener errors=new BaseErrorListener(){public void syntaxError(Recognizer<?,?> r,Object s,int l,int c,String m,RecognitionException e){bad[0]=true;}};
  lexer.removeErrorListeners();lexer.addErrorListener(errors);
  GreetingParser parser=new GreetingParser(new CommonTokenStream(lexer));
  parser.removeErrorListeners();parser.addErrorListener(errors);parser.name();
  if(bad[0])System.exit(2);
  System.out.println("Hello, "+name+"!");
 }
}
