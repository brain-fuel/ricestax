---
id: ricestax.how-to.build-wasm
kind: how-to
title: Build the WebAssembly halves
---
# Build the WebAssembly halves

The toolchain is Stack for everything native: building, testing, and mutation. Stack cannot
cross-compile, so the WebAssembly halves are built by cabal told to use GHC's own wasm backend, from
the same package files. ref:DEC-wasm-toolchain

Install the compiler once, from ghc-wasm-meta's release channel:

```
ghcup config add-release-channel https://gitlab.haskell.org/haskell-wasm/ghc-wasm-meta/-/raw/master/ghcup-wasm-0.0.9.yaml
ghcup install ghc wasm32-wasi-9.14
```

or with ghc-wasm-meta's bootstrap script, which puts it under `~/.ghc-wasm`. Then:

```
stack build --exec tools/wasm.sh
```

The script runs `ricestax gen`, which writes the wasm entry module, its cabal file, `npm/api.mjs`,
and `npm/index.d.ts` from the export table in `RicesTax.Api`; builds the core under `wasm/` and the
page under `web/`; and lays out `npm/` with `core.wasm`, its FFI shim, the page, and the launcher.
`wasm/vendor/` holds grammatical-parsers with a plain build type, since its custom Setup exists only
for its doctests and drags in a Cabal that does not compile for wasm. ref:DEC-npm-packaging

The core runs under Node's own WASI with the project root preopened; git is the one thing it asks the
host for, through canon's replaceable git runner. `npm/bin/ricestax.mjs` gives every verb from Node,
and `npm/api.mjs` gives one function per export to any script.
