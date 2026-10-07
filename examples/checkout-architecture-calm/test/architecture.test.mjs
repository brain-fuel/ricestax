import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import fc from 'fast-check';

const model = JSON.parse(await readFile('architecture.calm.json'));
const expectedTypes = {customer: 'actor', gateway: 'service', orders: 'service', payments: 'service', 'order-db': 'database'};
const expectedEdges = ['customer->gateway', 'gateway->orders', 'orders->payments', 'orders->order-db'].sort();

// This is the checkout policy, not a replacement for the complete CALM schema.
function assertCheckout(candidate) {
  assert.equal(candidate.$schema, 'https://calm.finos.org/release/1.2/meta/calm.json');
  const nodes = new Map(candidate.nodes.map(n => [n['unique-id'], n]));
  assert.equal(nodes.size, candidate.nodes.length, 'duplicate node identity');
  assert.deepEqual(Object.fromEntries([...nodes].map(([id, n]) => [id, n['node-type']])), expectedTypes);
  assert.equal(new Set(candidate.relationships.map(r => r['unique-id'])).size, candidate.relationships.length, 'duplicate relationship identity');
  const edges = candidate.relationships.map(r => {
    const {source, destination} = r['relationship-type'].connects;
    assert(nodes.has(source.node) && nodes.has(destination.node), 'dangling endpoint');
    return source.node + '->' + destination.node;
  });
  assert.deepEqual(edges.sort(), expectedEdges, 'checkout boundaries');
}

const parameters = {
  numRuns: 100,
  ...(process.env.FC_SEED ? {seed: Number(process.env.FC_SEED)} : {}),
  ...(process.env.FC_PATH ? {path: process.env.FC_PATH} : {}),
};

test('the supplied architecture satisfies the checkout contract', () => assertCheckout(model));

test('node and relationship ordering does not change the policy verdict', () => {
  fc.assert(fc.property(
    fc.shuffledSubarray(model.nodes, {minLength: model.nodes.length, maxLength: model.nodes.length}),
    fc.shuffledSubarray(model.relationships, {minLength: model.relationships.length, maxLength: model.relationships.length}),
    (nodes, relationships) => assertCheckout({...model, nodes, relationships}),
  ), parameters);
});

test('the policy rejects generated boundary violations and missing nodes', () => {
  // Establish a valid control before testing deliberate invalid variants.
  assertCheckout(model);
  const ids = Object.keys(expectedTypes);
  const forbidden = ids.flatMap(source => ids.filter(destination => !expectedEdges.includes(source + '->' + destination)).map(destination => [source, destination]));
  fc.assert(fc.property(fc.constantFrom(...forbidden), fc.integer({min: 0, max: ids.length - 1}), ([source, destination], removed) => {
    const crossing = structuredClone(model);
    crossing.relationships.push({'unique-id': 'forbidden-edge', 'relationship-type': {connects: {source: {node: source}, destination: {node: destination}}}});
    assert.throws(() => assertCheckout(crossing), assert.AssertionError);
    const missing = structuredClone(model);
    missing.nodes.splice(removed, 1);
    assert.throws(() => assertCheckout(missing), assert.AssertionError);
  }), parameters);
});
