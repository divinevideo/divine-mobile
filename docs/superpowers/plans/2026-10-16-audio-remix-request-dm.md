# Audio Remix Request DM Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let viewers request a video's original sound, let its creator enable public reuse, and reply with actions to use or save the published sound.

**Architecture:** Shared message contracts and a request repository live in `dm_repository`; injectable client contracts isolate DM transport, durable state, and publishing. App adapters compose existing services, while Cubits own presentation state and existing sound-library components handle saves. Publication and DM delivery have separate durable checkpoints.

**Tech Stack:** Flutter, Dart, BLoC/Cubit, Riverpod composition glue, GoRouter, Drift, SharedPreferences, NIP-17 DMs, existing Kind 1063 audio publishing.

**Spec:** [Approved design](../specs/2026-10-16-audio-remix-request-dm-design.md).

## Global Constraints

- Approval enables reuse for everyone; no per-user permission or automatic library save.
- Use the existing encrypted NIP-17 text-message transport and readable fallback content.
- Keep the original video kind, author, d-tag, content, media references, captions, collaborators, and unrelated tags.
- Follow `UI -> BLoC/Cubit -> Repository -> Client`; no Flutter UI types in repository contracts or models and no repository-to-repository dependencies.
- Use constructor injection, Cubits for new presentation state, adaptive Divine UI components, and localized copy.
- Full-length synthetic identifiers in fixtures; no real creator identifiers or secrets.
- Work on `feat/audio-remix-request-dm` in the existing task worktree; rebase onto fresh `origin/main` before publication.
- One combined PR targeting `main`; no merge without separate authorization.

## Review Focus

- A ready message signed by someone other than the video's owner must never unlock use/save actions (Task 1 and Task 5).
- Restart between DM enqueue and local checkpoint must reproduce the same rumor, not send another reply (Task 3).
- Account switch during extraction or signing must abort the old account's operation (Task 2 and Task 4).
- Source-video edits between request and approval must survive metadata replacement (Task 2).
- Existing “Use Sound” on `SoundDetailScreen` currently saves to the library; the new DM's **Use this sound** must actually enter creation with the audio selected (Task 5).

---

## Execution status

Tasks 1–5 are implemented and committed. Task 6 local validation is complete with the native-media gap below. Publication and remote checks are tracked on the pull request.
Independent review findings are resolved: newest signed source revisions,
repeat request cycles, retained original sounds, and consent-safe recovery across
metadata acknowledgement/checkpoint failures. New regressions reproduced each
finding before its fix.

Validation: the rebased affected suite passed 1,954 tests; its one file that
compiled before the workspace dependency refresh passed both tests on rerun.
All 65 repository guards, async safety, app analysis, and affected package
analysis pass. Earlier validation included 1,674 tests in the expanded suite; 71 affected app and
feature tests after review fixes; 27 addressable-video lookup tests; 18 request
lifecycle tests including final consent recovery. Real NIP-17 socket transport
passed on the host. Full native media extraction/upload/recording E2E remains
unrun: the local stack preflight found required ports occupied by another task.
No existing services were stopped. The native DM service runner is registered
in the Linux service workflow.
The native transport scenario also has a host runner that exercises real NIP-17
messages over loopback WebSockets with durable Drift storage. Full camera/media
backend E2E is unrun: the local stack preflight reports occupied ClickHouse
ports belonging to another task; no other task's services were stopped.

## File and responsibility map

- `mobile/packages/dm_repository/lib/src/sound_request_message.dart`: shared wire metadata, builders, strict parser.
- `mobile/packages/dm_repository/lib/src/sound_requests_repository.dart`: request state machine, replay, deduplication, fulfillment; pure Dart injected ports.
- `mobile/packages/dm_repository/lib/src/sound_request_clients.dart`: transport/store/publisher contracts and immutable checkpoint/result values.
- `mobile/packages/db_client/lib/src/database/daos/direct_messages_dao.dart`: owner-scoped reactive application-message query; no schema change required.
- `mobile/lib/services/sound_requests/`: app adapters for transport, persistence, published-video audio, and composition.
- `mobile/lib/blocs/sound_requests/`: feature state and request/approval actions.
- `mobile/lib/screens/inbox/conversation/widgets/sound_request_card.dart`: request and ready cards, sharing existing preview and action components.
- Existing metadata Sounds section, conversation view/page, recorder route, account scope, and localization files: integration points.

### Task 1: Typed message contract and history query

