// Deterministic CALM-derived starter code with executable topology tests. Application behaviour
// belongs to the project; these functions expose the declared service boundary, not an HTTP API.
import { readFile, writeFile, mkdir, mkdtemp, rm } from 'node:fs/promises';
import path from 'node:path';
import { tmpdir } from 'node:os';
import { initialize } from './setup.mjs';
import { connect } from './api.mjs';

const q = JSON.stringify;
export function template(language, architecture) {
  const ids = architecture.nodes.filter(n => n['node-type'] === 'service').map(n => n['unique-id']).sort();
  if (!ids.length) throw new Error('A starter requires at least one CALM service node');
  if (ids.some(id => !/^[A-Za-z][A-Za-z0-9_-]*$/.test(id))) throw new Error('Scaffold service ids must use letters, digits, underscores, or hyphens');
  const first = ids[0], list = ids.map(q).join(', ');
  const result = { files: {}, compile: [], test: [], evidence: {passed:'TESTS_PASSED: 2',failed:'TEST_ASSERTION_FAILED'}, mutation:null };
  const add = (file, content) => result.files[file] = content;
  const mutation = (file,original,replacement) => result.mutation={file,original,replacement};
  switch(language) {
    case 'javascript': case 'typescript': {
      const ext=language==='typescript'?'ts':'mjs';
      add(`src/topology.${ext}`,`// Service identities come from the reviewed architecture.\n/** Limits lookups to services declared by the architecture. */\nexport function isKnownService(id${ext==='ts'?': string':''})${ext==='ts'?': boolean':''} {\n  return [${list}].includes(id);\n}\n`);
      add('package.json',q({name:'calm-starter',version:'0.1.0',private:true,type:'module'}));
      add('test/topology.test.mjs',`import { isKnownService } from '../${ext==='ts'?'build/topology.js':'src/topology.mjs'}';\nif (!isKnownService(${q(first)}) || isKnownService('__unknown__')) throw new Error('TEST_ASSERTION_FAILED');\nconsole.log('TESTS_PASSED: 2');\n`);
      result.compile=ext==='ts'?['tsc','--target','es2022','--module','nodenext','--outDir','build','src/topology.ts']:['node','--check','src/topology.mjs'];
      result.test=['node','test/topology.test.mjs']; mutation(`src/topology.${ext}`,`return [${list}].includes(id);`,'return false;'); break;
    }
    case 'python':
      add('src/topology.py',`"""Expose architecture service identities to the application."""\n\ndef is_known_service(service_id):\n    """Keep undeclared services outside the application boundary."""\n    return service_id in [${list}]\n`);
      add('test_topology.py',`from src.topology import is_known_service\n\nif not is_known_service(${q(first)}) or is_known_service('__unknown__'):\n    raise AssertionError('TEST_ASSERTION_FAILED')\nprint('TESTS_PASSED: 2')\n`);
      result.compile=['python3','-m','py_compile','src/topology.py','test_topology.py']; result.test=['python3','test_topology.py']; mutation('src/topology.py',`return service_id in [${list}]`,'return False'); break;
    case 'java':
      add('src/Topology.java',`/** Service identities are derived from the architecture. */\npublic final class Topology {\n  /** Keeps undeclared services outside the application boundary. */\n  public static boolean isKnownService(String id) {\n    return java.util.Set.of(${list}).contains(id);\n  }\n}\n`);
      add('test/TopologyTest.java',`public final class TopologyTest {\n  public static void main(String[] args) {\n    if (!Topology.isKnownService(${q(first)}) || Topology.isKnownService("__unknown__")) throw new AssertionError("TEST_ASSERTION_FAILED");\n    System.out.println("TESTS_PASSED: 2");\n  }\n}\n`);
      result.compile=['javac','-d','build','src/Topology.java','test/TopologyTest.java']; result.test=['java','-cp','build','TopologyTest']; mutation('src/Topology.java',`return java.util.Set.of(${list}).contains(id);`,'return false;'); break;
    case 'kotlin':
      add('src/Topology.kt',`/** Service identities are derived from the architecture. */\nobject Topology {\n  /** Keeps undeclared services outside the application boundary. */\n  fun isKnownService(id: String): Boolean {\n    return setOf(${list}).contains(id)\n  }\n}\n`);
      add('test/TopologyTest.kt',`fun main() {\n  check(Topology.isKnownService(${q(first)}) && !Topology.isKnownService("__unknown__")) { "TEST_ASSERTION_FAILED" }\n  println("TESTS_PASSED: 2")\n}\n`);
      result.compile=['kotlinc','src/Topology.kt','test/TopologyTest.kt','-include-runtime','-d','build/topology.jar']; result.test=['java','-jar','build/topology.jar']; mutation('src/Topology.kt',`return setOf(${list}).contains(id)`,'return false'); break;
    case 'go':
      add('go.mod','module example.com/calmstarter\n\ngo 1.22\n');
      add('topology.go',`// Package topology exposes the architecture service boundary.\npackage topology\n\n// IsKnownService rejects undeclared service identities.\nfunc IsKnownService(id string) bool {\n    known := map[string]bool{${ids.map(id=>q(id)+': true').join(', ')}}\n    return known[id]\n}\n`);
      add('topology_test.go',`package topology\nimport "testing"\nfunc TestDeclaredServiceBoundary(t *testing.T) {\n    if !IsKnownService(${q(first)}) || IsKnownService("__unknown__") { t.Fatal("TEST_ASSERTION_FAILED") }\n    t.Log("TESTS_PASSED: 2")\n}\n`);
      result.compile=['go','test','-run','^$','./...']; result.test=['go','test','-count=1','-v','./...']; mutation('topology.go','return known[id]','return !known[id]'); break;
    case 'haskell':
      add('src/Topology.hs',`-- | Service identities are derived from the architecture.\nmodule Topology (isKnownService) where\n\n-- | Keeps undeclared services outside the application boundary.\nisKnownService :: String -> Bool\nisKnownService name = name \`elem\` [${list}]\n`);
      add('test/Main.hs',`module Main where\nimport Topology\nmain :: IO ()\nmain = if isKnownService ${q(first)} && not (isKnownService "__unknown__")\n  then putStrLn "TESTS_PASSED: 2"\n  else error "TEST_ASSERTION_FAILED"\n`);
      result.compile=['ghc','-isrc','-outputdir','build','-o','build/topology-test','test/Main.hs']; result.test=['./build/topology-test']; mutation('src/Topology.hs',`name \`elem\` [${list}]`,`name \`notElem\` [${list}]`); break;
    case 'calm':
      add('src/services.json',JSON.stringify(ids,null,2)+'\n');
      add('test/topology.test.mjs',`import { readFileSync } from 'node:fs';\nconst ids=JSON.parse(readFileSync('architecture.calm.json')).nodes.filter(n=>n['node-type']==='service').map(n=>n['unique-id']);\nconst inventory=JSON.parse(readFileSync('src/services.json'));\nif (JSON.stringify([...ids].sort()) !== JSON.stringify([...inventory].sort()) || !ids.includes(${q(first)}) || ids.includes('__unknown__')) throw new Error('TEST_ASSERTION_FAILED');\nconsole.log('TESTS_PASSED: 2');\n`);
      result.compile=['node','-e',"JSON.parse(require('node:fs').readFileSync('architecture.calm.json'))"];
      result.test=['node','test/topology.test.mjs']; mutation('src/services.json',q(first),q('__unknown__')); break;
    case 'antlr4':
      add('src/Topology.g4',`/** Recognises the architecture's service identifiers. */\ngrammar Topology;\n/** Rejects identities not present in the architecture. */\nservice: (${ids.map(id=>"'"+id+"'").join(' | ')}) EOF;\n/** Allows whitespace between tokens. */\nWS: [ \\t\\r\\n]+ -> skip;\n`);
      add('test/TopologyTest.java',`import org.antlr.v4.runtime.*;\npublic final class TopologyTest {\n  static boolean accepts(String input) {\n    TopologyLexer lexer = new TopologyLexer(CharStreams.fromString(input));\n    final boolean[] invalid = {false};\n    lexer.removeErrorListeners();\n    lexer.addErrorListener(new BaseErrorListener() {\n      public void syntaxError(Recognizer<?,?> r, Object symbol, int line, int col, String message, RecognitionException e) { invalid[0] = true; }\n    });\n    TopologyParser parser = new TopologyParser(new CommonTokenStream(lexer));\n    parser.removeErrorListeners();\n    parser.service();\n    return !invalid[0] && parser.getNumberOfSyntaxErrors() == 0;\n  }\n  public static void main(String[] args) {\n    if (!accepts(${q(first)}) || accepts("__unknown__")) throw new AssertionError("TEST_ASSERTION_FAILED");\n    System.out.println("TESTS_PASSED: 2");\n  }\n}\n`);
      result.compile=['antlr-build']; result.test=['antlr-test']; mutation('src/Topology.g4',"'"+first+"'","'__mutant__'"); break;
    default: throw new Error(`No scaffold template for ${language}`);
  }
  return result;
}

