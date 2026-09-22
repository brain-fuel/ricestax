// Exact source mutations, isolated builds, and explicit test evidence. No outcome is inferred
// from an empty queue or a failed compiler. Projects supply their own language toolchain.
import { readFile, writeFile, mkdir, readdir, lstat, rm, rename, symlink } from 'node:fs/promises';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { createHash, randomUUID } from 'node:crypto';
const sha = text => createHash('sha256').update(text).digest('hex');
const json = (p, value) => writeFile(p, JSON.stringify(value, null, 2) + '\n');
function relative(p) {
  if (typeof p !== 'string' || !p || path.isAbsolute(p) || p.split(/[\\/]/).some(x => x === '..' || x === '.git' || x === '.mut')) throw new Error(`Invalid project input: ${p}`);
  return p;
}
async function filesAt(root, rel) {
  relative(rel);
  const stat = await lstat(path.join(root, rel));
  if (stat.isSymbolicLink()) throw new Error(`Symlink inputs are not supported: ${rel}`);
  if (stat.isFile()) return [rel];
  if (!stat.isDirectory()) throw new Error(`Not a regular input: ${rel}`);
  const result = [];
  for (const name of (await readdir(path.join(root, rel))).sort()) result.push(...await filesAt(root, path.join(rel, name)));
  return result;
}
function argv(command) {
  if (!Array.isArray(command) || !command.length || command.some(x => typeof x !== 'string' || !x)) throw new Error('Commands must be nonempty arrays of arguments');
}
export async function runCommand(command, cwd, timeoutMs) {
  argv(command);
  return new Promise(resolve => {
    let output = '', timedOut = false, error = '', truncated = false;
    const env = { ...process.env };
    delete env.NODE_TEST_CONTEXT;
    const child = spawn(command[0], command.slice(1), { cwd, env, detached: process.platform !== 'win32', stdio: ['ignore', 'pipe', 'pipe'] });
    const capture = chunk => { if (output.length < 4_000_000) output += chunk; else truncated = true; };
    child.stdout.on('data', capture); child.stderr.on('data', capture);
    child.on('error', e => { error = e.message; });
    const timer = setTimeout(() => {
      timedOut = true;
      try { if (process.platform === 'win32') child.kill('SIGKILL'); else process.kill(-child.pid, 'SIGKILL'); } catch {}
    }, timeoutMs);
    child.on('close', (code, signal) => { clearTimeout(timer); resolve({ code, signal, timedOut, error, truncated, output }); });
  });
}
export function testOutcome(result, evidence) {
  if (result.timedOut) return 'timeout';
  if (result.error || result.signal || result.truncated) return 'infrastructure_error';
  if (result.code === 0) return new RegExp(evidence.passed, 'm').test(result.output) ? 'survived' : 'infrastructure_error';
  return new RegExp(evidence.failed, 'm').test(result.output) ? 'killed' : 'infrastructure_error';
}
export async function mutate(root, configPath = 'ricestax.mutations.json') {
  relative(configPath);
  const config = JSON.parse(await readFile(path.join(root, configPath), 'utf8'));
  if (config.schema !== 1 || !Array.isArray(config.inputs) || !config.inputs.length || !Array.isArray(config.mutations) || !config.mutations.length) throw new Error('Mutation schema 1 requires inputs and at least one mutation');
  argv(config.compile); argv(config.test);
  for (const key of ['passed', 'failed']) {
    if (typeof config.evidence?.[key] !== 'string' || !config.evidence[key]) throw new Error(`Missing test evidence pattern: ${key}`);
    if (new RegExp(config.evidence[key]).test('')) throw new Error('Test evidence must not match empty output');
  }
  const timeout = config.timeoutMs ?? 180000;
  if (!Number.isInteger(timeout) || timeout < 1 || timeout > 3600000) throw new Error('timeoutMs must be between 1 and 3600000');
  const files = [...new Set([...await filesAt(root, configPath), ...(await Promise.all(config.inputs.map(p => filesAt(root, p)))).flat()])].sort();
  const bytes = new Map(await Promise.all(files.map(async f => [f, await readFile(path.join(root, f))])));
  const ids = new Set();
  for (const m of config.mutations) {
    relative(m.file);
    if (!bytes.has(m.file) || typeof m.original !== 'string' || !m.original || typeof m.replacement !== 'string' || m.original === m.replacement) throw new Error('Each mutation requires an input file and distinct original/replacement strings');
    const source = bytes.get(m.file).toString('utf8');
    if (source.split(m.original).length !== 2) throw new Error(`Mutation must match exactly once: ${m.file}: ${m.original}`);
    m.id = sha(JSON.stringify([m.file, m.original, m.replacement])).slice(0, 16);
    if (ids.has(m.id)) throw new Error('Duplicate mutation'); ids.add(m.id);
  }
  const mut = path.join(root, '.mut');
  await mkdir(mut, { recursive: true });
  const lock = path.join(mut, 'runner.lock');
  try { await mkdir(lock); }
  catch (e) {
    if (e.code === 'EEXIST') throw new Error('A mutation runner lock exists at .mut/runner.lock. Check its owner.json; remove the lock only after confirming that run has stopped.');
    throw e;
  }
  const runName = `ricestax-${Date.now()}-${randomUUID().slice(0, 8)}`;
  const run = path.join(mut, 'runs', runName);
  const attempt = state => json(path.join(root, '.mut-attempt.json'), { mutationState: state, mutationCommand: 'ricestax mutate', mutationSince: new Date().toISOString(), mutationExit: state === 'finished' ? 0 : 1, mutationLog: [] });
  try {
    await json(path.join(lock,'owner.json'), { pid:process.pid, started:new Date().toISOString() });
    await attempt('running');
    await mkdir(path.join(run, 'out'), { recursive: true });
    await mkdir(path.join(run, 'augmented'), { recursive: true });
    await json(path.join(run, 'source-sha256.json'), Object.fromEntries([...bytes].map(([f,b]) => [f,sha(b)])));
    await json(path.join(run, 'run.json'), { seed: '0', driver: 'ricestax-catalog 1', toolchain: process.version, commit: '', date: new Date().toISOString(), scope: 'Explicit unique source replacements; project-supplied compile/test commands and evidence patterns; no coverage probes' });
    await json(path.join(run, 'augmented', 'manifest-augmented.json'), []);
    const prepare = async name => {
      const dir = path.join(run, name);
      for (const [f,b] of bytes) { await mkdir(path.dirname(path.join(dir,f)), { recursive: true }); await writeFile(path.join(dir,f), b, { mode: (await lstat(path.join(root,f))).mode }); }
      return dir;
    };
    const execute = async (dir, phase, command) => {
      const result = await runCommand(command, dir, timeout);
      await json(path.join(dir, `${phase}-result.json`), result);
      return result;
    };
    const baseline = await prepare('control');
    const build = await execute(baseline, 'compile', config.compile);
    if (build.code !== 0 || build.error || build.signal || build.timedOut) throw new Error('Control compilation failed; see retained compile-result.json');
    const tests = await execute(baseline, 'test', config.test);
    if (testOutcome(tests, config.evidence) !== 'survived') throw new Error('Control tests failed or did not supply passing-test evidence');
    const entries = [];
    for (const m of config.mutations) {
      const dir = await prepare(m.id);
      const source = bytes.get(m.file).toString('utf8');
      const offset = source.indexOf(m.original);
      const changed = source.slice(0, offset) + m.replacement + source.slice(offset + m.original.length);
      await writeFile(path.join(dir,m.file), changed);
      const compiled = await execute(dir, 'compile', config.compile);
      let outcome = compiled.timedOut ? 'timeout' : compiled.error || compiled.signal || compiled.truncated ? 'infrastructure_error' : compiled.code !== 0 ? 'invalid' : null;
      if (!outcome) {
        // A generation/build step must not silently overwrite the mutation.
        if (await readFile(path.join(dir,m.file),'utf8') !== changed) outcome = 'infrastructure_error';
        else {
          outcome = testOutcome(await execute(dir, 'test', config.test), config.evidence);
          if (await readFile(path.join(dir,m.file),'utf8') !== changed) outcome = 'infrastructure_error';
        }
      }
      const before = source.slice(0,offset).split('\n');
      const line = before.length;
      const endLine = line + m.original.split('\n').length - 1;
      const colEnd = m.original.includes('\n') ? [...m.original.split('\n').at(-1)].length + 1 : [...before.at(-1)].length + [...m.original].length + 1;
      entries.push({ outcome, status: outcome, mutation: { id: [m.id], module: m.file, operator: m.operator || 'catalog-replacement', source_file: m.file, line, end_line: endLine, col_start: [...before.at(-1)].length + 1, col_end: colEnd, original: m.original, replacement: m.replacement, source_lines: source.split('\n').slice(line-1,endLine), mutated_lines: changed.split('\n').slice(line-1,line+m.replacement.split('\n').length-1) } });
      console.log(`${outcome}: ${m.file} (${m.id})`);
    }
    await json(path.join(run,'out','report.json'), { controls: { passed: 1, failed: 0 }, groups: [entries] });
    const current = path.join(mut, 'current');
    try { const stat = await lstat(current); if (!stat.isSymbolicLink()) throw new Error('.mut/current exists and is not a symlink'); } catch(e) { if (e.code !== 'ENOENT') throw e; }
    const next = path.join(mut, `current-${randomUUID()}`);
    await symlink(path.join('runs',runName), next, 'dir'); await rename(next,current);
    await attempt('finished'); // Completed evidence is reviewable even when a survivor makes the CLI fail.
    return { ok: entries.every(x => x.outcome === 'killed'), run, entries };
  } catch(e) { await attempt('failed'); throw e; }
  finally { await rm(lock, { recursive: true, force: true }); }
}
