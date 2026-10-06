# Go Live / Spaces Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a native Divine public `Go Live` / `Spaces` beta with Nostr-backed room/session/chat state, LiveKit-backed room media, mobile-first host controls, and a second slice for resilience and replay handoff.

**Architecture:** The mobile app owns discovery, room detail, native room UI, and host controls. Nostr remains the public social/state layer via NIP-53 room/session/presence/chat events. LiveKit handles the real-time video/audio transport. A thin Divine backend issues room tokens, authorizes room roles, and reports recording/replay state.

**Tech Stack:** Flutter, `flutter_bloc`, Riverpod for DI, `go_router`, `nostr_client` / `nostr_sdk`, HTTP-backed backend service, LiveKit/WebRTC client package, existing Divine camera/audio/platform services, widget tests, bloc tests, and golden tests where visual changes matter.

**Design spec:** `docs/superpowers/specs/2026-04-06-go-live-spaces-design.md` (commit `fa333cfb8`).

**Key source references:**
- `mobile/lib/router/app_router.dart` — route wiring and tab shell behavior
- `mobile/lib/screens/explore_screen.dart` — discovery entry point and tab model
- `mobile/lib/features/feature_flags/models/feature_flag.dart` — feature gates
- `mobile/lib/features/feature_flags/services/build_configuration.dart` — env mapping for flags
- `mobile/lib/providers/app_providers.dart` — dependency injection patterns
- `mobile/lib/screens/comments/comments_screen.dart` — reference for live, reactive conversation UI shape
- `mobile/lib/screens/inbox/inbox_page.dart` and `mobile/lib/screens/inbox/inbox_view.dart` — page/view split pattern for non-trivial wiring
- `mobile/lib/services/api_service.dart` — existing HTTP service conventions
- `mobile/packages/nostr_app_bridge_repository/lib/src/preloaded_nostr_apps.dart` — current Nostr app/live references

**Backend dependency note:**
This repo does not contain the Divine backend. The plan therefore includes:
- a mobile-side backend client contract,
- integration stubs and tests at the client boundary,
- and explicit TODO checkpoints where backend endpoints must exist before the mobile slice can be fully verified end to end.

---

## Chunk 1: Audience + Host Beta

### Task 1: Add explicit live feature flags and dependency scaffolding

**Files:**
- Modify: `mobile/pubspec.yaml`
- Modify: `mobile/lib/features/feature_flags/models/feature_flag.dart`
- Modify: `mobile/lib/features/feature_flags/services/build_configuration.dart`
- Test: `mobile/test/core/feature_flag_test.dart`
- Test: `mobile/test/services/build_config_test.dart`

- [ ] **Step 1: Add failing feature-flag tests for the single live gate**

Add expectations for:
- `FeatureFlag.livestreamingBeta`

Add matching environment key expectations:
- `FF_LIVESTREAMING_BETA`

- [ ] **Step 2: Run the targeted tests and verify they fail**

Run:
```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/live-spaces-v1/mobile
flutter test test/core/feature_flag_test.dart test/services/build_config_test.dart
```

Expected: FAIL because the new flags and env keys do not exist yet.

- [ ] **Step 3: Keep the live feature behind one clear flag**

Update `FeatureFlag`:
```dart
livestreamingBeta(
  'Livestream',
  'Enable livestream discovery, joining, and hosting',
),
```

Map them in `BuildConfiguration.getDefault()` and `getEnvironmentKey()`.

- [ ] **Step 4: Add the LiveKit client dependency**

Add the chosen package in `mobile/pubspec.yaml` and run:
```bash
flutter pub get
```

Document the exact package chosen in the PR/commit body. Prefer a maintained LiveKit Flutter client rather than a raw `flutter_webrtc` integration.

- [ ] **Step 5: Re-run the targeted tests and verify they pass**

Run:
```bash
flutter test test/core/feature_flag_test.dart test/services/build_config_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/pubspec.yaml \
  mobile/lib/features/feature_flags/models/feature_flag.dart \
  mobile/lib/features/feature_flags/services/build_configuration.dart \
  mobile/test/core/feature_flag_test.dart \
  mobile/test/services/build_config_test.dart \
  mobile/pubspec.lock
git commit -m "feat(live): add go live feature flags and media dependency"
```

---

