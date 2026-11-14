# Video DM send progress that survives leaving the chat

Status: draft, awaiting Rabble's approval. Date: 2026-11-13.

## Why

A TestFlight report: sending a video in a DM "feels really slow and locks up
the UI", with a request for progress and for the send to keep working when you
navigate away.

The lockup itself is fixed separately (#10977 moves encryption off the UI
isolate). This design covers the rest:

1. **There is no real progress.** The only sign a video is going out is an
   indeterminate spinner on the composer's attach button. The upload reports
   progress internally (`BlossomUploadService.uploadEncryptedFile`'s
   `onProgress`), but `DmVideoSendService.sendVideo` never passes it on.
2. **The send's visible life is tied to the composer.** `VideoDmSendCubit` is
   created by `_SendBar` inside `ConversationView`. Leaving the chat closes
   it. The upload future keeps running (it is not cancelled), but the progress
   is gone, and for gallery videos the success/failure snackbar is gone too,
   because it is a `BlocListener` on that screen. Coming back shows nothing
   until the message lands.
3. **There is no bubble until the very end.** Video DMs don't use the durable
   outgoing queue that text uses (`sendFileMessage` writes no `outgoing_dms`
   row). The message row is inserted only after the recipient's relay accepts
   the gift wrap. The whole check → encrypt → upload stretch has no presence
   in the thread.

Success: after picking a video, the user immediately sees it in the thread as
a pending bubble with progress, can leave and come back and still see it
(still progressing or finished), and hears about the outcome wherever they are
in the app.

## Goals

- A **pending video bubble** in the 1:1 thread from the moment a send is
  requested until the persisted message replaces it, with no flicker or gap
  at handoff.
- **Progress on the bubble**: an indeterminate ring while waiting, checking,
  encrypting and publishing; a determinate ring (0–100%) while uploading.
- **Survives in-app navigation**: leaving the conversation, switching tabs or
  opening other screens neither stops the send nor loses its state. Reopening
  the conversation shows the bubble in its current state.
- **Outcome is always reported**: a snackbar on success and on every failure
  kind, shown wherever the user is in the app.
- **Failures are recoverable from the bubble**: a failed bubble offers
  **Retry** and **Remove**.
- Gallery videos and library clips (including multi-clip selections) both go
  through it.

## Non-goals

- **Surviving app kill or OS suspension.** In-flight sends live in memory. If
  the app is killed, the send is lost, the same as today. (Decided by Rabble:
  in-app navigation only.)
- **Cancelling an in-flight send.** No cancel button in v1.
- **Group threads.** Video DMs are 1:1 only today; the attach affordance is
  hidden in groups, and that stays.
- **Protocol changes.** The kind 15 event, encryption, tags and Blossom upload
  are unchanged.
- **Inbox list previews** ("Sending video…" on the conversation tile). Not in
  this change.

## Anti-goals

- A bubble that disappears and reappears, or jumps position, when the send
  finishes.
- A second copy of the send pipeline. The existing encrypt/upload/publish code
  (`DmVideoSendService`) and the clip checks are moved and reused, not
  rewritten.
- A send that silently vanishes: every request ends in either a persisted
  message or a visible failed bubble plus a snackbar.

## Constraints

- Layering: UI → BLoC → repository/service → client. Long-lived work belongs
  below the BLoC; BLoCs hold no mutable fields and no error strings in state
  (`.claude/rules/architecture.md`, `state_management.md`).
- Account scoping: the DM repository and the send service are rebuilt on
  account switch (`dmRepositoryProvider` watches `nostrSessionProvider`;
  `dmVideoSendServiceProvider` watches it). The new owner must be per account.
- Upload policy: one upload at a time. On flaky links, parallel uploads hurt
  more than they help.
- All new copy goes through `context.l10n`; new ARB keys are mirrored to every
  locale or listed in `_knownUntranslatedDebt`, and read in the same change.
- Reduced motion: use `DivineCircularProgressIndicator` (the raw Material
  indicators are banned by guard).
- A new file under `lib/services/` needs a same-named `*_test.dart`.

## Approaches considered

1. **App-level send tracker (chosen).** A small in-memory owner, one per
   signed-in account, runs the existing pipeline and publishes the in-flight
   sends. The conversation screen draws bubbles from it; an app-root listener
   shows outcome snackbars. Fits the layering, adds nothing on disk, and
   matches the in-app-only scope.
