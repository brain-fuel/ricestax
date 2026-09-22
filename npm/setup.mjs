// Project setup copies the package's pinned grammar assets; it never approves reviews.
import { readFile, writeFile, mkdir, cp, lstat, rename, rm } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const assets = fileURLToPath(new URL('./presets/', import.meta.url));
export async function languageProfiles() {
  return JSON.parse(await readFile(path.join(assets, 'languages.json'), 'utf8'));
}
export async function initialize(root, names) {
  const all = await languageProfiles();
  const selected = [...new Set(names)];
  if (!selected.length) throw new Error('Choose languages: ricestax init --languages java,calm');
  for (const name of selected) if (!(name in all)) throw new Error(`Unknown language: ${name}`);
  // Validate all destinations before touching an existing project. No merge or overwrite.
  for (const name of ['canon.yaml', '.ricestax']) {
    try { await lstat(path.join(root, name)); }
    catch (e) { if (e.code === 'ENOENT') continue; throw e; }
    throw new Error(`${name} already exists. Initialize a separate directory and merge its configuration deliberately.`);
  }
  const staging = path.join(root, `.ricestax-init-${process.pid}`);
  await mkdir(staging);
  try {
    await cp(path.join(assets, 'grammars'), path.join(staging, 'grammars'), { recursive: true });
    for (const file of ['provenance.json', 'CANON-LICENSE']) await cp(path.join(assets, file), path.join(staging, file));
    const languages = Object.fromEntries(selected.map(name => [name, structuredClone(all[name])]));
    if (languages.folio) languages.folio.embeds = Object.fromEntries(Object.entries(languages.folio.embeds).filter(([name]) => selected.includes(name)));
    const config = { version: '0.1.0', ignore: ['.ricestax', 'node_modules', 'target', 'build', 'dist', '.venv', '__pycache__'], languages };
    await writeFile(path.join(staging, 'languages.json'), JSON.stringify({ package: 'ricestax', profiles: selected }, null, 2) + '\n');
    await rename(staging, path.join(root, '.ricestax'));
    // JSON is a YAML subset, so no extra runtime YAML library is required.
    await writeFile(path.join(root, 'canon.yaml'), JSON.stringify(config, null, 2) + '\n', { flag: 'wx' });
  } finally {
    await rm(staging, { recursive: true, force: true });
  }
}
export async function setupCommand(args, root = process.cwd()) {
  if (args[0] === 'languages') {
    console.log(Object.keys(await languageProfiles()).join('\n'));
    return;
  }
  if (args.length !== 3 || args[1] !== '--languages') throw new Error('Usage: ricestax init --languages java,calm');
  await initialize(root, args[2].split(',').map(x => x.trim()));
  console.log('Created canon.yaml and .ricestax/. Commit both. Run ricestax assess to raise reviews.');
}
