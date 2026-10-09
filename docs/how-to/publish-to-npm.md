---
id: ricestax.how-to.publish
kind: how-to
title: Publish Rice’s Tax to npm
---
# Publish Rice’s Tax to npm

Run from the repository root in a Bash terminal. The public npm package is
`ricestax`; its payload is `npm/`. Git tags do not publish npm packages.

## Prerequisites and version selection

Install Node 22+, npm, Stack, and the sibling `../canon` checkout referenced by
`stack.yaml`. Install the WASM compiler using
[ghc-wasm-meta](https://gitlab.haskell.org/haskell-wasm/ghc-wasm-meta).
Both `tools/wasm.sh` and `web/build.sh` need `~/.ghc-wasm/env` to configure
`wasm32-wasi-ghc` and `wasm32-wasi-cabal`.

Complete acceptance also needs JDK 17+ (25 works), Maven, Kotlin CLI, Python 3.9+
with venv/pip, Go 1.22+, Stack, and `tsc` on PATH for scaffold checks. The worked
TypeScript example installs its own compiler. Set `ANTLR_JAR` to the absolute
ANTLR 4.13.2 complete JAR path. Set `JAVA_HOME` and put its `bin` on PATH if
macOS's Java stub cannot find the JDK. These are release-test prerequisites;
npm consumers do not compile Rice’s Tax.

```sh
cd ~/para/projects/ricestax
PACKAGE=ricestax
printf 'Unpublished release version (for example 0.3.3): '
read -r RELEASE
export RELEASE
RELEASE_DIR="$PWD/dist/$RELEASE"
mkdir -p "$RELEASE_DIR"
npm view "$PACKAGE" versions --json --registry=https://registry.npmjs.org
git status --short
git remote -v
```

Do not reuse a published version. The property-test development archive still
carries 0.3.2 and needs a new version before publication. Network/auth errors do
not establish version availability. Review existing changes before staging.

Update these fields to `$RELEASE`:

| File | Field |
| --- | --- |
| `package.yaml` | package `version:` |
| `canon.yaml` | root `version:` |
| `npm/package.json` | `version` |
| `web/rices-tax-web.cabal` | package `version:` |
| `docs/reference/api.md` | literal `"version: ..."` in the WASM Cabal generator |

Edit the last field in its literate source, not generated `src/RicesTax/Gen.hs`
or `wasm/ricestax-wasm.cabal`. Hpack updates `rices-tax.cabal`. Example project
versions, historical records and dependency versions are separate.

A release of canon that changes ids, digests, or vetting files changes canon's
version, and ships together with a Rice's Tax release built against it: set
`requiredCanon` in `docs/reference/core.md` and the `canon ==` bound in
`package.yaml` to it, re-vendor `grammars/` from that canon (the corpus rule
`lockstep.vendored-grammars-are-canon's` fails until they match), and run the
corpus, whose `lockstep` rules compare `ricestax audit` with `canon check`
(`DEC-canon-lockstep`).

## Build and validate

Run each command successfully before continuing:

```sh
stack --no-terminal exec -- ricestax canon tangle
stack --no-terminal test
./tools/wasm.sh
node --test test/npm/*.test.mjs
node npm/bin/ricestax.mjs canon tangle --check
git diff --check
```

The WASM script regenerates API/export wrappers, builds the core and browser
WASM, and copies current docs/examples using `tools/package-assets.mjs`. If
generation requires a changed native generator, run `stack build` and repeat
tangling/building. Verify all version fields and generated Cabal versions.

Write `releases/$RELEASE/RELEASE.md` with changes, limitations and actual test
results. Commit intended source and generated artifacts before the final audit:
uncommitted verdicts affect it. Review staged changes instead of sweeping unrelated
work into the release.

```sh
node npm/bin/ricestax.mjs audit > "$RELEASE_DIR/audit.log" 2>&1
```

**Publish only from a tree whose audit passes.** A nonzero exit stops the normal
procedure. Fix the findings, or obtain an explicit owner-authorized exception for
this particular release. Record the exact authorization, findings, scope and
rationale in its RELEASE.md, preserve the audit output, and commit that record.
An exception is not a passing audit; do not silently suppress the failure.

Historical exceptions under `releases/` are not standing permission for another
release. This preserves ref:DEC-npm-packaging and ref:DEC-umbrella-surface.

## Pack once and test that archive

```sh
npm pack ./npm --pack-destination "$RELEASE_DIR" --json > "$RELEASE_DIR/package-manifest.json"
ARCHIVE="$RELEASE_DIR/ricestax-$RELEASE.tgz"
shasum -a 256 "$ARCHIVE" > "$RELEASE_DIR/SHA256SUMS"
TEST_INSTALL=$(mktemp -d)
npm install --prefix "$TEST_INSTALL" --cache "$TEST_INSTALL/cache" \
  --ignore-scripts --no-audit --no-fund "$ARCHIVE"
TEST_PACKAGE="$TEST_INSTALL/node_modules/ricestax"
node tools/check-language-release.mjs "$TEST_PACKAGE"
node tools/check-tangling-release.mjs "$TEST_PACKAGE"
RICESTAX_EXAMPLE_REPORT="$RELEASE_DIR/examples.json" \
  node tools/check-examples-release.mjs "$TEST_PACKAGE"
```

Keep this order: the tangling check consumes the fixture path from the language
check. Do not run those checks concurrently, even in another release terminal.
Missing compilers are failures, not skipped evidence. The example check validates
compilation, tests, mutations, ingestion and loading reports through the API.

Inspect the manifest for `pay.mjs`, core WASM/FFI, API/types, CLI, presets,
docs/examples, and the page with its browser WASM/FFI assets. Exclude credentials,
caches, local builds and mutation runs. Save acceptance logs with the manifest.

Test the installed viewer on a disposable project:

```sh
REVIEW_PROJECT=$(mktemp -d)
cp -R "$TEST_PACKAGE/examples/checkout-architecture-calm/." "$REVIEW_PROJECT/"
(
  cd "$REVIEW_PROJECT"
  node "$TEST_PACKAGE/bin/ricestax.mjs" mutate
  node "$TEST_PACKAGE/bin/ricestax.mjs" pay 8091
)
```

While it runs, open `http://localhost:8091` in Brave. Confirm current findings
render and exercise decisions and history/archive/restore in this disposable
project. Check `http://localhost:8091/obligations` returns the JSON payload.
Stop with Ctrl-C; choose a different port if 8091 is occupied. API report loading
alone does not establish that the browser interactions work.

Record `git rev-parse HEAD` with the evidence and inspect `git status --short`.
The release commit must contain the intended payload and approval record. Publish
this exact archive; do not rebuild it between acceptance and publication.

## Authenticate and publish the tested archive

Run these commands as the npm account authorized to publish this package:

```sh
npm whoami --registry=https://registry.npmjs.org
npm owner ls "$PACKAGE" --registry=https://registry.npmjs.org
```

For a first publication, an E404 from `owner ls` can mean the package does not
exist; it does not reserve the name or prove availability. Resolve ownership/name
conflicts before publishing. If login is required:

```sh
npm login --auth-type=web --browser=false --registry=https://registry.npmjs.org
```

Keep that terminal open. Copy the fresh approval URL into **Brave**, complete the
approval, and wait for the command to exit successfully. On this Mac, do not use
plain `open` or rely on `open -a` to select the browser. In a second terminal,
this opens a tab directly inside Brave (replace the placeholder URL):

```sh
osascript - 'PASTE_THE_FRESH_NPM_APPROVAL_URL_HERE' <<'APPLESCRIPT'
on run argv
  tell application "Brave Browser"
    activate
    if (count of windows) is 0 then make new window
    tell front window
      make new tab at end of tabs with properties {URL:item 1 of argv}
      set active tab index to count of tabs
      return URL of active tab
    end tell
  end tell
end run
APPLESCRIPT
```

Then, from the release terminal with the variables set earlier:

```sh
npm publish "$ARCHIVE" --access public --tag latest \
  --registry=https://registry.npmjs.org --browser=false
```

Publication may request a separate browser approval even after login. Follow the
same Brave procedure using its new URL. An expired link cannot be reused: end the
waiting command with Ctrl-C, check whether the version was published, then retry
only if it was not. Keep approval URLs and credentials out of Git.

These commands are for a stable release. For a prerelease, use an intentional tag
such as `next` instead of moving `latest`. npm versions are immutable: a published
name/version cannot be overwritten, even after unpublishing. A dry run does not
prove authentication or publication permission. See npm's
[publish documentation](https://docs.npmjs.com/cli/v11/commands/npm-publish/) and
[login documentation](https://docs.npmjs.com/cli/v11/commands/npm-login/).

## Verify the registry, then push the release tag

```sh
npm view "$PACKAGE@$RELEASE" version dist.integrity dist.tarball \
  --json --registry=https://registry.npmjs.org > "$RELEASE_DIR/registry.json"
npm view "$PACKAGE" dist-tags --json --registry=https://registry.npmjs.org
node --input-type=module - "$RELEASE_DIR" <<'JS'
import {readFileSync} from 'node:fs';
const dir = process.argv[2];
const local = JSON.parse(readFileSync(dir + '/package-manifest.json'))[0];
const remote = JSON.parse(readFileSync(dir + '/registry.json'));
if (remote.version !== local.version || remote['dist.integrity'] !== local.integrity)
  throw new Error('Registry version/integrity does not match the tested tarball');
console.log('Registry integrity matches the tested archive');
JS
PUBLIC_INSTALL=$(mktemp -d)
npm install --prefix "$PUBLIC_INSTALL" --cache "$PUBLIC_INSTALL/cache" \
  --ignore-scripts --no-audit --no-fund --registry=https://registry.npmjs.org \
  "$PACKAGE@$RELEASE"
node -p "require(process.argv[1]).version" "$PUBLIC_INSTALL/node_modules/$PACKAGE/package.json"
```

The exact version and `latest` can propagate at different times. If publication
succeeded but reads still return E404 or an old tag, retry these read-only checks;
do not immediately republish. Confirm the displayed version and that `latest`
points to this release when that was the chosen tag. The package page is
`https://www.npmjs.com/package/NAME/v/VERSION`, substituting the actual values.

Save the archive, manifest, registry response, validation logs, and release commit
SHA. From the unchanged release commit, after successful public verification:

```sh
git tag -a "v$RELEASE" -m "Release $PACKAGE $RELEASE"
git push origin HEAD:main
git push origin "v$RELEASE"
```

Use the repository's actual release branch if it is not `main`. Do not move an
existing tag: investigate any collision. Tag the commit whose payload was tested
and published; if anything changes in the payload, rebuild, repack and revalidate.
