import {spawnSync} from 'node:child_process';
import {readdirSync} from 'node:fs';
const jar=process.env.ANTLR_JAR;if(!jar) throw new Error('Set ANTLR_JAR');
for(const args of [['java','-jar',jar,'-o','build','-Xexact-output-dir','src/Greeting.g4'],['javac','-cp',jar,'-d','build',...[]]]) {
if(args[0]==='javac') args.push(...readdirSync('build').filter(x=>x.endsWith('.java')).map(x=>'build/'+x),'src/GreetingMain.java');
const r=spawnSync(args[0],args.slice(1),{stdio:'inherit'});if(r.status!==0)process.exit(r.status??2);}
