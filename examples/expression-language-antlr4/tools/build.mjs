import {spawnSync} from 'node:child_process';
import {mkdirSync,readdirSync} from 'node:fs';
import path from 'node:path';
const jar=process.env.ANTLR_JAR;
if(!jar || !path.isAbsolute(jar)) throw new Error('Set ANTLR_JAR to an absolute ANTLR4 complete JAR path');
mkdirSync('build',{recursive:true});
for(const command of [['mvn','-q','org.apache.maven.plugins:maven-dependency-plugin:3.8.1:copy-dependencies','-DoutputDirectory=build/dependency'], ['java','-jar',jar,'-visitor','-o','build','-Xexact-output-dir','src/Expression.g4'], ['javac','-cp',jar+path.delimiter+'build/dependency/*','-d','build']]) {
 if(command[0]==='javac') command.push(...readdirSync('build').filter(x=>x.endsWith('.java')).map(x=>'build/'+x),'src/Evaluate.java','test/ExpressionTest.java');
 const r=spawnSync(command[0],command.slice(1),{stdio:'inherit'});if(r.error)throw r.error;if(r.status!==0)process.exit(r.status??2);
}
