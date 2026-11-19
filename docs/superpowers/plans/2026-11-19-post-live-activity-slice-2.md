# Post Live Activity, slice 2: making it run — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Start the post Live Activity when a post is handed to the publisher. Move it to live on publish and register it with the push service. End it on every path the design names. Give people the toggle and Stop. Make the tap land on that post's stats, with honest states.

**Architecture:**
- **One device-level owner.**
  - A Runner plugin (Swift, ActivityKit) is the only code that touches activities.
  - A pure-Dart `post_live_activity_repository` package owns every rule, behind two ports: the platform and the registrar.
  - The channel wrapper, registrar and repository are created once in `DeviceScope` and handed to every account container, like the database. Activities and their prefs belong to the device, and an event channel must have one listener.
- **Each account container:**
  - attaches its push identity to the registrar while it is the active account;
  - drives the repository from `BackgroundPublishBloc`;
  - ends its activities on the device when it signs out or is switched away.
- **The server is told an activity ended only while its account is signed in and the app is running.** On sign-out, account switch or a closed-app dismissal, the server finishes its hour on its own. The design doc's *When the server is told an activity ended* records why and the tradeoffs.
- **The post stats screen's loading moves into a cubit.**

**Tech Stack:** Swift / ActivityKit (iOS 16.2+, weak-linked), Flutter BLoC, Riverpod (composition only), go_router typed routes, SharedPreferences, NIP-44 kind 3079.

**Spec:** `docs/superpowers/specs/2026-11-18-post-live-activity-design.md` (*Turning it on and off*, *Mobile*, *When the server is told an activity ended*, *Token protocol*). Slice 1 plan: `docs/superpowers/plans/2026-11-18-post-live-activity-widget-ui.md`. Three code cross-checks on 2026-11-19 are folded in.

## Global Constraints

**Platform**
- iOS only.
  - Dart entry points no-op off iOS and on web.
  - Swift entry points are `@available(iOS 16.2, *)` and answer "not enabled" below it.
  - The deployment target stays 16.0.
- No `NSSupportsLiveActivitiesFrequentUpdates`.
- `pushType: .token` on every request.
- Handle `ActivityState` with `@unknown default`.

**Lifecycle**
- One running post activity per device. A newer post ends the old one immediately, with no summary.
- Settle point: `postedAt` + 10 min. Window: `postedAt` + 60 min. Summary dismissal: window end + 30 min.
- **`postedAt` is the device time the publish succeeded.** It drives the registration, the window and the stats screen's fallback.
  - It is never the signed event's `created_at`. A retry can reuse a signed event from hours earlier. A post scheduled within 2 minutes is signed with a future time.
  - The activity's own attribute is `startedAt`, and the Lock Screen counts from it.
- **Echo rules** (one sender, no doubles):
  - The repository drops an activity's tracking *before* calling `platform.end`.
  - It ignores state events for activity ids it isn't tracking.
  - It ignores state events after an activity's window end.
  - Only a `dismissed` state tells the server. An `ended` state, which the server's own end produces, only stops tracking.
- **Ordering per activity:**
  - Platform operations are serialized.
  - Before an `ended` registration goes out, retry timers are cancelled and any in-flight send is awaited, so an `active` can never arrive after its `ended`.
  - An activity counts as registered once any attempt was `published` or `uncertainFailure`, since the relay may have stored it.
- **Foreground first:** nothing network-bound runs between the publish request and `Activity.request`. Ended registrations for replaced activities are sent detached.
- **Stale date:** `start` and `update` set `staleDate` to now + 10 min, so a suspended "Posting…" or a silent server reads as stale.

**Content and copy**
- Content state carries no display strings: numbers, enums and identifiers only.
- New app strings go through `context.l10n`, read in the same change, and mirrored to all 23 `app_*.arb`.

**Notifications and wire format**
- A Live Activity registration never enrolls someone who declined notifications into notification pushes.
- Ending is a 3079 with `state: ended`, never a 3080.
- The registrar signs only as the account that owns the registration. Any other case is skipped silently, never reported as a failure.
- The wire format is the design's proposal, pending Daniel's review. It lives in Task 2's model and Task 5's encoder.

**Storage and logging**
- The toggle and the first-run marker are device-scoped prefs, declared in `deviceScopedPrefsKeys`. Nothing else is persisted.
- Never truncate pubkeys, event ids or coordinates in logs. Pubkeys go through `pubkeyForLogs`.

**Release**
- This PR merges only after the push service's Live Activity support is in production.
- The release checklist says the same (Task 12).

## Review Focus

1. **Account switch or sign-out mid-hour.** The activity leaves the Lock Screen at once, even when the sign-out teardown budget is spent, and never shows under the next account. (**RF1**)
2. **Toggle turned on after posts were published while it was off.** It doesn't start an activity for an earlier post. (**RF2**)
3. **Lock Screen dismissal while the app is running.** The server is told once. A dismissal while the app is closed isn't reported, which is accepted. (**RF3**)
4. **Scheduled posts.** None start an activity while still scheduled. A retry after the scheduled time is a normal post. (**RF4**)
5. **The publish finishing before the activity has started.** The activity still goes live. (**RF5**)

