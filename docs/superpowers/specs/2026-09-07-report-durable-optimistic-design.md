# Durable content reporting (#8053, #8822)

## Problem and acceptance boundary

Reporting previously waited for relay publication, support ticket creation,
and a private moderation message before showing confirmation. Slow or missing
connectivity held the report form open. A report must instead be accepted
when its complete delivery intent has been saved to the device.

The production service persists one `pending_reports` row containing the
reporter, unsigned kind-1984 event, target relays, redacted ticket fields, and
redacted private moderation message with recipient and tags. No signing,
relay response, ticket request, or DM preparation is awaited before acceptance.
A failed local write remains a visible error so the user can retry.

The confirmation says “Report saved” and explains automatic submission when
connected. Rapid repeated taps submit once, and closing the form does not own
or cancel delivery. Deliberate self-report refusals retain their silent behavior.
Legacy service callers without a DAO retain their explicit delivery outcomes;
the application provider always injects the durable DAO.

## Delivery

`ReportRetryService` runs on startup, foreground resume, network reconnection,
and a retry timer while the app is active. A new enqueue wakes the worker.
Retries use exponential backoff from two seconds to five minutes and remain
pending without a maximum attempt count. Reconnection forces another attempt.
Rows are filtered for readiness before applying the batch limit, so old failures
do not starve new reports.

The three channels run independently. Each attempt has a 30-second deadline
so one stalled destination cannot block later reports. The underlying request
stays coalesced until it settles, including after the worker's deadline.
Successful channels retire independently; the report row is removed only
when all requested destinations are done.

- **Relay:** sign the saved event when the owning account's signer is available,
  save the signature before publishing, and reuse that exact event on retries.
  Check account ownership again after signing and do not publish a row removed
  during an account wipe.
- **Support ticket:** check the expected reporter identity around initialization,
  token refresh, and native/REST fallback. Identity generations prevent an
  old token refresh from installing credentials after an account switch.
  Concurrent requests for a report share one in-flight operation.
- **Private moderation message:** enqueue through `DmRepository` using the saved
  report id and timestamp, then drive `recoverFullSend`. Identical replayed
  intent produces the same rumor id after a restart, including a crash between
  DM enqueue and report bookkeeping. Recovery uses NIP-17 without NIP-04 fallback.

Workers query only the active account's rows. Account removal also wipes its
pending reports. Payload redaction occurs before any queue write.

## Storage

Schema version 14 adds `pending_reports` after main's version-13 personal-event
migration. It has a report primary key, reporter, immutable payloads, creation
time, optional target relays, per-channel status and attempt count, and last
attempt/error fields. The raw legacy repair SQL matches Drift's fresh schema.
Generated snapshots cover version 14; migration tests preserve existing data.

`moderation_status` defaults to done when no moderation intent was requested.
The worker retains failed destinations as pending. The storage parser still
recognizes `deadLetter`, but the worker does not use an attempt budget to stop
retrying accepted reports.

## Delivery guarantees and limits

The local queue survives process restarts. Automatic sending runs while the app
is active and resumes when it reopens; this change does not add OS background
jobs or promise execution while the operating system suspends the app.

Relay event and moderation rumor ids are stable across retries. Support ticket
creation is at-least-once: its `external_id` is a correlation field, not an
upsert or uniqueness guarantee, and the native SDK does not accept it. A lost
response after successful ticket creation can therefore produce a duplicate
on retry. The report id is also in the ticket body for correlation. Exactly-once
ticket creation requires server-side idempotency beyond the current API.

The change preserves existing report contents, routing, signing protocols,
and ordinary DM sending behavior. It does not automatically merge or close
reports that moderators consider duplicates.
