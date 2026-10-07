# CALM: checkout ownership and access boundaries

This example models a Customer, API Gateway, Order Service, Payment Service and
Order Database. It describes a system; it does not implement or deploy one.

The allowed connections are Customer → Gateway → Orders, Orders → Payments, and
Orders → Order Database. Only Orders owns persistence. No customer may access
storage directly, and Payments has no access to the order database.

Requires Node 22+ and Rice’s Tax 0.3.2. From this directory:

```sh
ricestax canon tangle
ricestax canon tangle --check
node tools/build.mjs
node --test --test-reporter=tap test/architecture.test.mjs
ricestax mutate
ricestax assess
ricestax pay 8091
```

Edit `docs/reference/architecture.md` and retangle to produce
`architecture.calm.json`. The JSON parse is only a syntax check. Rice’s Tax
extracts the CALM elements for review and checks supported identities/references;
this example does not perform full CALM JSON Schema validation.

The independent architectural assertions encode the intended boundaries. Two
mutations retain valid JSON and existing node references: one connects Customer
to the database, and one gives Payments the Orders persistence connection. The
unchanged policy tests must kill both. This proves those model changes are noticed;
it does not prove deployed infrastructure enforces the design.

For a new architecture, add your actors, services, data stores and connections,
then encode the ownership and access rules you actually intend to preserve. For
an existing CALM model, initialize `calm,javascript,folio` separately and adopt the review
configuration before moving the model into documentation. Do not blindly copy
this checkout policy to another system.
See [the walkthrough](../../docs/tutorials/checkout-architecture.md),
[language reference](../../docs/reference/language-calm.md), and
[migration how-to](../../docs/how-to/adopt-existing-project.md).

CALM is declarative JSON, with no application runtime or executable test language.
The architecture-policy assertions use Node’s JavaScript test runner. This is
explicitly a model example, separate from the native HTTP application examples.

The build helper installs pinned fast-check dependencies with `npm ci`. The JavaScript
policy tests assert the supplied architecture against independently declared node
roles and connections. Two generated checks then permute node/relationship order
without changing the verdict, and add forbidden edges or remove nodes and require
rejection. These properties exercise the checkout policy checker; they do not turn
CALM into an executable HTTP service or validate the complete CALM JSON Schema.

Run `FC_SEED=123 node --test test/architecture.test.mjs` for a reproducible generation
sequence. Use the actual seed and `FC_PATH` printed on a failure to replay its shrunk
case. The five catalog faults challenge the gateway boundary, database ownership,
node type, a dangling reference, and duplicate relationship identity. Inspect which
assertion fails; a JSON parse error is not evidence that these policies caught a fault.
