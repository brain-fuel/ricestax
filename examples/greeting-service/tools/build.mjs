import {spawnSync} from 'node:child_process';
for(const file of ['src/greeting.mjs','src/server.mjs','test/service.test.mjs']){const r=spawnSync('node',['--check',file],{stdio:'inherit'});if(r.status!==0)process.exit(r.status??2);}
