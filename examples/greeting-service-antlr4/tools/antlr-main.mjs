import {spawnSync} from 'node:child_process';
import path from 'node:path';
const r=spawnSync('java',['-cp',['build',process.env.ANTLR_JAR].join(path.delimiter),'GreetingMain',process.argv[2]],{stdio:'inherit'});
process.exit(r.status??3);
