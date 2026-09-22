import { isKnownService } from '../src/topology.mjs';
if (!isKnownService("greeting-api") || isKnownService('__unknown__')) throw new Error('TEST_ASSERTION_FAILED');
console.log('TESTS_PASSED: 2');
