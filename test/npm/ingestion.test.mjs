import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,writeFile,readFile,mkdir,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {connect} from '../../npm/api.mjs';
import {initialize} from '../../npm/setup.mjs';
const arch=()=>({$schema:'https://calm.finos.org/release/1.2/meta/calm.json',nodes:[{'unique-id':'api','node-type':'service',name:'API',description:'Owns requests.'}],relationships:[]});
async function fixture(languages,fn){const root=await mkdtemp(path.join(tmpdir(),'ricestax-ingestion-'));try{await initialize(root,languages);await fn(root,await connect(root));}finally{await rm(root,{recursive:true,force:true});}}
const units=m=>m.units.flatMap(function visit(u){return [u,...u.children.flatMap(visit)];});
test('CALM preserves identity across reordering and rejects malformed architecture',()=>fixture(['calm'],async(root,api)=>{
 const a=arch();
 await writeFile(path.join(root,'app.calm.json'),JSON.stringify(a,null,2));
 const before=await api.model({path:'app.calm.json'});assert(!before.error);
 const node=units(before).find(x=>x.what.value.name==='API');assert.equal(node.id,'calm/app.calm.json/node/api');
 assert.equal(before.decisions[0].why.value.text,'Owns requests.');assert(before.decisions[0].where.span.start.line>1);
 a.nodes[0]={description:'Owns requests.',name:'API','node-type':'service','unique-id':'api'};
 await writeFile(path.join(root,'app.calm.json'),JSON.stringify(a));
 const after=await api.model({path:'app.calm.json'});assert.equal(units(after).find(x=>x.what.value.name==='API').id,node.id);
 for(const change of [x=>x.nodes.push({...x.nodes[0]}),x=>x.relationships.push({'unique-id':'edge','relationship-type':{connects:{source:{node:'api'},destination:{node:'missing'}}}}),x=>x.nodes[0]['node-type']='fiction',x=>x.$schema='https://example.invalid/schema',x=>x.nodes={}]){
  const bad=arch();change(bad);await writeFile(path.join(root,'app.calm.json'),JSON.stringify(bad));const result=await api.model({path:'app.calm.json'});assert(result.error,JSON.stringify(bad));
 }
 await writeFile(path.join(root,'app.calm.json'),JSON.stringify(arch()).slice(0,-1)+',"n\\u006fdes":[]}');assert((await api.model({path:'app.calm.json'})).error);
}));
test('Python docstrings belong to their own declarations, not assignments or nested strings',()=>fixture(['python'],async(root,api)=>{
 const text=`"""Module reason."""\n\nclass Example:\n    """Class reason."""\n    def documented(self):\n        """Method reason.\n        # this is docstring text\n        """\n        return 1\n\ndef assignment():\n    value = "Not documentation"\n    return value\n\ndef late():\n    pass\n    "Not documentation either"\n`;
 await writeFile(path.join(root,'sample.py'),text);
 const m=await api.model({path:'sample.py'});assert(!m.error,m.error);
 const docs=m.decisions.map(x=>x.why.value.text);
 assert(docs.includes('Module reason.'));assert(docs.includes('Class reason.'));assert(docs.some(x=>x.startsWith('Method reason.')));
 assert(!docs.some(x=>x.includes('Not documentation')));
 const method=units(m).find(x=>x.what.value.name==='documented');assert(method.how.value.body.includes('return 1'));assert(!method.how.value.body.includes('Method reason.'));
}));
test('each packaged source profile reports invalid input instead of an empty model',async()=>{
 const samples={java:['Bad.java','public class Broken {'],javascript:['bad.js','export function broken( {'],typescript:['bad.ts','interface Broken {'],python:['bad.py','def broken(:\n pass\n'],go:['bad.go','package x\nfunc Broken( {'],haskell:['Bad.hs','module Broken ('],kotlin:['Bad.kt','fun broken( {'],antlr4:['Bad.g4','grammar Bad; rule withoutcolon;']};
 for(const [language,[file,source]] of Object.entries(samples))await fixture([language],async(root,api)=>{await writeFile(path.join(root,file),source);assert((await api.model({path:file})).error,language);const payload=await api.reload();assert(payload.ingestionIssues.length>0,language);assert.equal((await api.audit()).ok,false,language);});
});
test('CALM structure changes invalidate a previously recorded What decision',()=>fixture(['calm'],async(root,api)=>{
 const a=arch();await writeFile(path.join(root,'app.calm.json'),JSON.stringify(a));
 await api.assess();const p=await api.payload();const row=p.items.find(x=>x.key==='name/calm/app.calm.json/node/api');assert(row);
 const decided=await api.decide({decideKey:row.key,decideVerdict:'good',decideNote:'Test fixture only',decideRevisit:''});assert(!decided.error,decided.error);
 a.nodes[0].interfaces=[{'unique-id':'http',url:'https://example.invalid'}];await writeFile(path.join(root,'app.calm.json'),JSON.stringify(a));
 const changed=await api.reload();assert.equal(changed.items.find(x=>x.key===row.key).state,'stale');
}));
test('init refuses an existing configuration without changing it',async()=>{
 const root=await mkdtemp(path.join(tmpdir(),'ricestax-existing-'));
 try{await writeFile(path.join(root,'canon.yaml'),'languages: {}\n');await assert.rejects(initialize(root,['java']),/already exists/);assert.equal(await readFile(path.join(root,'canon.yaml'),'utf8'),'languages: {}\n');}finally{await rm(root,{recursive:true,force:true});}
});

