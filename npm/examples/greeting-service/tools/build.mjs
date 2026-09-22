import { spawnSync } from 'node:child_process';
import { mkdirSync, readdirSync } from 'node:fs';
import path from 'node:path';
mkdirSync('build',{recursive:true});
const run=a=>{const r=spawnSync(a[0],a.slice(1),{stdio:'inherit'});if(r.error){console.error(r.error.message);process.exit(2)}if(r.status!==0)process.exit(r.status||2)};
let command=process.argv[2]==='compile'?["node","--check","src/topology.mjs"]:["node","test/topology.test.mjs"];
if(command[0].startsWith('antlr-')) {
 const jar=process.env.ANTLR_JAR; if(!jar){console.error('Set ANTLR_JAR to an absolute ANTLR4 complete JAR path');process.exit(2)}
 if(command[0]==='antlr-build'){run(['java','-jar',jar,'-o','build','-Xexact-output-dir','src/Topology.g4']);command=['javac','-cp',jar,'-d','build',...readdirSync('build').filter(x=>x.endsWith('.java')).map(x=>'build/'+x),'test/TopologyTest.java']}
 else command=['java','-cp',['build',jar].join(path.delimiter),'TopologyTest'];
}
run(command);
