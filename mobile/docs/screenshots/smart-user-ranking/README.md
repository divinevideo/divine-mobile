# Smart user ranking: delivery evidence

Source implementation: `514bc5a9b0e990af4942d64755bfc9e1de93a48f` (approved architecture correction, rebased patch-equivalently onto `098d9912bc674c20a7499382d5000b38a955b23d`); host macOS 26.5.2 arm64, pinned Flutter 3.47.2 / Dart 3.13.2.

These documentation captures render the real share sheet, new-message picker, and own-following screen with synthetic people and full-length synthetic keys. The images cover dark and light appearances at 390 × 844 logical pixels (DPR 1), encoded at 2× (780 × 1688). They are documentation PNGs, not CI golden references. The share-screen backdrop and video-thumbnail placeholder are fixture scaffolding; no production account, media, or user device was used.

The screenshot harness uses the app's normal test bootstrap to load bundled fonts, then drains `GoogleFonts.pendingFonts` with `tester.runAsync` and settles painting. A `RepaintBoundary` captures the whole app including its Scaffold surfaces and modal overlay. The only native channel mocks added by the harness acknowledge editor progress/log subscriptions; nothing is exported or uploaded.

From `mobile/`, reproduce manually with the pinned toolchain:

```sh
cp docs/screenshots/smart-user-ranking/capture.dart.txt test/task17_capture_test.dart
mise exec -- dart format --output=none --set-exit-if-changed test/task17_capture_test.dart
mise exec -- flutter test --no-pub test/task17_capture_test.dart
rm test/task17_capture_test.dart
```

The captured fixtures are local snapshots. This is a reproducible rendering harness, not an end-to-end device interaction claim. Keep the temporary file out of commits and remove it even if generation fails. Final capture replay after the architecture correction: 6/6 passed. All six PNG SHA-256 hashes match the accepted pre-extraction captures. Original capture/scoring/loader source was `4e56bdee6a0b9d27770a35ca59a61303061ed2e6`, whose patch-equivalent rebased commit is `7bb2c37c5479e3fc59623678078ebefcbd6b01cc`. The loader and scoring implementations were unchanged by extraction and rebase, so their measurements were preserved without unnecessary reruns.

## Latency evidence

Scoring and sorting 5,000 synthetic candidates is measured separately, without fixture setup, by the standalone committed script:

```sh
cd packages/user_ranking
mise exec -- dart run benchmark/rank_users_benchmark.dart
```

On the macOS arm64 host with Dart 3.13.2 JIT, the first invocation was **12.459 ms**, with **1.339 ms median** over 20 subsequent invocations (range 1.237–1.977 ms). The fixture covers relationship, interaction recency, posting recency, video count, verification, and name sorting. These are host timings, not a phone result.

The local-read harness invokes the actual `UserRankingSignalsLoader.load` followed by `loadCachedDisplayNames` for 5,000 synthetic followed accounts. It seeds a file-backed SQLite database outside the repository, closes the seed connection, reopens it through `AppDatabase.test(NativeDatabase(file))`, and times eleven full reads. This uses synchronous native SQLite in the Flutter-test host isolate, not the production background connection, encryption path, or a profile build. The first measured read includes connection/schema reopening, but OS caches are already warm from seeding; it is not a cold-device storage measurement. Fixture setup and checks are outside each stopwatch.

The fixture has 5,000 cached profiles, stats rows, and video events; 2,500 inbound followers, 1,000 accepted one-to-one conversations, and 715 valid verification rows. `ProfileRepository.getCachedProfiles` and the real DAOs read SQLite: `ConversationsDao.watchAcceptedConversations`, `MyFollowersDao.followerSubset`, `ProfileStatsDao.getStatsRawMany`, `NostrEventsDao.newestCreatedAtByAuthor`, `Nip05VerificationsDao.getValidVerifications`, and `UserProfilesDao.getProfilesByPubkeys` (twice, including the display-name batch). Follow membership uses a prebuilt in-memory set through a mock repository; a mock DM repository adapts real DAO rows into domain conversations without the full repository's decryption/enrichment overhead. No network or background refresh is invoked.

The first run measured **304.127 ms** after reopening, with **139.1045 ms median** over ten warm reads (108.071–152.680 ms). A second run, adding only stage timing and index inventory, measured **433.403 ms** after reopening, **150.4825 ms median** warm (130.224–272.622 ms). Its separately computed warm stage medians were **108.951 ms** for `load` and **39.1815 ms** for the additional display-name read. The sum of stage medians need not equal the total median. The complete outputs are in `loader-benchmark-first-output.txt` and `loader-benchmark-output.txt`; the second includes actual `sqlite_master` indexes; no special benchmark indexes were added.

No isolated physical phone or known 5,000-follow test account was available, so **the 50 ms mid-range-phone budget remains unverified**. These host results identify a local-read cost worth profiling on a phone; they neither prove nor disprove the profile-build device budget.

To reproduce the local-read measurement from `mobile/`:

```sh
cp docs/screenshots/smart-user-ranking/loader_benchmark.dart.txt test/task17_loader_benchmark_test.dart
mise exec -- dart format --output=none --set-exit-if-changed test/task17_loader_benchmark_test.dart
mise exec -- flutter test --no-pub test/task17_loader_benchmark_test.dart
rm test/task17_loader_benchmark_test.dart
```

The `.dart.txt` suffix intentionally keeps the manual capture and timing harnesses outside test discovery and CI optimization bundles. Do not convert the timing harness into a committed test or tagged CI suite. The pure-Dart benchmark stays under `packages/user_ranking/benchmark/`.
