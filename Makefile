# Rice's Tax's front door: one target per moment of the tax and one per piece of tooling, so
# nobody types tools/mutate.sh by hand. Every target runs natively through Stack; the WebAssembly
# halves and the package are built by the one script Stack cannot replace. ref:DEC-three-verbs
# ref:DEC-umbrella-surface

# | Where Stack put the binary, read once so every target runs the build it just made.
BIN = $$(stack path --local-install-root)/bin/ricestax

# | The seed the mutation run fixes, because a result under an unrecorded seed is an anecdote.
# ref:DEC-mutate-native
SEED ?= 42

# | How many rules the driver runs at once.
JOBS ?= 8

# | The port the review page listens on.
PORT ?= 8080

# | The directory the pay page's files are served from.
PAGES ?= web/public

# | The directory the site is rendered into, and the roots whose pages it holds.
OUT ?= _site
ROOTS ?= . ../canon ../goforge/wavelet

.DEFAULT_GOAL := help
.PHONY: help build test mutate assess pay audit check tangle tangle-check site wasm gen clean

# | What you can ask for, read from the help lines of the rules below, so the list cannot drift.
help: ## what you can ask for
	@grep -hE '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*##/\t/' | awk -F'\t' '{ printf "  %-12s %s\n", $$1, $$2 }'

# | Build the library, the binary, and the corpus, with canon from the checkout beside this one.
build: ## build the library and the binary
	stack build --no-terminal --test --no-run-tests

# | Run the corpus, every rule of which cites the requirement that wants it. ref:DEC-own-tests-sydtest
test: ## run the corpus
	stack test --no-terminal

# | The whole mutation run of this project, natively: instrument, cover, mutate, and record the
# run with its seed, driver, toolchain, commit, and date. Afterwards, assess. ref:DEC-mutate-native
mutate: ## instrument, cover, mutate, and record the run
	SEED=$(SEED) JOBS=$(JOBS) ./tools/mutate.sh

# | Determine what is owed: write every missing row, record the run, report the totals.
assess: build ## determine what is owed
	$(BIN) assess

# | Serve the review page on PORT, from PAGES. ref:DEC-ui-frontend
pay: build ## serve the review page
	$(BIN) pay $(PORT) $(PAGES)

# | Prove the tax is paid: fail on open, stale, uncommitted, unrecorded, untangled, or expired
# rows. ref:DEC-audit
audit: build ## prove the tax is paid
	$(BIN) audit

# | Everything a pipeline runs: canon's check, the tangle check, the corpus, and the audit.
check: build ## canon check, tangle check, corpus, audit
	$(BIN) canon check
	$(BIN) canon tangle --check
	stack test --no-terminal
	$(BIN) audit

# | Write the sources the reference pages tangle to. ref:DEC-self-folio
tangle: build ## write src, app, and test from docs/reference
	$(BIN) canon tangle

# | Report the tangled sources that differ from their pages, without writing. ref:DEC-self-folio
tangle-check: build ## report stale tangled sources
	$(BIN) canon tangle --check

# | Render every root's pages to a static site under OUT, with the pay page over a snapshot.
# ref:DEC-site
site: build ## render the pages of ROOTS to OUT
	$(BIN) site $(OUT) $(ROOTS)

# | Build the WebAssembly halves and lay out the npm package, through the one script that calls
# cabal with the wasm compiler. ref:DEC-wasm-toolchain
wasm: ## build the wasm core, the page, and npm/
	stack build --no-terminal --exec tools/wasm.sh

# | Write the wasm entry module, its cabal file, and the Node wrappers from the export table.
# ref:DEC-npm-packaging
gen: build ## regenerate the wasm entry and the Node wrappers
	$(BIN) gen

# | Drop the working directories and the rendered site; the ledgers and the records stay.
clean: ## drop the mutation working directories and the site
	rm -rf .mut .drv $(OUT)
