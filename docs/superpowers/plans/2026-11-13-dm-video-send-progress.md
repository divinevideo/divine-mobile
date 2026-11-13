# Video DM Send Progress Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a pending video bubble with real upload progress in a 1:1 DM
thread. The bubble survives leaving the chat and reports the outcome
anywhere in the app.

**Architecture:** A per-account, in-memory `VideoDmOutbox` (a service under
`lib/services/`) runs the existing encrypt/upload/publish pipeline. It runs
one send at a time and publishes per-conversation entries plus outcome
events. `ConversationBloc` merges its entries into the thread state, and the
view renders them as `PendingVideoBubble`s. An app-root
`VideoDmSendOutcomeListener` shows the snackbars. `VideoDmSendCubit` is
deleted, and its logic moves into the outbox.

**Tech Stack:** Flutter, flutter_bloc, Riverpod (provider wiring only),
rxdart, mocktail, bloc_test.

**Spec:** `docs/superpowers/specs/2026-11-13-dm-video-send-progress-design.md`
(approved by Rabble 2026-11-13). Read it before any task.

All paths below are relative to `mobile/` unless they start with `docs/`.
Run Flutter commands from `mobile/` with `mise exec -- … --no-pub`.

## Global Constraints

- **One upload at a time.** Queued entries run FIFO.
- **Lifetime.** `videoDmOutboxProvider` watches only
  `currentAccountIdProvider`. The send service, clip verifier and clip
  importer are read through callbacks when each job starts.
- **No protocol change.** The kind 15, its tags, the encryption and the
  Blossom upload stay as they are.
- **Retry redoes the whole pipeline**, including after an unconfirmed
  (`retryablePending`) send.
- **Retry and Remove by failure kind:** `tooLarge` and `clipNotVerified`
  offer Remove only; `failed` offers Retry and Remove.
- **No error text in state.** Failures are an enum. Programming errors go
  through the reportable path (`asReportableError` / `runDetached`
  conventions in `.claude/rules/error_handling.md`).
- **Copy goes through `context.l10n`.** New keys go into `app_en.arb` and
  are either mirrored to every `app_*.arb` or added to
  `_knownUntranslatedDebt` in `test/l10n/arb_consistency_test.dart`. Every
  new key is read from `lib/` in the same change.
- **Design system.** Use `DivineCircularProgressIndicator` (raw Material
  indicators fail a guard), `DivineButton`, `context.vineColors.*` for
  surfaces, and `VineTheme.*Font()`.
- **Widget tests** use `testMaterialApp(...)` or
  `appLocalizationsDelegates`.
- **Every test is inside a `group()`.** No `Future.delayed` in tests: use
  `fakeAsync`, `pumpEventQueue`, or completers.
- **New service file** `lib/services/video_dm_outbox.dart` gets
  `test/services/video_dm_outbox_test.dart`.
- **Pubkeys in logs** go through `pubkeyForLogs`. Never log key/nonce/paths
  of the plaintext.
- Every file starts with two `// ABOUTME:` lines.

## Review Focus

1. **The picked gallery file is gone at retry time.** The OS reclaimed the
   picker's temp copy. Retry must end in `failed`, not crash or hang.
   Owner: Task 2.
2. **An account switch while a send is running.** `dispose()` runs, then
   the in-flight `sendVideo` completes. There must be no emit after close
   and no outcome event. Owner: Task 2.
3. **Re-opening a conversation mid-upload.** A late `watchConversation`
   subscriber immediately receives the current entries, including
   progress. Owner: Task 2.
4. **Two picks in quick succession.** Both get bubbles at once. The second
   stays `queued` until the first settles. Owner: Task 2.
5. **The persisted row arrives in the same tick as `sent`.** There's no
   frame with neither the bubble nor the message, and no frame with both.
   Owner: Task 5.

---

### Task 1: Forward upload progress from `DmVideoSendService`

**Files:**
- Modify: `lib/services/dm_video_send_service.dart`
- Test: `test/services/dm_video_send_service_test.dart`