---

### Task 0: Post identity moves into content state; `postedAt` becomes `startedAt`

Verified: neither the post's `d` tag (the uploaded file's hash) nor its event id exists when the publish is requested.

**Files:**
- `mobile/ios/Shared/PostLiveActivity/PostActivityAttributes.swift`
- `PostActivityDisplay.swift`
- `PostActivityViews.swift`
- `mobile/ios/CameraQuickActionWidget/PostLiveActivityWidget.swift`
- `PostActivityDisplayTests.swift`
- `PostActivityViewsTests.swift`
- The slice 1 plan's attribute list

**Interfaces (Produces):**
- `PostActivityAttributes { ownerPubkey: String, thumbnailFileName: String?, startedAt: Date }`.
- `PostActivityContentState` gains `postCoordinate: String?` and `postEventId: String?`. Both decode as nil when absent.
- `PostActivityLink.url(postEventId: String?, postCoordinate: String?) -> URL?` returns nil unless both are non-empty.
  - The widget sets no `widgetURL` then.
- Views that read `postedAt` read `startedAt`.

**Steps:**
- [ ] Write the failing tests:
  - `testLinkIsNilWhileThePostHasNoIdentity`;
  - `testContentStateDecodesWithoutPostIdentity`;
  - renamed attribute usages in the existing tests.
- [ ] Run them and confirm they fail.
- [ ] Implement.
- [ ] Run the full `RunnerTests` and confirm they pass.
- [ ] Commit `fix(ios): give the post Live Activity its post identity after publish`.

### Task 1: The Runner plugin

**Files:**
- Create: `mobile/ios/Runner/PostLiveActivityPlugin.swift`, `mobile/ios/Runner/PostActivityThumbnailWriter.swift`.
- Modify: `AppDelegate.swift` (register beside `NostrBridgeAttestationPlugin.setup`), `project.pbxproj`.
- Test: `mobile/ios/RunnerTests/PostLiveActivityPluginTests.swift`.

**Interfaces:**

Method channel `divine/post_live_activity`:
- `isEnabled` → `Bool`.
- `writeThumbnail {bytes}` → `String`.
  - The name is `UUID().uuidString + ".jpg"`, never caller-supplied.
  - The image is at most 144 px on its longest side, JPEG quality 0.7.
  - It is written to `<group.co.openvine.app>/LiveActivityThumbnails/`.
  - Every other file there is deleted. The repository calls this only after it has immediately ended everything `list()` returns, including activities in the `ended` state that are still showing a summary.
- `start {ownerPubkey, thumbnailFileName?, showFirstRunNote}` → activity id.
  - `startedAt` is now; `staleDate` is now + 10 min.
  - Phase is `posting`; counts and identity are nil.
- `update {activityId, phase, postCoordinate?, postEventId?, showFirstRunNote}` → null. Never touches counts; refreshes `staleDate` to now + 10 min.
- `end {activityId, immediate}` → null.
- `list` → `[{activityId, ownerPubkey, startedAtMs, postCoordinate?, postEventId?, state}]`.

Event channel `divine/post_live_activity/events`:
- Events:
  - `enablement {enabled}`
  - `pushToken {activityId, token}` (lowercase hex)
  - `state {activityId, state}`, with `state` ∈ `active | ended | dismissed | stale`
- Behaviour:
  - At launch it observes `pushTokenUpdates` and `activityStateUpdates` for every existing activity.
  - In the stream handler's **`onListen`**, it replays each existing activity's current `activity.pushToken` (when non-nil) and its state.

Pure pieces:
- `PostActivityStartArguments(_:)`
- `PostActivityUpdateArguments(_:)`
- `PostActivityThumbnailWriter.write(_:containerURL:)`
- `PostActivityPushToken.hex(_:)`
- An activity source protocol, so `onListen` can be tested.

**Steps:**
- [ ] Write the failing tests:
  - the parsers accept the full shapes and reject missing or mistyped keys;
  - the thumbnail writer uses its own name and clears old files;
  - the push token hex is lowercase;
  - `onListen` replays current tokens.
- [ ] Run them and confirm they fail.
- [ ] Implement, using the error codes `bad_args` and `activity_failed`.
- [ ] Run the full `RunnerTests` and a simulator build.
- [ ] Commit `feat(ios): add the post Live Activity bridge`.

### Task 2: `post_live_activity_repository` — package, models, ports

**Files:**
- Create `mobile/packages/post_live_activity_repository/`:
  - `pubspec.yaml`:
    - runtime: `shared_preferences`, `unified_logger`, `equatable`, `nostr_sdk` (for `pubkeyForLogs`);
    - dev: `flutter_test`, `fake_async`, `mocktail`, `very_good_analysis`.
  - `analysis_options.yaml`: `very_good_analysis`, with no relaxations.
  - The barrel file.
  - `lib/src/models/`.
  - `lib/src/live_activity_platform.dart`.
  - `lib/src/live_activity_registrar.dart`.
