import {readFile} from 'node:fs/promises';
JSON.parse(await readFile('architecture.calm.json','utf8'));
