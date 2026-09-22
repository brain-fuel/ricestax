---
id: expression.reference.grammar
kind: reference
title: Integer expression language
---
# Integer expression language

Parse and evaluate nonnegative integer literals, arithmetic and parentheses.
Multiplication and division bind more tightly than addition and subtraction;
operators associate left. Division uses Java integer division. Unary minus is
not supported. Lexer and parser errors reject the entire expression.

## header

Generate a parser and visitor in Java.

```antlr4 file=src/Expression.g4 part=header
grammar Expression;
```

## input

Consume the whole input so trailing garbage cannot pass.

```antlr4 file=src/Expression.g4 part=input
input : expression EOF ;
```

## expression

Add and subtract complete multiplicative terms, from left to right.

```antlr4 file=src/Expression.g4 part=expression
expression : term (('+' | '-') term)* ;
```

## term

Multiply and divide atoms before evaluating additive operators.

```antlr4 file=src/Expression.g4 part=term
term : atom (('*' | '/') atom)* ;
```

## atom

Parentheses explicitly override precedence.

```antlr4 file=src/Expression.g4 part=atom
atom : INT | '(' expression ')' ;
```

## integer

A literal has one or more decimal digits.

```antlr4 file=src/Expression.g4 part=integer
INT : [0-9]+ ;
```

## spacing

Whitespace has no semantic value.

```antlr4 file=src/Expression.g4 part=spacing
WS : [ \t\r\n]+ -> skip ;
```

