# Durable, optimistic content reporting (#8053)

Design doc. Status: approved (decisions locked with the product owner 2026-09-07).

## Problem

Submitting a content report blocks the user behind three sequential network
round-trips before the confirmation shows:

1. kind-1984 (NIP-56) relay publish, OK-awaited
2. Zendesk ticket, awaited HTTPS POST
3. moderation DM (NIP-17 gift wrap), awaited

On a slow connection the Report button spins; on a bad one it spins and fails.
Reporting is a "get this away from me" action; the user wants to move on.

The wait is load-bearing today: of the three channels, only the moderation DM
is durable (`outgoing_dms` + `OutgoingDmRetryService`). The kind-1984 publish
and the Zendesk ticket are fire-and-forget, and `content_reporting_service.dart`
says so outright: local report history is never replayed, so a report that
reaches no channel is a dead letter. The blocking await is the only thing that
tells the user nothing got through. Making the flow fire-and-forget without
adding durability would turn a visible failure into a silent drop behind a
green checkmark, on a flow that carries child-safety reports.

## Goals

- Report submission feels instant: the confirmation shows after a
  sub-millisecond local write, not after the network.
- No report is silently dropped: the two currently-undurable channels
  (kind-1984, Zendesk) become durable with retry.
- The moderation DM keeps its existing durability; we do not rebuild it.
- No regression to #8214 (labeler load) or #6610 (duplicate-DM coalescing).

## Non-goals

- Surfacing delivery failure back to the reporter. Decision taken and endorsed:
  the confirmation is unconditional; the queue owns delivery; a report that
  exhausts retries is an ops signal (dead-letter + warning log), never a
  user-facing one.
- Persisting/replaying the moderation DM here (it already has its own outbox).
- Changing what a report contains or how it is built/signed, beyond signing
  timing and idempotency needed for retry.

## Decisions (locked)

1. **Two independent PRs, durability first**, so there is never a window where a
   report can silently drop:
   - **PR 1 — durability.** Add the `pending_reports` queue + `ReportRetryService`.
     `reportContent` enqueues the 1984 + Zendesk channels and drives them through
     the queue. UI behavior is unchanged: the first drive is awaited and its
     outcome reported exactly as today; failed channels stay queued and retry.
   - **PR 2 — optimistic UI.** Flip `_submitReport` to await only the enqueues,
     make the confirmation unconditional, remove `ReportDelivery.localOnly` /
     `notSent` / the DM-delayed notice, and add a public enqueue-only seam to
     `DmRepository`. Relies on PR 1's durability, so no silent-drop window.
2. **DM channel keeps its own outbox.** `pending_reports` covers only kind-1984
   and Zendesk. PR 2 adds `DmRepository.enqueueSend(...) -> rumorId` so the
   cubit can await only the enqueue and let `OutgoingDmRetryService` /
   `recoverFullSend` drive publish.
3. **Retry model:** foreground-driven sweep with per-row backoff (2s doubling to
   a 5-min clamp), mirroring `ViewEventRetryService`, **capped at 10 attempts
   per channel**, after which the channel is marked dead-letter with a warning
   log (report id + channel). Because retries fire on app-foreground, 10
   attempts span many sessions (hours to days of use), not seconds. The row is
   kept, not deleted, for post-hoc inspection.
4. **Zendesk idempotency:** ticket creation is keyed on the report id
   (`external_id`) so a retry updates rather than duplicates. If the Zendesk
   client does not support `external_id`, adding it is a PR 1 sub-task.

## Architecture

Two currently-inline channels move behind a durable queue. The per-channel
delivery logic is centralized in one place used by both the inline first drive
and the background sweep.

```
reportContent(...)
  guards (init/auth/self-report)             unchanged
  redact details/context (sanitizeDiagnosticText)  unchanged, BEFORE enqueue
  build + SIGN kind-1984 event once          (persist the signed event)
  enqueue PendingReport row {                sub-ms local write
    reportId (PK), signed 1984 event JSON,
    zendesk payload, per-channel status,
    userPubkey, createdAt }
  drive the row once, awaited  ─────────────▶ _driveReportChannels(row)
  compute ReportDelivery from the drive       (unchanged UI semantics in PR 1)
  save local history                          unchanged

ReportRetryService (foreground-driven sweep)
  getRetryableForUser → per-row backoff gate → _driveReportChannels(row)

_driveReportChannels(row)  (single source of truth for both callers)
  if 1984 pending:  publishEvent(signed event); on OK → mark relay done
  if zendesk pending: createTicket(external_id = reportId); on 2xx → mark done
  all channels done → deleteById
  a channel past 10 attempts → mark deadLetter + Log.warning
  else markFailed (increments attempt count)
```

### Data model: `pending_reports` (drift, schemaVersion 12 → 13)

One row per report; per-channel delivery tracked so channels retire
independently.