- `.github/workflows/post_live_activity_repository.yaml`: copy `badge_repository.yaml`, with a 100% coverage floor.
- `mobile/pubspec.yaml`: workspace entry and dependency.
- Regenerate `mobile/scripts/baseline/package_coverage_floors.txt`.

**Interfaces (Produces):**
- `enum LiveActivityPhase { posting, live, notFound, summary }`
- `enum LiveActivityState { active, ended, dismissed, stale }`
- `class RunningLiveActivity { id, ownerPubkey, startedAt, postCoordinate?, postEventId?, state }`
- `sealed class LiveActivityPlatformEvent`:
  - `EnablementChanged(bool)`
  - `PushTokenChanged(String activityId, String token)`
  - `ActivityStateChanged(String activityId, LiveActivityState)`
- `abstract interface class LiveActivityPlatform`:
  - `isEnabled()`, `events`, `writeThumbnail(Uint8List)`;
  - `start({ownerPubkey, thumbnailFileName?, showFirstRunNote})`;
  - `update(id, {phase, postCoordinate?, postEventId?, showFirstRunNote})`;
  - `end(id, {immediate})`, `list()`.
- `enum LiveActivityRegistrationState { active, ended }`
- `class LiveActivityRegistration { activityId, ownerPubkey, activityPushToken, postCoordinate, List<String> postEventIds, postedAt, windowEndsAt, showFirstRunNote, state }`:
  - `forPost(...)` sets `windowEndsAt = postedAt + 60 min`;
  - `ended()` returns a copy in the ended state;
  - `liveActivityWire()` produces the `liveActivity` object only.
- `enum LiveActivityRegistrarResult { published, retryLater, skipped, failed }`
  - `skipped` means "not this account's to send". It is silent and not retried.
- `abstract interface class LiveActivityRegistrar { Future<LiveActivityRegistrarResult> register(LiveActivityRegistration r); }`
- `typedef PostLiveActivityErrorReporter = void Function(Object error, StackTrace stack, {required String site});`

**Steps:**
- [ ] Write the failing model tests: equality, the window, and the exact keys of `liveActivityWire`.
- [ ] Run them and confirm they fail.
- [ ] Implement.
- [ ] Run the package tests with coverage and `check_package_ci_floor.sh`, then regenerate the floor.
- [ ] Commit `feat(live-activity): add the post Live Activity repository package`.

### Task 3: `PostLiveActivityRepository` — the rules

**Files:**
- `lib/src/post_live_activity_repository.dart`
- `lib/src/post_live_activity_prefs_keys.dart`
- `lib/src/post_live_activity_reportable_sites.dart`
- Test: `test/src/post_live_activity_repository_test.dart`, with a fake platform and registrar, `fake_async` and `SharedPreferences.setMockInitialValues`.

**Interfaces (Produces):**
- `PostLiveActivityPrefsKeys`:
  - `enabled = 'post_live_activity_enabled'`;
  - `firstRunNoteShown = 'post_live_activity_first_run_note_shown'`;
  - `deviceScopedPrefsKeys = [enabled, firstRunNoteShown]`.
- `PostLiveActivityRepository({required LiveActivityPlatform platform, required LiveActivityRegistrar registrar, required SharedPreferences sharedPreferences, DateTime Function()? now, PostLiveActivityErrorReporter? errorReporter})`.
- `bool featureEnabled` (settable, default `true`): the app sets it from `FeatureFlag.postLiveActivity`. When false, nothing starts and `sweep` ends rather than re-adopts.
- Toggle and system switch:
  - `bool get isToggleOn`, default `true`;
  - `Future<void> setToggleOn(bool)`;
  - `Future<bool> isSystemEnabled()`;
  - `Stream<bool> get systemEnabledChanges`.
- Publish lifecycle:
  - `void startPosting({required String key, required String ownerPubkey, required Future<Uint8List?> thumbnail})`:
    - synchronous;
    - records the pending start under `key` (the draft id) before any await.
  - `Future<void> markLive({required String key, required String postCoordinate, required String postEventId})`.
  - `Future<void> end({required String key})`: the publish failed or is still scheduled. Ends the activity and tells the server if it had registered.
- Per-post:
  - `Future<void> stopForPost(String postCoordinate)`;
  - `Future<bool> isRunningFor(String postCoordinate)`;
  - `Future<DateTime?> postedAtFor(String postCoordinate)`;
  - Both fall back to `platform.list()` (coordinate and `startedAt`) when the activity is not tracked yet, which covers a cold start from a tap before the sweep has run.
  - `Future<void> noteEdited({required String postCoordinate, required String newEventId})`.
- Bulk and housekeeping:
  - `Future<void> endAll()`: toggle-off. Tells the server for each registered activity.
  - `Future<void> endLocally({required String ownerPubkey})`: sign-out and switch.
    - Synchronously cancels that owner's pending starts, retry timers and tracking.
    - Then ends immediately every activity `list()` returns for that owner, tracked or not.
    - Never registers.
  - `Future<void> sweep({required String? currentOwnerPubkey})`. A null owner (signed out) ends everything listed.
  - `Future<void> dispose()`.

**Rules, one test each:**

