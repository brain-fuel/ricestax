# Vendored for the WebAssembly build

`grammatical-parsers-0.7.2.1` is the Hackage release with its `build-type`
changed from `Custom` to `Simple` and its `Setup.hs` removed. Its custom
Setup exists only to run doctests, and it drags the Cabal library into the
wasm build, where Cabal 3.14 does not compile on GHC 9.14. Nothing else
differs from the release. Delete this directory once upstream builds without
a custom Setup (DEC-wasm-toolchain).
