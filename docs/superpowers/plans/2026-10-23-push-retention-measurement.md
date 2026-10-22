# Push Retention Measurement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for native execution, or superpowers:subagent-driven-development if that execution method is selected. Implement task-by-task; checkboxes track verified work.

**Goal:** Measure the additional foreground returns and meaningful activity caused by non-essential push notifications using a stable account-level holdout.

**Architecture:** Keep operational consent, enrollment, assignment, and an export outbox in the push service's Redis; both social and campaign delivery already converge on that service. Funnelcake authenticates a narrowly allowed service identity and derives the existing pseudonymous analytics subject without exporting its HMAC secret. Mobile adds governed foreground/tap events and syncs explicit measurement capability/consent; bounded cohort analysis compares all enrolled accounts.

**Tech Stack:** Flutter/Dart, Drift, Rust/Tokio/Axum, Redis Lua, existing NIP-44/NIP-98, Cloudflare Workers/TypeScript, ClickHouse, Python standard-library analysis tests.

**Spec:** `docs/superpowers/specs/2026-10-23-push-retention-measurement-design.md`.

## Global Constraints

- Experiment `push_retention_v1`; proposed pilot allocation 50/50, frozen before enrollment.
- Primary window `(eligible_at, eligible_at + 168 hours]`; supporting return window 24 hours; UTC calendar dates for active days.
- Existing 400-day product-event retention ceiling; operational records expire experiment end plus 30 days, or sooner where policy requires.
- Explicit measurement consent and supported clients only; no changed consent defaults or enabled production flags.
- Existing quiet hours, caps, preferences, expiry, and essential-message exemptions remain authoritative.
- No raw account identity, FCM token, notification text, or route in analytics storage; full synthetic identities in fixtures.
- Preserve identity/consent boundaries, existing release gates, and the livestream hold.
- Every repository change uses its own branch/worktree from fresh origin/main; PRs target main, with checks inspected and normal review routing.

## Review Focus

- Two send workers enroll one account concurrently: one enrollment and one immutable eligible_at (Task 4).
- Another registered device runs an older client: do not create a falsely complete account cohort (Task 3).
- Consent changes while a cold-start tap waits for authentication: discard the previous boundary's attribution (Task 7).
- An enqueue succeeds but acknowledgement is lost across restart: a duplicate callback cannot create a second logical open (Task 7).
- A send starts before experiment pause and finishes afterward: report the interrupted exposure period and do not claim an uninterrupted seven-day effect (Tasks 5 and 8).

## Source baseline and execution order

The mobile design worktree is based on `5a9eac06f795a329f2b192ee894d31e0a5c0a3ce`.
Fresh fetched sender main is `cf79a4a`; engagement main is `acef6d0`; Funnelcake
main is `8b381c14`. The shared checkouts are behind these refs and contain other
work; leave them alone and read/branch from the remote refs. Sender main includes
`src/campaign_delivery.rs`, which the earlier local checkout lacked.

Implement contracts, server acceptance, operational state, sender enforcement,
mobile transport, mobile tracking, and analysis in that order. Repositories need
separate PRs because their build and release boundaries differ; these are ordered
integration dependencies, not stacked PR bases. Publish authoritative generated
artifacts before advancing consumer pins. No partial slice is the full outcome.

### Task 1: Typed measurement contracts and shared fixtures

**Files:** in divine-context, modify `analytics/event-contract.yaml`,
`analytics/README.md`, and `analytics/codegen/tests/test_generate.py`; create
`analytics/push-measurement-contract.json` and `analytics/push-measurement-vectors.json`;
regenerate `analytics/generated/` through `analytics/codegen/generate.py` only.

**Interfaces:** client `notification_opened` has required UUID notification_id,
bounded notification_type, optional allowlisted experiment_key and UUID campaign_revision_id.
Client `app_foregrounded` has required UUID episode_id. Client
`notification_permission_changed` has previous/current states
`enabled|disabled|unknown`; emit only on an observed state change. All are signed-in,
product_analytics events with event_raw_400d retention. The separate server batch
has version 1 and up to 100 records: immutable record_id UUID, experiment_key,
consent_epoch UUID, operational recipient_pubkey, occurred_at UTC timestamp, and
type `enrolled | provider_accepted | provider_failed | observation_ended | notification_preference_changed`.
Enrollment adds variant and eligible_at; provider records add notification_id;
observation end adds bounded reason; preference changes add bounded notification
type and previous/current enabled booleans. Recipient identity is request-only and must
be removed before persistence. Server records do not invent client envelopes.

