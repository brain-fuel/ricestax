# Rice’s Tax 0.2.0 release

Package: ricestax-0.2.0.tgz
SHA-256: b62ed2a0a9de850688663b54e5cd1f63304398e3e4e093aa82b840768e2101a0

## Verified

- Native Rice’s Tax corpus: 34 tests passed; Canon dependency: 150 tests passed.
- Literate source generation check passed.
- Both WASM halves rebuilt from the 0.2.0 sources.
- Clean npm tarball installation and review-server startup succeeded.
- Installed globally at /opt/homebrew/bin/ricestax; a fresh process reloaded persisted history successfully.
- Real Chrome UI exercised archive (bulk/individual), undo, history search,
  restore, reload persistence, source-hash freshness, missing reports,
  returning survivors, stale-write rejection, and mobile layout.
- All three historical Offscript IDs match explicit kills in its real report.
- Test interactions used an isolated copy; original Offscript verdict files unchanged.
- Package includes the previously omitted pay.mjs, LICENSE, core and browser WASM.

## Publication authorization

On 22 September 2026, npm authentication was verified as `goforgedev`.
The owner explicitly authorized a documented exception to the failing self-audit:
“Authorize a documented audit exception”. This permits publishing the tested
0.2.0 tarball without claiming that the self-audit passes.
Published successfully on 22 September 2026 after browser authentication.
Registry: https://www.npmjs.com/package/ricestax/v/0.2.0
Registry SHA-512 integrity and SHA-1 shasum match the verified tarball manifest.
An empty-cache registry install passed the WASM API smoke test against the
isolated Offscript fixture: three resolved decisions, one archived, and all
retained event histories loaded successfully.

The repository release guide says: “Publish only from a tree whose audit passes”.
Current audit fails: 564 failing findings, 168 stale entries, and 2715 uncommitted
verdict findings. These categories overlap. The checkout already had 560 failing,
143 stale, and 2715 uncommitted findings before the final release checks.
Version 0.2.0 also reaches the revisit deadlines of DEC-grammar-sharing and
DEC-how-subkinds. See audit.json for exact findings. No verdicts were automatically
approved and no gate was weakened.

The working checkout has substantial pre-existing uncommitted work and no Git remote.
This release packages the current built application; no source push or
release tag has been made.

## Published artifact

The owner-authorized audit exception applies to this exact verified tarball:

    npm publish dist/0.2.0/ricestax-0.2.0.tgz --access public

Publication, registry integrity verification, and clean registry installation are complete.