export async function scaffold(architecturePath, language, output) {
  const source=await readFile(architecturePath,'utf8');
  const scratch=await mkdtemp(path.join(tmpdir(),'ricestax-calm-'));
  try {
    await initialize(scratch,['calm']);
    await writeFile(path.join(scratch,'architecture.calm.json'),source);
    const api=await connect(scratch);
    const model=await api.model({path:'architecture.calm.json'});
    if (model.error) throw new Error(model.error);
  } finally { await rm(scratch,{recursive:true,force:true}); }
  const architecture=JSON.parse(source);
  const t=template(language,architecture);
  if (language === 'calm') {
    const changed=structuredClone(architecture);
    changed.nodes.find(n=>n['node-type']==='service')['node-type']='actor';
    t.mutation={file:'architecture.calm.json', original:source, replacement:JSON.stringify(changed,null,2)+'\n', operator:'service-reclassified'};
  }
  await mkdir(output); // Existing projects are never overwritten.
  try {
    await initialize(output,[...new Set([language,'calm','folio'])]);
    const files={...t.files,'architecture.calm.json':source};
    const driver=`import { spawnSync } from 'node:child_process';\nimport { mkdirSync, readdirSync } from 'node:fs';\nimport path from 'node:path';\nmkdirSync('build',{recursive:true});\nconst run=a=>{const r=spawnSync(a[0],a.slice(1),{stdio:'inherit'});if(r.error){console.error(r.error.message);process.exit(2)}if(r.status!==0)process.exit(r.status||2)};\nlet command=process.argv[2]==='compile'?${q(t.compile)}:${q(t.test)};\nif(command[0].startsWith('antlr-')) {\n const jar=process.env.ANTLR_JAR; if(!jar){console.error('Set ANTLR_JAR to an absolute ANTLR4 complete JAR path');process.exit(2)}\n if(command[0]==='antlr-build'){run(['java','-jar',jar,'-o','build','-Xexact-output-dir','src/Topology.g4']);command=['javac','-cp',jar,'-d','build',...readdirSync('build').filter(x=>x.endsWith('.java')).map(x=>'build/'+x),'test/TopologyTest.java']}\n else command=['java','-cp',['build',jar].join(path.delimiter),'TopologyTest'];\n}\nrun(command);\n`;
    files['tools/build.mjs']=driver;
    for(const [file,body] of Object.entries(files)){await mkdir(path.dirname(path.join(output,file)),{recursive:true});await writeFile(path.join(output,file),body);}
    const config=JSON.parse(await readFile(path.join(output,'canon.yaml'),'utf8'));
    config.runtime={name:'ricestax-catalog',artefacts:'.mut/current',package:'.',tests: language==='python'?'.':'test',command:'ricestax mutate'};
    config.kinds={mutant:{unreviewed:'open','logical-equivalency':'closed','inadequate-testing':'work','unnecessary-code':'work','needs-research':'deferred'}};
    await writeFile(path.join(output,'canon.yaml'),JSON.stringify(config,null,2)+'\n');
    const mutation={schema:1,inputs:[...Object.keys(files),'canon.yaml'],compile:['node','tools/build.mjs','compile'],test:['node','tools/build.mjs','test'],evidence:t.evidence,mutations:[t.mutation]};
    await writeFile(path.join(output,'ricestax.mutations.json'),JSON.stringify(mutation,null,2)+'\n');
    await writeFile(path.join(output,'.gitignore'),'.mut/\n.mut-attempt.json\n.canon-cache/\nbuild/\n__pycache__/\n*.pyc\n');
  } catch(e) {
    // Keep partial output for inspection. Never remove a directory after handing paths to tools.
    throw new Error(`Scaffold incomplete at ${output}: ${e.message}`);
  }
  return output;
}
