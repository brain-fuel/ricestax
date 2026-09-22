import {mkdirSync,readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
mkdirSync('build',{recursive:true});
const {compile}=JSON.parse(readFileSync('commands.json'));
const r=spawnSync(compile[0],compile.slice(1),{stdio:'inherit'});
if(r.error)throw r.error;process.exit(r.status??2);
