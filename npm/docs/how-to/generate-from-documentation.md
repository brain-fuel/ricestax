---
id: ricestax.how-to.generate-from-documentation
kind: how-to
title: Generate executable sources from documentation
---
# Generate executable sources from documentation

Enable your language and `folio` when initializing a new project. For an existing
project, merge these profiles as described in the migration guide. The Folio
profile's `embeds` map must name each language whose blocks you intend to generate.
The initializer includes only the selected languages in that map.

Create a reference page with `id`, `kind: reference`, and `title` front matter.
Give each definition a numbered section explaining its reason, followed by a
block with a destination and definition name. For example, the page contains:

````markdown
## 1. Positive input

Zero and negative quantities cannot start a shipment.

```javascript file=src/quantity.mjs def=isPositiveQuantity
export function isPositiveQuantity(quantity) {
  return Number.isInteger(quantity) && quantity > 0;
}
```
````

Use `part=imports` or another meaningful part name for scaffolding that does not
define one unit. Use separate definition blocks when each unit needs its own
reason. Plain code fences without `file=` are illustrations and are not tangled.
To show a complete fenced-block example inside documentation, enclose it in a
four-backtick fence as this guide does.

Run:

```sh
ricestax canon tangle
ricestax canon tangle --check
```

The first command writes the named paths; check the destination before doing it.
The second compares the current output to the assembled pages without writing.
Then compile and test with the language's own tools. Repeat generation should
produce identical bytes for unchanged pages and profiles.

The packaged profiles use Javadoc-style block comments for Java, JavaScript,
TypeScript, Go, Kotlin, and ANTLR4; Haddock for Haskell; and Python line comments.
Authored Python docstrings remain code inside the block. CALM uses comment-free
JSON output: write the explanatory descriptions as JSON fields and retain the
page itself as documentation. A JSON output cannot have a generated comment banner.

Do not include source comments in blocks whose profile generates the comment
from prose. Avoid tangled outputs outside the project. Commit pages, profiles,
and generated sources together so a reader can reproduce the relationship.

CI checks generation before tests and mutation. The mutation runner works on
copies of the already-generated source; regenerating inside a mutated compile or
test step is rejected as infrastructure failure. Include the source pages in the
mutation input manifest so a later prose/code edit makes that evidence stale.

For CALM-derived project scaffolding instead, use
`ricestax scaffold architecture.calm.json --language java --out new-project`.
Generate into a new directory when revising a scaffold and compare changes before
merging: this command does not overwrite or silently migrate your existing project.