**Files:**
- Create `mobile/packages/dm_repository/lib/src/sound_request_message.dart`.
- Create `mobile/packages/dm_repository/lib/src/sound_request_clients.dart` with the ports and immutable values specified in Task 3, before their publication adapter is implemented in Task 2.
- Modify `mobile/packages/dm_repository/lib/dm_repository.dart` to export the contract.
- Modify `mobile/packages/dm_repository/lib/src/dm_repository.dart`.
- Modify `mobile/packages/db_client/lib/src/database/daos/direct_messages_dao.dart`.
- Test `mobile/packages/dm_repository/test/src/sound_request_message_test.dart`.
- Test `mobile/packages/db_client/test/src/database/daos/direct_messages_dao_test.dart`.

**Interfaces:**
- `SoundRequestMessage? parseSoundRequestMessage(DmMessage message, {required String ownerPubkey, required bool isGroup})`.
- `SoundRequestMessage` carries `kind` (`request`/`ready`), `messageId`, `senderPubkey`, `videoAddress`, optional `requestId`, and optional `audioEventId`.
- `List<List<String>> soundRequestTags({required String videoAddress, String relayHint = ''})`.
- `List<List<String>> soundReadyTags({required String videoAddress, required String requestId, required String audioEventId, String relayHint = '', String audioRelayHint = ''})`.
- DAO: `Stream<List<DirectMessageRow>> watchApplicationMessages({required String ownerPubkey, required String marker})`.
- DM repository: `Stream<List<DmMessage>> watchSoundRequestMessages()`; fail closed when no owner, use existing row decoding and exclude group conversations.

- [x] Write parser tests asserting request marker `['divine', 'sound-request', '1']`, ready marker `['divine', 'sound-ready', '1']`, exact source coordinate, reply marker, and audio marker round-trip.
- [x] Assert null for duplicate/conflicting required tags, invalid IDs, unsupported video kinds/versions, a missing reply/audio on ready, wrong ready author, group context, or missing recipient ownership. Preserve d-tags containing colons.
- [x] Add DAO tests for two owners with matching messages, deleted rows, unrelated markers, and stream updates. Filtering is a coarse data query followed by strict shared parsing, never substring-based authorization.
- [x] Run the new tests and record expected red failures before implementing.
- [x] Implement these interfaces and exports, keeping request ownership checks separate from creator-author checks on ready messages.
- [x] Run `flutter test packages/dm_repository/test/src/sound_request_message_test.dart` and the DAO suite from `mobile/`; expect all tests to pass.
- [x] Commit only Task 1 files with `feat(audio): add typed sound request messages`.

### Task 2: Publish audio and replace the source video's metadata

**Files:**
- Create `mobile/lib/services/sound_requests/published_video_sound_client.dart`.
- Modify `mobile/lib/services/video_publish/video_audio_publisher.dart` to expose narrowly reusable original-sound publication.
- Modify `mobile/lib/services/video_event_publisher.dart` with metadata replacement.
- Test `mobile/test/services/sound_requests/published_video_sound_client_test.dart`.
- Test `mobile/test/services/video_event_publisher_audio_reuse_test.dart`.
- Extend `mobile/test/services/video_publish/video_audio_publisher_test.dart`.

**Interfaces:**
- `Future<String?> VideoAudioPublisher.publishOriginalSound({required String videoPath, required String videoDTag, required String videoTitle})` reuses existing extraction/upload/signing internals and authenticated owner.
- `Future<VideoEvent?> VideoEventPublisher.republishWithAudioReuse({required VideoEvent existingEvent, required String audioEventId, required String audioRelayHint})`.
- `PublishedVideoSoundClient` implements Task 3's `SoundRequestPublisher` via injected source lookup, media acquisition, audio publishing, video replacement, and policy verification adapters. It receives a fixed owner and a current-owner callback.

- [x] Write tests for a remote video with no local original and verify extraction uses the published media without uploading the video again.
- [x] Assert the replacement preserves kind, author, d-tag (including colons), content, and every unrelated original tag, removes conflicting reuse/audio markers, adds `['allow_audio_reuse', 'true']` plus the marked audio reference, and advances the replacement timestamp.
- [x] Assert latest signed metadata is fetched before replacement; changed owner, revoked eligibility, unrelated linked sound, unavailable media, no audio, upload failure, and relay rejection cannot report success.
- [x] Assert an account switch across each awaited publication boundary stops further writes. Retain only feature-owned temporary files for cleanup; never mutate content-addressed media.
- [x] Run tests red, implement the methods and adapter, then run the affected audio/subtitle/publish-confirmation tests green.
- [x] Preserve a successfully published audio ID in the Task 3 store before replacing the video, so retries reuse it. Do not reuse the initial-upload degradation path that permits video-only success.
- [x] Commit with `feat(audio): enable sound reuse on published videos`.

### Task 3: Durable requests, publication checkpoints, and reply jobs

