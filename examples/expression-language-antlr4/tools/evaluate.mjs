import {spawnSync} from 'node:child_process';
import path from 'node:path';
if(!process.env.ANTLR_JAR) throw new Error('Set ANTLR_JAR');
const r=spawnSync('java',['-cp',['build',process.env.ANTLR_JAR].join(path.delimiter),'Evaluate',...process.argv.slice(2)],{stdio:'inherit'});
if(r.error)throw r.error;process.exit(r.status??2);