### Task 2: Define the live-domain models and Nostr mapping layer

**Files:**
- Create: `mobile/lib/models/live/live_role.dart`
- Create: `mobile/lib/models/live/live_room.dart`
- Create: `mobile/lib/models/live/live_session.dart`
- Create: `mobile/lib/models/live/live_presence.dart`
- Create: `mobile/lib/models/live/live_chat_message.dart`
- Create: `mobile/lib/services/live_nostr_codec.dart`
- Test: `mobile/test/models/live/live_room_test.dart`
- Test: `mobile/test/models/live/live_session_test.dart`
- Test: `mobile/test/models/live/live_presence_test.dart`
- Test: `mobile/test/models/live/live_chat_message_test.dart`
- Test: `mobile/test/services/live_nostr_codec_test.dart`

- [ ] **Step 1: Write failing model and codec tests**

Cover:
- parsing and serializing `30312` room events
- parsing and serializing `30313` session events
- parsing and serializing `10312` presence events
- parsing and serializing `1311` chat messages
- parent-session references via `a` tags
- host/speaker/audience role derivation

Example test seed:
```dart
test('parses a live room event from kind 30312', () {
  final event = Event(
    kind: 30312,
    content: 'Public room for mobile creators',
    tags: [
      ['d', 'room-abc'],
      ['title', 'Divine Live'],
      ['image', 'https://example.com/cover.jpg'],
      ['service', 'livekit'],
    ],
    pubkey: testPubkey,
    createdAt: 1,
    id: testEventId,
    sig: testSig,
  );

  final room = LiveNostrCodec.parseRoom(event);

  expect(room.id, 'room-abc');
  expect(room.title, 'Divine Live');
});
```

- [ ] **Step 2: Run the new test files and verify they fail**

Run:
```bash
flutter test test/models/live test/services/live_nostr_codec_test.dart
```

Expected: FAIL because the models and codec do not exist.

- [ ] **Step 3: Add the model files with strict, minimal fields**

Keep fields focused:
- `LiveRoom`: id, hostPubkey, title, summary, imageUrl, relays, visibility
- `LiveSession`: id, roomId, status, startedAt, endedAt, speakerPubkeys, audienceCount
- `LivePresence`: sessionId, pubkey, role, handRaised, updatedAt
- `LiveChatMessage`: id, sessionAddress, pubkey, content, createdAt

Prefer immutable value types and keep UI-specific state out of these models.

- [ ] **Step 4: Add `LiveNostrCodec` for event conversion**

Add explicit methods:
```dart
LiveRoom parseRoom(Event event)
Event buildRoomEvent(LiveRoom room, NostrSigner signer)
LiveSession parseSession(Event event)
LivePresence parsePresence(Event event)
LiveChatMessage parseChatMessage(Event event)
```

Do not hide tag semantics inside widgets or blocs.

- [ ] **Step 5: Re-run the model/codec tests and verify they pass**

Run:
```bash
flutter test test/models/live test/services/live_nostr_codec_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/models/live \
  mobile/lib/services/live_nostr_codec.dart \
  mobile/test/models/live \
  mobile/test/services/live_nostr_codec_test.dart
git commit -m "feat(live): add live room domain models and Nostr codec"
```

---

### Task 3: Add the backend/media client boundary

**Files:**
- Create: `mobile/lib/services/live_api_service.dart`
- Create: `mobile/lib/services/livekit_room_service.dart`
- Create: `mobile/lib/models/live/live_room_token.dart`
- Create: `mobile/lib/models/live/live_room_recording.dart`
- Test: `mobile/test/services/live_api_service_test.dart`
- Test: `mobile/test/services/livekit_room_service_test.dart`

- [ ] **Step 1: Write failing service tests for the backend contract**

Cover:
- create room draft request
- start session request
- join room token fetch
- end session request
- recording status fetch

Example expectation:
```dart
test('fetchJoinToken returns a publish token for hosts', () async {
  when(() => mockApi.post('/live/rooms/room-abc/join', data: any(named: 'data')))
      .thenAnswer((_) async => {
        'token': 'jwt-token',
        'roomName': 'room-abc',
        'participantIdentity': testPubkey,
        'canPublish': true,
      });

  final token = await service.fetchJoinToken(
    roomId: 'room-abc',
    role: LiveRole.host,
  );

  expect(token.canPublish, isTrue);
});
```

