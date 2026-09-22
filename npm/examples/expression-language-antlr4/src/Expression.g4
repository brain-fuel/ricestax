// Tangled from grammar.md.
// Edit the specification, not this file.
// Every comment below is generated from the prose there.

/** Generate a parser and visitor in Java.
 *
 * Specified by grammar.
 */
grammar Expression;

/** Consume the whole input so trailing garbage cannot pass.
 *
 * Specified by grammar.
 */
input : expression EOF ;

/** Add and subtract complete multiplicative terms, from left to right.
 *
 * Specified by grammar.
 */
expression : term (('+' | '-') term)* ;

/** Multiply and divide atoms before evaluating additive operators.
 *
 * Specified by grammar.
 */
term : atom (('*' | '/') atom)* ;

/** Parentheses explicitly override precedence.
 *
 * Specified by grammar.
 */
atom : INT | '(' expression ')' ;

/** A literal has one or more decimal digits.
 *
 * Specified by grammar.
 */
INT : [0-9]+ ;

/** Whitespace has no semantic value.
 *
 * Specified by grammar.
 */
WS : [ \t\r\n]+ -> skip ;
