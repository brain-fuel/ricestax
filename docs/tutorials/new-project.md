---
id: ricestax.tutorial.new-project
kind: tutorial
title: Start a project with architecture and review
---
# Start a project with architecture and review

Use this tutorial to create a small JavaScript starter from an explicit service
boundary. You need Node.js 22 or newer and the 0.3 Rice’s Tax package. The commands
use the npm CLI; no Haskell or Go compiler is needed for this target.

## 1. Describe the boundary

Create `architecture.calm.json` in your working directory:

```json
{
  "$schema": "https://calm.finos.org/release/1.2/meta/calm.json",
  "nodes": [
    {
      "unique-id": "greeting-api",
      "node-type": "service",
      "name": "Greeting API",
      "description": "Owns greeting responses so callers share one contract."
    }
  ],
  "relationships": []
}
```

The identifier is the stable identity; the name and description are material to
review. This is deliberately one service, not a claim about a deployed system.

## 2. Generate a starting project

```sh
ricestax scaffold architecture.calm.json --language javascript --out greeting-service
cd greeting-service
node tools/build.mjs compile
node tools/build.mjs test
```

The tests check one declared service and one unknown service. Inspect
`src/topology.mjs`, `test/topology.test.mjs`, and `ricestax.mutations.json`.
The generator has created a service-membership boundary, not an HTTP application.

To learn with another language, replace `javascript` with `java`, `typescript`,
`python`, `go`, `haskell`, `kotlin`, `calm`, or `antlr4` and supply the toolchain
listed in its [reference](../reference/languages.md). The same build/test commands
invoke that target’s compiler and tests. CALM emits an inventory; ANTLR4 builds a
Java-target recognizer.

## 3. Challenge the test

```sh
ricestax mutate
```

The unchanged control must pass. The generated mutation breaks service membership
and must be killed. Inspect `.mut/current/out/report.json` and the per-command
results in its run directory. A compiler error or timeout would not be a test kill.

## 4. Review what remains

```sh
git init
ricestax assess
ricestax pay 8091
```

Open `http://localhost:8091`. Read the architecture descriptions, source comments,
and names in Why and What. A passing test is not an approval of their wording.
Only record decisions you have reviewed. Commit the material and verdicts when
ready: Git supplies the signer. `ricestax audit --json` reports remaining work;
this tutorial does not pre-approve the new project to promise an automatic green audit.

Continue with [architecture through a running service](architecture-to-service.md)
to add documented application code, an actual HTTP test, and a second mutation.
