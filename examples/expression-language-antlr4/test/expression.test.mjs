import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
const evaluate=input=>spawnSync('node',['tools/evaluate.mjs',input],{encoding:'utf8'});
test('precedence, parentheses, associativity, whitespace and multi-digit literals',()=>{
 for(const [input,expected] of [['2+3*4','14'],['(2+3)*4','20'],['20-5-3','12'],['20/5/2','2'],[' 12 + 3 \n','15'],['7/2','3']]) {
  const r=evaluate(input);assert.equal(r.status,0,input+': '+r.stderr);assert.equal(r.stdout.trim(),expected,input);
 }
});
test('reject malformed expressions, trailing input and invalid arithmetic',()=>{
 for(const input of ['', '2+', '(2+3', '1 2', '2@3', '2**3', '-1', '4/0', '999999999999999999999999']) {
  const r=evaluate(input);assert.equal(r.status,2,input);assert.equal(r.stdout,'',input);assert.match(r.stderr,/Invalid (expression|arithmetic)/);
 }
});