- [ ] **Step 2: Run the new service tests and verify they fail**

Run:
```bash
flutter test test/services/live_api_service_test.dart test/services/livekit_room_service_test.dart
```

Expected: FAIL because the services do not exist.

- [ ] **Step 3: Add `LiveApiService` using the existing HTTP conventions**

Keep it thin. Methods should describe backend intent, not leak route strings into blocs:
```dart
Future<LiveRoomToken> fetchJoinToken(...)
Future<void> startSession(...)
Future<void> endSession(...)
Future<LiveRoomRecording?> fetchRecording(...)
```

- [ ] **Step 4: Add `LiveKitRoomService` as a wrapper around the package client**

The wrapper should expose app-level concepts:
```dart
Future<void> connect(LiveRoomToken token)
Future<void> publishLocalTracks({...})
Future<void> setCameraEnabled(bool enabled)
Future<void> setMicrophoneEnabled(bool enabled)
Future<void> switchCamera()
Future<void> disconnect()
Stream<LiveMediaState> watchState()
```

Do not let raw package types leak throughout the UI.

- [ ] **Step 5: Re-run the service tests and verify they pass**

Run:
```bash
flutter test test/services/live_api_service_test.dart test/services/livekit_room_service_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/services/live_api_service.dart \
  mobile/lib/services/livekit_room_service.dart \
  mobile/lib/models/live/live_room_token.dart \
  mobile/lib/models/live/live_room_recording.dart \
  mobile/test/services/live_api_service_test.dart \
  mobile/test/services/livekit_room_service_test.dart
git commit -m "feat(live): add backend and LiveKit service boundaries"
```

---

### Task 4: Add repositories and dependency injection

**Files:**
- Create: `mobile/lib/repositories/live_repository.dart`
- Create: `mobile/lib/repositories/live_chat_repository.dart`
- Create: `mobile/lib/providers/live_providers.dart`
- Modify: `mobile/lib/providers/app_providers.dart` (only if needed for export/integration)
- Test: `mobile/test/repositories/live_repository_test.dart`
- Test: `mobile/test/repositories/live_chat_repository_test.dart`
- Test: `mobile/test/providers/live_providers_test.dart`

- [ ] **Step 1: Write failing repository and provider tests**

Cover:
- subscribe to public room/session streams
- publish room/session events through `LiveNostrCodec`
- subscribe to chat stream for a session
- publish chat messages
- expose providers for the repositories/services

- [ ] **Step 2: Run the new tests and verify they fail**

Run:
```bash
flutter test test/repositories/live_repository_test.dart \
  test/repositories/live_chat_repository_test.dart \
  test/providers/live_providers_test.dart
```

Expected: FAIL because the repositories/providers do not exist.

- [ ] **Step 3: Implement `LiveRepository`**

Responsibilities:
- query public rooms/sessions
- publish room/session/presence events
- normalize room/session state for blocs

Do not put LiveKit concerns in this repository.

- [ ] **Step 4: Implement `LiveChatRepository`**

Responsibilities:
- subscribe to `1311` chat messages for a session
- publish chat messages
- keep room chat separate from comments

- [ ] **Step 5: Add Riverpod providers for live services and repositories**

Prefer a dedicated `live_providers.dart` file instead of stuffing everything into `app_providers.dart`.

If `@riverpod` annotations are used, run:
```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 6: Re-run the repository/provider tests and verify they pass**

Run:
```bash
flutter test test/repositories/live_repository_test.dart \
  test/repositories/live_chat_repository_test.dart \
  test/providers/live_providers_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/repositories/live_repository.dart \
  mobile/lib/repositories/live_chat_repository.dart \
  mobile/lib/providers/live_providers.dart \
  mobile/lib/providers/live_providers.g.dart \
  mobile/test/repositories/live_repository_test.dart \
  mobile/test/repositories/live_chat_repository_test.dart \
  mobile/test/providers/live_providers_test.dart