| column | type | notes |
|---|---|---|
| `report_id` | TEXT PK | matches `ContentReport.reportId`; Zendesk `external_id` |
| `user_pubkey` | TEXT NOT NULL | reporter; scopes sweeps and account wipe |
| `event_json` | TEXT NOT NULL | the signed kind-1984 event, republished as-is (stable id → idempotent) |
| `target_relays` | TEXT NULL | JSON list from `_targetRelaysForReport(sourceRelay)` |
| `zendesk_payload` | TEXT NOT NULL | JSON of the ticket fields (already redacted) |
| `relay_status` | TEXT NOT NULL | `pending`\|`done`\|`deadLetter` (throw-on-unknown parse) |
| `zendesk_status` | TEXT NOT NULL | `pending`\|`done`\|`deadLetter` |
| `relay_attempts` | INTEGER NOT NULL DEFAULT 0 | |
| `zendesk_attempts` | INTEGER NOT NULL DEFAULT 0 | |
| `last_error` | TEXT NULL | |
| `last_attempt_at` | DATETIME NULL | int-seconds codec, per the drift convention |
| `created_at` | DATETIME NOT NULL | sweep ordering |

Indexes: `(user_pubkey)` for sweep scoping; `(created_at)` for ordering.

Migration checklist (from the `pending_view_events` precedent, verified in
`app_database.dart`):
1. Table class in `tables.dart` with `@DataClassName('PendingReportRow')`.
2. Register table + DAO in `@DriftDatabase`.
3. Bump `schemaVersion` to 13.
4. `onUpgrade`: `if (from < 13) { await m.createTable(pendingReports); create indexes; }`.
5. Mirror the CREATE TABLE / CREATE INDEX in `_normalizeLegacyV1Schema()` behind a
   `sqlite_master` existence check; add to `legacyV1NormalizationRepairTables`,
   `_needsSchemaRepair`, `legacyV1NormalizationRepairIndexes`. Column
   order/types/defaults must match drift's `createAll` (schema-parity test).
6. `dart run build_runner build --delete-conflicting-outputs`.
7. Generate the drift schema snapshot under `drift_schemas/app_database` so the
   generated migration test passes.

### DAO: `PendingReportsDao`

Mirrors `PendingViewEventsDao`, per-channel aware:
`enqueue` (insertOrIgnore), `getRetryableForUser({userPubkey, limit})`
(any channel `pending`, ordered by `created_at`), `markChannelDone`,
`markChannelFailed` (increments attempts, sets last_error/last_attempt_at),
`markChannelDeadLetter`, `resetInFlightToPending(userPubkey)` (startup recovery),
`deleteById`, `deleteAllForUser` (account wipe), `getById`. Status parsed with a
throw-on-unknown helper so a corrupt/future status never coerces to `pending`.

### `ReportRetryService`

Plain service in `lib/services`, modeled on `ViewEventRetryService`:
foreground-stream-driven `initialize()` (calls `resetInFlightToPending` then
sweeps on each foreground), `sweep()` with `_isSweeping` re-entrancy guard,
per-row backoff (`ReportRetryConfig`: initial 2s, max 5min, x2,
`maxAttemptsPerChannel = 10`), `dispose()`. Success on a channel →
`markChannelDone`; all channels done → `deleteById`; attempts ≥ cap →
`markChannelDeadLetter` + `Log.warning`; else `markChannelFailed`. Wired via a
keepAlive Riverpod provider force-activated in `app_side_effects.dart` beside the
other durable-queue drivers.

### `_driveReportChannels(row)`

The single delivery routine used by both `reportContent`'s inline first drive
and the sweep. Publishes the stored signed 1984 event (stable id → safe to
republish) and posts the Zendesk ticket with `external_id = reportId` (idempotent
update, not duplicate). Returns per-channel outcomes so `reportContent` can
compute `ReportDelivery` in PR 1 exactly as today.

## PR 1 scope (this PR)

- `pending_reports` table + migration + DAO + generated code.
- `ReportRetryService` + provider + startup wiring.
- Refactor `reportContent` to sign-once, enqueue, and drive-once via
  `_driveReportChannels`; failed channels stay queued. **UI semantics
  unchanged** (`ReportDelivery.reached/localOnly/refused` still computed and
  returned from the first drive).
- Zendesk `external_id` idempotency (verify client support; add if missing).
- Tests: DAO (enqueue/retryable/mark*/reset), retry service (backoff gate,
  per-channel retirement, dead-letter at cap, foreground trigger), migration
  test, and characterization tests proving `reportContent`'s delivery outcomes
  are unchanged.

## PR 2 scope (follow-up)

- `DmRepository.enqueueSend(...) -> rumorId` enqueue-only seam.
- `_submitReport` awaits only the enqueues; unconditional confirmation.
- Remove `ReportDelivery.localOnly` / `notSent` / DM-delayed UI; rework the ~20
  pinned tests in `content_reporting_service_test.dart`,
  `report_submission_cubit_test.dart`, `report_content_dialog_test.dart`,
  `report_content_confirmation_test.dart`.
- Preserve #6610 duplicate-DM coalescing (its own test).

## Risks / watch-items

- **Schema-parity + migration tests** are strict; the normalization-SQL mirror
  must exactly match drift's `createAll`. Highest-friction part of PR 1.
- **Zendesk `external_id`**: if unsupported, retry could duplicate tickets;
  gate the sweep on idempotency landing.
- **Signing at enqueue** needs the signer available at submit; if it isn't, fall
  back to the current failure path rather than enqueuing an unsigned row.
- **Account switch / wipe**: `deleteAllForUser` must run on the same trigger the
  other per-user queues use, so one account's reports never sweep under another.