**Files:**
- Implement the `sound_request_clients.dart` ports introduced in Task 1 through the adapters below.
- Create `mobile/packages/dm_repository/lib/src/sound_requests_repository.dart`.
- Create `mobile/lib/services/sound_requests/sound_request_dm_client.dart`.
- Create `mobile/lib/services/sound_requests/sound_request_preferences_store.dart`.
- Modify `mobile/packages/dm_repository/lib/dm_repository.dart` exports.
- Test `mobile/packages/dm_repository/test/src/sound_requests_repository_test.dart`.
- Test `mobile/test/services/sound_requests/sound_request_preferences_store_test.dart`.
- Test `mobile/test/services/sound_requests/sound_request_dm_client_test.dart`.

**Interfaces:**
- `SoundRequestTransport.watchMessages(): Stream<List<DmMessage>>` and `enqueue(SoundRequestSendIntent intent): Future<String>` return the canonical rumor ID; `retry(String rumorId): Future<void>` delegates to existing outbox recovery.
- `SoundRequestStore.read(String ownerPubkey): Future<SoundRequestSnapshot>` and `write(String ownerPubkey, SoundRequestSnapshot snapshot): Future<void>`.
- `SoundRequestPublisher.resolve(String videoAddress): Future<SoundRequestSource>` returns latest signed owner/eligibility/current audio; `publishAudio(SoundRequestSource source): Future<String>`; `enableReuse(SoundRequestSource source, String audioEventId): Future<void>`; `verifyReady(String videoAddress, String audioEventId): Future<bool>`.
- `SoundRequestsRepository({required String ownerPubkey, required SoundRequestTransport transport, required SoundRequestStore store, required SoundRequestPublisher publisher})` exposes `start()`, `close()`, `watchState()`, `request(String videoAddress)`, `approve(String requestId)`, `dismiss(String requestId)`, and `retry(String requestId)`.
- Immutable snapshot values contain pending/dismissed/publishing/awaitingPolicy/ready states, canonical request IDs, per-video audio checkpoints, and per-recipient reply intents including fixed content, idempotency key, createdAt, and rumor ID.

- [x] Write state-machine tests for repeated request taps, duplicate history, several requesters, dismiss/replay, already-enabled sound, and history arriving after approval.
- [x] Assert every publish boundary is persisted before proceeding, video failure emits no ready reply, and reply failure/restart never repeats audio publication.
- [x] Simulate crash after `enqueueSend` but before checkpoint: the exact persisted key/timestamp/content/tags reproduce the same rumor. Assert locale changes during recovery do not alter the saved message content.
- [x] Assert all state is owner-scoped, concurrent writes serialize, invalid persisted data fails visibly without overwriting recoverable records, write failures stop publication, and closing aborts future work.
- [x] Run tests red, then implement ports/state/repository and adapters. Use `DmRepository.enqueueSend` with both `idempotencyKey` and `createdAt`, then `recoverFullSend`; do not build another queue or use fresh `sendMessage` calls for retries.
- [x] Ensure structured sends suppress legacy NIP-04 fallback during both the initial attempt and recovery; pin this with an integration test in the DM repository before changing shared recovery behavior.
- [x] Run all new tests plus DM idempotency/outbox recovery tests; expect green.
- [x] Commit with `feat(audio): persist sound requests and fulfillment replies`.

### Task 4: Account lifecycle and request entry point

**Files:**
- Create `mobile/lib/services/sound_requests/sound_requests_scope.dart` for account-scoped composition and lifecycle.
- Create `mobile/lib/blocs/sound_requests/sound_requests_cubit.dart` and `sound_requests_state.dart`.
- Modify `mobile/lib/startup/app_composition_root.dart` to install the new scope alongside `SavedSoundsScope`. Observe account readiness from the existing session source used by `mobile/lib/providers/repository_providers.dart`; do not change DM startup ownership.
- Modify `mobile/lib/widgets/video_feed_item/metadata/metadata_sounds_section.dart`.
- Test `mobile/test/blocs/sound_requests/sound_requests_cubit_test.dart`.
- Extend `mobile/test/widgets/metadata_sounds_section_test.dart`.

**Interfaces:**
- `SoundRequestsCubit({required SoundRequestsRepository repository})` subscribes to immutable repository state and exposes `request(String videoAddress)`, `approve(String requestId)`, `dismiss(String requestId)`, `retry(String requestId)`.
- `SoundRequestsScope` composes one repository per current account and disposes it on logout/account switch. Lifecycle work starts with the DM system, independent of opened conversation routes.
- Cubit state uses status enums and canonical identifiers, not localized strings, exceptions, Flutter objects, or other blocs.