git commit -m "feat(live): add repositories and dependency wiring"
```

---

### Task 5: Add BLoCs for discovery, room, chat, and host setup

**Files:**
- Create: `mobile/lib/blocs/live_discovery/live_discovery_bloc.dart`
- Create: `mobile/lib/blocs/live_discovery/live_discovery_event.dart`
- Create: `mobile/lib/blocs/live_discovery/live_discovery_state.dart`
- Create: `mobile/lib/blocs/live_room/live_room_bloc.dart`
- Create: `mobile/lib/blocs/live_room/live_room_event.dart`
- Create: `mobile/lib/blocs/live_room/live_room_state.dart`
- Create: `mobile/lib/blocs/live_chat/live_chat_bloc.dart`
- Create: `mobile/lib/blocs/live_chat/live_chat_event.dart`
- Create: `mobile/lib/blocs/live_chat/live_chat_state.dart`
- Create: `mobile/lib/blocs/go_live/go_live_cubit.dart`
- Create: `mobile/lib/blocs/go_live/go_live_state.dart`
- Test: `mobile/test/blocs/live_discovery/live_discovery_bloc_test.dart`
- Test: `mobile/test/blocs/live_room/live_room_bloc_test.dart`
- Test: `mobile/test/blocs/live_chat/live_chat_bloc_test.dart`
- Test: `mobile/test/blocs/go_live/go_live_cubit_test.dart`

- [ ] **Step 1: Write failing bloc/cubit tests**

Cover:
- discovery loads active/upcoming rooms
- room join triggers backend token fetch + media connect
- room state reflects speaker roster and host permissions
- chat sends/receives messages
- host setup validates title and starts a room/session

- [ ] **Step 2: Run the bloc tests and verify they fail**

Run:
```bash
flutter test test/blocs/live_discovery/live_discovery_bloc_test.dart \
  test/blocs/live_room/live_room_bloc_test.dart \
  test/blocs/live_chat/live_chat_bloc_test.dart \
  test/blocs/go_live/go_live_cubit_test.dart
```

Expected: FAIL because the blocs do not exist.

- [ ] **Step 3: Implement `LiveDiscoveryBloc`**

Responsibilities:
- load active and upcoming public rooms
- surface loading, success, empty, and error states
- refresh on demand

- [ ] **Step 4: Implement `GoLiveCubit`**

Responsibilities:
- validate host form state
- create room draft or session metadata
- request host token
- produce a route-ready "session created" state

- [ ] **Step 5: Implement `LiveRoomBloc`**

Responsibilities:
- join as audience or host
- connect to media service
- subscribe to room/session/presence streams
- expose stage participants, role, audience count, reconnecting/error states

- [ ] **Step 6: Implement `LiveChatBloc`**

Responsibilities:
- start/stop chat subscription
- send chat messages
- expose unread/send/error states

- [ ] **Step 7: Re-run the bloc tests and verify they pass**

Run:
```bash
flutter test test/blocs/live_discovery/live_discovery_bloc_test.dart \
  test/blocs/live_room/live_room_bloc_test.dart \
  test/blocs/live_chat/live_chat_bloc_test.dart \
  test/blocs/go_live/go_live_cubit_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/blocs/live_discovery \
  mobile/lib/blocs/live_room \
  mobile/lib/blocs/live_chat \
  mobile/lib/blocs/go_live \
  mobile/test/blocs/live_discovery \
  mobile/test/blocs/live_room \
  mobile/test/blocs/live_chat \
  mobile/test/blocs/go_live
git commit -m "feat(live): add discovery, room, chat, and host blocs"
```

---

### Task 6: Add routes, discovery UI, room detail, room screen, and host flow

**Files:**
- Create: `mobile/lib/screens/live/live_discovery_page.dart`
- Create: `mobile/lib/screens/live/live_discovery_view.dart`
- Create: `mobile/lib/screens/live/live_room_detail_page.dart`
- Create: `mobile/lib/screens/live/live_room_detail_view.dart`
- Create: `mobile/lib/screens/live/live_room_page.dart`
- Create: `mobile/lib/screens/live/live_room_view.dart`
- Create: `mobile/lib/screens/live/go_live_page.dart`
- Create: `mobile/lib/screens/live/go_live_view.dart`
- Create: `mobile/lib/screens/live/widgets/live_room_card.dart`
- Create: `mobile/lib/screens/live/widgets/live_room_stage.dart`
- Create: `mobile/lib/screens/live/widgets/live_chat_panel.dart`
- Create: `mobile/lib/screens/live/widgets/live_host_controls_sheet.dart`
- Modify: `mobile/lib/router/app_router.dart`
- Modify: `mobile/lib/screens/explore_screen.dart`
- Test: `mobile/test/screens/live/live_discovery_page_test.dart`
- Test: `mobile/test/screens/live/live_room_detail_page_test.dart`
- Test: `mobile/test/screens/live/live_room_page_test.dart`
- Test: `mobile/test/screens/live/go_live_page_test.dart`

- [ ] **Step 1: Write failing widget/router tests**

Cover:
- Explore shows a `Live` entry when `livestreamingBeta` is enabled
- tapping a room card opens room detail
- room detail join button opens room page when `livestreamingBeta` is enabled
- `Go Live` route is available only when `livestreamingBeta` is enabled
- host controls appear for hosts, not audience members

- [ ] **Step 2: Run the screen tests and verify they fail**

Run:
```bash
flutter test test/screens/live/live_discovery_page_test.dart \
  test/screens/live/live_room_detail_page_test.dart \
  test/screens/live/live_room_page_test.dart \
  test/screens/live/go_live_page_test.dart