*Starting*
- `startPosting does nothing when the toggle is off` / `when the system switch is off`.
- `startPosting ends everything list() returns (including ended activities still showing a summary), sends ended for any registered one detached, then writes the thumbnail and starts`, with no network wait before the start.
- `the first-run note shows on the first start only`. The marker is written after the platform start succeeds.
- `a start that returns after its key was cancelled or superseded is ended immediately and not tracked`: sign-out mid-start, toggle-off mid-start, and two quick posts (only the second survives).
- `markLive and end for a superseded key do nothing`.
- `a failed platform start clears the pending key`, so later `markLive` and `end` do nothing.

*The publish race*
- `markLive awaits a start still in flight for the same key, then goes live` (**RF5**).
- `end awaits a start in flight, then ends`.
- `markLive for a key that never started does nothing`.

*Registration*
- `markLive sets postedAt to now, updates the platform with identity, and registers once a token exists`.
- `a token for an id start has not returned yet is buffered and applied when it returns`.
- A rotated token re-registers.
- `retryLater is retried with backoff 15 s, 30 s, 60 s, 120 s, then every 300 s until the window ends`.
- `skipped is neither retried nor reported`.
- `failed is reported (site: register) and not retried`.
- `an ended registration waits for an in-flight active send and cancels its retries first`.
- `an activity whose only attempt was uncertainFailure counts as registered`, so ending it still tells the server.
- In every case the activity stays up.

*Echoes and state events*
- `an app-initiated end does not send a second ended when its ended state event echoes back`.
- `ActivityStateChanged dismissed for a tracked activity inside its window sends ended once and stops tracking, without calling platform.end` (**RF3**).
- `ActivityStateChanged ended stops tracking and sends nothing`: the server ended it (summary or not found), so it already knows.
- `stale is ignored`.
- `state events after the window end are ignored`.

*Ending*
- `end and stopForPost end immediately and send ended when registered`.
- `setToggleOn(false) ends every running activity and tells the server`.
- `setToggleOn(true) starts nothing` (**RF2**).
- `endLocally ends only that owner's activities, cancels their retries, and sends nothing` (**RF1**).

*Sweep*
- `sweep ends, on the device, listed activities of another owner, all of them when signed out, and any past startedAt + 90 min`. Measuring from `startedAt` cuts a summary short by the upload time, which is accepted.
- `sweep re-adopts the current owner's untracked live activity`, from `list()` identity and the replayed token, when the toggle and the feature are on and its window (from `startedAt`) has not passed. It registers with `postedAt` = `startedAt`, an approximation. Otherwise it ends it.
- `sweep ends an untracked activity with no identity that started over 15 min ago`. The app was killed mid-publish; the publish flow already surfaces the interrupted upload.

*Edits*
- `noteEdited re-registers with the new id appended`, only for the matching coordinate.

**Steps:**
- [ ] Write the failing tests above.
- [ ] Run them and confirm they fail.
- [ ] Implement:
  - in-memory `_Tracked` records keyed by draft key and by activity id;
  - a pending-start map, registered synchronously;
  - a token buffer;
  - an in-flight set;
  - a serial queue for platform operations;
  - timers tested with `fake_async`, window maths through the injectable `now`.
- [ ] Reach 100% coverage.
- [ ] Commit `feat(live-activity): decide when the post Live Activity starts, registers and ends`.

### Task 4: Device-level wiring, channel, registrar, feature flag

**Files:**
- Create:
  - `mobile/lib/services/post_live_activity_channel.dart`;
  - `mobile/lib/services/post_live_activity_registrar.dart`;
  - `mobile/lib/providers/post_live_activity_providers.dart`.
- Modify:
  - `mobile/lib/providers/device_scope.dart`: an optional `PostLiveActivityDevice? postLiveActivity` field, holding the channel, registrar and repository, plus its override;
  - `mobile/lib/startup/app_bootstrap.dart` (around line 749): construct it on iOS;
  - `mobile/lib/features/feature_flags/models/feature_flag.dart`;
  - `mobile/lib/features/feature_flags/services/build_configuration.dart`.
- Tests:
  - `mobile/test/services/post_live_activity_channel_test.dart`;
  - `mobile/test/services/post_live_activity_registrar_test.dart`;
  - `mobile/test/providers/device_scope_test.dart`.
  - The 10 existing `DeviceScope` constructions (5 test files) keep compiling, because the field is optional.

**Interfaces:**

`PostLiveActivityChannel implements LiveActivityPlatform`:
- Constructor: `{MethodChannel? methodChannel, EventChannel? eventChannel, bool Function()? isSupported}`.
- One broadcast `events` stream.
- When unsupported:
  - `isEnabled` returns false;
  - `start` throws `UnsupportedError`;
  - everything else no-ops;
  - `events` is empty.
- Malformed events are logged and dropped.

