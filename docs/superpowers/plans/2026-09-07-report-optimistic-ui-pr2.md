# Report optimistic UI (#8053 PR 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make content-report submission instant — persist the intent, show the confirmation immediately, and let the durable queue (landed in PR 1) drive all three channels — without ever silently dropping a report.

**Architecture:** PR 1 added the `pending_reports` durable queue + `ReportRetryService` and routed the kind-1984 and Zendesk channels through it (delivery outcome unchanged). PR 2 flips the UI to optimistic: split an enqueue-only seam out of `DmRepository.sendMessage` so the moderation DM is awaited only to its durable `outgoing_dms` enqueue, have `reportContent` enqueue-and-return instead of awaiting the inline drive, make the confirmation unconditional, and remove the now-dead `ReportDelivery.localOnly` / `notSent` / DM-delayed UI.

**Tech Stack:** Flutter/Dart, drift, Riverpod, mocktail, dm_repository (NIP-17), nostr_sdk.

**Spec:** `docs/superpowers/specs/2026-09-07-report-durable-optimistic-design.md`

**Depends on:** PR 1 (`fix/8053-report-optimistic-durable`, #8822). This branch is cut from PR 1; do NOT mark ready until PR 1 merges, then rebase onto `main` (which will contain PR 1) so the diff is PR-2-only.

## Global Constraints

- Preserve #6610 duplicate-DM coalescing: a repeat submit must re-drive the same parked `outgoing_dms` row via `recoverFullSend`, never mint a second rumor.
- Preserve the #8352 self-report refusal: a self-report stays a silent no-op, never enqueued and never DM'd.
- No secret persisted: redaction (`sanitizeDiagnosticText`) stays before any enqueue (already true from PR 1).
- Confirmation becomes unconditional (product decision, endorsed): a report that fails every channel is never surfaced to the reporter; the queue owns delivery.
- divine-mobile CI ratchets: every test inside a `group`; no new `Future.delayed` in tests (use `pumpEventQueue`/fake async); run `dart run build_runner build` and commit generated files; `flutter analyze` clean project-wide.

---

## File Structure

- `mobile/packages/dm_repository/lib/src/dm_repository.dart` — extract `_prepareAndEnqueueRumor`; add public `enqueueSend`. Behemoth file; do not restructure beyond this seam.
- `mobile/packages/models/lib/src/enqueue_send_result.dart` (create) — `EnqueueSendResult` result type; export from `models`.
- `mobile/lib/blocs/report/report_submission_cubit.dart` — optimistic submit; drive DM via `enqueueSend` + unawaited `recoverFullSend`; drop `notSent` and `moderationDmFailed`.
- `mobile/lib/services/content_reporting_service.dart` — add an enqueue-and-return path (no inline await of delivery); remove `ReportDelivery.localOnly` and the reached/localOnly computation.
- `mobile/lib/widgets/report_content_dialog.dart` + `report_confirmation_body.dart` — unconditional confirmation; delete the "reached no channel" suppression and the DM-delayed caveat.
- Tests: `dm_repository` send tests; `report_submission_cubit_test.dart`; `report_content_dialog_test.dart`; `report_content_confirmation_test.dart`; `content_reporting_service_test.dart`.

---

### Task 1: `DmRepository.enqueueSend` enqueue-only seam

**Files:**
- Modify: `mobile/packages/dm_repository/lib/src/dm_repository.dart` (`sendMessage` ~:4521-4637; add `enqueueSend` + private `_prepareAndEnqueueRumor`)
- Create: `mobile/packages/models/lib/src/enqueue_send_result.dart`
- Modify: `mobile/packages/models/lib/models.dart` (export the new type)
- Test: `mobile/packages/dm_repository/test/src/dm_repository_send_test.dart` (or the existing send test file)

**Interfaces:**
- Produces: `EnqueueSendResult` — `{ String? queuedRumorId, bool refused, bool blocked, bool tooLong, String? error }` with `bool get accepted => queuedRumorId != null`.
- Produces: `Future<EnqueueSendResult> DmRepository.enqueueSend({required String recipientPubkey, required String content, String? replyToId, List<List<String>> additionalTags})` — runs the guards (init/self-send/send-gate), builds the rumor (with the `#7326` sendBatchId), refuses oversize, enqueues the `outgoing_dms` row, and returns the `rumor.id` as `queuedRumorId`. Does NOT publish.
- Consumes (unchanged): `recoverFullSend(rumorId:)` drives the parked row to publish afterward.

- [ ] **Step 1: Write the failing test** — enqueueSend parks a row and does not publish.

```dart
test('enqueueSend enqueues a pending row and returns its rumor id without '
    'publishing', () async {
  final result = await repo.enqueueSend(
    recipientPubkey: _peer,
    content: 'report dm',
  );
  expect(result.accepted, isTrue);
  final row = await outgoingDmsDao.getById(result.queuedRumorId!);
  expect(row, isNotNull);
  expect(row!.recipientWrapStatus, OutgoingWrapStatus.pending);
  verifyNever(() => mockNip17MessageService.sendRumor(any()));
});
```

- [ ] **Step 2: Run test to verify it fails** — `flutter test .../dm_repository_send_test.dart -n "enqueueSend enqueues"` → FAIL (no `enqueueSend`).

- [ ] **Step 3: Extract `_prepareAndEnqueueRumor`** — move `sendMessage`'s guards → send-gate → `sendBatchId`/`rumor` build → `_refuseIfOversized` → `outgoingDao.enqueue` block into a private method returning a record `({NIP17SendResult? refusal, Event? rumor, String? conversationId, String? sendBatchId, List<List<String>> rumorTags, List<String> participants})`. `sendMessage` calls it, returns `refusal` if set, else continues its existing publish/persist block using the returned `rumor`/`conversationId`/`rumorTags`/`participants`/`sendBatchId`. **Behavior-preserving** — no logic change, only extraction. Keep every invariant comment with its code.

- [ ] **Step 4: Add `enqueueSend`** — call `_prepareAndEnqueueRumor`; map `refusal` (self-send→refused, blocked→blocked, tooLong→tooLong) onto `EnqueueSendResult`, else return `EnqueueSendResult(queuedRumorId: rumor.id)`.

- [ ] **Step 5: Run the new test + the FULL dm_repository suite** — `flutter test packages/dm_repository/test` → all PASS. The existing `sendMessage` tests are the regression guard for the extraction; they must stay green unchanged.

- [ ] **Step 6: Commit** — `feat(dm): add enqueueSend seam (enqueue without publish) for #8053`.

---

### Task 2: Optimistic moderation-DM dispatch in the cubit

**Files:**
- Modify: `mobile/lib/blocs/report/report_submission_cubit.dart` (`_dispatchModerationDm` ~:492-590)
- Test: `mobile/test/blocs/report/report_submission_cubit_test.dart`

**Interfaces:**
- Consumes: `DmRepository.enqueueSend` (Task 1), `recoverFullSend(rumorId:)`.

- [ ] **Step 1: Write the failing test** — submit awaits only the enqueue; publish is not awaited before the confirmed state.

```dart
test('submit confirms after the DM is enqueued, not after it publishes',
    () async {
  when(() => dmRepo.enqueueSend(...)).thenAnswer(
    (_) async => const EnqueueSendResult(queuedRumorId: 'rumor1'));
  final completer = Completer<NIP17SendResult>();
  when(() => dmRepo.recoverFullSend(rumorId: 'rumor1'))
      .thenAnswer((_) => completer.future); // never completes in-test
  await cubit.submit(reason: ..., reasonTitle: ..., details: 'x');
  expect(cubit.state.status, ReportSubmissionStatus.submitted);
  verify(() => dmRepo.enqueueSend(...)).called(1);
});
```

- [ ] **Step 2: Run test to verify it fails** — the current code awaits `sendMessage`, so it will not reach `submitted` without the publish resolving.

- [ ] **Step 3: Rewrite `_dispatchModerationDm`** — first submit: `final r = await dmRepo.enqueueSend(...)`; if `r.refused`/`blocked`/`tooLong`, handle as today (no DM); else store `r.queuedRumorId` in `ModerationDmProgress` and `unawaited(dmRepo.recoverFullSend(rumorId: r.queuedRumorId!))`. Repeat submit (coalesce, #6610): if a `queuedRumorId` is already parked, `unawaited(recoverFullSend(rumorId: parked))` — never a second `enqueueSend`.

- [ ] **Step 4: Run the cubit suite** — `flutter test test/blocs/report/report_submission_cubit_test.dart`. Rework the 5 pinned tests (`:225`, `:303`, `:342`, `:380`, `:525`) to the enqueue+recover shape; the coalescing test (`:380`, `:525`) must still prove one rumor per report.

- [ ] **Step 5: Commit** — `feat(report): enqueue the moderation DM and confirm optimistically (#8053)`.

---

### Task 3: `reportContent` enqueue-and-return; remove `localOnly`

**Files:**
- Modify: `mobile/lib/services/content_reporting_service.dart` (`reportContent` inline-drive block; `ReportDelivery` enum ~:24)
- Test: `mobile/test/services/content_reporting_service_test.dart`

**Interfaces:**
- Produces: `reportContent` returns `ReportResult` with `delivery` in `{reached (=queued), refused}` only; `localOnly` is removed.

- [ ] **Step 1: Write the failing test** — with a wired DAO, `reportContent` enqueues and returns without awaiting relay/Zendesk delivery.

```dart
test('reportContent returns after enqueue without awaiting the channels',
    () async {
  final publishCompleter = Completer<PublishResult>();
  when(() => nostr.publishEvent(any(), targetRelays: any(named: 'targetRelays')))
      .thenAnswer((_) => publishCompleter.future); // never completes
  final result = await service.reportContent(...);
  expect(result.success, isTrue);
  expect(await dao.getById(result.reportId!), isNotNull); // parked, undelivered
});
```

- [ ] **Step 2: Run test to verify it fails** — current `reportContent` awaits `_publishReportEvent`, so it hangs on the never-completing publish.

- [ ] **Step 3: Change the queue path** — when the DAO is wired: enqueue, then `unawaited(_driveReportChannelsOnce(reportId))` (a helper that drives relay+zendesk once via the existing `deliverReportChannel` and records outcomes best-effort), and return `createSuccess(reportId, delivery: reached)` immediately. Delete the reached/localOnly computation and the `ReportDelivery.localOnly` enum value; update `ReportResult.failure` to use a non-localOnly default (introduce `queued` or reuse `reached`). Null-DAO path (legacy callers/tests) keeps the old inline behavior guarded behind the null check.

- [ ] **Step 4: Run the content-reporting suite** — rework `content_reporting_service_test.dart` delivery assertions (`:839`, `:883`, `:920`) that reference `localOnly`/`reached` to the new queued semantics.

- [ ] **Step 5: Commit** — `feat(report): make reportContent enqueue-and-return, drop localOnly (#8053)`.

---

### Task 4: Unconditional confirmation UI; remove DM-delayed / no-channel

**Files:**
- Modify: `mobile/lib/blocs/report/report_submission_cubit.dart` (`ReportSubmissionState.moderationDmFailed`, `notSent` status)
- Modify: `mobile/lib/widgets/report_content_dialog.dart` (`_submitReport` ~:423-468; `_ConfirmationBody`)
- Modify: `mobile/lib/widgets/report_confirmation_body.dart` (or wherever `reportModerationDmDelayed` renders)
- Test: `mobile/test/widgets/report_content_dialog_test.dart`, `report_content_confirmation_test.dart`

- [ ] **Step 1: Write the failing test** — the dialog always animates to the confirmation after submit, with no delayed caveat.

```dart
testWidgets('shows the unconditional confirmation after submit', (t) async {
  // even when every channel is failing/unconfirmed
  await _submitAReport(t);
  expect(find.byType(ReportConfirmationBody), findsOneWidget);
  expect(find.text(l10n.reportModerationDmDelayed), findsNothing);
});
```

- [ ] **Step 2: Run test to verify it fails** — the delayed caveat/no-channel suppression still exists.

- [ ] **Step 3: Remove the dead UI** — delete `moderationDmFailed` from the state, the `notSent` status branch in `_submitReport`, the "reached no channel" inline error, and the `reportModerationDmDelayed` caveat. Confirmation is shown whenever `status == submitted`; `submitted` is now the only non-refused success terminal.

- [ ] **Step 4: Run the dialog + confirmation suites** — rework the pinned tests: `report_content_dialog_test.dart` (`:1096`, `:1121`, `:1139`, `:1153`, `:1169`, `:1189`, `:2017`, `:2056`) and `report_content_confirmation_test.dart` (`:31`). Delete the ones asserting removed behavior; keep/repoint the ones asserting the confirmation shows.

- [ ] **Step 5: l10n** — remove the now-unused `reportModerationDmDelayed` (and any `reportNotSent`) ARB keys across locales, or add them to the orphaned-key baseline with a `# staged` note; run `flutter gen-l10n`. Confirm the orphaned-arb-key ratchet passes.

- [ ] **Step 6: Commit** — `feat(report): unconditional confirmation, remove DM-delayed UI (#8053)`.

---

### Task 5: Final verification pass

- [ ] **Step 1:** `dart run build_runner build --delete-conflicting-outputs` in `mobile/` and `packages/db_client`; commit any generated changes.
- [ ] **Step 2:** `flutter analyze` project-wide → clean.
- [ ] **Step 3:** Run the ratchet scripts touched: `scripts/check_ungrouped_tests.sh`, `scripts/check_future_delayed_ceiling.sh`, `scripts/check_orphaned_arb_key_floor.sh`.
- [ ] **Step 4:** Full affected-suite run: dm_repository send, report cubit, report dialog, confirmation, content-reporting, and the PR-1 durable-queue tests (unchanged, must stay green).
- [ ] **Step 5:** Adversarial self-review loop (independent reviewer + first-hand + mutation checks), focusing on: coalescing (#6610) still one-rumor-per-report; no silent-drop path reintroduced; the `sendMessage` extraction is truly behavior-preserving.

---

## Resume checklist (after PR 1 merges)

1. `git fetch origin && git rebase origin/main` this branch (PR 1 is now in main; the diff becomes PR-2-only).
2. Re-run the PR-1 durable-queue tests to confirm the base is intact.
3. Execute Tasks 1-5.
4. Only then mark ready + request `@divinevideo/reviewers` (on Matt's go).