```

Expected: FAIL because the screens/routes do not exist.

- [ ] **Step 3: Add the new live routes to `app_router.dart`**

Recommended paths:
```dart
/live
/live/room/:roomId
/live/room/:roomId/session/:sessionId
/live/go
```

Use page/view splits for the non-trivial screens.

- [ ] **Step 4: Add the discovery entry to Explore**

Start with a clear Explore entry point rather than a brand-new tab shell.

Gate it with:
```dart
FeatureFlag.livestreamingBeta
```

- [ ] **Step 5: Build `LiveDiscoveryPage` and `LiveRoomDetailPage`**

UI requirements:
- active/upcoming sections
- clear live/scheduled state
- host name and speaker count
- join/share CTA on detail page

- [ ] **Step 6: Build `LiveRoomPage` with native room shell**

Include:
- stage area
- participant summary
- chat panel
- zap CTA
- raise hand CTA
- host controls sheet

The page can start with simple placeholders for actual remote video rendering if the media widget integration is not yet finished, but the room state wiring must be real.

- [ ] **Step 7: Build `GoLivePage`**

Include:
- room title
- summary
- optional image
- create/start CTA

Keep the host setup minimal for beta.

- [ ] **Step 8: Re-run the screen tests and verify they pass**

Run:
```bash
flutter test test/screens/live/live_discovery_page_test.dart \
  test/screens/live/live_room_detail_page_test.dart \
  test/screens/live/live_room_page_test.dart \
  test/screens/live/go_live_page_test.dart
```

Expected: PASS.

- [ ] **Step 9: Run a broader validation pass for the beta slice**

Run:
```bash
flutter test test/models/live \
  test/services/live_nostr_codec_test.dart \
  test/services/live_api_service_test.dart \
  test/services/livekit_room_service_test.dart \
  test/repositories/live_repository_test.dart \
  test/repositories/live_chat_repository_test.dart \
  test/providers/live_providers_test.dart \
  test/blocs/live_discovery/live_discovery_bloc_test.dart \
  test/blocs/live_room/live_room_bloc_test.dart \
  test/blocs/live_chat/live_chat_bloc_test.dart \
  test/blocs/go_live/go_live_cubit_test.dart \
  test/screens/live/live_discovery_page_test.dart \
  test/screens/live/live_room_detail_page_test.dart \
  test/screens/live/live_room_page_test.dart \
  test/screens/live/go_live_page_test.dart
```

Expected: PASS.

- [ ] **Step 10: Commit Chunk 1**

```bash
git add mobile/lib/router/app_router.dart \
  mobile/lib/screens/explore_screen.dart \
  mobile/lib/screens/live \
  mobile/test/screens/live