`PostLiveActivityRegistrar implements LiveActivityRegistrar`:
- `Object attach(LiveActivityAccountBinding binding)` returns a handle. `void detach(Object handle)` removes only that binding. Bindings are kept per owner.
- `LiveActivityAccountBinding { String ownerPubkey; PushNotificationService? Function() readPushService; Future<bool> Function() readNotificationsAuthorized; bool Function() isActiveAccount; }`.
- `register(r)` returns:
  - `retryLater` when no binding exists yet for `r.ownerPubkey` (the account is still getting ready), or the push service is null;
  - `skipped` when the binding's account is no longer active (switched away or signed out);
  - otherwise it calls `registerLiveActivity` (Task 5) and maps the result:
    - `published` → `published`;
    - `retryableFailure` → `retryLater`;
    - `uncertainFailure` → `retryLater`, reported to the repository as possibly stored;
    - `terminalFailure` → re-check the binding: if the account changed mid-flight, `skipped`; otherwise `failed`.

Providers:
- `postLiveActivityRepositoryProvider`: a nullable value, default `null`, overridden from `DeviceScope`.

Feature flag:
- `FeatureFlag.postLiveActivity('Post Live Activity', 'Follow a just-published post on the Lock Screen and in the Dynamic Island (iOS).')`.
- Environment key `FF_POST_LIVE_ACTIVITY`, default `true`, `audience: FeatureFlagAudience.internal`: the server is the kill switch and the Notification settings toggle is the person's control, so the flag isn't shown to users.

**Steps:**
- [ ] Write the failing tests:
  - each channel method sends the right arguments;
  - `list` parses all four states;
  - malformed events are dropped;
  - an unsupported platform never touches the channel;
  - channel handlers are cleared in `tearDown`;
  - each registrar rule, including no binding yet → `retryLater`, an account changed mid-flight → `skipped`, and A→B→A where detaching the first A's handle leaves the second A's binding;
  - two containers get the same repository from `DeviceScope`.
- [ ] Run them and confirm they fail.
- [ ] Implement.
- [ ] Run `flutter analyze lib test`.
- [ ] Commit `feat(live-activity): wire the post Live Activity bridge at device level`.

### Task 5: Registration over kind 3079

**Files:**
- Modify: `mobile/lib/services/push_notification_service.dart`.
- Test: `mobile/test/services/push_notification_service_live_activity_test.dart`.

**Interfaces:**
- `Future<PushRegistrationResult> registerLiveActivity(String userPubkey, LiveActivityRegistration r, {required bool notificationsAuthorized})`.
  - It runs on the normal, session-current path.
  - It logs with its own action label: "live activity".
- `notificationsAuthorized` is true for `authorized` and `provisional`, false for `denied` and `notDetermined`. Those are the four `AuthorizationStatus` values in the locked firebase_messaging.
- The registration payload builder is extracted from `_publishRegistration`, not copied, so the existing fields stay identical.
- The plaintext is today's registration payload, plus a top-level `notificationsAuthorized` and the `liveActivity` object, exactly as the spec's *Token protocol* shows.
  - Today's payload is `token`, `timezoneOffsetMinutes`, `campaignTargetTypes`, and `timezone` when known.
  - It is encrypted with NIP-44 to `pushServicePubkey`, with the same tags and expiration as today.

**Steps:**
- [ ] Write the failing tests:
  - decrypt the payload and assert the existing fields are unchanged, plus `notificationsAuthorized` and `liveActivity`;
  - the mapping for all four permission statuses;
  - `state: ended` is sent;
  - the kind is 3079 for both states, never 3080;
  - no FCM token → `retryableFailure`.
- [ ] Run them and confirm they fail.
- [ ] Implement.
- [ ] Run them again.
- [ ] Commit `feat(push): register a post Live Activity with the push service`.

### Task 6: Publish flow drives the activity

**Files:**
- Modify:
  - `mobile/lib/blocs/background_publish/background_publish_bloc.dart`;
  - `mobile/lib/providers/video_publish_provider.dart`: `_willBeScheduled` becomes a top-level `willBeScheduled(DivineVideoDraft draft, ScheduledPostsRepository? repository)`, used by both;
  - `mobile/lib/startup/app_composition_root.dart`;
  - `mobile/lib/services/video_metadata_update_service.dart` and its construction in `mobile/lib/providers/video_providers.dart`.
- Tests:
  - `mobile/test/blocs/background_publish_bloc/background_publish_bloc_live_activity_test.dart`;
  - `mobile/test/services/video_metadata_update_service_test.dart`.

**Interfaces:**
- `BackgroundPublishBloc({..., PostLiveActivityRepository? liveActivity, String? Function()? currentOwnerPubkey, bool Function(DivineVideoDraft draft)? isScheduledDraft})`.
  - Injected at `app_composition_root.dart` with:
    - `liveActivity`: the device repository (null off iOS). The flag is enforced by the repository's `featureEnabled`, kept in sync by Task 7, because this bloc is created once per container;
    - `currentOwnerPubkey: () => ref.read(authServiceProvider).currentPublicKeyHex`, read at call time (the `authService` captured in `build` can go stale);
    - `isScheduledDraft: (d) => willBeScheduled(d, ref.read(scheduledPostsRepositoryProvider))`.
  - No new state fields.
