#!/usr/bin/env bash
# Builds the pages to WebAssembly and lays out public/ for a static server. Run from web/.
# Needs ghc-wasm-meta's toolchain, sourced from ~/.ghc-wasm/env.
set -euo pipefail
cd "$(dirname "$0")"
. ~/.ghc-wasm/env
wasm32-wasi-cabal update || echo "package list not refreshed; building with what is cached"
wasm32-wasi-cabal build
rm -rf public && cp -r static public
wasm="$(wasm32-wasi-cabal list-bin rices-tax-web | tail -n 1)"
"$(wasm32-wasi-ghc --print-libdir)/post-link.mjs" --input "$wasm" --output public/ghc_wasm_jsffi.js
cp "$wasm" public/rices-tax-web.wasm
echo "built public/"