- [ ] Write generator/fixture tests asserting `notification_opened` rejects identity and free-text additions; malformed UUIDs fail; `app_foregrounded` is unavailable anonymously; server batches reject unknown record types and more than 100 records.

  Test assertions: `assert not validate(open_with_pubkey)`;
  `assert not validate(anonymous_foreground)`;
  `assert not validate_server(batch_of_101)`.
- [ ] Run `python3 -m unittest discover -s analytics/codegen/tests -p 'test_*.py'`; confirm the new expectations fail before adding the schema.
- [ ] Add the exact fields and fixtures above, including absent optional campaign metadata and a synthetic full-length recipient key in server transport fixtures only.
- [ ] Run the unit suite and `python3 analytics/codegen/generate.py --check`; confirm generated cross-language validators agree. Commit only canonical and generated changes together.

### Task 2: Server acceptance and pseudonymous export boundary

**Files:** in divine-funnelcake, create `crates/api/src/push_measurement.rs` and
`crates/clickhouse/src/push_measurement.rs`; modify `crates/api/src/product_analytics.rs`,
`crates/api/src/router.rs`, module exports and `analytics-contract.lock`;
create `tests/integration_push_measurement.rs` and a paired next-number migration
named `push_measurement_events` after verifying the migration allocator.

**Interfaces:** `POST /api/internal/analytics/push-measurement/events` accepts the
Task 1 server batch. Use existing NIP-98 body-hash/URL/timestamp verification,
then require its signer in the dedicated `PUSH_MEASUREMENT_SERVICE_PUBKEYS`
allowlist. Neither ordinary account auth nor campaign UI auth grants this role.
`PUSH_MEASUREMENT_ENABLED=false` by default. A successful response identifies
accepted immutable record IDs; retryable errors do not acknowledge them. Derive
the subject through the existing ProductAnalyticsConfig identity authority, not
through a new HMAC key in the sender. Store the identity-key version with every
record. Replays of identical IDs are harmless; different payloads for one ID are
rejected by canonical-payload digest verification.

- [ ] Add tests equivalent to `assert_eq!(ordinary_account_request.status(), 403)` and `assert!(persisted_json.get("recipient_pubkey").is_none())`; also cover bad body signatures, wrong URLs, stale signatures, disabled collection, duplicate/conflicting IDs, invalid epochs, and key-version changes.
- [ ] Run `cargo test -p funnelcake-api push_measurement`; confirm the handler/contract tests fail before implementation.
- [ ] Add bounded, service-authenticated ingest, reusing existing subject derivation in a focused internal helper. Enforce a 128 KiB body ceiling and the 100-record contract limit before row construction. Do not log request bodies or recipient identity.
- [ ] Add append-oriented enrollment/outcome storage with typed columns, experiment/date predicates, 400-day TTL, and explicit record-ID deduplication in reads; do not rely on background merges. Add optional notification/episode columns to product-event storage and update its known-event constraints/validators for the new generated client types.
- [ ] Run API tests, `cargo test -p funnelcake-clickhouse`, and the repository integration harness for `integration_push_measurement`. Apply and reverse migrations on a disposable database; inspect EXPLAIN and measure bounded cohort scans before publishing. Use the repository's query guardrails and independent-cost-review requirements; no production migration is authorized here.
- [ ] Commit and publish the server slice after checks. Consumer contract pins must identify the published Task 1 artifacts.

### Task 3: Explicit capability and consent at the operational boundary

**Files:** sender `src/crypto.rs`, `src/event_handler.rs`, `src/redis_store.rs`,
new `src/push_measurement/consent.rs`; mobile
`mobile/lib/services/push_notification_service.dart`,
`mobile/lib/services/push_notification_session_coordinator.dart`,
`mobile/lib/services/analytics_service.dart`, and corresponding service tests.

**Interfaces:** extend the existing encrypted registration/preferences JSON with
optional `measurement: {version: 1, enabled: bool, consentEpoch: UUID}`. Do not
introduce a Nostr kind/tag. Missing or unknown versions never imply consent.
`MeasurementConsentStore.apply(account, device, signed_created_at, event_id, state)`
is monotonic for the authenticated account/device; stale enables cannot undo a
newer withdrawal. Account-wide disabled consent prevents enrollment. A newer
explicit grant creates a new epoch but does not reenroll an account withdrawn
from this experiment. Existing push registration still succeeds without metadata.

- [ ] Write paired mobile/sender tests asserting `legacy_registration.measurement == None`, stale enabled updates cannot override disabled state, and account A metadata cannot affect account B. Test a mixed old/new-client account remains outside enrollment.

  Test assertions: `assert!(legacy.measurement.is_none())`;
  `assert!(!apply_stale_enable_after_withdrawal().enabled)`;
  `assert_eq!(mixed_client_decision, OutsideExperiment)`.