- On `BackgroundPublishRequested`, only when the draft is not already uploading and is not scheduled, call `liveActivity.startPosting(key: draft.id, ownerPubkey: owner, thumbnail: _readCoverThumbnail(draft))`.
  - The call is synchronous, with the thumbnail passed as a future.
  - It also covers retries, which re-add the same event.
- On `PublishSuccess`:
  - Take the coordinate from `signedEventBody` (`kind`, `pubkey`, `d` tag).
  - If the body is null, build it from `NIP71VideoKinds.addressableShortVideo`, the owner and `stableId`, with `eventId`.
  - If neither is available, call `end`.
  - Otherwise call `markLive`.
- On `PublishScheduled`, `PublishError` or `BackgroundPublishVanished`, call `end`.
- On a successful metadata edit, call `noteEdited(coordinate, updatedEvent.id)`.
- Every repository future (`markLive`, `end`, `noteEdited`) goes through `runDetached(future, '<description>', logName: 'BackgroundPublishBloc', category: <the bloc's log category>)`, since `discarded_futures` is enabled.

**Tests:**
- `starts an activity keyed by draft id`; `a duplicate request for a draft already uploading starts nothing`.
- `does not start one for a draft still scheduled, including on retry before its time; a retry after its time does` (**RF4**).
- `ends it on PublishScheduled, PublishError and BackgroundPublishVanished`.
- `marks it live from the signed event`.
- `falls back to stableId and eventId when the body is null`.
- `a publish that settles before the start returns still goes live` (**RF5**). Uses the real repository with a slow fake platform.
- `with no repository injected, behaves as before`.
- `a Live Activity failure never fails a publish`.
- Metadata update: `noteEdited on success only`.

**Steps:**
- [ ] Write the failing tests.
- [ ] Run them and confirm they fail.
- [ ] Implement.
- [ ] Run the background publish tests and `flutter analyze lib test`.
- [ ] Commit `feat(live-activity): start the post Live Activity with the publish and follow it`.

### Task 7: Per-account wiring and ending on account exit

**Files:**
- Modify:
  - `mobile/lib/providers/post_live_activity_providers.dart`;
  - `mobile/lib/startup/app_side_effects.dart`: watch `postLiveActivitySyncProvider` beside `pushNotificationSyncProvider`;
  - `mobile/lib/providers/swap_account.dart`.
- Tests:
  - `mobile/test/providers/post_live_activity_providers_test.dart`;
  - `mobile/test/providers/swap_account_test.dart`.

**Behaviour:**

`postLiveActivitySync` runs per account and stays alive. It does five things:
1. Attaches the registrar binding while the account is ready, and detaches by handle on dispose. Registrations made before it attaches get `retryLater`, so nothing is lost while the account gets ready.
2. Ends the account's activities on the device when it stops being the signed-in identity, so the local end does not depend on the sign-out teardown budget. The trigger is precise: the auth identity becomes null, its pubkey differs from the owner, or the session phase becomes `tearingDown` or `signedOut`. A `nostrReady` → `identityKnown` drop never ends anything.
3. Also registers `registerBeforeSessionTeardownCallback(() => repo.endLocally(ownerPubkey: owner))` as an earlier best effort.
4. On resume, and once after the binding attaches, runs `sweep`, via `runProviderDetached` and only while its container is `deviceScope.switchController.currentContainer`. On a signed-out cold start, a sweep with a null owner ends everything listed.
5. Keeps `repo.featureEnabled` in sync with `FeatureFlag.postLiveActivity`. When the flag turns off, calls `endAll()`.

Account switch:
- In `swapAccount`, right after commit, call `endLocally(ownerPubkey: outgoing)` on the device repository directly, whether or not there is an outgoing push coordinator.

**Steps:**
- [ ] Write the failing tests:
  - sign-out ends the activity locally even when the teardown budget is exhausted before the callback runs (**RF1**);
  - a switch ends the outgoing account's activities at commit with no outgoing coordinator present;
  - the incoming account's sweep ends anything left over;
  - with the flag off there is no binding, and running activities end;
  - resume sweeps only in the current container.
- [ ] Run them and confirm they fail.
- [ ] Implement.
- [ ] Run them again.
- [ ] Commit `feat(live-activity): end the post Live Activity when its account leaves`.

### Task 8: The toggle in Notification settings

**Files:**
- Create: `mobile/lib/blocs/post_live_activity_settings/post_live_activity_settings_cubit.dart`, plus its state.
- Modify: `mobile/lib/screens/notification_settings_screen.dart`, and the 23 `app_*.arb`.
- Tests: the cubit test, and `mobile/test/screens/notification_settings_screen_test.dart`.

**Interfaces:**
- `PostLiveActivitySettingsCubit({required PostLiveActivityRepository repository})`.
  - State: `{bool toggleOn, bool systemEnabled}`.
  - Methods: `load()` and `setToggleOn(bool)`.
  - Uses `CloseGuardedEmit`.
  - Its `BlocProvider` is keyed with `ValueKey(repository)`.
- The settings row:
  - goes after campaigns;
  - is shown only when the flag is on and the repository is non-null;
  - is a `DivineSwitchTile` whose value is `toggleOn && systemEnabled`;
  - is disabled when `!systemEnabled`, with the unavailable subtitle.

