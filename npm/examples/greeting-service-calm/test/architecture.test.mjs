import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
test('the greeting boundary is a service with its agreed identity',async()=>{
 const model=JSON.parse(await readFile('architecture.calm.json'));
 assert.equal(model.$schema,'https://calm.finos.org/release/1.2/meta/calm.json');
 assert.equal(model.nodes.length,1);
 assert.equal(model.nodes[0]['unique-id'],'greeting-api');
 assert.equal(model.nodes[0]['node-type'],'service');
 assert.equal(model.nodes[0].name,'Greeting API');
 assert.deepEqual(model.relationships,[]);
});
