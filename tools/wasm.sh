#!/usr/bin/env bash
# Builds the back end and the page for WebAssembly and lays out npm/ for Node. Stack builds
# natively and cannot cross-compile, so this is the one place cabal is called, with ghcup's
# wasm32-wasi GHC; run it as stack build --exec tools/wasm.sh to make it part of a Stack build
# (DEC-wasm-toolchain). Install the compiler once: see README, "Building for WebAssembly".
set -euo pipefail
cd "$(dirname "$0")/.."
# stack build --exec hands the script Stack's own package path, which cabal refuses to run under;
# the wasm build has its own package databases.
unset GHC_PACKAGE_PATH
if [ -f ~/.ghc-wasm/env ]; then . ~/.ghc-wasm/env; fi
command -v wasm32-wasi-cabal >/dev/null || { echo "wasm32-wasi-cabal not found: install the wasm GHC (README, Building for WebAssembly)" >&2; exit 1; }

echo "== generate from the export table"
stack --no-terminal exec -- ricestax gen

echo "== core"
( cd wasm && wasm32-wasi-cabal build ricestax-wasm 2>&1 | grep -v "relative-path\|sdist\|outside of the source tree" | tail -3 )
CORE="$(cd wasm && wasm32-wasi-cabal list-bin ricestax-wasm | tail -n 1)"
"$(wasm32-wasi-ghc --print-libdir)/post-link.mjs" --input "$CORE" --output npm/core_jsffi.js
cp "$CORE" npm/core.wasm

echo "== page"
( cd web && ./build.sh 2>&1 | tail -1 )
rm -rf npm/page && cp -r web/public npm/page

node tools/package-assets.mjs

echo "built npm/: $(du -sh npm/core.wasm | cut -f1) core, page in npm/page"