**Copy** (Tier 2 self-checked; Tier 3 requested in the PR):
- `notificationSettingsLiveActivityTitle`: "Show new post activity on Lock Screen"
- `notificationSettingsLiveActivitySubtitle`: "Views, likes and comments for your post's first hour"
- `notificationSettingsLiveActivityUnavailable`: "Live Activities are off for Divine in iPhone Settings"

**Steps:**
- [ ] Write the failing tests:
  - cubit: load, write-through, a system change;
  - widget: hidden without a repository; disabled with the unavailable copy; copy resolved from `lookupAppLocalizations`.
- [ ] Run them and confirm they fail.
- [ ] Implement.
- [ ] Run `arb_consistency_test`.
- [ ] Commit `feat(live-activity): let people turn the post Live Activity off in Notification settings`.

### Task 9: The tap link and the way back

**Files:**
- `mobile/lib/services/deep_link_service.dart`.
- `mobile/lib/router/universal_link_resolver.dart`, including both exhaustive switches.
- `mobile/lib/router/deep_link_coordinator.dart`.
- `mobile/lib/router/routes/video_routes.dart`, plus its generated `.g.dart`.
- `mobile/lib/router/route_paths.dart`.
- `mobile/lib/screens/creator_analytics_screen.dart`: back from account stats.
- `mobile/docs/DEEP_LINK_URL_REFERENCE.md`: the `/creator-analytics/:videoId` row and a `divine:///post-analytics` entry.
- Tests:
  - `deep_link_service_test.dart`;
  - `universal_link_resolver_test.dart`;
  - `deep_link_coordinator_test.dart`;
  - `app_router_divine_scheme_gating_test.dart`;
  - `route_locations_resolve_test.dart`.

**Changes:**
- `DeepLinkType.postAnalytics`, with `DeepLink.postEventId` and `DeepLink.postCoordinate`.
- A two-segment branch for `divine:///post-analytics/<64-hex>?coordinate=<addr>`, checked before the single-segment map.
  - Not added to `customSchemeRoutablePrefixes`.
- It follows the `savedVideos` convention:
  - `deepLinkRouterPath` returns null, and the coordinator routes the link;
  - `customSchemeToRouterPath` returns the new `RoutePaths.postAnalytics(String videoId, {String? coordinate})`.
- `PostAnalyticsDetailRouteData` gains `@TypedQueryParameter(name: 'coordinate') this.coordinate`.
- The coordinator uses `go`, unlike `savedVideos`' `push`. Only `go` builds the nested account stats page beneath it, because both routes are nested on the root navigator.
- Account stats' app bar gets `onBackPressed: () => context.safePop()`, which falls back to the home feed.

**Tests:**
- A link parses with both values.
- Rejected: the authority form, a short id, a missing id.
- Signed out, the link lands on the welcome screen.
- Pop from post stats lands on account stats; pop again lands on the feed.

**Steps:**
- [ ] Write the failing tests.
- [ ] Run them and confirm they fail.
- [ ] Implement.
- [ ] Run `build_runner`.
- [ ] Run the tests again.
- [ ] Commit `feat(live-activity): open a post's stats from its Live Activity`.

### Task 10: Post stats — resolve by address, honest states, Stop

**Files:**
- Create: `mobile/lib/blocs/post_analytics_detail/post_analytics_detail_cubit.dart`, plus its state.
- Move `VideoPerformance`, unchanged, from `creator_analytics_screen.dart` to `mobile/lib/features/creator_analytics/video_performance.dart`. Update every importer that `grep -rln VideoPerformance lib test` finds, including:
  - `lib/router/routes/video_routes.dart`;
  - `test/screens/post_analytics_detail_route_test.dart`;
  - `test/router/routes/video_routes_test.dart`.
- Modify `creator_analytics_screen.dart`:
  - the Page provides the cubit with `ValueKey((repository, ownerPubkey, videoId))`;
  - `_resolvePerformance` is deleted.
- Modify the 23 `app_*.arb`.
- Tests: the cubit test and `mobile/test/screens/creator_analytics_screen_test.dart`.

**Interfaces:**
- `PostAnalyticsDetailCubit({required CreatorAnalyticsRepository repository, required String? ownerPubkey, required String videoId, String? coordinate, VideoPerformance? initialPerformance, PostLiveActivityRepository? liveActivity, DateTime Function()? now})`.
  - Methods: `load()`, `retry()`, `stop()`.
  - Uses `CloseGuardedEmit`: it emits after awaits, a timer and `stop()`.
- `enum PostAnalyticsDetailStatus { loading, ready, onTheirWay, nothingYet, cantFind, couldNotLoad }`.
- The state carries `VideoPerformance? performance`, `PostCounts counts`, `DateTime? postedAt` and `bool liveActivityRunning`.
  - `PostCounts { int? views; int? likes; int? comments; }`: nullable where unknown, read from `extractVideoViews`, `liveLikeCountSeed` and `liveCommentCountSeed`.
  - The account stats screen is unchanged.

**Resolution:**