2. **Durable queue in the database.** Persist pending video sends like text
   so they survive an app kill. Needs a Drift migration, account cleanup,
   salvage classification, and either the AES key at rest or re-encrypting on
   resume. Much bigger than the chosen scope. Rejected for now.
3. **Lift `VideoDmSendCubit` to the app shell.** Fewest new pieces, but it
   puts long-lived upload work and pipeline logic inside a BLoC, against the
   repo's layering rules. Rejected.

Rabble picked 1.

## Design

### 1. `VideoDmOutbox` (new, `lib/services/video_dm_outbox.dart`)

An in-memory, per-account owner of outgoing video DMs.

**Provider.** `videoDmOutboxProvider` watches **only**
`currentAccountIdProvider`, so it is disposed and rebuilt on an account
switch and nothing else. *(Builder's call.)* Keying it on the send service
would be wrong: `dmVideoSendServiceProvider` watches `dmRepositoryProvider`,
which rebuilds on more than an account switch. It also rebuilds when the
Nostr session goes from identity-known to ready, or its client is
regenerated, and each such rebuild would silently wipe in-flight sends.

Instead the outbox gets reader callbacks for the send service, the clip
verifier and the clip importer. Each job reads the current instances when it
starts. A job already running keeps the instances it started with.

Disposal (account switch) stops publishing state and drops all entries. A send
already mid-flight is not cancelled (it can't be today) and its result is
discarded: the same behaviour as now.

**Entry model.** `OutgoingVideoDm` (Equatable, immutable):

- `id`: a local id (uuid), stable for the entry's life.
- `conversationId`: from `DmRepository.computeConversationId([self, recipient])`.
- `recipientPubkey`.
- `localPath`: the picked or library file.
- `clipAspectRatio`: non-null for library clips (drives `DmClipTag`), null
  for gallery videos.
- `batchId`: shared by the clips of one multi-clip pick; null for a single
  gallery video.
- `requestedAt`.
- `frame`: JPEG bytes of the card frame, null until read or if the read fails.
- `phase`: `queued | checking | encrypting | uploading | publishing | sent |
  failed`.
- `uploadProgress`: `double?`, set only while `uploading`.
- `failure`: `tooLarge | clipNotVerified | failed`, set only when
  `phase == failed`.
- `rumorEventId`: set when `phase == sent`. It's the persisted message
  row's id.

**API.**

- `Stream<List<OutgoingVideoDm>> watchConversation(String conversationId)`:
  current entries for one thread, emitting the current value on listen.
- `Stream<VideoDmSendOutcome> get outcomes`: one event per finished request
  (a single video, or a whole clip batch). Broadcast, no replay.
- `void sendVideo({required String recipientPubkey, required File file})`.
- `void sendClips({required String recipientPubkey, required List<DivineVideoClip> clips})`.
- `void retry(String id)`: re-queues a failed entry with the same inputs.
- `void remove(String id)`: drops a failed entry.
- `void acknowledge(String id)`: drops a `sent` entry once its message row is
  on screen (see §3).
- `void dispose()`.

The `send*` methods return immediately. They add `queued` entries
synchronously, so the bubble appears on the same frame as the request.

**Pipeline.** One worker processes queued entries FIFO, one at a time.

- **Gallery video.** encrypt → upload → publish, via
  `DmVideoSendService.sendVideo`.
- **Clip batch.** The C2PA/archived-Vine checks, including
  `signOwnRecordings`, run once for the whole batch before any upload. All
  entries in the batch are `checking` meanwhile. This is the logic in
  `VideoDmSendCubit._sendClips` today, moved here. As today, the check stops
  at the first rejected clip and nothing in the batch is uploaded. *(Builder's
  call.)* Only the rejected clip becomes `failed(clipNotVerified)`. Every
  other clip in the batch becomes `failed(failed)`: some passed the check,
  and some were never checked. If the check passes, each clip goes through
  the gallery-video pipeline in order.
- **Stopping a batch.** If one clip fails, the remaining clips of that batch
  become `failed(failed)` without being attempted. That keeps today's "stop
  the rest" behaviour, and each one is retryable.
- **Card frame.** Read with `readDmVideoCardFrame(file)` when the entry is
  created, independent of the queue, so a queued bubble can already show its
  frame.
- **Progress.** `DmVideoSendService.sendVideo` gains an
  `onUploadProgress(double)` callback, passed through to
  `uploadEncryptedFile(onProgress:)`. The outbox stores the value as given
  (Blossom reports 0.1 → 1.0, monotonic). Phases come from the existing
  `onPhase`.
- **Retry.** Re-queues the single entry at the back of the queue and redoes
  its whole pipeline. A retried clip runs the check again for that clip alone,
  then encrypts, uploads and publishes it. `clipNotVerified` and `tooLarge`
  entries have no Retry (see §4), so a retry never re-checks a clip that
  already failed the check.
- **Unconfirmed sends.** *(Rabble's decision.)* `sendFileMessage` returns a
  soft failure (`retryablePending`) when the message was written to the
  recipient's relay but no `OK` came back. The message may have arrived. The
  outbox treats this like any other failure: `failed(failed)`, and Retry
  redoes everything with fresh ciphertext and a new kind 15. Accepted cost:
  the recipient can end up with two copies of the video, and the upload is
  repeated. Republishing the stored signed wrap instead was considered and
  not chosen.

**Outcomes.** `VideoDmSendOutcome { status, sentCount, total }` reuses the
`ClipSendOutcome` shape and the existing status set. It is emitted when a
single video finishes, or when the last entry of a batch settles. A retry
emits its own single-entry outcome.

**Errors.** Failures are logged and classified exactly as the cubit does now:
`DmVideoTooLargeException` → `tooLarge`; programming errors are forwarded
through the reportable-error path; anything else → `failed`. No error text is
stored in an entry.

### 2. Moving the work out of `VideoDmSendCubit`

`VideoDmSendCubit` and its state are deleted. The pipeline logic moves into
the outbox and the status/outcome types move with it. Its 19 tests are ported
to `test/services/video_dm_outbox_test.dart` against the same behaviours
(drop on double-request becomes "queues behind"). This is a move of existing
logic, not a rewrite.

### 3. Conversation integration

**`ConversationBloc`** gains the outbox as a constructor dependency and
subscribes to `watchConversation(conversationId)`, the same way it already
combines `watchMessages` with `watchOutgoing`.

**`ConversationState`** gains `pendingVideoSends: List<OutgoingVideoDm>` and a
getter `displayedVideoSends`. The getter drops any `sent` entry whose
`rumorEventId` is already in `messages`; that's the same rule
`displayedMessages` applies to text queue rows. When the bloc sees a `sent`
entry whose row has arrived, it calls `outbox.acknowledge(id)`.

**Handoff.** `sendFileMessage` commits the message row before it returns, and
the entry turns `sent` only after that return. So for one stream tick the
entry is `sent` and its row may not be in `messages` yet; the bubble stays up.
On the next tick the row arrives, the entry is filtered out and acknowledged.
The result: no gap, no duplicate, no jump.

**New events**, so the composer goes UI → bloc → outbox and never reaches the
outbox directly:

- `ConversationVideoSendRequested(File)`
- `ConversationClipsSendRequested(List<DivineVideoClip>)`
- `ConversationVideoSendRetried(id)`
- `ConversationVideoSendRemoved(id)`

**Placement.** Pending video bubbles, failed ones included, always sit at
the newest end of the thread (the bottom), in `requestedAt` order, below every persisted message and
text bubble. A text message typed during an upload therefore appears *above*
the pending video. When the video's row lands, its `createdAt` is "now", so it
takes the same bottom position. Nothing jumps. *(Builder's call.)* A failed
bubble stays pinned at the bottom until it is retried or removed, so it stays
in view rather than being scrolled away. In the reversed `ListView`,
these are the first `displayedVideoSends.length` indices, offset before
`displayedMessages`, and keyed by `ValueKey('pending-video-$id')`.

### 4. Pending video bubble (new widget)

`PendingVideoBubble`, in `lib/screens/inbox/conversation/widgets/`, is
right-aligned like own media.

- **Size and look.** 248×350, the same size as `EncryptedVideoCard`, with the
  `mediaCard` fill. It shows `frame` via `Image.memory`, and the existing
  placeholder card when there's no frame.
- **Progress overlay.** A centred scrim with a ring:
  - `queued`, `checking`, `encrypting` and `publishing`: indeterminate
    `DivineCircularProgressIndicator`.
  - `uploading`: determinate, with the value set to `uploadProgress`.
  - `sent`: renders without the overlay for its last tick.
- **Status line.** Below the card, in secondary text: "Waiting…" /
  "Preparing…" / "Uploading 42%" / "Sending…". Checking and encrypting both
  read "Preparing…": the user doesn't care which.
- **Failed.** The ring is replaced by the existing warning icon, with a
  status line reusing `dmVideoSendFailed` / `dmVideoTooLarge` /
  `dmClipSendNotVerified`, plus two `DivineButton`s: **Retry** and **Remove**.
  `tooLarge` and `clipNotVerified` offer **Remove** only, since retrying
  cannot change the answer.
- **Semantics.** One merged node per bubble: "Sending video, 42%" / "Video
  failed to send". Each progress change is not announced; the outcome
  snackbar announces the end, as today.

### 5. Composer

- `_SendBar` stops creating a cubit.
- `_onAttachVideo` and `_onAttachClip` pick as today, then add the bloc
  events.
- The attach button is no longer disabled or spinning while a send runs.
  Sends queue, and the bubble is the progress.
- `_onVideoSendOutcome`, and `_onAttachClip`'s own snackbar code, are
  removed; the app-root listener replaces both.

### 6. App-root outcome listener (new)

`VideoDmSendOutcomeListener`, in `lib/startup/`, mirrors
`UploadFailureListener`. It is mounted in `AppCompositionRoot`, subscribes to
`videoDmOutboxProvider`'s `outcomes`, and shows the snackbar through
`NavigatorKeys.root.currentContext`.

- The copy mapping is exactly today's `_onAttachClip` switch: sent / partly
  sent / too large / not verified / failed.
- It sends the same `SemanticsService.sendAnnouncement`.
- If no context is available, the outcome is dropped. The bubble still shows
  the state.

### Copy (new ARB keys)

Mirrored to all locales, or listed as known untranslated debt, as the l10n
rules require:

- `dmPendingVideoWaiting`: "Waiting…"
- `dmPendingVideoPreparing`: "Preparing…"
- `dmPendingVideoUploading`: "Uploading {percent}%"
- `dmPendingVideoSending`: "Sending…"
- `dmPendingVideoRetry`: "Retry"
- `dmPendingVideoRemove`: "Remove"
- `dmPendingVideoSemantics` / `dmPendingVideoFailedSemantics`

Existing keys are reused for every outcome message.

## Testing

- **`video_dm_outbox_test.dart`**: the ported cubit cases plus:
  - FIFO and one-at-a-time ordering
  - immediate `queued` entry
  - progress passthrough
  - batch stop-the-rest
  - retry and remove
  - acknowledge
  - outcome per request and per batch
  - dispose drops entries and ignores late results
- **`dm_video_send_service_test.dart`**: `onUploadProgress` is forwarded.
- **`conversation_bloc` / `conversation_state` tests**:
  - the merge
  - the `sent` handoff, kept until the row arrives, then acknowledged
  - the new events
- **Widget tests for `PendingVideoBubble`**, one per phase: ring type,
  percent text, failed actions (Retry hidden for too-large / not-verified),
  and semantics.
- **`conversation_view_test.dart`**:
  - the "encrypted video DM send outcomes" group is updated: the bubble
    appears on request, survives the page being popped and re-pushed, and is
    replaced by the persisted message
  - its snackbar assertions move to a `VideoDmSendOutcomeListener` test
- The l10n delegates rules apply to every widget test.

## Left to the builder

- Exact widget layout inside the card (scrim opacity, ring size) within the
  design system.
- Whether the frame read runs on entry creation or lazily on first watch,
  provided a queued bubble shows a frame when one is readable.
- Internal structure of the worker loop.

## Decisions log

- **Rabble:**
  - approach 1, the app-level send tracker
  - pending bubble in the thread
  - in-app navigation only
  - Retry redoes everything, even after an unconfirmed send
- **Builder's calls** (marked inline above):
  - the outbox is keyed to the account only
  - per-clip outcome when a batch fails its check
  - failed bubbles stay pinned at the bottom
  - plus the defaults stated under Goals and Non-goals: Retry/Remove, no
    cancel, one upload at a time

## Open risks

- `ConversationBloc` grows four events and one dependency.
- Retry after an unconfirmed send can deliver the video twice (accepted).
- An account switch mid-send discards the visible state of a send that may
  still be delivered from the old account. That's unchanged from today, but
  now there's a visible bubble that vanishes with the switch.
