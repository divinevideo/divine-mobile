# Instant video return implementation plan

> For agentic workers: use the `implement-plan` skill to implement this plan task by task. Each implementation task starts with reproduction and a failing regression test. This document plans the work; it does not claim implementation or performance results.

**Goal:** Return viewers to the same video and playback position quickly, including after process death, while fresh content loads without interrupting them.

**Architecture:** UI -> BLoC/Cubit -> repository -> client/storage. A repository-owned, versioned viewing snapshot records the intended destination and video; the existing media cache owns playable bytes. Startup restores local identity and the validated destination before optional background work, with account and playback gates preserved.

**Tech stack:** Flutter, Dart, BLoC/Cubit, go_router, existing cache_sync/database facilities, media_cache, infinite_video_feed, divine_video_player, native iOS/Android players, Patrol and physical-device performance traces.

**Tracking:** [Epic #8978](https://github.com/divinevideo/divine-mobile/issues/8978).

## Evidence and limits

Inspected source: commit 38380b115a5a1c339a2ae0313f62002b2fec338b. The reported two-to-three-second delay is an estimate; no device reproduction, baseline, or timing attribution was obtained in the planning session. Recheck the current implementation before editing.

- The stale auto-refresh handler in mobile/lib/blocs/video_feed/video_feed_bloc.dart clears videos and resets the index after a ten-minute freshness interval. mobile/lib/screens/feed/video_feed_page.dart dispatches it on genuine foreground return. For You, Following and New participate.
- mobile/lib/blocs/video_feed/home_feed_resume_manager.dart saves a forward window starting after the active item. mobile/lib/blocs/video_feed/home_feed_cache.dart expires it after six hours. This is upcoming-content caching, not exact viewing restoration.
- mobile/lib/router/app_router.dart normally starts at Welcome; mobile/lib/startup/startup_splash_release_controller.dart holds the splash until authentication and the relevant redirect settle. This guard prevents a previously observed Welcome flash.
- mobile/lib/services/auth_service.dart already restores a matching local Divine OAuth identity and upgrades remote capability in the background. Accounts without usable local identity have other paths. Do not describe this project as adding authentication caching from scratch.
- The home screen calls markVideoReady from active-video selection. Selection is not proof that a native frame rendered or playback advanced.
- Native caching, a disk prefetcher, and content-preserving feed splice logic already exist. Audit and extend those paths rather than building a parallel stack.

## Product contract

An ordinary foreground return preserves the current video, playback position and user playback intent. Fresh recommendations must not clear the screen or change the active item. Keep the current item and ready lookahead stable; insert refreshed content after that prefix with stable-identity deduplication. Explicit refresh remains a deliberate request for a new feed. Known content restrictions and deletions take precedence over continuity.

After process death, restore a small saved viewing session: account, destination/feed context, stable video identity, playback offset, paused/playing intent and ordered nearby videos. Support home modes and read-only video feeds reached through profile, search, hashtag and lists. Preserve the bounded preceding context so the user can scroll back. Camera/editor flows, transient overlays and authentication screens retain their existing dedicated lifecycle handling.

Recommendation TTL and viewing-snapshot lifetime are separate. Keep one latest snapshot per account until replaced, explicitly signed out/removed, invalidated or rejected for unsupported schema. Use a maximum 30-item metadata window with up to five preceding items, the active item and the remaining lookahead. Never make the current six-hour feed-cache TTL silently erase the viewing bookmark.

Persist during use, coalesce rapid updates, flush pending state on backgrounding and serialize writes. OS termination is not guaranteed to send a callback. An abrupt kill can restore the latest committed position; it must not produce another account's state or corrupt the record. Seek only after media is ready, clamp to valid duration and retain a coherent policy at loop boundaries. Restore within one second of the latest committed offset, unless duration or eligibility changed.

Explicit incoming deep links and notification destinations override the saved destination. Validate snapshot route context against supported destinations rather than replaying GoRouter object graphs. A missing/blocked/deleted active item falls forward to the next eligible saved item; an unusable snapshot falls back to the appropriate current-account feed. Corruption must not produce a startup loop.

Local identity restoration is necessary before displaying account-scoped state. Preserve restriction, deletion, verification and recovery gates. Local viewing readiness is distinct from remote signer/RPC readiness; unavailable remote signing must never be represented as ready. Offline return guarantees apply to locally restorable accounts whose required gates permit viewing.

## Issue map and delivery order

| Order | Work | Tracking | Dependency / delivery boundary |
| --- | --- | --- | --- |
| 1 | Correct return timing and establish baseline | [#8974](https://github.com/divinevideo/divine-mobile/issues/8974) | Enables measured optimization and release decisions |
| 2 | Preserve the live feed on resume | [#5134](https://github.com/divinevideo/divine-mobile/issues/5134) | Can ship independently; include Following and New parity |
| 3 | Repository-owned viewing snapshots | [#8975](https://github.com/divinevideo/divine-mobile/issues/8975), [#2313](https://github.com/divinevideo/divine-mobile/issues/2313) | Combine cache migration with its consumer replacement if interdependent |
| 4 | Reliable playable return media | [#8976](https://github.com/divinevideo/divine-mobile/issues/8976) | Coordinate retention with the snapshot contract |
| 5 | Shorten startup and restore destination directly | [#8977](https://github.com/divinevideo/divine-mobile/issues/8977) | Requires snapshot contract and trustworthy milestones |
| 6 | Enforce return coverage and rollout gates | [#8757](https://github.com/divinevideo/divine-mobile/issues/8757) | Extend existing CI work; do not create a duplicate lane |

Existing issues keep their current parents. New issues are native sub-issues of #8978. Related work: [#3606](https://github.com/divinevideo/divine-mobile/issues/3606) for cleanup, [#7117](https://github.com/divinevideo/divine-mobile/issues/7117) for telemetry correctness, [#7869](https://github.com/divinevideo/divine-mobile/issues/7869) for route-restoration failure. #4244 is closed; reassess #2313's dependency against current cache_sync implementation instead of assuming it remains blocked.

All implementation PRs target main. Combine genuinely interdependent features in one PR with delineated commits. Independent improvements can merge separately. Never stack feature branches or require an unmerged PR as another PR's base.

## Task 1: Measure the intended video actually playing

Files to inspect/change:

- mobile/lib/services/startup_performance_service.dart
- mobile/lib/features/app/startup/startup_metrics.dart
- mobile/lib/screens/feed/video_feed_page.dart
- mobile/lib/widgets/video_feed_item/feed_videos.dart
- mobile/packages/divine_video_player/lib/src/divine_video_player_controller.dart
- mobile/test/startup/startup_performance_service_test.dart
- mobile/integration_test/perf/feed_ttff_test.dart

- [ ] Reproduce a retained-process return and process restart on physical iOS and Android devices. Record build, device/OS and whether media was cached. Separate the native launch screen from in-app loading UI.
- [ ] Add deterministic tests proving video selection and thumbnail display cannot complete first-frame/playback timing. Test failed/disposed first-frame futures, duplicate/late callbacks, loops, cancellation and account changes.
- [ ] Extend one attempt-scoped timeline: foreground/native launch, local identity ready, snapshot read, destination visible, thumbnail visible, native video frame, advancing playback. Use monotonic clocks; do not subtract timestamps from incompatible clock domains.
- [ ] Connect native/external start measurement to account for the period before Dart runs. Capture cache-hit/miss, lifecycle class and bounded outcome attributes; omit account/content IDs from telemetry attributes.
- [ ] Record paused restoration separately. A deliberately paused player must not be a failed autoplay sample, nor count as successful advancing playback.
- [ ] Run the focused startup-performance tests and inspect a native trace or frame recording to verify marker order. Audio recording alone cannot establish visible video identity or first frame.
- [ ] Publish baseline p50/p95 with sample counts and failures before making performance claims. Commit the instrumentation independently when it is complete and green.

## Task 2: Preserve the live feed during refresh

Files:

- mobile/lib/blocs/video_feed/video_feed_bloc.dart
- mobile/lib/blocs/video_feed/home_feed_resume_manager.dart
- mobile/lib/screens/feed/video_feed_page.dart
- mobile/test/blocs/video_feed/video_feed_bloc_test.dart
- mobile/test/blocs/video_feed/video_feed_bloc_revalidate_test.dart
- mobile/test/widgets/app_lifecycle_handler_test.dart

- [ ] Reproduce stale return at a nonzero index using a delayed repository response; repeat with a rejected response and changed recommendation ordering.
- [ ] Add regression cases for For You, Following and New: no empty-list emission during a refresh, stable active identity/index/player, refresh failure retaining content, fresh data deduplicated after the stable prefix and stale responses after an account/source switch ignored.
- [ ] Replace the auto-refresh hard reset with the existing content-preserving merge approach after validating its controller-preservation behavior. Keep freshness intervals and explicit refresh semantics.
- [ ] Verify a return during an overlay, an inactive tab, or user pause does not force playback. Preserve content eligibility/removal behavior when a retained item becomes disallowed.
- [ ] Run bloc and relevant lifecycle/widget coverage; compare retained-player return timing with the baseline. Commit and ship through #5134 without waiting for cold-start work.

## Task 3: Persist and restore a viewing snapshot

Ownership and files:

- Put the snapshot model and persistence port in the owning feed repository under mobile/packages/feed_repository/lib/src/, with constructor-injected existing storage/cache facilities. Inspect package boundaries first; do not introduce a dependency cycle or Flutter UI types.
- Coordinate existing feed data ownership in mobile/packages/videos_repository/ and #2313.
- Replace the relevant responsibilities in mobile/lib/blocs/video_feed/home_feed_cache.dart and mobile/lib/blocs/video_feed/home_feed_resume_manager.dart once repository consumers are wired.
- Wire lifecycle and destination adapters in mobile/lib/widgets/app_lifecycle_handler.dart and mobile/lib/router/.
- Add repository tests alongside mobile/packages/feed_repository/test/src/ and route/lifecycle tests in mobile/test/.

- [ ] Define serialization version 1 and its account, supported destination, source parameters, stable identities, bounded videos, playback offset, playback intent and captured-time fields. Resolve existing model/package placement before adding a type.
- [ ] Test round-trip restore after feed-cache expiry, empty/malformed/unknown-version records, end-of-loop offset, unavailable items, source reconstruction and account separation. Use valid synthetic full identifiers.
- [ ] Test serialized writes with controlled completion order, swipe/background flush, abrupt kill after the last committed write, and sign-out invalidation racing an old write.
- [ ] Implement repository read/write/invalidate through current storage infrastructure; migrate and remove the replaced BLoC cache in the same complete change as required by #2313. Do not preserve competing sources of truth.
- [ ] Wire active-video and playback-intent updates with coalescing and lifecycle flush. Save frequently enough to meet the committed-offset restoration contract without per-frame disk writes.
- [ ] Test destination precedence and reconstruction for home, profile, search, hashtag and lists. Reuse eligibility checks and deterministic fallbacks; do not serialize the raw route stack implicated in #7869.
- [ ] Verify a nonzero-index process restart returns to the same video after more than six hours. Run owning repository, bloc and routing tests and commit the complete snapshot change.

## Task 4: Make cached return media playable

Files:

- mobile/packages/media_cache/lib/src/media_cache_manager.dart
- mobile/packages/infinite_video_feed/lib/src/services/disk_prefetcher.dart
- mobile/packages/infinite_video_feed/lib/src/utils/source_loader.dart
- mobile/packages/divine_video_player/lib/src/divine_video_player_controller.dart
- mobile/packages/divine_video_player/android/src/main/kotlin/com/divinevideo/divine_video_player/VideoCache.kt
- mobile/packages/divine_video_player/darwin/divine_video_player/Sources/divine_video_player/DivineVideoPlayerPlugin.swift
- Existing tests in each owning package, including mobile/packages/infinite_video_feed/test/src/services/disk_prefetcher_test.dart

- [ ] Trace actual disk writes and subsequent playback reads on both platforms. Distinguish complete playable files from URLCache entries, manifests and partial ranges.
- [ ] Add tests for retained current media, eviction/clear, incomplete and corrupt entries, obsolete prefetch cancellation, cache-key identity and failover. Include segmented-media dependencies when that rendition is used.
- [ ] Retain the latest active short clip and thumbnail within existing cache limits; prioritize current playback before next-two lookahead. Coordinate metadata snapshot invalidation and release obsolete retention. Respect data-saving and low-storage behavior.
- [ ] For a fully cached owned fixture, terminate the process, disable networking and reopen. Verify local file use, the same video and position, and one complete loop on iOS and Android. A widget rebuild or Dart restart is insufficient proof.
- [ ] Repeat with evicted/partial media: expect a classified cache miss and graceful fallback, never false hit metrics or a blank-screen loop.
- [ ] Run media/prefetch/player tests and applicable native tests, record bandwidth/storage changes, and commit the verified cache behavior.

## Task 5: Restore directly and reduce measured startup contention

Files:

- mobile/lib/startup/app_bootstrap.dart
- mobile/lib/startup/startup_coordinator_factory.dart
- mobile/lib/startup/startup_splash_release_controller.dart
- mobile/lib/router/app_router.dart
- mobile/lib/router/app_router_redirect.dart
- mobile/lib/services/auth_service.dart
- mobile/test/startup/app_first_frame_startup_test.dart
- mobile/test/startup/app_startup_test.dart
- mobile/test/startup/startup_splash_release_controller_test.dart
- mobile/test/services/auth_service_local_first_startup_test.dart

- [ ] Use Task 1 traces to identify the actual blocking operations, including account-state gates and work before Dart. Confirm #3606's cleanup claim against current code and measured timings.
- [ ] Add a routing decision matrix: local account plus valid snapshot; absent snapshot; explicit sign-out/fresh install; local key absent; slow remote refresh; remote signer; incoming link/notification; pending verification; restriction/deletion/recovery; storage failure.
- [ ] Implement direct validated destination selection for eligible returning viewers. Preserve a safe fallback, correct account scope and late-arriving launch-intent precedence.
- [ ] Render saved content while decoding, keeping the splash/redirect guard that prevents Welcome flashes. Do not release it early simply to improve a first-frame number.
- [ ] Defer only measured nonessential work until first playback or idle, preserving encryption/migrations, early diagnostics and startup-repair behavior. Respect dependencies and bound background concurrency. An unawaited Future alone does not move CPU work off the UI isolate.
- [ ] Verify local viewing can proceed during optional remote refresh without enabling unavailable signer/RPC capabilities. Keep all required account gates.
- [ ] Run the focused startup/auth/router tests and compare physical-device distributions. Commit each independent proven improvement; combine changes whose correctness depends on each other.

## Task 6: Benchmarks, CI and rollout

Use #8757's CI lane. The current mobile/integration_test/perf/feed_ttff_test.dart registers an account and exercises feed swipes; it does not establish returning-user process-death restoration. Extend the harness rather than assuming the existing filename means this coverage exists.

- [ ] Add harness-driven lifecycle scenarios with persistent app data and explicit process termination/relaunch. Use a deterministic owned media fixture and condition-based synchronization.
- [ ] Verify correctness on physical iOS and Android phones, including an older supported device on each platform. Run retained process, cached restart, cache miss, offline, weak network, rapid swipe/background, user pause, account switch and incoming-link cases.
- [ ] Collect at least 30 attempts per measured device/scenario/build cell for an initial comparison; report p50/p95 and sample count with uncertainty, and gather more when variability prevents a conclusion. Keep failures/cancellations visible alongside successful latency distributions.
- [ ] Cross-check in-app milestones with native traces/frame capture. Report visible content, rendered frame and actual playback separately.
- [ ] Integrate deterministic regression coverage and the documented performance protocol into the existing lane; verify a real run executes and enforces its declared budgets. Device-lab performance data is separate from simulator correctness results.
- [ ] Roll out through the existing release process in stages. Compare latency, blank-screen/restore failures, crashes, memory pressure, bytes fetched and scroll responsiveness. Stop expansion or revert the responsible release for account leakage, broken required gates, restore loops or regressions beyond baseline variability.

Candidate p95 budgets, to validate on the agreed release-device matrix:

| Scenario | Recognizable saved content | Advancing playback |
| --- | --- | --- |
| Retained player on foreground return | Existing surface retained | 250 ms |
| Process restart, valid snapshot and complete media cache | 500 ms | 1 second |
| Prefetched next swipe | Existing transition UI | 150 ms |

These are proposed budgets, not current measurements. Cold cache/network-bound cases have separate results and graceful fallback requirements. Intentionally paused returns must restore the surface and position while remaining paused.

## Implementation verification commands

Run Flutter commands from mobile/. Start with the focused tests named by each task, then run the affected owning packages' test commands and native checks when those paths change. For the existing app tests above:

```sh
flutter test test/startup/startup_performance_service_test.dart
flutter test test/blocs/video_feed/video_feed_bloc_test.dart test/blocs/video_feed/video_feed_bloc_revalidate_test.dart
flutter test test/widgets/app_lifecycle_handler_test.dart
flutter test test/startup/app_first_frame_startup_test.dart test/startup/app_startup_test.dart test/startup/startup_splash_release_controller_test.dart test/services/auth_service_local_first_startup_test.dart
flutter analyze lib test integration_test
```

Each new regression must first fail for the intended behavior, then pass with the fix. All affected tests and analysis must be green before an implementation push. Verify PR CI before handoff and request the normal review team. This planning PR changes documentation only; it does not run or claim these implementation checks.
