# B2 rendition parity implementation plan

> Execute inline with superpowers:executing-plans; obtain a fresh whole-diff review before publication.

Goal: preserve normal rendition planning while routing eligible originals through the opt-in B2 host.

Architecture: resolve the existing canonical ladder first. Insert B2 immediately before eligible original entries, retaining canonical fallback. Derivatives remain canonical. Cache decisions follow the first planned source; prefetch stops before a B2 attempt so it cannot mask that attempt with original disk bytes. Both declared B2 hosts retain strict failure handling. A debug-only build define selects the QA host without stored preferences.

The task explicitly selects this transitional approach. Rewriting derivatives is excluded until server capabilities support them. Globally disabling disk caching would prevent parity for canonical derivatives.

- [x] Add regression tests for rendition/resolver order, original routing, canonical disk/prefetch behavior and both-host recognition; observe RED.
- [x] Implement source planning and selected-source cache decisions; preserve actual B2 denial/failover behavior.
- [x] Provide a private debug entry using an in-memory video and the real native player/source loader, with no app bootstrap, analytics opt-in, Nostr publication or preferences changes.
- [x] Run the package suite, analysis and relevant static guards; obtain independent fresh review.
- [ ] Commit, rebase on fresh origin/main, push, open a main-targeted PR, request mapped reviewers and inspect CI.

Review focus: signed/private URL context; derivative-before-original order; actual B2 404 versus explicit 503 failover; cache masking of actual B2 attempts; debug/release host isolation; QA disposal and absence of telemetry initialization.

Validation: 365 feed package tests; 377 player package Dart tests; 21 targeted app QA/localization tests. Scoped app and both package analyses passed. Both host-override variants passed. Style, test grouping and process-global/channel guards passed. Android JVM tests are delegated to CI because the shared disk was exhausted; no native application build, install or playback was attempted. The localization helper has an outdated debt-list parser; the authoritative ARB consistency test passed.