- [ ] Run `cargo test measurement_consent` and `mise exec -- flutter test test/services/push_notification_service_test.dart`; confirm new cases fail first.
- [ ] Sync explicit measurement state only when existing governed collection permits it. Persist withdrawal before clearing local state; retry the signed operational withdrawal without queueing usage events. On the sender require all currently registered devices to have supported capability for account-level enrollment; unknown devices exclude the account. This deliberately narrows the supported-client condition in the spec.
- [ ] Record observed notification-preference enabled-to-disabled changes independently of analytics-consent withdrawal, only while measurement consent permits collection. Test that the initial unknown preference is not reported as an opt-out. Run sender consent tests plus mobile registration/session-coordinator/analytics-consent suites. Verify metadata contains no measurement secret and leaves notification permission unchanged. Commit each repository's tested change.

### Task 4: Stable assignment, atomic enrollment, and durable outbox

**Files:** sender create `src/push_measurement/{mod.rs,assignment.rs,store.rs,outbox.rs}`
and Redis Lua scripts under `src/push_measurement/scripts/`; modify `src/config.rs`,
`src/state.rs`, `src/lib.rs`, `src/main.rs`, and `src/cleanup_service.rs`.

**Interfaces:** `decide(EligibleOpportunity) -> Result<MeasurementDecision>` returns
`OutsideExperiment | Shadow | Treatment(Enrollment) | Holdout(Enrollment)`.
Opportunity contains the operational account, a stable source-opportunity key,
notification type, eligible_at from the server clock, and verified consent state.
Config freezes experiment key, mode `off|shadow|treatment`, start/end, 5000 holdout
basis points, and an assignment-key version. HMAC-SHA256 uses a dedicated server
assignment secret and domain separation; enrollment preserves its initial bucket.
An atomic script creates account enrollment, opaque notification-ID mapping,
and measurement outbox records. Retries return the stored result. The identity
authority secret never enters this configuration.

- [ ] Write deterministic assignment vectors and tests asserting `first.eligible_at == retry.eligible_at`, concurrent attempts create exactly one enrollment, two devices share one variant, expired config cannot reenroll, and changing campaign revision does not rebucket an account.

  Test assertions: `assert_eq!(first.eligible_at, retry.eligible_at)`;
  `assert_eq!(concurrent_enrollments.len(), 1)`;
  `assert_eq!(device_a.variant, device_b.variant)`.
- [ ] Run `cargo test push_measurement`; confirm failing cases before implementation.
- [ ] Implement atomic enrollment/export records with cleanup at experiment end plus 30 days. Outbox request rows may contain operational identity until acknowledged, but analytics rows may not. Use the existing push-service signer for Task 2 NIP-98 calls and bounded retry/backoff; keep notification_id stable after export acknowledgement.
- [ ] Test acknowledgement loss, Redis unavailability, outbox retry, inconsistent duplicate payloads, withdrawal tombstones, and replay after operational expiry. Off mode must create no enrollment/outbox data; shadow cannot suppress sends. Run `cargo test push_measurement` and `cargo clippy --all-targets --all-features`; commit.

### Task 5: Enforce one experiment at both sender decision points

**Files:** sender `src/event_handler.rs`, `src/campaign_delivery.rs`,
`src/fcm_sender.rs`, `src/models.rs`, and sender tests;
engagement `src/push/deliveries.ts`, `src/campaigns/reporting.ts`, and delivery tests.

**Interfaces:** both sender paths call Task 4 after existing per-account/device
eligibility and before FCM. The decision emits bounded outcomes and adds opaque
`notificationId`, `experimentKey`, and optional `campaignRevisionId` to data
payloads. A holdout produces no FCM call and reports a distinct `experiment_holdout`
campaign result; it is not provider failure or confirmed delivery.

- [ ] Write tests asserting `holdout.fcm_calls == 0`, provider-failed treatment remains enrolled, ineligible/quiet-hour accounts have no eligible_at, source retries reuse notification_id, and global holdout wins over campaign treatment.

  Test assertions: `assert_eq!(holdout.fcm_calls, 0)`;
  `assert_eq!(failed_provider.enrollment.variant, Treatment)`;
  `assert!(quiet_hours.enrollment.is_none())`.
