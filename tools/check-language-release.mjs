// Release acceptance runs real compilers and tests; missing toolchains are failures, not skips.
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, readFile } from 'node:fs/promises';
import path from 'node:path';
import { tmpdir } from 'node:os';
import { pathToFileURL } from 'node:url';
const pkg=path.resolve(process.argv[2] || 'npm');
const { scaffold }=await import(pathToFileURL(path.join(pkg,'scaffold.mjs')));
const { mutate, runCommand }=await import(pathToFileURL(path.join(pkg,'mutate.mjs')));
const { connect }=await import(pathToFileURL(path.join(pkg,'api.mjs')));
const base=await mkdtemp(path.join(tmpdir(),'ricestax-030-acceptance-'));
await writeFile('/tmp/ricestax-030-acceptance-path',base);
const arch={ $schema:'https://calm.finos.org/release/1.2/meta/calm.json',nodes:[
  {'unique-id':'greeting-api','node-type':'service',name:'Greeting API',description:'Owns greeting responses.'},
  {'unique-id':'audit-service','node-type':'service',name:'Audit service',description:'Retains delivery evidence.'}
],relationships:[{'unique-id':'api-to-audit',description:'Retain evidence separately from serving requests.','relationship-type':{connects:{source:{node:'greeting-api'},destination:{node:'audit-service'}}}}]};
await writeFile(path.join(base,'architecture.calm.json'),JSON.stringify(arch,null,2));
const units=m=>m.units.flatMap(function visit(u){return [u,...u.children.flatMap(visit)];});
const expected={java:['src/Topology.java','isKnownService'],javascript:['src/topology.mjs','isKnownService'],typescript:['src/topology.ts','isKnownService'],python:['src/topology.py','is_known_service'],go:['topology.go','IsKnownService'],haskell:['src/Topology.hs','isKnownService'],kotlin:['src/Topology.kt','isKnownService'],calm:['architecture.calm.json','Greeting API'],antlr4:['src/Topology.g4','service']};
for(const [language,[file,name]] of Object.entries(expected)){
  const dir=path.join(base,language);
  await scaffold(path.join(base,'architecture.calm.json'),language,dir);
  const api=await connect(dir);
  const model=await api.model({path:file});
  assert(!model.error,`${language}: ${model.error}`);
  const unit=units(model).find(u=>u.what.value.name===name);
  assert(unit,`${language}: missing ${name}`);
  assert(unit.where.value.span.start.line>0);
  assert(model.decisions.some(d=>d.units.includes(unit.id)),`${language}: missing documentation for ${unit.id}`);
  for(const phase of ['compile','test']){
    const r=await runCommand(['node','tools/build.mjs',phase],dir,180000);
    await writeFile(path.join(dir,`${phase}-acceptance.json`),JSON.stringify(r,null,2));
    assert.equal(r.code,0,`${language} ${phase}: ${r.output}`);
    if(phase==='test') assert(r.output.includes('TESTS_PASSED: 2'));
  }
  const run=await mutate(dir);
  assert.equal(run.entries.length,1);
  assert.equal(run.entries[0].outcome,'killed',`${language}: ${run.entries[0].outcome}`);
  const payload=await api.reload();
  assert(!payload.error,JSON.stringify(payload));
  assert.equal(payload.runIssue,'',`${language} review: ${payload.runIssue}`);
  assert(payload.facts.factList.some(([k,v])=>k==='killed'&&v==='1'));
  console.log(`PASS ${language}: model, attached documentation, compiler, tests, mutation kill, review report`);
}
console.log(`Evidence retained: ${base}`);
