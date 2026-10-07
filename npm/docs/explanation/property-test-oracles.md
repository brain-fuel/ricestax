---
id: ricestax.explanation.property-test-oracles
kind: explanation
title: Why generated examples still need independent expectations
---
# Why generated examples still need independent expectations

Random inputs do not make an assertion meaningful. A test that calls the application's
normalizer to calculate the expected greeting can preserve the very normalization
bug it was meant to detect. The HTTP examples instead build a known core, surround
it with generated padding, and expect the original core. The server owns trimming;
the test owns the expected result. The tests communicate with real HTTP listeners
and decode actual response bodies, so transport encoding and routing are exercised.

Java and Kotlin deliberately use Jackson in their tests rather than copying their
application's handwritten JSON quoting routine. ANTLR's generator computes an
arithmetic value from a tree before rendering text for the separate parser process.
CALM's expected roles and connections are stated independently of the supplied model.
Its generated permutations and invalid variants exercise the policy assertions,
not a nonexistent CALM application runtime or complete CALM schema validator.

Shrinking is valuable because a long escaped Unicode string can reduce to `A+Z`,
revealing that a plus was incorrectly turned into a space. Replay lets another person
inspect that failure. Neither mechanism chooses the right contract: deciding which
whitespace to trim or how duplicate query parameters behave still requires a domain
decision. The [reference](../reference/example-properties.md) states the actual
sampling domains and deliberately leaves unsupported claims out.

The catalogs challenge specific faults, including literal-plus corruption that the
original fixed HTTP examples missed. Killing those faults establishes that the
assertions distinguish those implementations under the tested inputs. It does not
establish a universal mutation score, exhaustive behavioral coverage, production
readiness or correctness of every test oracle. Surviving, uncompilable and timed-out
mutations remain distinct findings; none should be silently counted as a passing
quality gate.

The [replay how-to](../how-to/replay-property-failures.md) describes how to preserve
counterexamples and use them during review. Each language tutorial demonstrates
building, deliberately breaking and repairing its own example.
