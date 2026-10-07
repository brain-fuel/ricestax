// Run the complete examples from a source tree or installed npm package.
// Requires every target compiler; missing tools fail rather than skip evidence.
import {spawnSync} from 'node:child_process';
import {readdir,readFile,mkdtemp,cp,writeFile} from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
const root=path.resolve(process.argv[2]??'npm');
const cli=path.join(root,'bin/ricestax.mjs');
const {connect}=await import(pathToFileURL(path.join(root,'api.mjs')));
const temporary=await mkdtemp(path.join(os.tmpdir(),'ricestax-greeting-'));
console.log('Evidence directory: '+temporary);
const projects=(await readdir(path.join(root,'examples'),{withFileTypes:true})).filter(x=>x.isDirectory()).map(x=>x.name).sort();
assert.deepEqual(projects,['checkout-architecture-calm','expression-language-antlr4','greeting-service','greeting-service-go','greeting-service-haskell','greeting-service-java','greeting-service-kotlin','greeting-service-python','greeting-service-typescript']);
const evidence = [];
for(const name of projects) {
 const cwd=path.join(temporary,name);
 const source=path.join(root,'examples',name);
 await cp(source,cwd,{recursive:true,filter:p=>!path.relative(source,p).split(path.sep).some(x=>['.mut','.canon-cache','build','__pycache__','.hypothesis','.kotest','node_modules','.stack-work'].includes(x))});
 const nativeTests={
  'greeting-service':'test/service.test.mjs',
  'greeting-service-java':'test/GreetingTest.java',
  'greeting-service-python':'test/test_service.py',
  'greeting-service-go':'src/main_test.go',
  'greeting-service-kotlin':'test/GreetingTest.kt',
  'greeting-service-typescript':'test/service.test.ts',
  'greeting-service-haskell':'test/Main.hs',
  'expression-language-antlr4':'test/ExpressionTest.java'
 };
 if(nativeTests[name]) assert((await readFile(path.join(cwd,nativeTests[name]),'utf8')).length>0);
 assert(!(await readdir(path.join(cwd,'tools'))).includes('server.mjs'),'Legacy process adapter shipped: '+name);
 console.log('\nTARGET '+name);
 const commands=[['node',cli,'canon','tangle'],['node',cli,'canon','tangle','--check']];
 if(name!=='greeting-service')commands.push(['node','tools/build.mjs']);
 commands.push(['node',cli,'mutate']);
 for(const args of commands){const r=spawnSync(args[0],args.slice(1),{cwd,encoding:'utf8',env:process.env,timeout:240000});process.stdout.write(r.stdout??'');process.stderr.write(r.stderr??'');if(r.error)throw r.error;if(r.status!==0)throw new Error(name+': '+args.join(' ')+' failed ('+r.status+')');}
 const api=await connect(cwd);
 const catalog=JSON.parse(await readFile(path.join(cwd,'ricestax.mutations.json')));
 const model=await api.model({path:catalog.mutations[0].file});
 assert(!model.error,JSON.stringify(model));
 const payload=await api.reload();
 assert(!payload.error,JSON.stringify(payload));
 assert.equal(payload.runIssue,'');
 assert.deepEqual(payload.ingestionIssues,[],name+': ingestion errors');
 assert(payload.facts.factList.some(([key,value])=>key==='killed'&&value===String(catalog.mutations.length)));
 const run = JSON.parse(await readFile(path.join(cwd,'.mut/current/run.json')));
 const control = JSON.parse(await readFile(path.join(cwd,'.mut/current/control/test-result.json')));
 evidence.push({example:name, mutations:catalog.mutations.length, baselineExitCode:control.code, ingestionIssues:payload.ingestionIssues, facts:payload.facts.factList, run, catalogSha256:createHash('sha256').update(await readFile(path.join(cwd,'ricestax.mutations.json'))).digest('hex'), evidenceDirectory:cwd});
 console.log('PASS: ingested source, loaded review report, generated documentation, checked drift, compiled baseline, ran example assertions and killed catalog fault');
}

if(process.env.RICESTAX_EXAMPLE_REPORT) await writeFile(process.env.RICESTAX_EXAMPLE_REPORT,JSON.stringify(evidence,null,2)+"\n");