- [x] Install the scope in `mobile/lib/startup/app_composition_root.dart`, mirroring the account-change stream lifecycle in `SavedSoundsScope`. Existing DM credentials/listening remain in `mobile/lib/providers/repository_providers.dart`; do not introduce another transport listener per conversation.
- [x] Add tests for request entry with sharing off, already reusable, owner, classic policy, missing address, referenced third-party audio, unknown consent, blocked DM, queued request, and failed request.
- [x] Add lifecycle tests switching owner during a request and during publication; callbacks from the previous scope cannot update state or sign as the next account.
- [x] Run tests red, implement Cubit and scope, then add the localized **Request this sound** affordance using shared Divine components.
- [x] Verify repeated queued/pending request taps navigate to the canonical conversation without minting another request.
- [x] Run new Cubit/scope and affected metadata tests green; commit with `feat(audio): request unavailable sounds from video metadata`.

### Task 5: Creator approval and requester use/save cards

**Files:**
- Create `mobile/lib/screens/inbox/conversation/widgets/sound_request_card.dart`.
- Create `mobile/lib/blocs/sound_requests/sound_ready_actions_cubit.dart`.
- Modify `mobile/lib/screens/inbox/conversation/conversation_page.dart` and `conversation_view.dart`.
- Modify `mobile/lib/router/routes/video_routes.dart` and recorder route wiring to accept a typed sound selection.
- Modify `mobile/lib/screens/video_recorder_screen.dart` (`VideoRecorderRoute`) and create `mobile/lib/router/recorder_sound_selection.dart` for that typed selection and one-time handoff.
- Test `mobile/test/screens/inbox/conversation/widgets/sound_request_card_test.dart`.
- Extend `mobile/test/screens/inbox/conversation/conversation_view_test.dart`.
- Test `mobile/test/blocs/sound_requests/sound_ready_actions_cubit_test.dart` and recorder route sound handoff.

**Interfaces:**
- `SoundRequestCard({required SoundRequestMessage message, required bool isSent})` reads the scope's Cubit; never publishes or saves in build/init/render callbacks.
- `SoundReadyActionsCubit` receives pure async callbacks for sound resolution and current consent; `prepareUse()` and `prepareSave()` emit a validated `AudioEvent` for their respective UI action. Saving is dispatched to the existing `SavedSoundsBloc`, and saved state is selected from its live state.
- A typed recorder-route extra carries the validated `AudioEvent`; the route's composition adapter selects it through existing editor wiring before recorder initialization reads `videoEditorProvider.selectedSound`.

- [x] Write tests asserting the creator sees the public-effect copy and **Enable sound reuse** / **Dismiss**, while sender-side and group cards cannot approve.
- [x] Assert malformed/unsupported messages retain readable text, wrong-sender ready cards expose no actions, and duplicate replies collapse by canonical request identity without hiding ordinary messages.
- [x] Assert **Use this sound** opens creation with the resolved sound selected; it must not simply call `SoundDetailScreen._onUseSound`, which currently only saves.
- [x] Assert **Save to My Sounds** saves without starting recording, becomes **Saved**, reflects later removal, and reports save errors without a false saved state. The ready message alone does not save.
- [x] Assert takedown, permission revocation, expired/unavailable source, and account switch between verification and action stop use/save.
- [x] Run tests red, implement the cards/actions/route wiring, then run affected conversation, saved-sounds, and recorder-route tests green.
- [x] Commit with `feat(audio): act on sound requests and ready replies`.

### Task 6: Localization, full-flow validation, and publication

**Files:**
- Modify `mobile/lib/l10n/app_en.arb`, corresponding supported locale ARBs, and generated localization files.
- Add the feature's end-to-end integration coverage under `mobile/integration_test/` using the established local backend harness.
- Update this plan's task checkboxes with verified progress.

- [x] Add all specified request/ready copy plus pending, dismissed, retry, unavailable, and saved states using existing localization conventions. Preserve persisted fallback content across locale changes.
- [x] Run the repository's localization skills/checks and generation commands; verify all supported locales and generated files remain synchronized.
- [ ] Exercise two signed-in accounts: request from a video with sharing off, approve without the original local file, receive the ready reply, save it, then enter creation with it selected. Repeat with two requesters and a failed/retried reply.
- [x] Run affected package and app tests plus `flutter analyze lib test integration_test` from `mobile/`. Run relevant architecture, generated-file, localization, and identifier guards. Resolve failures caused by this change.
- [x] Review the whole diff against the spec, especially Review Focus cases, and commit the finished change. Do not publish a partial flow.
- [x] Load shared `PR_REVIEW.md` and `PR_REVIEW_TEAMS.md`, fetch/rebase fresh `origin/main`, and rerun affected validation after any conflict resolutions.
- [ ] Push the task branch; open one PR targeting `main` with a Conventional Commit title, concrete user behavior, and validation evidence. Request the mapped review team once and verify the request.
- [ ] Watch and inspect required/relevant checks to completion; resolve introduced failures. Return the PR URL and actual validation state, leaving merge to the authorized maintainer.
