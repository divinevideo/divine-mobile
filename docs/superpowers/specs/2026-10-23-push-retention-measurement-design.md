# Measuring the effect of push notifications

Date: 2026-10-23

Status: written design approved by Rabble's instruction to implement on
2026-10-23; implementation plan awaiting review. No production experiment,
collection, dashboard, or notification suppression is enabled by this document.

## Intent and success

Rabble asked whether newly introduced push notifications improve returning use
and engagement, then authorized the proposed sender/app/reporting work. Success
means an account-level randomized comparison of later foreground use and
meaningful actions, with reliable denominators, uncertainty, and trust guardrails.
Notification taps alone do not establish incremental returns.

The proposed primary outcome is a foreground return within seven days after the
first eligible notification opportunity. Supporting outcomes are a 24-hour
return, active days, meaningful actions, and observed notification opt-outs.
These metric choices require recording through the existing analytics decision
process; this document does not mark pending decisions approved.

## Current implementation and boundaries

- Mobile routes OS cold-start, local cold-start, OS background, and local taps
  through `mobile/lib/notifications/notification_tap_router.dart`.
  Wiring is in `mobile/lib/startup/startup_coordinator_factory.dart` and
  `mobile/lib/app/divine_app.dart`. Android data-only messages are rendered
  locally. iOS alerts are normally rendered by the OS.
- `mobile/lib/services/notification_helpers.dart` normalizes and reconstructs
  tap payloads. Measurement metadata must survive that reconstruction.
- `mobile/lib/services/analytics_service.dart` owns consent, identity rotation,
  the product queue, and separate release gates. Existing consumption events
  remain gated; a measurement feature must not bypass them.
- The local `divine-engagement` checkout has deterministic revision-level
  assignment in `src/experiments/holdout.ts`. Revisions deliberately reshuffle
  accounts. `src/campaigns/reporting.ts` reports assignments and send outcomes,
  not retention lift, and distinguishes provider acceptance from device display.
- The local `divine-push-service` checkout sends social notifications through
  `src/event_handler.rs` and `src/fcm_sender.rs`. These checkout observations
  establish extension points, not what is deployed in production.
- `divine-context/analytics/event-contract.yaml` is the schema authority. Its
  generated artifacts are pinned by consumer repositories. Server and client
  changes must use generated artifacts rather than hand-edit them.

## Approach selected

Extend the existing services; do not create a new analytics or experiment
platform. A before/after GA4 report can describe historical trends but is not
the causal comparison. Existing per-campaign holdouts remain useful for those
campaigns, but are not relabeled as an all-push experiment.

Use a separate account-level experiment, `push_retention_v1`, at the final
non-essential push decision boundary. Treatment receives normal eligible social
and campaign pushes; holdout receives none of those tested pushes. Security,
account-recovery, and other essential messages are excluded from both the test
and its eligibility trigger. Existing in-app notification lists are unchanged.

## Assignment, eligibility, and sending

1. Enroll only signed-in accounts with explicit applicable measurement consent,
   a supported measurement-capable client, and at least one operationally
   eligible push opportunity. New instrumentation does not change consent
   defaults. Legacy or unmeasurable clients continue existing behavior outside
   the experiment; never enroll only people who later open the app.
2. Evaluate consent, device registration, notification preferences, expiry,
   quiet hours, and caps identically before applying treatment versus holdout.
   Where a rule delays rather than rejects delivery, use the time it becomes
   sendable. Suppressed opportunities do not enroll an account.
3. Freeze experiment scope, salt, allocation, eligibility rules, and start/end
   dates in versioned configuration. Proposed pilot allocation is 50/50 for
   statistical efficiency. Activation requires a recorded launch decision.
4. Derive a stable bucket from a domain-separated keyed hash of the experiment
   version and canonical account identity. The server is authoritative. Devices,
   restarts, retries, and campaign edits cannot change the assignment. Allocation
   or scope changes start a new experiment version; they never rebucket it.
5. Persist one enrollment per account/version, including assignment and a
   server-authored `eligible_at`, before any experimental send. All devices of
   the account share it. Replayed source events do not advance that timestamp.
