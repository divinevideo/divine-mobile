# User experience performance monitoring implementation plan

> **For Claude:** Use `${SUPERPOWERS_SKILLS_ROOT}/skills/collaboration/executing-plans/SKILL.md` to implement this plan task-by-task.

**Goal:** Make slow or unsuccessful user operations distinguishable by operation, phase, outcome, and app release.

**Architecture:** Extend the existing injected Firebase trace interfaces and HTTP decorator. Record bounded operation names and outcomes, never user identifiers, URLs containing identifiers, credentials, or response bodies. Add matching structured phase measurements to the moderation service without changing deletion behavior. Reuse existing feed, upload, publish, camera, and startup measurements where available.

**Tech Stack:** Flutter/Dart, Firebase Performance, BigQuery SQL, Cloudflare Workers, Vitest.

## Task 1: Server deletion phase measurements

Work in the moderation-service worktree on `feat/delete-performance-monitoring`.

Files: `src/creator-delete/sync-endpoint.mjs`, `funnelcake-fetch.mjs`, `src/nostr/relay-client.mjs`, their tests, and a monitoring runbook.

1. Run the existing focused tests before changing behavior.
2. Add regression tests for retry attempt counts, phase durations, found/missing/transient/invalid outcomes, and telemetry failure isolation.
3. Instrument deletion lookup retries and handler stages using bounded structured events. Include elapsed time, attempts, outcome, and upstream status where observed. Preserve existing HTTP responses, retry schedule, authentication, and deletion policy. Do not add identities or payloads to new telemetry.
4. Run focused tests and `npm run lint`; document the event contract and operator queries.
5. Commit the implementation and request independent review before publication.

## Task 2: Mobile network and deletion operations

Files: `mobile/lib/observability/network/*`, `mobile/lib/repositories/creator_delete_enforcement_repository.dart`, provider wiring, and corresponding tests.

1. Establish a passing focused baseline using the repository Flutter SDK.
2. Test bounded endpoint labels, independent concurrent spans, HTTP errors, transport/body failures, cancellation, and absence of identifying attributes.
3. Extend HTTP monitoring with operation-specific custom traces so Firebase's URL aggregation cannot hide different routes. Use a finite operation classification and record first-byte and transfer timing, status, method, and completion outcome. Preserve ordinary HttpMetric recording and third-party exclusions.
4. Add one deletion-confirmation trace per operation, covering signing, POST, polling, and terminal result. Keep signing and request budgets unchanged and telemetry off the awaited user path.
5. Run affected tests and static analysis, then commit.

## Task 3: Visible playback and startup measurements

Files: app-layer performance observer/provider, `mobile/lib/startup/app_side_effects.dart`, startup monitoring service/provider where required, and tests.

1. Audit existing first-frame, startup, feed, upload, publish, and camera instrumentation against actual lifecycle wiring.
2. Export existing first-frame phase durations into bounded Firebase custom metrics without transmitting video identifiers. Clearly distinguish measured duration metrics from the short reporting trace's own duration.
3. Connect useful existing startup phase/milestone measurements to Firebase, preserving early-start measurements and avoiding duplicate subscriptions or traces.
4. Test subscription disposal, metric units, repeat/concurrent operations, and monitoring-disabled behavior.
5. Run focused tests and commit.

## Task 4: Operator reports and verification

Files: `mobile/docs/NETWORK_PERFORMANCE_MONITORING.md`, a focused UX monitoring runbook, and parameterized SQL under `scripts/`.

1. Document each UX boundary, where its data lives, failure denominators, and known limits. Include feed, search/profile, login/signing, playback, upload, publish, and deletion.
2. Provide partition-bounded BigQuery reports for route/method/status, custom phase metrics, build comparisons, sample counts, failure rates, and export freshness. Validate SQL with dry runs against the existing export.
3. Document exact Firebase custom URL patterns and alert setup; verify any live configuration changes before claiming them active.
4. Independently review the code and resolve material findings. Run affected tests, required analysis, and relevant CI.
5. Fetch/rebase, push each independent repository branch, open Conventional Commit pull requests, request `divinevideo/reviewers`, and report release/deployment requirements. No automatic merge or release.
