import {spawnSync} from 'node:child_process';
for(const args of [['npm','ci','--ignore-scripts','--no-audit','--no-fund'],['npm','exec','--','tsc','-p','tsconfig.json']]){const r=spawnSync(args[0],args.slice(1),{stdio:'inherit'});if(r.error)throw r.error;if(r.status!==0)process.exit(r.status??2);}
