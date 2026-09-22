# Greeting service: CALM architecture

CALM is the architecture language in this example. The running HTTP service is
JavaScript. The architecture test asserts the agreed service identity and type;
it does not establish complete CALM schema conformance or prove that a deployed
service matches its model. The separate HTTP test exercises the implementation.

Requires Node 22+ and Rice’s Tax 0.3.0 candidate. From this directory:

```sh
ricestax canon tangle
ricestax canon tangle --check
node --test --test-reporter=tap test/architecture.test.mjs test/service.test.mjs
ricestax mutate
ricestax assess
ricestax pay 8091
node --input-type=module -e "import {createGreetingServer} from './src/server.mjs'; createGreetingServer().listen(8097,'127.0.0.1')"
```

Visit http://localhost:8097/greet?name=Ada . Stop with Ctrl-C.
Change the architecture in docs/reference/architecture.md, then retangle. The
catalog changes the declared service to an actor: the independent architecture
assertion must reject that valid-JSON but incorrect model. No automatic code
synthesis from a CALM responsibility description is claimed.
