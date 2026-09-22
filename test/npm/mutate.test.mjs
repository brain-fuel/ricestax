import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, readFile, mkdir, rm, readlink } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { mutate, testOutcome } from '../../npm/mutate.mjs';

test('real compile/test runs distinguish killed, surviving, invalid, and timed out mutants', async () => {
  const root = await mkdtemp(path.join(tmpdir(),'ricestax-runner-'));
  try {
    await mkdir(path.join(root,'src')); await mkdir(path.join(root,'test'));
    const source = 'export function allowed() { const symbol = "🌍"; return true; }\n';
    await writeFile(path.join(root,'src/value.mjs'),source);
    await writeFile(path.join(root,'test/value.test.mjs'),`import test from 'node:test';\nimport assert from 'node:assert/strict';\nimport { allowed } from '../src/value.mjs';\ntest('allows valid input', () => assert.equal(allowed(), true));\n`);
    const config = { schema:1, inputs:['src','test'], compile:[process.execPath,'--check','src/value.mjs'], test:[process.execPath,'--test','--test-reporter=tap','test/value.test.mjs'], evidence:{passed:'# pass 1',failed:'not ok'}, timeoutMs:2000, mutations:[
      {file:'src/value.mjs',original:'true',replacement:'false'},
      {file:'src/value.mjs',original:'true',replacement:'Boolean(1)'},
      {file:'src/value.mjs',original:'true',replacement:'@'},
      {file:'src/value.mjs',original:'true',replacement:'(()=>{while(true){}})()'}
    ]};
    await writeFile(path.join(root,'ricestax.mutations.json'),JSON.stringify(config));
    const result=await mutate(root);
    assert.deepEqual(result.entries.map(x=>x.outcome),['killed','survived','invalid','timeout']);
    assert.equal(result.ok,false);
    assert.equal(result.entries[0].mutation.col_start,[...source.slice(0,source.indexOf('true'))].length+1);
    assert.equal(await readFile(path.join(root,'src/value.mjs'),'utf8'),source);
    const current=await readlink(path.join(root,'.mut/current'));
    const report=JSON.parse(await readFile(path.join(root,'.mut/current/out/report.json')));
    assert.deepEqual(report.controls,{passed:1,failed:0});
    const hashes=JSON.parse(await readFile(path.join(root,'.mut/current/source-sha256.json')));
    assert.deepEqual(Object.keys(hashes),['ricestax.mutations.json','src/value.mjs','test/value.test.mjs']);
    config.test=[process.execPath,'-e','process.exit(0)'];
    await writeFile(path.join(root,'ricestax.mutations.json'),JSON.stringify(config));
    await assert.rejects(mutate(root),/did not supply passing-test evidence/);
    assert.equal(await readlink(path.join(root,'.mut/current')),current);
    assert.equal(JSON.parse(await readFile(path.join(root,'.mut-attempt.json'))).mutationState,'failed');
  } finally { await rm(root,{recursive:true,force:true}); }
});

test('exit codes without evidence are infrastructure failures',()=>{
  const evidence={passed:'tests passed',failed:'assertion failed'};
  for (const code of [0,1]) assert.equal(testOutcome({code,output:''},evidence),'infrastructure_error');
  assert.equal(testOutcome({code:1,output:'compiler failed'},evidence),'infrastructure_error');
  assert.equal(testOutcome({code:1,output:'assertion failed',signal:'SIGTERM'},evidence),'infrastructure_error');
});

test('regeneration in either the compile or test command cannot erase a mutant',async()=>{
 for(const phase of ['compile','test']) {
  const root=await mkdtemp(path.join(tmpdir(),'ricestax-regeneration-'));
  try {
   await writeFile(path.join(root,'value.mjs'),'export const allowed = true;\n');
   const reset="require('node:fs').writeFileSync('value.mjs','export const allowed = true;\\n'); console.log('TESTS_PASSED')";
   const config={schema:1,inputs:['value.mjs'],compile:[process.execPath,'--check','value.mjs'],test:[process.execPath,'-e',"console.log('TESTS_PASSED')"],evidence:{passed:'TESTS_PASSED',failed:'TEST_FAILED'},mutations:[{file:'value.mjs',original:'true',replacement:'false'}]};
   config[phase]=[process.execPath,'-e',reset];
   await writeFile(path.join(root,'ricestax.mutations.json'),JSON.stringify(config));
   const result=await mutate(root);assert.equal(result.entries[0].outcome,'infrastructure_error',phase);
  } finally {await rm(root,{recursive:true,force:true});}
 }
});
