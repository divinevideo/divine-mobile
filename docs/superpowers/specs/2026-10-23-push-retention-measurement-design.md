# Push notification engagement measurement

Date: 2026-10-23

Status: measurement-only scope explicitly confirmed by Rabble. This replaces
this document's earlier experiment proposal, which expanded the requested task.

## Outcome

Show how many consented app sessions begin with a notification tap, what people
do afterward, and how returning use changes over time. No experiment assignment,
holdouts, send suppression, or notification preference changes are part of this
work. Existing notification delivery and existing analytics consent remain intact.

## Design

Add a shared NotificationAnalyticsTracker in the existing analytics package. It
records push_notification_opened through the existing Firebase event sink with
only bounded notification_type and open_source parameters. Source event IDs
may be used locally to deduplicate overlapping callbacks; never export them,
notification text, routes, tokens, or actor identities as new event parameters.

Wire the shared push tap router, reached by OS/local cold-start and warm taps.
Receipt and background processing are not opens. Navigation never awaits
analytics. Await the existing analytics consent initialization before recording,
and discard pending attribution if its account/session boundary changes.
Firebase's existing collection control remains authoritative. Failures are
best effort and cannot prevent notification navigation.

Preserve an optional transport message ID through local payloads to deduplicate
callbacks when available. Prefer it to the source event ID. Old campaigns
without either identifier remain measurable, with duplicate limitations stated.
Deduplication is bounded and session-scoped; it is not a claim of durable
cross-install exactly-once delivery.

Provide a BigQuery report over the existing GA4 export. Use installation-scoped
user_pseudo_id plus ga_session_id, never a new raw-account identity join. Report
by UTC day and platform: sessions, returning sessions, notification opens,
sessions with a notification open, and engagement observed after the first open
in each session. Count existing publish_succeeded events and GA4 engagement time. Playback,
comment, and follow metrics are unavailable in this Firebase path; do not treat
feed loads or screen views as video views.
Report GA4 engagement time separately from wall-clock duration.

Provide daily return-use trends for before/after rollout comparisons. Label
association and attribution explicitly: a session with a notification tap is
not proof of an incremental return caused by notifications. Do not calculate
an open rate without verified compatible send denominators. Use existing sender
operational metrics/Firebase reporting for sends; this change does not modify
the sender or promise cross-platform device-delivery coverage.

## Verification and delivery

Test bounded parameter normalization, explicit consent denial, concurrent tap
deduplication, privacy changes during async initialization, sink failure, payload
round trips, and actual routing while analytics remains pending. Validate the
report SQL with BigQuery dry-run where credentials allow, and report a blocked
validation honestly. Run the analytics package suite, affected app tests, and
Flutter analysis. Commit, push, open a main-targeting PR, inspect checks, and
request normal review. Production analytics defaults and first-party consumption
release gates are not changed.
