// Run the complete examples from a source tree or installed npm package.
// Requires every target compiler; missing tools fail rather than skip evidence.
import {spawnSync} from 'node:child_process';
import {readdir,readFile,mkdtemp,cp} from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
const root=path.resolve(process.argv[2]??'npm');
const cli=path.join(root,'bin/ricestax.mjs');
const {connect}=await import(pathToFileURL(path.join(root,'api.mjs')));
const temporary=await mkdtemp(path.join(os.tmpdir(),'ricestax-greeting-'));
console.log('Evidence directory: '+temporary);
for(const name of (await readdir(path.join(root,'examples'))).filter(x=>x.startsWith('greeting-service')).sort()) {
 const cwd=path.join(temporary,name);
 await cp(path.join(root,'examples',name),cwd,{recursive:true,filter:p=>!p.split(path.sep).some(x=>['.mut','.canon-cache','build','__pycache__'].includes(x))});
 console.log('\nTARGET '+name);
 const commands=[['node',cli,'canon','tangle'],['node',cli,'canon','tangle','--check']];
 if(name!=='greeting-service'&&!name.endsWith('-calm'))commands.push(['node','tools/build.mjs']);
 commands.push(['node',cli,'mutate']);
 for(const args of commands){const r=spawnSync(args[0],args.slice(1),{cwd,encoding:'utf8',env:process.env,timeout:240000});process.stdout.write(r.stdout??'');process.stderr.write(r.stderr??'');if(r.error)throw r.error;if(r.status!==0)throw new Error(name+': '+args.join(' ')+' failed ('+r.status+')');}
 const api=await connect(cwd);
 const catalog=JSON.parse(await readFile(path.join(cwd,'ricestax.mutations.json')));
 const model=await api.model({path:catalog.mutations[0].file});
 assert(!model.error,JSON.stringify(model));
 const payload=await api.reload();
 assert(!payload.error,JSON.stringify(payload));
 assert.equal(payload.runIssue,'');
 assert(payload.facts.factList.some(([key,value])=>key==='killed'&&value==='1'));
 console.log('PASS: ingested source, loaded review report, generated documentation, checked drift, compiled baseline, ran HTTP assertions and killed catalog fault');
}
