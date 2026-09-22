import {mkdirSync} from 'node:fs';
import {readFile} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
mkdirSync('build',{recursive:true});
const {compile}=JSON.parse(await readFile('commands.json'));
const result=spawnSync(compile[0],compile.slice(1),{stdio:'inherit'});
if(result.error) console.error(result.error);
process.exit(result.status??2);