**Interfaces:**
- Produces: `DmVideoSendService.sendVideo(..., void Function(double fraction)? onUploadProgress)`.
  This is forwarded verbatim to `BlossomUploadService.uploadEncryptedFile(onProgress:)`.

- [ ] **Step 1: Write the failing test.** Add it inside the existing
  `sendVideo` group: `test('forwards Blossom upload progress to onUploadProgress')`.
  - Stub `uploadEncryptedFile` (mocktail `any(named: 'onProgress')`) so it
    captures the callback, calls it with `0.1`, `0.55`, `1.0`, then returns
    success.
  - Expect the collected values `[0.1, 0.55, 1.0]`.
  - Also update the existing `uploadEncryptedFile` stubs/verifies to accept
    the new named argument.
- [ ] **Step 2: Run** `flutter test --no-pub test/services/dm_video_send_service_test.dart`.
  Expected: the new test FAILS (no values collected).
- [ ] **Step 3: Implement.** Add the optional named parameter, document it
  in the dartdoc, and pass `onProgress: onUploadProgress`.
- [ ] **Step 4: Run** the same file. Expected: all pass.
- [ ] **Step 5: Commit**: `feat(dm): report upload progress from the video DM send pipeline`.

### Task 2: `VideoDmOutbox`, gallery videos

**Files:**
- Create: `lib/services/video_dm_outbox.dart` (the model and the outbox)
- Test: `test/services/video_dm_outbox_test.dart`

**Interfaces:**
- Consumes: Task 1's `onUploadProgress`; `DmVideoSendPhase` and
  `DmVideoSendService`; `readDmVideoCardFrame` (`lib/services/dm_video_preview.dart`);
  `DmVideoTooLargeException` and `NIP17SendSuccess.rumorEventId`.
- Produces:

  ```dart
  enum OutgoingVideoDmPhase { queued, checking, encrypting, uploading, publishing, sent, failed }
  enum OutgoingVideoDmFailure { tooLarge, clipNotVerified, failed }
  enum VideoDmSendStatus { sent, tooLarge, clipNotVerified, failed } // outcome status
  class OutgoingVideoDm extends Equatable { id, conversationId, recipientPubkey,
    localPath, DivineVideoClip? clip, String? batchId, DateTime requestedAt,
    Uint8List? frame, OutgoingVideoDmPhase phase, double? uploadProgress,
    OutgoingVideoDmFailure? failure, String? rumorEventId;
    bool get canRetry => phase == failed && failure == OutgoingVideoDmFailure.failed;
    OutgoingVideoDm copyWith(...); }
  class VideoDmSendOutcome extends Equatable { VideoDmSendStatus status;
    int sentCount; int total; bool get isPartial; }
  typedef DmVideoCardFrameReader = Future<Uint8List?> Function(File video);
  class VideoDmOutbox {
    VideoDmOutbox({
      required DmVideoSendService Function() sendService,
      ClipProvenanceVerifier? Function()? clipVerifier,
      Future<void> Function(List<DivineVideoClip>)? signOwnRecordings,
      ArchivedVineCheck? isArchivedVine,
      DmVideoCardFrameReader readFrame = readDmVideoCardFrame,
      String Function()? newId,           // defaults to Uuid().v4
      DateTime Function()? now,           // defaults to DateTime.now
    });
    Stream<List<OutgoingVideoDm>> watchConversation(String conversationId);
    Stream<VideoDmSendOutcome> get outcomes;
    void sendVideo({required String conversationId, required String recipientPubkey, required File file});
    void sendClips({required String conversationId, required String recipientPubkey, required List<DivineVideoClip> clips}); // Task 3
    void retry(String id);         // Task 3
    void remove(String id);        // Task 3
    void acknowledge(String id);   // Task 3
    void dispose();
  }
  ```

  - `ArchivedVineCheck` moves here from `video_dm_send_cubit.dart`.
  - Keep `videoDmMaxMegabytes`, `videoDmMimeTypeFor` and
    `VideoDmSendFailure` too, moved here with the same names.

