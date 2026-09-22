import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const model=JSON.parse(await readFile('architecture.calm.json'));
const nodes=new Map(model.nodes.map(n=>[n['unique-id'],n]));
const edges=model.relationships.map(r=>{const e=r['relationship-type'].connects;return [e.source.node,e.destination.node];});
test('declares the agreed actors, services, storage and valid references',()=>{
 assert.equal(model.$schema,'https://calm.finos.org/release/1.2/meta/calm.json');
 assert.equal(nodes.size,model.nodes.length);
 assert.deepEqual(Object.fromEntries([...nodes].map(([id,n])=>[id,n['node-type']])),{customer:'actor',gateway:'service',orders:'service',payments:'service','order-db':'database'});
 assert.equal(new Set(model.relationships.map(r=>r['unique-id'])).size,model.relationships.length);
 for(const [source,destination] of edges){assert(nodes.has(source));assert(nodes.has(destination));}
});
test('all customer access enters through the gateway',()=>{
 assert.deepEqual(edges.filter(([s])=>s==='customer'),[['customer','gateway']]);
 assert(edges.some(([s,d])=>s==='gateway'&&d==='orders'));
});
test('orders owns persistence and delegates payment across a service boundary',()=>{
 assert.deepEqual(edges.filter(([,d])=>d==='order-db'),[['orders','order-db']]);
 assert(edges.some(([s,d])=>s==='orders'&&d==='payments'));
 assert.equal(edges.length,4);
});
