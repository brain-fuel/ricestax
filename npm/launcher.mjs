// The Node half of Rice's Tax: it instantiates the WebAssembly core with Node's own WASI, hands
// it the working directory and git, and exposes the core's exports as plain async functions.
// What the core cannot do inside wasm, run git and listen on a port, lives here and nowhere
// else (DEC-wasm-toolchain).
import { WASI } from "node:wasi";
import { readFile } from "node:fs/promises";
import { execFile } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));

function git(cwd, argsJson) {
  return new Promise((resolve) => {
    const args = JSON.parse(argsJson);
    if (process.env.RICESTAX_TRACE) console.error(`[git] ${cwd} ${args.slice(0, 3).join(" ")}`);
    execFile("git", ["-C", cwd, ...args], { maxBuffer: 1 << 28 }, (error, stdout, stderr) => {
      if (error && error.code === "ENOENT") resolve(JSON.stringify({ code: -1, out: "", err: "git not found" }));
      else resolve(JSON.stringify({ code: error ? (typeof error.code === "number" ? error.code : 1) : 0, out: stdout, err: stderr }));
    });
  });
}

// The core reaches the host through one object, so the JavaScript the Haskell side names is a
// single well-known name and nothing else on the global.
globalThis.__ricestax = { git };

export async function loadCore(root = process.cwd()) {
  const wasi = new WASI({
    version: "preview1",
    args: ["ricestax"],
    env: { PATH: "", PWD: root, GHCRTS: process.env.RICESTAX_GHCRTS || "-H256m" },
    preopens: { "/": "/" },
  });
  const ghc_wasm_jsffi = (await import("./core_jsffi.js")).default;
  const exports = {};
  const mod = await WebAssembly.compile(await readFile(path.join(here, "core.wasm")));
  const instance = await WebAssembly.instantiate(mod, { wasi_snapshot_preview1: wasi.wasiImport, ghc_wasm_jsffi: ghc_wasm_jsffi(exports) });
  Object.assign(exports, instance.exports);
  wasi.initialize(instance);
  // Every export takes and returns JSON text; the generated api.mjs gives them their names.
  return async (name, input) => JSON.parse(await instance.exports.ricestax_call(name, JSON.stringify(input ?? {})));
}