*Finding the post*
- With `initialPerformance` (the warm path), there is no fetch. The coordinate comes from `performance.video`, so Stop works there too.
- Match on `video.id == videoId`. Otherwise match `video.stableId` against the coordinate's `d`, with the owner matching.
- `postedAt` is the activity's, from `liveActivity.postedAtFor`. Without one, it is the video's `createdAt`.

*Counts*
- A thrown fetch → `couldNotLoad`.
- When `hasEngagementData` is false, or a count is null, that count shows as unknown.
- Before the settle point, any zero also shows as unknown.

*States*
- Not found:
  - before `postedAt + 10 min` → `onTheirWay`;
  - after that, or with no `postedAt` → `cantFind`.
- Found, after the settle point, with views, likes and comments all non-null zeros → `nothingYet`.
- Found, before the settle point, with no non-zero count → `onTheirWay`.
- `onTheirWay` schedules one reload at the settle point, on a held `Timer` that is cancelled in `close()`.

**Copy:**
- `analyticsStatsOnTheirWay`: "Stats are on their way"
- `analyticsNoViewsYet`: "No views yet · live for {minutes} min" (ICU plural)
- `analyticsCantFindStats`: "We can't find stats for this post"
- `analyticsViewPost`: "View post". It opens the typed video route. It is a new key, because the crosspost sheet's "View post" means the external post.
- `analyticsStopLiveActivity`: "Stop Lock Screen activity"
- Stop is a `DivineButton`, shown while `liveActivityRunning`, that calls `stopForPost`.

**Steps:**
- [ ] Write the failing tests:
  - cubit:
    - one test per status;
    - the warm path does no fetch, and Stop works from it;
    - an edited post is found by address;
    - an unknown count never reads as zero;
    - a zero before the settle point reads as unknown;
    - a throw gives `couldNotLoad`;
    - the settle-point reload fires (`fake_async`);
    - Stop ends the activity and hides itself.
  - widget:
    - each status renders its copy;
    - "View post" opens the video;
    - retry works.
- [ ] Run them and confirm they fail.
- [ ] Implement.
- [ ] Run them again.
- [ ] Commit `feat(live-activity): show honest states and Stop on a post's stats`.

### Task 11: Local demo build

- [ ] On a separate local branch, `local/post-live-activity-demo`, built on the PR branch and **never pushed**, add:
  - a Developer options entry, "Play post Live Activity demo";
    - it starts an activity and plays a compressed hour: posting → live → counts rising → stale → summary;
    - a separate "can't find stats" run;
  - a debug-only `debugPushState {activityId, contentState}` bridge method behind `#if DEBUG`.
- [ ] If the simulator can target a Live Activity token, send one real APNs Live Activity payload, to prove the content-state shape and its date encoding. Use `xcrun simctl push` with `apns-push-type: liveactivity`, or Xcode's push console. If it can't, say so.
- [ ] Build for Matt's simulator, and for his phone if signing allows.
- [ ] Walk the full path:
  - the tap into stats;
  - back twice;
  - Stop;
  - the toggle;
  - the unavailable state;
  - sign-out mid-hour.
- [ ] Record a screen capture for the PR.

### Task 12: Verify and hand back

- [ ] Run:
  - `flutter analyze lib test integration_test`;
  - `bash scripts/ci/run_guards.sh`;
  - `dart run build_runner build --delete-conflicting-outputs` and `flutter gen-l10n`, then a clean `git status --short`;
  - `flutter test test/l10n/arb_consistency_test.dart`;
  - `scripts/golden.sh verify` if a golden covers Notification settings or post stats;
  - the affected Dart tests;
  - inside the new package: `flutter analyze`, `dart format --set-exit-if-changed .`, bloc lint, and `very_good test --coverage --min-coverage 100` (80-column lint is on there, unlike the app);
  - the full `RunnerTests`, after checking target membership in `project.pbxproj` (shared Swift in Runner and the widget extension, plugin files in Runner only);
  - a launch on an iOS 16.0 or 16.1 simulator: no activity, the toggle hidden, no crash.
- [ ] Add the release checklist line: no build carrying this code before the push service's Live Activity support is in production.
- [ ] Update the PR description:
  - the slice 2 section;
  - the simplified ending, with a link to the spec's decision;
  - the dependency on Daniel;
  - the device checks;
  - the Tier 3 ask for the new ARB keys;
  - the demo capture.
- [ ] Device checks, listed as unverified until run:
  - an FCM token and an activity push token are issued with notifications declined. **Gate before merge:** if no FCM token is issued, people who declined are left out until Daniel's answer on an optional `token`;
  - Firebase delivers `apns.live_activity_token` updates (local push-service build; staging is down);
  - `activity.pushToken` is readable after a cold start;
  - the state events an app-initiated `.immediate` end and a server end produce;
  - whether `.dismissed` arrives while suspended;
  - the Settings switch appears after the first activity;
  - whether `simctl` can target Live Activity tokens;
  - which state event a server `notFound` end produces;
  - a cold-start tap within the first 10 minutes shows "on their way";
  - two quick posts leave one activity;
  - sign-out during "Posting…" clears it.
