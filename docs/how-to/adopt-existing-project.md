---
id: ricestax.how-to.adopt-existing-project
kind: how-to
title: Adopt an existing project
---
# Adopt an existing project

Start from a clean commit or a separate worktree. Adoption should expose existing
review debt, not rewrite the application or approve it automatically.

1. Install the 0.3 package and keep the project's current build and tests green.
2. Run `ricestax languages` to inspect available profiles. In a repository without
   `canon.yaml`, run `ricestax init --languages java,typescript,calm,folio` with
   your actual languages. Commit `canon.yaml` and `.ricestax/`.
3. If `canon.yaml` already exists, initialize a scratch directory instead. Copy
   `.ricestax/` and merge the selected `languages` entries into your existing
   configuration. Preserve registry, decisions, exemptions, kinds, runtime,
   and verdict paths. `init` deliberately refuses to overwrite either destination.
4. Run `ricestax canon files`. Review the list before assessment: add generated
   outputs, vendored sources, caches, and build folders to `ignore`. Set `root`
   only if limiting scope is intentional; it also limits documentation discovery.
5. Inspect representative files with `ricestax canon model path/to/file`.
   Check declarations and their comments against the real source. A parse failure
   is a migration issue to fix or explicitly exclude, not a passing audit.
6. Run `ricestax assess`, then `ricestax pay 8091`. Read Why and What obligations.
   Existing comments are evidence to review, not automatically good decisions.
7. Use explicit, reasoned, version-bounded exemptions for an adoption backlog.
   Keep the debt visible. Do not bulk label it good to get a green build.
8. Commit verdicts to record sign-off through Git. Run `ricestax audit --json`.
   Keep extraction failures, stale decisions, and uncommitted verdicts visible.
9. Add generation and mutation only after the initial scope is understood.
   Use [the mutation guide](run-mutations.md), retaining the existing language
   toolchain. Existing Refine and sydtest reports need not be replaced.

To adopt documentation-to-code, move one owned source at a time into a Folio
reference page. Compare `ricestax canon tangle` output with the original and run
the normal tests. Tangling writes the paths named by the pages: never point an
experimental page at a source you have not chosen to generate. In CI, use
`ricestax canon tangle --check` to detect drift without overwriting files.

For Offscript, retain its Refine mutation command and report configuration.
Add Java and Folio profiles using the scratch-directory merge above. Ignore
`target/`: generated contract ownership remains Refine's responsibility. This
migration adds authored Java/documentation review alongside existing mutation
review; it does not manufacture historical sign-off.