6. Both groups get the same enrollment record. Only treatment may proceed to
   send. A failed provider attempt remains in treatment for analysis.
7. Use a durable outbox for measurement export. If assignment/enrollment cannot
   be committed, do not make an experimental delivery decision: retry the
   opportunity within its existing expiry. Kill switches are independent of
   analytics export availability.

The experiment membership authority must be shared by every participating send
path. Campaign-specific holdouts still apply to treatment campaigns and are
recorded as part of the tested normal policy; a global holdout always wins.
Revalidate preferences and consent at delivery. Assignment does not override
delivery protections. Exclude other competing push experiments during enrollment.

## Identity, consent, and storage

The operational push services already need account identity to deliver messages.
Do not copy operational recipient tables into analytics. A protected server
integration with the existing identity authority exports only the versioned
`analytics_subject_id` derived by that authority, never raw pubkeys or FCM tokens.
Do not distribute the analytics HMAC secret to additional services or use a
campaign idempotency key containing an account identity as measurement metadata.

Subject derivation must use the same approved identity-key version as app ingest.
Partition analysis by that version; rotation ends the current observation cohort
rather than silently joining identities. The server integration needs explicit
service authentication, experiment allowlists, consent checks, and idempotency.
Its exact transport belongs in the implementation plan after the current deployed
ingest and push contracts have been verified.

Analytics-consent withdrawal stops experimental measurement, clears pending
client events, and removes the account from experimental delivery policy so
ordinary user preferences govern future pushes. Do not silently reinstate an
experiment on re-consent. Report withdrawal and other known observation loss by
arm using only approved retained aggregates. Do not interpret lost observation
as inactivity or claim complete population retention. Identity rotation and
account-switch boundaries apply to queued taps and session attribution too.

Use the existing 400-day product-event retention ceiling. Operational enrollment
and outbox records expire after experiment end plus a 30-day reconciliation
period unless a shorter existing policy applies. No indefinite tracking ledger.

## Events and mobile integration

Add approved typed client events to the canonical contract for
`notification_opened` and `app_foregrounded`. Define enrollment and provider
outcomes in a separate server-authoritative record contract: the current product
envelope is client-authored and must not be fabricated by a sender. Specify
server validation, storage, deduplication, and retention with that contract.

Each logical notification carries a random opaque `notification_id` and an
allowlisted `experiment_key`; campaign notifications additionally carry their
non-identifying revision ID. Notification type is a bounded enum. IDs are stable
across retries and devices for the same account/opportunity but never encode a
recipient, source Nostr event, token, message text, or route. Missing metadata on
older notifications preserves routing without generating invented attribution.

Client integration must:

- Preserve metadata through FCM parsing, local display payloads, and all four tap
  paths. Record once through a shared tracker invoked before navigation, so a
  routing failure does not erase a real tap. Record routing success separately
  only if needed for diagnostics; it is not the tap definition.
- Deduplicate opens by subject boundary and notification ID, across overlapping
  callbacks and process restarts. Use the existing durable queue, not an
  in-memory-only set. A retry must preserve the original event timestamp/ID.
- Emit foreground episodes on actual resumed UI transitions, including cold
  start. Repeated resumed callbacks within one episode do not create returns.
  Background handlers and notification receipt never emit foreground use.
- Include a random episode ID; clear or rotate it at account and consent
  boundaries. Startup/auth completion within an already active episode is not
  an additional return. Analytics errors cannot block routing or foreground use.
- Keep tap attribution independent of the primary outcome. A direct app open
  counts without a notification ID. No arbitrary last-touch attribution window
  is needed to calculate randomized lift.

Re-use playback, confirmed engagement, and publishing events only where their
existing collection and release gates permit them. Shares remain share intent,
not verified external sharing. Do not substitute feed loads or screen views for
videos watched. Do not add prohibited identity or free-text fields.

## Outcome definitions and reporting

Use first eligibility as time zero for both arms. A foreground episode already
in progress at that instant is excluded. All windows are elapsed UTC durations.

