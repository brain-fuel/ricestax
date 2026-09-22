// Copy maintained documentation and the runnable tutorial into the npm artifact.
import {cp,rm,readFile,writeFile,readdir} from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
async function files(dir){let out=[];for(const item of await readdir(dir,{withFileTypes:true})){const p=path.join(dir,item.name);out.push(...(item.isDirectory()?await files(p):[p]));}return out.sort();}
const provenance=JSON.parse(await readFile('npm/presets/provenance.json','utf8'));
provenance.files=Object.fromEntries(await Promise.all((await files('npm/presets/grammars')).map(async p=>[path.relative('npm/presets',p),createHash('sha256').update(await readFile(p)).digest('hex')])));
await writeFile('npm/presets/provenance.json',JSON.stringify(provenance,null,2)+'\n');
for (const example of (await readdir('examples',{withFileTypes:true})).filter(entry => entry.isDirectory()).map(entry => entry.name)) {
 const dest=path.join('examples',example,'.ricestax');
 await cp('npm/presets/grammars',path.join(dest,'grammars'),{recursive:true});
 await cp('npm/presets/provenance.json',path.join(dest,'provenance.json'));
 await cp('npm/presets/CANON-LICENSE',path.join(dest,'CANON-LICENSE'));
}
const excluded=new Set(['.git','.mut','.canon-cache','node_modules','build','__pycache__']);
for(const dir of ['docs','examples']){
 await rm(path.join('npm',dir),{recursive:true,force:true});
 await cp(dir,path.join('npm',dir),{recursive:true,filter:p=>!p.split(path.sep).some(x=>excluded.has(x))&&!p.endsWith('.pyc')&&!p.endsWith('.mut-attempt.json')});
}
await cp('README.md','npm/README.md');
const p=JSON.parse(await readFile('npm/package.json','utf8'));
p.files=[...new Set([...p.files,'docs','examples'])];
await writeFile('npm/package.json',JSON.stringify(p,null,2)+'\n');