test('escaped template delimiters remain string content in JS and TS',async()=>{
 for(const language of ['javascript','typescript']) await fixture([language],async(root,api)=>{
  const source='// Module rationale.\n/** Carries literal source without executing it. */\nexport function sourceText() { return `a \\`quoted\\` token and \\${literal}`; }\n';
  const file=language==='javascript'?'sample.mjs':'sample.ts';await writeFile(path.join(root,file),source);
  const m=await api.model({path:file});assert(!m.error,m.error);assert(units(m).some(u=>u.what.value.name==='sourceText'));
 });
});
test('Haskell contextual identifiers and delimited case layout preserve function bodies',()=>fixture(['haskell'],async(root,api)=>{
 const source='-- | A small layout regression.\nmodule Example (unsafe) where\n-- | Keeps layout local to the list expression.\nunsafe :: Maybe Bool -> [Bool]\nunsafe value = [True, case value of\n  Just flag -> flag\n  Nothing -> False]\n';
 await writeFile(path.join(root,'Example.hs'),source);
 const m=await api.model({path:'Example.hs'});assert(!m.error,m.error);const u=units(m).find(u=>u.what.value.name==='unsafe');assert(u);assert(u.how.value.body.includes('Nothing -> False'));
}));

test('scaffolding is deterministic and refuses existing output or invalid architecture',async()=>{
 const {scaffold}=await import('../../npm/scaffold.mjs');
 const root=await mkdtemp(path.join(tmpdir(),'ricestax-scaffold-'));
 try{
  const source=path.join(root,'input.calm.json');await writeFile(source,JSON.stringify(arch(),null,2));
  await scaffold(source,'javascript',path.join(root,'one'));
  await scaffold(source,'javascript',path.join(root,'two'));
  for(const f of ['src/topology.mjs','test/topology.test.mjs','tools/build.mjs','canon.yaml','ricestax.mutations.json'])assert.equal(await readFile(path.join(root,'one',f),'utf8'),await readFile(path.join(root,'two',f),'utf8'));
  const original=await readFile(path.join(root,'one/src/topology.mjs'),'utf8');
  await assert.rejects(scaffold(source,'javascript',path.join(root,'one')),/exist/i);
  assert.equal(await readFile(path.join(root,'one/src/topology.mjs'),'utf8'),original);
  await writeFile(source,'{}');await assert.rejects(scaffold(source,'javascript',path.join(root,'invalid')),/CALM/);
 }finally{await rm(root,{recursive:true,force:true});}
});

test('CALM relationship and flow descriptions are independently reviewable',()=>fixture(['calm'],async(root,api)=>{
 const a=arch();a.nodes.push({'unique-id':'worker','node-type':'service',name:'Worker',description:'Owns background processing.'});
 a.relationships=[{'unique-id':'request','description':'Offloads the work.','relationship-type':{connects:{source:{node:'api'},destination:{node:'worker'}}}}];
 a.flows=[{'unique-id':'delivery',name:'Delivery',description:'Completes requested work.',transitions:[{'relationship-unique-id':'request','sequence-number':1,direction:'source-to-destination'}]}];
 await writeFile(path.join(root,'app.calm.json'),JSON.stringify(a,null,2));
 const m=await api.model({path:'app.calm.json'});assert(!m.error,m.error);
 assert(units(m).some(x=>x.id==='calm/app.calm.json/relationship/request'));
 assert(units(m).some(x=>x.id==='calm/app.calm.json/flow/delivery'));
 assert(m.decisions.some(x=>x.why.value.text==='Completes requested work.'));
 a.flows[0].transitions[0]['relationship-unique-id']='absent';await writeFile(path.join(root,'app.calm.json'),JSON.stringify(a));
 assert.match((await api.model({path:'app.calm.json'})).error,/unknown relationship/);
}));

test('a documentation-only project raises page review without an embedded code language',()=>fixture(['folio'],async(root,api)=>{
 await mkdir(path.join(root,'docs/how-to'),{recursive:true});
 await writeFile(path.join(root,'docs/how-to/read.md'),'---\nid: example.how-to.read\nkind: how-to\ntitle: Read evidence\n---\n# Read evidence\n\nRead the retained evidence before making a decision.\n');
 const p=await api.payload();assert.deepEqual(p.ingestionIssues,[]);assert(p.items.some(x=>x.kind==='doc'));
}));
