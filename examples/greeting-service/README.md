# Greeting service

A runnable counterpart to Rice’s Tax’s architecture-to-service tutorial.

```sh
ricestax canon tangle
node --test --test-reporter=tap test/service.test.mjs
ricestax mutate
ricestax assess
ricestax pay 8091
```

The source page owns `src/greeting.mjs` and `src/server.mjs`. Edit its prose/code,
retangle, and rerun tests. The example supplies no pre-approved verdicts.
