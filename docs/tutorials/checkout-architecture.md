---
id: ricestax.tutorial.checkout-architecture
kind: tutorial
title: Review checkout boundaries with CALM
---
# Review checkout boundaries with CALM

Use [the complete example](../../examples/checkout-architecture-calm/README.md).
Copy it from the source checkout or installed npm package into a working directory.
It needs Node and Rice’s Tax, but no application server or language compiler.

## 1. State responsibilities and access

Read `docs/reference/architecture.md`: the customer enters through the gateway,
Orders calls Payments, and Orders alone accesses the order database. These are
specific design decisions, not universal rules for every checkout system.

## 2. Generate and inspect the model

Run `ricestax canon tangle` to generate `architecture.calm.json`. Run
`node tools/build.mjs` to check JSON syntax and `ricestax canon model architecture.calm.json`
to inspect the extracted architecture elements. Names and descriptions become
review material. Neither command deploys anything; full CALM schema validation
is a separate concern.

## 3. Exercise architecture assertions

Run `node --test --test-reporter=tap test/architecture.test.mjs`. Tests check node
types, references, entry through the gateway and exclusive database ownership.
Then run `ricestax mutate`: one fault gives Customer direct database access, and
another gives Payments the persistence connection. Both models still parse and
reference existing nodes. The policy assertions must kill both faults.

## 4. Review a change

Run `ricestax assess` and `ricestax pay 8091`. Review the design and its evidence.
Edit the source page when responsibilities change, retangle and check the new
model. Keep tests independent: changing the architecture is not itself a reason
to automatically rewrite an assertion to accept it. Deliberate boundary changes
need a corresponding decision and review.

Use [the migration guide](../how-to/adopt-existing-project.md) for an existing
model, [the CALM reference](../reference/language-calm.md) for extraction details,
and [the explanation](../explanation/language-specific-examples.md) for the limits
of model-level evidence. Passing tests do not establish deployed network policy.