- [ ] **Step 1: Write the failing tests** in
  `group(VideoDmOutbox)` → `group('sendVideo')`. Use a mocktail
  `DmVideoSendService` whose `sendVideo` completes a test-controlled
  `Completer` and drives `onPhase` / `onUploadProgress`, plus a fake
  `readFrame`.
  - `adds a queued entry synchronously, before any await`: after
    `sendVideo(...)`, `await pumpEventQueue()` once.
    `watchConversation('c1')` emits a list of 1 with phase `queued` or
    later, and the `localPath` and `recipientPubkey` given.
  - `walks encrypting → uploading with progress → publishing → sent`: drive
    `onPhase(encrypting)`, `onPhase(uploading)`, `onUploadProgress(0.4)`,
    `onPhase(sending)`, then complete with
    `NIP17SendResult.success(rumorEventId: 'r1', ...)`. Expect the emitted
    phases in order. Expect `uploadProgress == 0.4` while uploading and
    `null` after. The final entry is `sent` with `rumorEventId == 'r1'`.
  - `emits one sent outcome`: `outcomes` emits
    `VideoDmSendOutcome(status: sent, sentCount: 1, total: 1)`.
  - `runs one send at a time` (Review Focus 4): two `sendVideo` calls. Both
    entries exist at once. The second is `queued` and `sendVideo` was called
    once until the first completer completes, then twice.
  - `a late subscriber gets the current entries` (Review Focus 3):
    subscribe after progress `0.4`. The first event already carries
    `uploading` and `0.4`.
  - `maps DmVideoTooLargeException to failed(tooLarge)` and a
    `tooLarge` outcome; `canRetry` is false.
  - `maps a failure result, including retryablePending, to failed(failed)`
    and a `failed` outcome; `canRetry` is true.
  - `a missing file ends failed, not thrown` (Review Focus 1): the send
    service throws `FileSystemException`, so the entry ends `failed(failed)`
    and no exception escapes the zone.
  - `stores the card frame read from the file`: `readFrame` returns bytes,
    and the entry's `frame` equals them. With a `readFrame` that returns
    null, `frame` stays null and the send still completes.
  - `dispose drops entries and ignores a send that finishes afterwards`
    (Review Focus 2): dispose mid-send, then complete the completer.
    No new `watchConversation` event, no outcome, no throw. `sendVideo`
    after dispose is a no-op.
  - `keeps conversations separate`: entries for `c2` never appear in
    `watchConversation('c1')`.
