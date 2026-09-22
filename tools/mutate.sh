#!/usr/bin/env bash
# Mutation testing of Rice's Tax itself, natively with Stack: an instrumented build writes the
# manifest, the driver learns which rules cover which mutants, then runs the rules against each
# mutant and reports the survivors. The seed is fixed, because a result under an unrecorded seed
# is an anecdote. Afterwards: rices-tax ingest, then rices-tax review (DEC-mutate-native).
set -euo pipefail
cd "$(dirname "$0")/.."

SEED=${SEED:-42}
JOBS=${JOBS:-8}
export SYDTEST_SEED="$SEED"
# The corpus's scratch rules find the grammars from here, wherever the driver runs them.
export RICES_TAX_ROOT="$PWD"

echo "== 1. instrumented build =="
# The plugin writes the manifest as GHC compiles each module, so the package is cleaned first and
# every module recompiled: a module Stack finds up to date would write none, and the manifest
# must describe exactly this code.
rm -rf mutation-manifest
stack --no-terminal clean rices-tax
stack --no-terminal build --fast --test --no-run-tests --flag rices-tax:mutation 2>&1 | tail -1
BIN=$(find .stack-work -name corpus -type f -perm +111 | head -1)
"$BIN" +RTS --info | grep -q "rts_thr" || { echo "corpus is not linked -threaded" >&2; exit 1; }

DRIVER="$(stack path --local-install-root)/bin/sydtest-mutation-driver"
[ -x "$DRIVER" ] || stack --no-terminal build sydtest-mutation-driver --copy-bins --local-bin-path "$(dirname "$DRIVER")" 2>&1 | tail -1

# The driver runs the suite out of process and expects it at ROOT/test/<exe>. The run is built
# beside the current artefacts and swapped in at the end, so a page serving the current run reads
# a whole run or the previous one, never a half-written one (DEC-mutation-rerun).
WORK=.mut.next
rm -rf "$WORK"
mkdir -p "$WORK/pkg/test" "$WORK/res" "$WORK/augmented" "$WORK/aug2" "$WORK/out"
cp "$BIN" "$WORK/pkg/test/corpus"

echo
echo "== 2. coverage =="
"$DRIVER" coverage \
  --manifest "$PWD/mutation-manifest" \
  --suite-pkg "rices-tax=$PWD/$WORK/pkg=$PWD/$WORK/res" \
  --mutation-augmented-manifest-dir "$PWD/$WORK/augmented" 2>&1 | tail -2

echo
echo "== 3. mutation =="
"$DRIVER" run \
  --manifest "$PWD/mutation-manifest" \
  --suite-pkg "rices-tax=$PWD/$WORK/pkg=$PWD/$WORK/res" \
  --coverage-dir "$PWD/$WORK" \
  --mutation-augmented-manifest-dir "$PWD/$WORK/aug2" \
  --out-dir "$PWD/$WORK/out" \
  --mutation-jobs "$JOBS" \
  --no-fail-fast 2>&1 | tail -2

# The facts of this run, from what ran rather than from constants here.
GHCV=$(stack --no-terminal ghc -- --numeric-version)
SNAP=$(grep -o "lts/[0-9]*/[0-9]*" stack.yaml | head -1 | tr '/' '-')
DRV=$("$DRIVER" --version 2>&1 | tail -1 | sed "s/ *$//")
COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then COMMIT="$COMMIT-dirty"; fi
DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > "$WORK/run.json" <<JSON
{ "seed": $SEED
, "driver": "$DRV"
, "toolchain": "GHC $GHCV, Stack $SNAP"
, "commit": "$COMMIT"
, "date": "$DATE"
}
JSON

rm -rf .mut
mv "$WORK" .mut

echo
echo "  now: ricestax assess, then ricestax pay"
