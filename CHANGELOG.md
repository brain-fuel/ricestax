# Changelog for `rices-tax`

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added
- The founding model: an obligation is what a machine raised and cannot decide, with a kind, an identity, a subject, the digests it was judged against, a verdict from the kind's own words, an optional argument, and a sign-off read from git; `RicesTax.Model` states it in types
- Three review queues, Why, What, and How, with Who, When, and Where derived and raising nothing; mutation review is a subset of How
- The decisions ledger recording every founding choice, and six open decisions with a revisit version
- The Haskell dialect vendored from canon at commit f639753 so canon checks this project's own source
