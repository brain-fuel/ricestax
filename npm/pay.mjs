// The pay server in Node: static files for the page and the same routes the native Warp server
// serves, each answered by the core. Decisions patch the core's own cache, as natively.
import http from "node:http";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { gzipSync } from "node:zlib";
import { spawn } from "node:child_process";
import { openSync, closeSync, existsSync, readFileSync, writeFileSync } from "node:fs";

const here = path.dirname(fileURLToPath(import.meta.url));
const mime = { ".html": "text/html; charset=utf-8", ".js": "application/javascript", ".mjs": "application/javascript", ".wasm": "application/wasm", ".css": "text/css", ".json": "application/json" };

function send(res, req, status, type, body) {
  const accepts = (req.headers["accept-encoding"] || "").includes("gzip") && Buffer.byteLength(body) > 1024;
  const out = accepts ? gzipSync(body) : body;
  res.writeHead(status, { "Content-Type": type, "Cache-Control": "no-store", ...(accepts ? { "Content-Encoding": "gzip" } : {}) });
  res.end(out);
}

async function body(req) { const chunks = []; for await (const c of req) chunks.push(c); return Buffer.concat(chunks).toString("utf8"); }

// The mutation the page can start: the command canon.yaml names, run in the project, its output
// in a log the page reads the tail of; the project is re-read when it ends, so decisions made
// meanwhile carry over. A re-read asked for while it runs is refused.
const logFile = ".mut.log";
let mutation = { mutationState: "idle", mutationCommand: "", mutationSince: "", mutationExit: 0, mutationLog: [] };
function status() {
  const lines = existsSync(logFile) ? readFileSync(logFile, "utf8").split("\n").filter((l) => l !== "") : [];
  return { ...mutation, mutationLog: lines.slice(-30) };
}
async function start(call) {
  const payload = await call("payload", { root: "." });
  const command = payload?.facts?.command || "";
  if (!command) return [400, "canon.yaml names no runtime command, so the mutation cannot be started from the page"];
  if (mutation.mutationState === "running") return [409, "the mutation is already running"];
  const fd = openSync(logFile, "w");
  const since = new Date().toISOString();
  mutation = { mutationState: "running", mutationCommand: command, mutationSince: since, mutationExit: 0, mutationLog: [] };
  writeFileSync(".mut-attempt.json", JSON.stringify(mutation));
  console.error(`mutation started: ${command}`);
  const child = spawn("sh", ["-c", command], { stdio: ["ignore", fd, fd] });
  child.on("exit", async (code) => {
    closeSync(fd);
    mutation = { mutationState: code === 0 ? "finished" : "failed", mutationCommand: command, mutationSince: since, mutationExit: code ?? 1, mutationLog: [] };
    writeFileSync(".mut-attempt.json", JSON.stringify(mutation));
    await call("reload", { root: "." });
    console.error(`mutation ended with ${code}`);
  });
  return [200, JSON.stringify(status())];
}

export async function serve(call, port) {
  await call("gather", { root: "." });
  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, "http://x");
    try {
      if (req.method === "GET" && url.pathname === "/obligations") return send(res, req, 200, mime[".json"], JSON.stringify(await call("payload", { root: "." })));
      if (req.method === "GET" && url.pathname === "/reload") {
        if (mutation.mutationState === "running") return send(res, req, 409, "text/plain; charset=utf-8", "the mutation is running; the project is re-read when it ends");
        return send(res, req, 200, mime[".json"], JSON.stringify(await call("reload", { root: "." })));
      }
      if (req.method === "GET" && url.pathname === "/mutation") return send(res, req, 200, mime[".json"], JSON.stringify(status()));
      if (req.method === "POST" && url.pathname === "/mutate") { const [code, text] = await start(call); return send(res, req, code, code === 200 ? mime[".json"] : "text/plain; charset=utf-8", text); }
      if (req.method === "GET" && url.pathname.startsWith("/whole/")) { const [, , kind, id] = url.pathname.split("/"); return send(res, req, 200, mime[".json"], JSON.stringify(await call("whole", { root: ".", kind, id }))); }
      if (req.method === "POST" && url.pathname === "/history" && ["running", "failed"].includes(mutation.mutationState)) return send(res, req, 409, "text/plain", "The latest mutation attempt is running or failed. Complete a successful run before changing history.");
      if (req.method === "POST" && ["/decide", "/exempt", "/lift", "/history"].includes(url.pathname)) {
        const r = await call(url.pathname.slice(1), { root: ".", ...JSON.parse(await body(req)) });
        if (r.error) return send(res, req, 400, "text/plain; charset=utf-8", r.error);
        return send(res, req, 200, mime[".json"], JSON.stringify(r));
      }
      const rel = url.pathname === "/" ? "index.html" : url.pathname.slice(1);
      if (rel.includes("..")) return send(res, req, 404, "text/plain", "not found");
      const file = await readFile(path.join(here, "page", rel));
      return send(res, req, 200, mime[path.extname(rel)] || "application/octet-stream", file);
    } catch (e) {
      return send(res, req, e.code === "ENOENT" ? 404 : 500, "text/plain; charset=utf-8", String(e.message || e));
    }
  });
  server.listen(port, () => console.error(`pay at http://localhost:${port}  (ctrl-c to stop)`));
}
