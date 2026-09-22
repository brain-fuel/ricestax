---
id: ricestax.how-to.publish
kind: how-to
title: Publish the package
---
# Publish the package

The package is `npm/`, and everything in it that is not hand-written is generated, so a release is
a build and a publish:

```
stack test
stack build --exec tools/wasm.sh
node npm/bin/ricestax.mjs audit
(cd npm && npm publish)
```

`package.json` lists what ships: the binary, the generated api and types, the launcher, the core and
its FFI shim, and the page. The version is the one `canon.yaml` names, and the tag `ricestax@0.2`
that the pipelines install is the major and minor of it. Publish only from a tree whose audit passes,
since the package is the umbrella's own proof. ref:DEC-npm-packaging ref:DEC-umbrella-surface

Version 0.2.0 was published on 22 September 2026 with an explicit owner-authorized
exception to the failing self-audit, documented in `dist/0.2.0/RELEASE.md`. The audit
did not pass: 564 failing findings, 168 stale entries, and 2715 uncommitted verdict
findings (overlapping categories). This exception applies only to that release. `npm pack --dry-run` must include `pay.mjs` as
well as both WebAssembly halves. Test the packed tarball from a clean installation,
including the review server and history API, before running `npm publish`.
