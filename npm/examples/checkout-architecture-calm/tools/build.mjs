import {spawnSync} from 'node:child_process';
const install = spawnSync('npm', ['ci', '--ignore-scripts', '--no-audit', '--no-fund'], {stdio: 'inherit'});
if (install.error) throw install.error;
if (install.status !== 0) process.exit(install.status ?? 2);
import {readFile} from 'node:fs/promises';
JSON.parse(await readFile('architecture.calm.json','utf8'));
