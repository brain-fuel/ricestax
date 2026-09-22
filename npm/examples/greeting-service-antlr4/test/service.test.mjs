import test from 'node:test';
import assert from 'node:assert/strict';
import {createGreetingServer} from '../tools/server.mjs';
test('greeting contract through actual HTTP and target-language process',async()=>{
 const server=createGreetingServer();
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 try {
  const base='http://127.0.0.1:'+server.address().port;
  for(const name of ['Ada','  Ada Lovelace  ','A"B','Zoë']) {
   const response=await fetch(base+'/greet?name='+encodeURIComponent(name));
   assert.equal(response.status,200);
   assert.deepEqual(await response.json(),{greeting:'Hello, '+name.trim()+'!'});
  }
  for(const query of ['', '?name=', '?name=%20%20']) assert.equal((await fetch(base+'/greet'+query)).status,400);
  assert.equal((await fetch(base+'/other')).status,404);
  assert.equal((await fetch(base+'/greet?name=Ada',{method:'POST'})).status,404);
 } finally {await new Promise(resolve=>server.close(resolve));}
});
