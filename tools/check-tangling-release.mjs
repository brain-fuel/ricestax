import assert from 'node:assert/strict';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
const pkg=path.resolve(process.argv[2]||'npm');
const {connect}=await import(pathToFileURL(path.join(pkg,'api.mjs')));
const {runCommand}=await import(pathToFileURL(path.join(pkg,'mutate.mjs')));
const base=(await readFile('/tmp/ricestax-030-acceptance-path','utf8')).trim();
const files={java:'src/Topology.java',javascript:'src/topology.mjs',typescript:'src/topology.ts',python:'src/topology.py',go:'topology.go',haskell:'src/Topology.hs',kotlin:'src/Topology.kt',calm:'architecture.calm.json',antlr4:'src/Topology.g4'};
for(const [language,file] of Object.entries(files)){
 const dir=path.join(base,language);
 const source=(await readFile(path.join(dir,file),'utf8')).split('\n').filter(l=>!/^\s*(\/\*\*|\/\/|--)/.test(l)).join('\n');
 await mkdir(path.join(dir,'docs/reference'),{recursive:true});
 await writeFile(path.join(dir,'docs/reference/topology.md'),`---\nid: starter.reference.topology\nkind: reference\ntitle: Service boundary\n---\n# Service boundary\n\n## 1. Declared topology\n\nService membership limits lookups to architecture-owned identities.\n\n\`\`\`${language} file=${file} part=topology\n${source.trimEnd()}\n\`\`\`\n`);
 const api=await connect(dir);
 const tangled=await api.canon({args:['tangle']});assert.equal(tangled.exit,0,JSON.stringify(tangled));
 const first=await readFile(path.join(dir,file),'utf8');
 const check=await api.canon({args:['tangle','--check']});assert.equal(check.exit,0,`${language} stale output`);
 await api.canon({args:['tangle']});assert.equal(await readFile(path.join(dir,file),'utf8'),first);
 for(const phase of ['compile','test']){
  const r=await runCommand(['node','tools/build.mjs',phase],dir,180000);
  assert.equal(r.code,0,`${language} generated ${phase}: ${r.output}`);
 }
 await writeFile(path.join(dir,file),first+'\n');
 const stale=await api.canon({args:['tangle','--check']});assert.notEqual(stale.exit,0,`${language} failed to detect edited output`);
 await writeFile(path.join(dir,file),first);
 console.log(`PASS ${language}: deterministic tangling, executable output, stale-output detection`);
}