- [ ] Run sender campaign/social tests and engagement `npm test`; confirm new behavior fails before implementing it.
- [ ] Wire shared enforcement, keeping the existing claim/expiry/cap semantics. Use post-policy coalesced opportunities, not each raw source event. Explicitly exempt essential security/recovery messages; enumerate eligible notification types from current sender code, including direct-message classification without recording message contents.
- [ ] Add the new campaign result to validation and reports without relabeling the existing provider-accepted result as device display. Verify pause races preserve a recorded exposure-end boundary. Run `cargo test`, `cargo clippy --all-targets --all-features`, `npm run check`, `npm run lint`, `npm run format:check`, and `npm run build` in their respective worktrees; commit tested changes.

### Task 6: Carry typed metadata through every mobile payload path

**Files:** mobile `mobile/lib/services/notification_helpers.dart`,
`mobile/lib/services/notification_service.dart`,
`mobile/lib/notifications/notification_tap_router.dart`,
`mobile/lib/startup/startup_coordinator_factory.dart`,
`mobile/lib/app/divine_app.dart`, generated contract pin/artifact, and existing
helper/router/service tests.

**Interfaces:** `NotificationMeasurementMetadata` validates notificationId UUID,
allowlisted experimentKey, bounded notification type, and optional campaign UUID.
Pass it as a typed optional argument to `NotificationTapEvent` and
`routeNotificationTap`; use null for legacy/malformed measurement metadata while
preserving existing routing fields and behavior.

- [ ] Write round-trip tests asserting `parse(localNotificationTapPayload(data)).measurement == original`, malformed metadata cannot break a valid route, and each of the four OS/local cold/warm tap paths forwards identical metadata.

  Test assertions: `expect(roundTripped.measurement, original)`;
  `expect(routeWithMalformedMetadata.target, originalRoute)`;
  `expect(allFourPaths.map((tap) => tap.measurement).toSet(), {original})`.
- [ ] Run helper/router/startup tests and confirm new metadata assertions fail first.
- [ ] Implement the shared parser and forwarding, without adding logging of payload bodies. Vendor the published Task 1 generated artifact with its exact lockfile checksums.
- [ ] Run `mise exec -- flutter test test/services/notification_helpers_test.dart test/notifications/notification_tap_router_test.dart test/features/app/startup/startup_coordinator_test.dart`; commit after pass.

### Task 7: Durable opens and actual foreground episodes

**Files:** mobile create `mobile/lib/features/push_measurement/push_measurement_tracker.dart`
and `mobile/test/features/push_measurement/push_measurement_tracker_test.dart`;
modify `mobile/lib/services/analytics_service.dart`,
`mobile/lib/services/product_event_queue.dart`, analytics provider wiring,
`mobile/packages/db_client/lib/src/database/daos/pending_product_events_dao.dart`,
database schema/exports and migration tests, and the Task 6 router call site.

**Interfaces:** `PushMeasurementTracker.notificationOpened(metadata)` and
`foregroundChanged({required bool resumed})` record through AnalyticsService.
Add `recordNotificationOpened({required NotificationMeasurementMetadata metadata}) -> Future<String?>` and
`recordAppForegrounded({required String episodeId}) -> Future<String?>`.
Durable open deduplication and enqueue share one Drift transaction, keyed by
privacy boundary and notification ID. Receipts survive successful queue deletion
and process restart for 30 days; clear them on consent/account boundaries.
Foreground episodes emit once on initial resumed UI or a real background/resume
transition. Completing authentication during an episode cannot create a return.

- [ ] Write tests asserting two callbacks across restart enqueue one open, consent-off enqueues none, account-switch drops an awaiting tap, direct resumes create a foreground event without notification ID, and background FCM processing creates no foreground event.

  Test assertions: `expect(opensAfterRestart.length, 1)`;
  `expect(eventsWithConsentOff, isEmpty)`;
  `expect(backgroundReceipt.foregroundEvents, isEmpty)`.
- [ ] Run the new tracker and DAO tests; confirm they fail first.
- [ ] Implement the tracker with constructor injection, using explicit lifecycle state and the existing analytics release gate plus a new default-off push-measurement gate. Never wait for analytics before navigating. Preserve original event timestamp/ID across queue retries and count a failed route as a tap.
- [ ] Observe OS permission state through NotificationService on foreground. Record `notification_permission_changed` only with measurement consent; distinguish known enabled-to-disabled transitions from first observations of denied/unknown permission. Test that no foreground callback means permission state is unknown, not an inferred opt-out.
- [ ] Test cold-start initial foreground, repeated resumed callbacks, rapid consent withdrawal/restoration, account switch while storage awaits, DB migration from the previous version, and queue acknowledgement loss. Generate Drift code through the repository command; run tracker, DAO, consent, queue, and migration tests plus `mise exec -- flutter analyze lib test integration_test`; commit.