| Outcome | Definition |
| --- | --- |
| Seven-day return (primary) | At least one new foreground episode in `(eligible_at, eligible_at + 168 hours]` |
| 24-hour return | Same definition with a 24-hour endpoint |
| Active days | Number of distinct UTC dates with a qualifying new episode within the seven-day window |
| Meaningful actions | Confirmed reactions, comments, follows, and successful publishes in the window, separately by action and per assigned account |
| Viewing | Qualified playback and watch time under the existing playback semantics, per assigned account |
| Push opt-out | Observed enabled-to-disabled preference or permission transition after enrollment; report measurement coverage |

Active days are calendar dates and can span eight UTC dates in an elapsed
seven-day window; label the definition explicitly. OS permission changes are
observable only when the app checks them. No foreground observation is not proof
of an uninstall, permission revocation, or zero engagement.

Count enrolled accounts, including non-tappers and provider failures, in their
original arms. Analyze mature seven-day cohorts only after the window and
measured ingestion-latency allowance close. Show younger cohorts as pending.
Deduplicate before aggregation; attach late events to their occurrence window.
Reject impossible future timestamps and quarantine clock discrepancies rather
than assigning them to an outcome window silently.

Show arm sizes, outcome numerators and denominators, absolute percentage-point
lift, relative lift when the control rate is nonzero, and 95% uncertainty
intervals. Calculate binary-outcome differences with Newcombe intervals using
Wilson arm intervals. Other outcome uncertainties resample accounts, not events.
Do not pool people twice across devices or campaign revisions. Display consent
coverage, unsupported clients, known observation loss, and identity-key versions.

Freeze a sample-size target from an observed eligible baseline, minimum useful
absolute lift, 80% power, and two-sided 5% significance before launch. Freeze the
recruitment cutoff then wait seven days plus the verified ingestion allowance.
Weekly reports are descriptive; do not stop on the first favorable p-value.
If target enrollment is infeasible, mark the result inconclusive rather than
relabeling a before/after trend as experimental proof.

Interpretation and any business dashboard remain behind the consent,
dashboard-actionability, metric-trust, named identity-review, server-acceptance,
and release decisions in `divine-context/analytics/human-decisions.yaml`.
Technical QA may use synthetic accounts without enabling a business dashboard.

## Verification and rollout

The implementation plan must cover contract generation/conformance; sender
assignment and atomic enrollment; all participating send paths; client lifecycle,
payload and queue integration; ingest validation; and cohort aggregation.

Required regression cases include both arms at identical eligibility, retries
and simultaneous opportunities, multi-device accounts, old payloads, four tap
paths, duplicate callbacks after restart, denied/withdrawn consent, account
switch during startup, direct opens, already-foreground eligibility, background
receipt without a return, provider failure, missing client events, late events,
immature cohorts, identity-key rotation, and exact outcome-window boundaries.
Use full synthetic identities and deterministic clocks, never copied user data.

Roll out in order: accepted contracts and server storage; clients with collection
disabled; synthetic iOS/Android end-to-end checks; consented shadow enrollment
with unchanged notification delivery; then separately authorized treatment.
Shadow records are marked diagnostic and excluded from treatment analysis.
Existing delivery and measurement kill switches remain independent. Pausing a
test ends its valid exposure period; do not pool interrupted cohorts into an
uninterrupted seven-day estimate.

No production deployment, send suppression, expansion of consent, or disabling
existing analytics gates is part of design approval. Livestream and LiveKit
work is outside this task and remains on hold.

## Delivery boundaries

This is a coordinated cross-repository change: canonical schemas in
`divine-context`, assignment and campaign integration in `divine-engagement`,
social send enforcement and payloads in `divine-push-service`, client work in
`divine-mobile`, and server acceptance/analysis in `divine-funnelcake`.
Each repository gets its own branch and PR targeting main; generated-contract
pins advance only after the authoritative contract is published. Do not stack
PR bases or claim end-to-end completion from a mobile-only change.

This design is the current review artifact. Implementation planning follows
written-spec approval, with the exact server integration resolved from fresh
code and deployed API evidence before any implementation slice begins.