git commit -m "feat(live): add public room discovery and host beta flow"
```

---

## Chunk 2: Polish + Replay

### Task 7: Add mobile-first speaker publishing and host media controls

**Files:**
- Modify: `mobile/lib/services/livekit_room_service.dart`
- Modify: `mobile/lib/blocs/live_room/live_room_bloc.dart`
- Modify: `mobile/lib/screens/live/live_room_view.dart`
- Create: `mobile/lib/screens/live/widgets/live_local_media_controls.dart`
- Create: `mobile/lib/screens/live/widgets/live_speaker_queue_sheet.dart`
- Test: `mobile/test/blocs/live_room/live_room_bloc_test.dart`
- Test: `mobile/test/screens/live/live_room_page_test.dart`

- [ ] **Step 1: Add failing tests for local publish controls**

Cover:
- camera enable/disable
- microphone enable/disable
- switch camera
- host can promote a speaker into a publish-capable slot
- active publisher cap blocks excess video publishers

- [ ] **Step 2: Run the affected tests and verify they fail**

Run:
```bash
flutter test test/blocs/live_room/live_room_bloc_test.dart \
  test/screens/live/live_room_page_test.dart
```

Expected: FAIL until the controls and cap logic exist.

- [ ] **Step 3: Add the mobile-first controls**

Expose explicit room actions:
```dart
ToggleMicrophoneRequested()
ToggleCameraRequested()
SwitchCameraRequested()
PromoteSpeakerRequested(pubkey)
DemoteSpeakerRequested(pubkey)
```

Put them in the room page’s bottom action area and host sheet.

- [ ] **Step 4: Add a hard cap for simultaneous video publishers**

Keep this configurable in one place, for example:
```dart
const int maxActiveVideoSpeakers = 4;
```

Enforce the cap in room state, not only in the widget tree.

- [ ] **Step 5: Re-run the tests and verify they pass**

Run:
```bash
flutter test test/blocs/live_room/live_room_bloc_test.dart \
  test/screens/live/live_room_page_test.dart
```

Expected: PASS.

---

### Task 8: Add reconnect, app-lifecycle, and audio-only fallback handling

**Files:**
- Modify: `mobile/lib/services/livekit_room_service.dart`
- Modify: `mobile/lib/blocs/live_room/live_room_state.dart`
- Modify: `mobile/lib/blocs/live_room/live_room_bloc.dart`
- Modify: `mobile/lib/providers/app_lifecycle_provider.dart` or add a live-specific bridge
- Test: `mobile/test/services/livekit_room_service_test.dart`
- Test: `mobile/test/blocs/live_room/live_room_bloc_test.dart`

- [ ] **Step 1: Write failing tests for reconnect and degraded network state**

Cover:
- reconnecting state surfaces in the bloc
- host can fall back to audio-only
- app background/foreground transitions do not immediately end the room session

- [ ] **Step 2: Run the affected tests and verify they fail**

Run:
```bash
flutter test test/services/livekit_room_service_test.dart \
  test/blocs/live_room/live_room_bloc_test.dart
```

Expected: FAIL until reconnect and fallback logic exist.

- [ ] **Step 3: Add explicit media lifecycle states**

Add states such as:
- `connecting`
- `connected`
- `reconnecting`
- `audioOnly`
- `failed`

Do not collapse all failures into a generic "error."

- [ ] **Step 4: Bridge app lifecycle into room behavior**

When the app backgrounds:
- audience attempts clean suspend/resume
- host does not immediately destroy the session locally

Avoid arbitrary delays. Use explicit lifecycle and media callbacks.

- [ ] **Step 5: Add audio-only fallback action**

Expose a single, obvious action from the UI and the bloc:
```dart
EnableAudioOnlyRequested()
```

- [ ] **Step 6: Re-run the tests and verify they pass**

Run:
```bash
flutter test test/services/livekit_room_service_test.dart \
  test/blocs/live_room/live_room_bloc_test.dart
```

Expected: PASS.

---

### Task 9: Add recording/replay handoff for ended sessions

**Files:**
- Modify: `mobile/lib/services/live_api_service.dart`
- Modify: `mobile/lib/repositories/live_repository.dart`
- Modify: `mobile/lib/blocs/live_room/live_room_bloc.dart`
- Modify: `mobile/lib/screens/live/live_room_detail_view.dart`
- Create: `mobile/lib/screens/live/widgets/live_replay_banner.dart`
- Test: `mobile/test/services/live_api_service_test.dart`
- Test: `mobile/test/repositories/live_repository_test.dart`
- Test: `mobile/test/screens/live/live_room_detail_page_test.dart`

- [ ] **Step 1: Write failing tests for ended-session replay handoff**

Cover:
- backend recording status maps into repository state
- ended room detail shows a replay banner/link when recording exists
- no replay UI appears when recording is absent

- [ ] **Step 2: Run the affected tests and verify they fail**

Run:
```bash
flutter test test/services/live_api_service_test.dart \
  test/repositories/live_repository_test.dart \
  test/screens/live/live_room_detail_page_test.dart
