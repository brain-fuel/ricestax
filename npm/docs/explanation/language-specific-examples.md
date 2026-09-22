---
id: ricestax.explanation.language-specific-examples
kind: explanation
title: Different languages need different evidence
---
# Different languages need different evidence

General-purpose language examples implement an HTTP server and its tests in
the same language. ANTLR4 defines a language's syntax; its example generates a recognizer and
uses a Java visitor to evaluate expressions. CALM models architectural intent;
its example asserts access boundaries and data ownership over a checkout model.
Making all three look like web applications obscures what each actually supplies.

The shared process is document, generate, exercise, mutate and review. Its evidence
differs. HTTP responses test a running implementation; parser results and failures
test syntax and interpretation; architectural assertions test a model against
chosen design constraints. None substitutes for the other two.

A compiler accepting a grammar is not proof that the intended language is accepted.
A model being valid JSON is not proof that its boundaries are appropriate.
The example mutations therefore compile or parse successfully while breaking a
specific independent assertion. They do not claim exhaustive coverage, production
readiness, full schema validation, or enforcement of the architecture in deployment.

Version 0.3.1 replaces the 0.3.0 greeting-service variants for ANTLR4 and CALM.
The seven general-purpose greeting variants remain. The `scaffold` command still
creates small service-membership starters; these richer worked examples are
packaged projects, not newly inferred scaffold output.

Version 0.3.2 removes the process-based HTTP adapters from the general-purpose
examples. Java, Python, Go, Haskell and Kotlin own their HTTP transports and native
tests; TypeScript owns typed server and test sources. ANTLR’s evaluator and tests
are Java. CALM remains a declarative architecture with JavaScript policy checks.
