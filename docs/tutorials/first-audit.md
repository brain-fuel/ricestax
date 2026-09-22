---
id: ricestax.tutorial.first-audit
kind: tutorial
title: Your first audit
---
# Your first audit

This tutorial takes a small project from initial assessment through the review needed for a passing audit, on the
command line and in the page. It assumes Node is installed and the project is in git.

## 1. Install

```
npm install -g ricestax
```

`ricestax` with no arguments prints its verbs.

## 2. Tell canon what the project is

With the 0.3 npm package, initialize the selected language profiles:

```sh
ricestax init --languages haskell,folio
```

This writes configuration and bundled grammars; no Canon checkout is required.
For existing configuration, use the [migration guide](../how-to/adopt-existing-project.md).
Then see what Canon reads:

```
ricestax canon files
ricestax canon check
```

The check fails: every exported unit without a canonical comment is a finding, and that is the truth
the tool exists to show.

## 3. Assess

```
ricestax assess
```

Every comment, decision, and reference gets a pending row under `canonical_vetting/`, and every unit
that requires a comment gets a What row. The totals per queue follow.

## 4. Pay

```
ricestax pay 8080
```

Open the address it prints. Decide a Why row Good if the comment says why and the why holds, and Bad
if it only restates the name; decide a What row Good if the name and the signature state, in full
words, the fact the unit establishes. Each click writes the verdict into its ledger file. When the
queue is empty, look at `git diff`, and commit: the committer is the signer.

## 5. Audit

```
ricestax audit
```

It passes when every row is decided and committed. Add the audit to the pipeline, as the how-to
guide on auditing shows, and the tax stays paid. ref:DEC-three-verbs ref:DEC-what-raised
