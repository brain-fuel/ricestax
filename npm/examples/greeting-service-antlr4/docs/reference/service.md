---
id: greeting.antlr4.service
kind: reference
title: Greeting service (antlr4)
---
# Greeting policy

Reject an empty or whitespace-only name, trim surrounding whitespace, and greet the caller.
The Node HTTP adapter maps rejection to 400, routes other requests to 404, and
JSON-encodes successful text. The antlr4 implementation below owns validation
and greeting construction together with the Java visitor-free driver.

```antlr4 file=src/Greeting.g4 part=header
grammar Greeting;
```

## 1. Complete name

Accept a nonempty name and consume the complete input.

```antlr4 file=src/Greeting.g4 def=name
name : WORD (SPACE WORD)* EOF ;
```

## 2. Visible words

A visible word retains punctuation and Unicode characters.

```antlr4 file=src/Greeting.g4 def=WORD
WORD : ~[ \t\r\n]+ ;
```

## 3. Internal spacing

Spaces and tabs separate words inside a name.

```antlr4 file=src/Greeting.g4 def=SPACE
SPACE : [ \t]+ ;
```
