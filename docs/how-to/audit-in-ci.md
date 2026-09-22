---
id: ricestax.how-to.audit-in-ci
kind: how-to
title: Audit a project in a pipeline
---
# Audit a project in a pipeline

A pipeline runs the audit the way a person does, and reads the exit code: 0 means the tax is paid
within its exemptions, 1 means it is not, and 2 means the audit could not run, for want of a
`canon.yaml` or a readable ledger. With `--json` the same document is written whatever the code, so a
step can both fail and keep the report. ref:DEC-umbrella-surface

Check out the whole history: sign-off is read from git blame, and a shallow clone reads every verdict
as uncommitted, which fails the audit for the wrong reason.

With the npm package, no Haskell toolchain is needed:

```yaml
name: audit
on: [push, pull_request]
jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: actions/setup-node@v4
        with: { node-version: 22 }
      - run: npm install -g ricestax@0.3.1
      - run: ricestax canon check
      - run: ricestax audit --json > audit.json
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: audit, path: audit.json }
```

A ledger-only audit, with no mutation run in the tree, re-digests no mutant; the report says
`runtime: absent` so nobody mistakes it for the full proof. A project that wants the full proof runs
its mutation first, in a second and slower job. This repository audits itself with Stack, in
`.github/workflows/audit.yml`, because it is ahead of the published package.
