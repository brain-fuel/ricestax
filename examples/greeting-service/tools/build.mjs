import {spawnSync} from 'node:child_process';
const install=spawnSync('npm',['ci','--ignore-scripts','--no-audit','--no-fund'],{stdio:'inherit'});
if(install.error)throw install.error;if(install.status!==0)process.exit(install.status??2);
for(const file of ['src/greeting.mjs','src/server.mjs','test/service.test.mjs']){const r=spawnSync('node',['--check',file],{stdio:'inherit'});if(r.status!==0)process.exit(r.status??2);}
