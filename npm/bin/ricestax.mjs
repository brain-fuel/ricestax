#!/usr/bin/env node
// The verbs from Node: the same core as the native binary, run through the launcher. The verbs
// and the usage come from the export table, so a verb cannot exist here and not there.
import { verbs, usage } from "../api.mjs";

const hostUsage = "\nproject tools (npm):\n  languages\n  init --languages java,calm,folio\n  scaffold architecture.calm.json --language java --out new-project\n  mutate [ricestax.mutations.json]\n";
const [verb, ...rest] = process.argv.slice(2);
if (verb === "scaffold") {
  try {
    if (rest.length !== 5 || rest[1] !== "--language" || rest[3] !== "--out") throw new Error("Usage: ricestax scaffold architecture.calm.json --language javascript --out new-project");
    const { scaffold } = await import("../scaffold.mjs");
    console.log(await scaffold(rest[0], rest[2], rest[4]));
  } catch (e) { console.error(e.message); process.exitCode = 2; }
  process.exit(process.exitCode || 0);
}
if (verb === "mutate") {
  try { if (rest.length > 1) throw new Error("Usage: ricestax mutate [config.json]"); const { mutate } = await import("../mutate.mjs"); const r = await mutate(process.cwd(), rest[0]); process.exitCode = r.ok ? 0 : 1; }
  catch (e) { console.error(e.message); process.exitCode = 2; }
  process.exit(process.exitCode || 0);
}
if (verb === "init" || verb === "languages") {
  try { const { setupCommand } = await import("../setup.mjs"); await setupCommand([verb, ...rest]); }
  catch (e) { console.error(e.message); process.exitCode = 2; }
  process.exit(process.exitCode || 0);
}
if (!verb || !(verb in verbs)) { console.error(usage + hostUsage); process.exit(2); }
const { loadCore } = await import("../launcher.mjs");
const call = await loadCore(process.cwd());
if (verb === "assess") {
  const r = await call("assess", { root: "." });
  if (r.error) { console.error(r.error); process.exitCode = 2; } else process.stdout.write(r.report);
} else if (verb === "audit") {
  const r = await call("audit", { root: "." });
  if (r.error) { console.error(r.error); process.exitCode = 2; }
  else {
    // Exit only once stdout has drained: a pipe would otherwise lose everything past 64 KB.
    process.exitCode = r.ok ? 0 : 1;
    process.stdout.write(rest.includes("--json") ? JSON.stringify(r.json) + "\n" : r.text);
  }
} else if (verb === "pay") {
  const { serve } = await import("../pay.mjs");
  await serve(call, Number(rest[0] || 8080));
} else if (verb === "import-records") {
  const r = await call("importRecords", { root: ".", paths: rest });
  if (r.error) { console.error(r.error); process.exitCode = 2; }
  else r.forEach((c, i) => process.stdout.write(`${rest[i]}: ${c.imported} verdicts imported, ${c.missed} not in the current run\n`));
} else if (verb === "canon") {
  const r = await call("canon", { root: ".", args: rest });
  process.exitCode = r.error ? 2 : r.exit;
  if (r.error) console.error(r.error);
} else if (verb === "site") {
  const [out, ...roots] = rest;
  if (!out) { console.error(usage + hostUsage); process.exit(2); }
  const { fileURLToPath } = await import("node:url");
  const path = await import("node:path");
  const pages = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "page");
  const r = await call("site", { root: ".", out, roots: roots.length ? roots : ["."], pages });
  if (r.error) { console.error(r.error); process.exitCode = 2; } else process.stdout.write(`${r.pages} pages under ${out}\n`);
} else { throw new Error(`${verb} is in the table but has no arm`); }
