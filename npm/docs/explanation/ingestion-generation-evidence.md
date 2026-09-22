---
id: ricestax.explanation.ingestion-generation-evidence
kind: explanation
title: What ingestion, generation and testing establish
---
# What ingestion, generation and testing establish

Ingestion identifies material that people need to judge. A parser establishes
that it can read the selected syntax; it does not establish that the program is
correct, that a comment is true, or that an architecture is deployed.

Generation has two paths. Folio tangling assembles explicit code blocks from
reviewable documentation and records their source mapping. CALM scaffolding uses
architecture service identities to build a small executable starting boundary.
The latter does not infer domain behaviour from descriptions. Both outputs still
need compilation, tests, review, and change detection.

Mutation testing asks whether particular faults are detected. The catalog runner
makes those faults explicit and reproducible. A failed compiler proves only that
the mutated program could not compile. A killed mutant requires test-failure
evidence. A survivor may reveal a testing gap, unnecessary code, or equivalence;
a person must investigate before deciding. The test evidence patterns and declared
input scope are part of that evidence and must be reviewed too.

Architecture descriptions are Why assertions. Structural bodies and source names
are What material. A topology change does not prove a runtime regression, but it
invalidates a review that was made against the old structure. Relationship
references connect the architecture elements; they are not proof that every
network connection in the implementation follows that model.

Diátaxis separates learning, practical tasks, exact reference, and explanation.
The tutorials build competence through working examples. Migration and mutation
guides solve adoption tasks. References specify the supported boundaries. This
page explains why the boundaries exist. ref:diataxis