```

Expected: FAIL until replay mapping exists.

- [ ] **Step 3: Add recording fetch/state plumbing**

Use a small model:
```dart
class LiveRoomRecording {
  final String playbackUrl;
  final RecordingStatus status;
}
```

Do not build a full archive browser in this slice.

- [ ] **Step 4: Surface replay only on ended sessions**

Use room detail as the primary place for replay handoff. Keep the live room screen focused on active sessions.

- [ ] **Step 5: Re-run the tests and verify they pass**

Run:
```bash
flutter test test/services/live_api_service_test.dart \
  test/repositories/live_repository_test.dart \
  test/screens/live/live_room_detail_page_test.dart
```

Expected: PASS.

---

### Task 10: Add golden/manual QA coverage and final verification

**Files:**
- Create or modify: `mobile/test/goldens/screens/live/*`
- Create: `mobile/test/manual/live_spaces_mobile_qa.md`
- Modify: `mobile/docs/GOLDEN_TESTING_GUIDE.md` only if new live-screen guidance is needed

- [ ] **Step 1: Add or update live-screen widget/golden tests**

Cover:
- discovery cards
- room detail
- room page host vs audience controls
- replay banner state

- [ ] **Step 2: Run the golden verification flow**

Run:
```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/live-spaces-v1/mobile
scripts/golden.sh verify
```

Expected: PASS, or intentional golden updates reviewed and committed.

- [ ] **Step 3: Add a focused manual QA checklist**

Document:
- host from mobile phone
- camera flip while live
- audio-only fallback
- reconnect on weak network
- audience join/leave churn
- replay banner after session end

- [ ] **Step 4: Run the broad verification suite**

Run:
```bash
flutter test test/models/live \
  test/services/live_nostr_codec_test.dart \
  test/services/live_api_service_test.dart \
  test/services/livekit_room_service_test.dart \
  test/repositories/live_repository_test.dart \
  test/repositories/live_chat_repository_test.dart \
  test/providers/live_providers_test.dart \
  test/blocs/live_discovery/live_discovery_bloc_test.dart \
  test/blocs/live_room/live_room_bloc_test.dart \
  test/blocs/live_chat/live_chat_bloc_test.dart \
  test/blocs/go_live/go_live_cubit_test.dart \
  test/screens/live/live_discovery_page_test.dart \
  test/screens/live/live_room_detail_page_test.dart \
  test/screens/live/live_room_page_test.dart \
  test/screens/live/go_live_page_test.dart
flutter analyze
```

Expected: PASS.

- [ ] **Step 5: Commit Chunk 2**

```bash
git add mobile/lib/services/live_api_service.dart \
  mobile/lib/services/livekit_room_service.dart \
  mobile/lib/repositories/live_repository.dart \
  mobile/lib/blocs/live_room \
  mobile/lib/screens/live \
  mobile/test/services/live_api_service_test.dart \
  mobile/test/services/livekit_room_service_test.dart \
  mobile/test/repositories/live_repository_test.dart \
  mobile/test/blocs/live_room/live_room_bloc_test.dart \
  mobile/test/screens/live \
  mobile/test/goldens/screens/live \
  mobile/test/manual/live_spaces_mobile_qa.md
git commit -m "feat(live): harden mobile hosting and add replay handoff"
```

---

## Execution Notes

- Keep the feature module isolated. Do not splice live chat into the existing comments stack.
- Keep repositories free of Flutter UI types.
- Prefer page/view splits for live screens with non-trivial wiring.
- Use `FeatureFlag.livestreamingBeta` as the single on or off gate for the live rollout.
- If the backend contract is missing, implement the mobile client boundary first with fakes/mocks and stop before wiring end-to-end token exchange.
- If LiveKit package constraints create platform issues, isolate the package behind `LiveKitRoomService` and keep bloc/screen code unchanged.

## Suggested PR Strategy

If implementation begins immediately, prefer two PRs:

1. `feat(live): add public room discovery and host beta flow`
2. `feat(live): harden mobile hosting and add replay handoff`

This matches the approved compressed rollout without forcing one monolithic change set.