- [ ] **Step 2: Run** `flutter test --no-pub test/services/video_dm_outbox_test.dart`.
  Expected: FAIL (the file or class doesn't exist).
- [ ] **Step 3: Implement** the model, `sendVideo`, the worker loop,
  `watchConversation` (a `BehaviorSubject` of all entries, `map`ped and
  `distinct`-filtered per conversation), `outcomes` (broadcast) and
  `dispose`.
  - Map `DmVideoSendPhase.sending` to `publishing`.
  - Classify exceptions as in the cubit's `send()`.
  - Unexpected errors: log through `Log.error` and forward reportable ones
    with `detachedFailureReporter` / `asReportableError`. Mirror
    `runDetached`'s gate.
  - Read the frame independently of the queue: start it at enqueue and
    `copyWith(frame:)` when it lands, if the entry still exists.
- [ ] **Step 4: Run** the same file. Expected: all pass.
- [ ] **Step 5: Commit**: `feat(dm): add an outbox that owns outgoing video DMs`.

### Task 3: Outbox clip batches, retry, remove, acknowledge

**Files:**
- Modify: `lib/services/video_dm_outbox.dart`
- Test: `test/services/video_dm_outbox_test.dart`
- Reference (cases to port): `test/blocs/dm/video_dm_send/video_dm_send_cubit_test.dart`

**Interfaces:**
- Consumes: Task 2's types.
- Produces: the working `sendClips`, `retry`, `remove`, `acknowledge`.
  - Clip entries carry `clip` and a shared `batchId`.
  - Each clip is sent with `extraTags: [DmClipTag.build(clip.targetAspectRatio)]`.

- [ ] **Step 1: Write the failing tests** under `group('sendClips')`, then
  `group('retry')`, `group('remove')`, `group('acknowledge')`. Port every
  behaviour the cubit's `sendClips` tests pin, including:
  - an empty list is a no-op;
  - a clip without a file → that entry `failed(failed)`;
  - `signOwnRecordings` runs before verify;
  - an archived Vine passes when `noCredentials`;
  - `isArchivedVine` throwing lets the clip through;
  - no verifier means no check.

  Add these tests:
  - `checks the whole batch before any upload`: all entries are `checking`,
    and `sendVideo` is never called while verify is pending.
  - `a rejected clip fails only itself as clipNotVerified; the rest fail as
    failed`: three clips, the second rejected. Entry 2 is `clipNotVerified`,
    entries 1 and 3 are `failed`. Nothing uploads, and one outcome is
    emitted: `clipNotVerified`, `sentCount 0`, `total 3`.
  - `a failed upload stops the rest of the batch`: clip 1 sends, clip 2
    fails. Clip 3 is never attempted and ends `failed(failed)`. One outcome:
    `failed`, `sentCount 1`, `total 3`, `isPartial` true.
  - `retry re-queues a failed entry and re-checks a clip alone`: verify is
    called with only that clip's path, then it sends. A new single-entry
    outcome is emitted.
  - `retry is ignored unless canRetry`: no-op for `tooLarge`,
    `clipNotVerified` or a running entry.
  - `remove drops a failed entry and ignores others`.
  - `acknowledge drops a sent entry and ignores others`.
- [ ] **Step 2: Run** the test file. Expected: the new groups FAIL.
- [ ] **Step 3: Implement.** The batch check runs inside the worker as one
  job, ahead of that batch's clip entries. Move `_isSendableVine` here
  unchanged.
- [ ] **Step 4: Run** the test file. Expected: all pass.
- [ ] **Step 5: Commit**: `feat(dm): send clip batches, retries and removals through the video outbox`.

### Task 4: `videoDmOutboxProvider`, keyed on the account only

**Files:**
- Modify: `lib/providers/video_providers.dart` (next to `dmVideoSendServiceProvider`)
- Test: `test/providers/video_dm_outbox_provider_test.dart`

**Interfaces:**
- Produces: `final videoDmOutboxProvider = Provider<VideoDmOutbox>(...)`.
  - It `ref.watch`es only `currentAccountIdProvider`.
  - It passes `sendService: () => ref.read(dmVideoSendServiceProvider)`,
    `clipVerifier: () => ref.read(clipProvenanceVerifierProvider)`,
    `signOwnRecordings: NativeProofModeService.signOwnRecordings`, and
    `isArchivedVine` reading `videoClipImportServiceProvider` at call time
    (as `_SendBar` does today).
  - It calls `ref.onDispose(outbox.dispose)`.

- [ ] **Step 1: Write the failing tests** (`ProviderContainer` with
  overrides):
  - `keeps the same outbox when the DM repository rebuilds`: invalidate
    `dmVideoSendServiceProvider` (or override it with a changing value),
    and the read outbox is `same` as before.
  - `builds a new outbox and disposes the old one when the account changes`:
    override `currentAccountIdProvider` with a `StateProvider`-backed value,
    change it, and the outbox is a different instance. The old one's
    `watchConversation` stream is done.
- [ ] **Step 2: Run** the test. Expected: FAIL (the provider is missing).
- [ ] **Step 3: Implement** the provider.
- [ ] **Step 4: Run** the test. Expected: PASS.
- [ ] **Step 5: Commit**: `feat(dm): provide the video outbox per account`.

### Task 5: `ConversationBloc` merges pending videos and takes send events

**Files:**
- Modify: `lib/blocs/dm/conversation/conversation_bloc.dart`, `conversation_event.dart`, `conversation_state.dart`
- Modify: `lib/screens/inbox/conversation/conversation_page.dart:208-215` (pass the outbox; add it to the `ValueKey` record)
- Test: `test/blocs/dm/conversation/conversation_bloc_test.dart`, `test/blocs/dm/conversation/conversation_state_test.dart`

**Interfaces:**
- Consumes: Task 2 and 3's `VideoDmOutbox`, Task 4's provider.
- Produces:
  - `ConversationBloc({required DmRepository dmRepository, required String conversationId, required VideoDmOutbox videoOutbox})`.
  - Events:
    - `ConversationVideoSendRequested({required String recipientPubkey, required File file})`
    - `ConversationClipsSendRequested({required String recipientPubkey, required List<DivineVideoClip> clips})`
    - `ConversationVideoSendRetried(String id)`
    - `ConversationVideoSendRemoved(String id)`
  - State: `ConversationState.pendingVideoSends: List<OutgoingVideoDm>`,
    plus the getter `List<OutgoingVideoDm> get displayedVideoSends`. It
    drops `sent` entries whose `rumorEventId` is among `messages` ids, and
    sorts by `requestedAt` **descending**, so that index 0 is the newest,
    matching the reversed list.

- [ ] **Step 1: Write the failing tests.**
  - State: `displayedVideoSends hides a sent entry once its row is
    persisted, keeps it before`; `orders newest request first`.
  - Bloc:
    - `merges the outbox's entries for this conversation into state`.
    - `acknowledges a sent entry once its row is in messages` (verify
      `outbox.acknowledge(id)`).
    - `the row and the sent entry arriving in one tick never show both`
      (Review Focus 5): an emitted state with both has the entry absent
      from `displayedVideoSends`.
    - `ConversationVideoSendRequested calls outbox.sendVideo with this
      conversationId`. Do the same for clips, retry and remove.
  - Use `transformer: sequential()` for the four new events. They only
    forward to the outbox.
  - Update the existing bloc tests' construction to pass a mock outbox
    whose `watchConversation` returns `Stream.value(const [])`.
- [ ] **Step 2: Run**
  `flutter test --no-pub test/blocs/dm/conversation/`. Expected: the new
  tests FAIL.
- [ ] **Step 3: Implement.**
  - `_onStarted` switches to `Rx.combineLatest3` with
    `videoOutbox.watchConversation(_conversationId)`.
  - `_ConversationTick` gains the third list.
  - `ConversationPage` reads `ref.watch(videoDmOutboxProvider)` and passes
    it in.
- [ ] **Step 4: Run** the same tests plus
  `test/screens/inbox/conversation/conversation_page_test.dart`.
  Expected: PASS.
- [ ] **Step 5: Commit**: `feat(dm): show the conversation's outgoing videos in its state`.

### Task 6: `PendingVideoBubble` and its copy

**Files:**
- Create: `lib/screens/inbox/conversation/widgets/pending_video_bubble.dart` (and export it from `widgets.dart`)
- Modify: `lib/l10n/app_en.arb`, every other `lib/l10n/app_*.arb` or `test/l10n/arb_consistency_test.dart` `_knownUntranslatedDebt`; run `flutter gen-l10n`
- Test: `test/screens/inbox/conversation/widgets/pending_video_bubble_test.dart`

**Interfaces:**
- Produces: `PendingVideoBubble({required OutgoingVideoDm entry, required VoidCallback onRetry, required VoidCallback onRemove, super.key})`.
  - Card size: `encryptedVideoCardWidth` × `encryptedVideoCardHeight`
    (`encrypted_video_card.dart`). Right-aligned.
- ARB keys (exact English):
  - `dmPendingVideoWaiting` "Waiting…"
  - `dmPendingVideoPreparing` "Preparing…"
  - `dmPendingVideoUploading` "Uploading {percent}%" (`percent`: int)
  - `dmPendingVideoSending` "Sending…"
  - `dmPendingVideoRetry` "Retry"
  - `dmPendingVideoRemove` "Remove"
  - `dmPendingVideoSemantics` "Sending video, {percent}%" (`percent`: int)
  - `dmPendingVideoFailedSemantics` "Video failed to send"

  Failure lines reuse `dmVideoSendFailed`, `dmVideoTooLarge` (argument:
  `videoDmMaxMegabytes`) and `dmClipSendNotVerified`.

- [ ] **Step 1: Write the failing widget tests**, one per state, each
  resolving copy through `lookupAppLocalizations(const Locale('en'))`:
  - `queued`: an indeterminate ring (`DivineCircularProgressIndicator` with
    a null value) and "Waiting…".
  - `checking` / `encrypting`: "Preparing…".
  - `uploading` at `0.42`: a determinate ring at `0.42` and "Uploading 42%".
  - `publishing`: "Sending…".
  - `frame` bytes: `Image` present; null frame: the placeholder.
  - `failed(failed)`: shows Retry and Remove, and tapping each calls its
    callback.
  - `failed(tooLarge)` and `failed(clipNotVerified)`: Remove only, with the
    matching failure copy.
  - Semantics: the merged label for uploading and for failed.
- [ ] **Step 2: Run** the test. Expected: FAIL.
- [ ] **Step 3: Implement** the widget, as small private widget classes
  with no builder methods. Add the ARB keys and regenerate.
- [ ] **Step 4: Run** the test, `test/l10n/arb_consistency_test.dart` and
  `bash scripts/check_orphaned_arb_key_floor.sh`. Expected: PASS. Keys
  unread until Task 7 make the orphan check fail, so run that one check
  again after Task 7, before committing Task 7; Tasks 6 and 7 may share a
  commit if that is simpler.
- [ ] **Step 5: Commit**: `feat(dm): add the pending video bubble`.

### Task 7: Thread renders pending bubbles; composer dispatches; cubit removed

**Files:**
- Modify: `lib/screens/inbox/conversation/conversation_view.dart`
  - `_ConversationContent`'s `BlocSelector` (~1666) also selects
    `displayedVideoSends`.
  - `_MessageList` (~1753, list ~2162) takes `pendingVideoSends`.
    `itemCount` is `pending.length + messages.length`. Pending items come
    first and are keyed `ValueKey('pending-video-${entry.id}')`. Extend
    `findChildIndexCallback` for both kinds.
  - `_SendBar` and `_SendBarBody` (~1014-1290): drop the
    `BlocProvider<VideoDmSendCubit>`, the `isAttachVideoBusy` gating, the
    `_onVideoSendOutcome` listener and `_onAttachClip`'s snackbar.
    `_onAttachVideo` / `_onAttachClip` add the Task 5 events instead.
- Delete: `lib/blocs/dm/video_dm_send/video_dm_send_cubit.dart` and
  `test/blocs/dm/video_dm_send/video_dm_send_cubit_test.dart` (their cases
  were ported in Tasks 2 and 3).
- Modify: `lib/screens/inbox/conversation/widgets/message_input_bar.dart`,
  only if `isAttachVideoBusy` becomes unused. Remove the parameter and its
  tests.
- Test: `test/screens/inbox/conversation/conversation_view_test.dart`
  (group "encrypted video DM send outcomes", ~6227)

**Interfaces:**
- Consumes: Task 5's events and state; Task 6's widget.

- [ ] **Step 1: Rewrite the group's tests** against a mock outbox / bloc:
  - `picking a gallery video adds ConversationVideoSendRequested` (verify
    the bloc event with the recipient and file).
  - `a pending entry renders as a PendingVideoBubble at the bottom of the
    thread`.
  - `tapping Retry and Remove dispatches the matching events`.
  - `the pending bubble is shown again after the page is popped and
    re-pushed while the outbox still holds it`.
  - `the attach button stays enabled while a video is sending`.
  - Keep the library-clip offer test.
- [ ] **Step 2: Run** the group. Expected: FAIL.
- [ ] **Step 3: Implement** the edits above. Delete the cubit, then fix
  every reference (`grep -rn "VideoDmSendCubit\|video_dm_send_cubit" lib test`
  returns nothing).
- [ ] **Step 4: Run**
  - `flutter test --no-pub test/screens/inbox test/blocs/dm test/services`;
  - `bash scripts/check_orphaned_arb_key_floor.sh`;
  - `flutter analyze --no-pub lib test integration_test`.

  Expected: all pass, no issues.
- [ ] **Step 5: Commit**: `feat(dm): render outgoing videos in the thread and send through the outbox`.

### Task 8: App-root outcome snackbar

**Files:**
- Create: `lib/startup/video_dm_send_outcome_listener.dart`
- Modify: `lib/startup/app_composition_root.dart:217-224` (wrap inside `UploadFailureListener`)
- Test: `test/startup/video_dm_send_outcome_listener_test.dart`

**Interfaces:**
- Consumes: `videoDmOutboxProvider` and `VideoDmSendOutcome`.
- Produces: `VideoDmSendOutcomeListener({required Widget child})`.
  - A `ConsumerStatefulWidget` that resubscribes to `outcomes` when the
    provider's instance changes.
  - It shows the snackbar on `ScaffoldMessenger.maybeOf(NavigatorKeys.root.currentContext)`,
    using `DivineSnackbarContainer.snackBar(message, error:)`.
  - It announces through `SemanticsService.sendAnnouncement` via
    `runDetached`.
  - If there's no context, it drops the outcome.
  - Copy mapping (exactly today's `_onAttachClip` switch):
    - partial → `dmClipsPartlySent(sent, total)`, error
    - sent → `dmVideoSent`
    - tooLarge → `dmVideoTooLarge('$videoDmMaxMegabytes')`, error
    - clipNotVerified → `dmClipSendNotVerified`, error
    - failed → `dmVideoSendFailed`, error

- [ ] **Step 1: Write the failing tests**, one per mapping row. Push an
  outcome on a fake outbox's controller; expect the snackbar text. Also
  test `survives the outbox being replaced` (override the provider, swap
  it, and an outcome on the new outbox still shows).
- [ ] **Step 2: Run** the test. Expected: FAIL.
- [ ] **Step 3: Implement** the listener and mount it.
- [ ] **Step 4: Run** the test and `test/startup/`. Expected: PASS.
- [ ] **Step 5: Commit**: `feat(dm): report video DM send results anywhere in the app`.

### Task 9: Guards, full verification, PR

- [ ] **Step 1: Run the guards**:
  - `cd mobile && bash scripts/ci/run_guards.sh`. Expected: all pass.
  - If a ratchet reports a *reduction* (for example the
    `isAttachVideoBusy` or cubit removals shrink `post_close_emit`), lock
    it with that script's `UPDATE_BASELINE=1` and commit the baseline.
  - If `check_untested_services_floor.sh` flags anything, the outbox test
    is missing or misnamed.
- [ ] **Step 2: Run the checks:**
  - `dart format` on the changed files;
  - `flutter analyze --no-pub lib test integration_test`;
  - `flutter test --no-pub test/services test/blocs/dm test/screens/inbox test/startup test/providers test/l10n`.

  Expected: clean, all pass.
- [ ] **Step 3: Rebase and push:**
  - `git fetch origin && git rebase origin/main`;
  - push with output redirected to a file (the pre-push hook);
  - open the PR titled `feat(dm): show video DM upload progress that
    survives leaving the chat`, with the body per `PR_REVIEW.md`;
  - check that `reviewRequests` is populated (CODEOWNERS auto-requests).
- [ ] **Step 4: Watch** `gh pr checks <n>` until every check settles, then
  read the table. Fix anything red.
