# Push Engagement Measurement Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans in this session.

**Goal:** Attribute notification opens and subsequent existing engagement without
changing which notifications users receive.

**Architecture:** Add a shared tracker on the existing Firebase sink, wire the
existing shared tap router, and query GA4 exports for descriptive reporting.

**Tech Stack:** Dart/Flutter, existing Riverpod provider wiring, GA4 BigQuery SQL.

**Spec:** docs/superpowers/specs/2026-10-23-push-retention-measurement-design.md

## Global Constraints

- Measurement only: no holdouts, assignment, suppression, or sender changes.
- Existing consent and account boundaries apply; never await analytics to route.
- Export only allowlisted notification type and entry path as new parameters.
- Query installation/session identifiers internally; return aggregate rows only.
- Report descriptive trends and attribution, not causal lift or invented open rates.

## Review Focus

- Cold-start consent is still loading: wait for consent without delaying navigation.
- Multiple callbacks describe one tap: deduplicate locally using a delivery key.
- Session/account changes during consent initialization: drop stale attribution.
- Campaigns lack source event IDs: use transport IDs where present; otherwise state limitations.
- Engagement preceded the tap: include only events at/after the first tap timestamp.

### Task 1: Shared tracker and tap integration

- [ ] Add tracker tests for exported parameters, normalization, denied consent,
  overlapping callbacks, privacy changes, missing delivery keys, and sink failures.
- [ ] Watch the tests fail before implementing NotificationAnalyticsTracker.
- [ ] Add the tracker to mobile/packages/analytics, export it, and provide it
  through analytics_providers.dart using the existing sink and consent service.
- [ ] Preserve optional message IDs through normalized local notification payloads.
- [ ] Add router integration tests proving navigation continues while analytics
  waits, and that cold/warm paths identify their actual notification entry path.
- [ ] Run the package suite, affected notification/startup tests, and analysis.

### Task 2: GA4 report and closeout

- [ ] Write bounded SQL over the existing GA4 export; derive sessions from
  user_pseudo_id plus ga_session_id and compare post-tap event timestamps.
- [ ] Include active/returning-session trends and post-open engagement; document
  the exact definitions, maturity/coverage limits, and before/after interpretation.
- [ ] Run BigQuery dry-run and synthetic query checks if credentials permit.
- [ ] Review the diff for accidental delivery changes and identity leakage.
- [ ] Commit and push the focused change, open a PR targeting main, request normal
  review, and inspect completed required checks before handback.

## Execution ruling

Ruling: Rabble explicitly rejected the previous experimental design and confirmed
measurement only. Its cross-repository assignment, consent-protocol, suppression,
and experiment-analysis tasks are withdrawn. Existing Firebase measurement is the
bounded implementation path. Native execution continues without another planning
approval loop; the user's corrected scope is authoritative.