### Task 8: Bounded cohort analysis and uncertainty

**Files:** in divine-context create `analytics/push/{cohorts.sql,report.py,README.md}`
and `analytics/push/tests/test_report.py`; server add corresponding bounded query
fixtures and extend `scripts/measure_product_analytics_queries.sh`.

**Interfaces:** `build_report(accounts, outcomes, as_of, ingestion_allowance) -> Report`
consumes only pseudonymous subject/key-version/epoch records and deduplicated
events. Return explicit `pending|diagnostic|incomplete|mature` cohort states,
arm denominators/numerators, percentage-point lift, zero-safe relative lift,
Wilson/Newcombe 95% binary intervals, and account-bootstrap secondary intervals.
Require a frozen experiment manifest specifying recruitment cutoff, observed
baseline, minimum useful absolute lift, 80% power, 5% two-sided significance,
sample target, and measured ingestion allowance before a treatment report.

- [ ] Add synthetic tests asserting `20/100 - 16/100 == 0.04` within numeric tolerance, exact 24/168-hour endpoints count, preexisting foreground episodes do not count, and zero-return holdouts do not divide by zero.

  Test assertions: `self.assertAlmostEqual(report.absolute_lift, 0.04)`;
  `self.assertEqual(at_168_hours.returned, True)`;
  `self.assertIsNone(zero_control.relative_lift)`.
- [ ] Run `python3 -m unittest discover -s analytics/push/tests -p 'test_*.py'`; confirm failure before implementing the report.
- [ ] Implement UTC windows and per-account analysis, including all assigned non-tappers and provider failures. Report observation loss by arm; do not silently equate known loss with inactivity. Exclude shadow and interrupted exposure cohorts from valid treatment estimates and never join identity-key versions. Bound both sides of every ClickHouse scan by received_date and experiment window, then aggregate before joining; no unbounded browser-triggered query. Show actions whose collection is gated as unavailable, never zero. The canonical contract currently has no successful-publish event; mark publishing unavailable unless a separately accepted governed event is present, without joining raw public identities to analytics.
- [ ] Test young cohorts, delayed events, duplicates, mixed identity versions, unknown permissions/uninstall, eight-calendar-date active windows, small samples, paused tests, and missing required action collection. Compare confidence-interval fixtures against independently calculated references; bootstrap with a fixed synthetic-test seed only. Measure EXPLAIN/read rows/bytes/memory/runtime and cold independent query-cost review before publishing SQL changes.
- [ ] Commit the analysis with a clear untrusted status while registry decisions remain pending; do not build/enable a business dashboard under this task's code authorization.

### Task 9: Synthetic end-to-end verification and delivery

**Files:** extend existing mobile integration tests, sender integration tests,
server synthetic fixtures, and the experiment README with verified commands and
release evidence; no production infrastructure edits.

**Interfaces:** a local synthetic harness registers capable accounts, creates one
eligible opportunity per arm, exports enrollment, simulates direct foreground
returns plus notification opens, and computes the expected report.

- [ ] Add an end-to-end assertion that a non-tapping treatment account returning directly contributes to return lift, while holdout has an enrollment but no provider call.

  Test assertions: `assert report.treatment.returned == 1`;
  `assert direct_return.notification_opens == 0`;
  `assert holdout.provider_calls == 0`.
- [ ] Run iOS and Android cold/background/foreground tap paths; verify one open, correct route, and zero background-only returns. Repeat consent-off, account-switch, mixed-client, retry, and provider-failure cases; inspect stored rows for prohibited fields.
- [ ] Run affected suites and repository checks in each worktree. Rebase new branches onto fresh origin/main, rerun relevant validation, push, open main-targeting PRs, request normal reviewers once, and watch/inspect required CI. Obtain independent review according to the shared policy; do not merge or deploy without applicable authority.
- [ ] Hand back an integration matrix showing merged/accepted contracts, server/client versions, each gate's state, CI evidence, and any incomplete device checks. Code completion is not experiment launch: consent/legal/identity, metric actionability/trust, sample target, and production activation remain separately recorded decisions. Do not claim a retention improvement from synthetic verification.

## Plan self-review and execution selection

Each spec section maps to Tasks 1–9; the five review-focus conditions have named
tests above. The sender is the single membership authority, the server derives
analytics identity, and transport metadata never doubles as an account key.
No existing collection/release gates are changed by plan approval.

Recommended execution is native in this session because sender, schema, and
client interfaces are tightly coupled. Required independent review still occurs
before integration. Implementation begins after plan review and execution-method
selection, as required by the writing-plans skill.
