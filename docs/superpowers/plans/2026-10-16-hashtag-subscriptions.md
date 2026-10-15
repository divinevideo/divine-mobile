# Hashtag Subscriptions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Let an authenticated user follow a hashtag, select its videos from Home, and manage their follows.

**Architecture:** A Flutter-independent repository owns confirmed, account-scoped local subscription state through an injected persistence interface. A Cubit presents follow and management state; VideoFeedBloc consumes repository snapshots and fetches through VideosRepository. Existing subscribed-list behavior remains intact.

**Tech Stack:** Dart pub workspace, Flutter, BLoC/Cubit, SharedPreferences, RxDart, GoRouter, existing Divine UI components.

**Spec:** `docs/superpowers/specs/2026-10-16-hashtag-subscriptions-design.md`

## Global Constraints

- Device-local persistence is an explicit first-version limitation: it survives app restarts, but does not synchronize to another device or another Nostr client.
- No new Nostr event format is introduced.
- Following requires the existing sign-in flow; no anonymous subscription bucket is created.
- Store follows locally under an account-qualified key using the full public key.
- Use adaptive theme tokens and shared Divine components in light and dark modes.
- Mixing hashtag videos into Following, recommendation signals for For You, notification preferences and delivery, and a composer shortcut remain separate product work.
- Work in the existing isolated Paseo worktree on `feature/hashtag-subscriptions`. Target main when publishing; do not merge without authorization.

## Review Focus

- Switching accounts during an outstanding write must never display or persist the first account's follows under the second account.
- Hashtags containing literal percent signs or non-Latin characters must survive management navigation and persistence without double decoding.
- A storage read failure must not convert existing follows into an empty list and overwrite them.
- A failed refresh must keep the current videos visible and allow retry.
- An unfollow while that hashtag is loading must invalidate its result and leave Home on For You.

---

### Task 1: Account-scoped subscription repository

**Files:** Create `mobile/packages/hashtag_subscription_repository/pubspec.yaml`, `lib/hashtag_subscription_repository.dart`, `lib/src/hashtag_subscription_repository.dart`, `test/hashtag_subscription_repository_test.dart`; modify `mobile/pubspec.yaml` and resolved workspace lockfile.

**Interfaces:** Produce `HashtagSubscription(canonicalTag, displayTag)` as an immutable value, `HashtagSubscriptionStore.read(): Future<String?>` and `.write(String value): Future<void>`, and `HashtagSubscriptionRepository(store:)` with `initialize()`, `subscriptions`, replaying `subscriptionsStream`, `follow(String tag)`, `unfollow(String tag)`, and `dispose()`. Errors propagate to the caller; reads complete before mutations. No Flutter types or auth globals.

- [x] Write tests asserting `follow(' #LNIC ')` followed by `follow('lnic')` creates one subscription with canonical `lnic` and display `LNIC`; empty, internal whitespace, and repeated # inputs throw validation errors. Japanese text and `100%fun` retain their exact display strings.
- [x] Write tests asserting restart restores confirmed follows, queued writes preserve independent tags, failed writes retain prior confirmed state, and malformed JSON/read failures prevent writes until a successful initialization retry. A late stream subscriber receives current state; disposal does not emit afterward.
- [x] Run `dart test` in the new package and observe missing-implementation failures.
- [x] Implement the interfaces with serialized mutations, immutable snapshots sorted by canonical tag, JSON storage, and injected persistence. A failed queued operation must not poison subsequent writes.
- [x] Run package tests and analysis; commit the package and workspace registration.

### Task 2: App persistence and follow presentation

**Files:** Create `mobile/lib/providers/hashtag_subscription_repository_provider.dart`, `mobile/lib/features/hashtag_follows/cubit/hashtag_follows_cubit.dart`, `mobile/lib/features/hashtag_follows/data/shared_preferences_hashtag_subscription_store.dart`, and corresponding tests under `mobile/test/features/hashtag_follows/`.

**Interfaces:** Consume Task 1 repository. Produce an account-scoped provider returning a nullable repository for anonymous sessions, recreated when the authenticated public key changes. Produce `HashtagFollowsCubit(repository:)` with immutable state containing subscriptions, loading/read error, pending canonical tags, and write error; expose `initialize()`, `follow(String)`, `unfollow(String)`, and error dismissal. Close its stream subscription with the Cubit.

- [x] Write adapter tests asserting keys include the full account public key, two synthetic accounts remain isolated, and SharedPreferences returning false becomes a write error.
- [x] Write Cubit tests for initial loading, failed-read retry, follow/unfollow success and failure, repeated taps while pending, and close during an outstanding operation. No old-account completion may update a newly scoped Cubit.
- [x] Run those tests and confirm they fail before implementation.
- [x] Implement the adapter and provider using existing auth and preferences providers as compatibility wiring. Keep BLoC/Cubit as the owner of new UI state; initialize and dispose each account's repository explicitly.
- [x] Implement the Cubit, rerun affected tests and analysis, and commit.

### Task 3: Follow action and management screen

**Files:** Modify `mobile/lib/screens/hashtag_feed_screen.dart` and `mobile/lib/router/routes/search_routes.dart`; create `mobile/lib/features/hashtag_follows/view/followed_hashtags_page.dart`, `hashtag_follow_button.dart`, tests under `mobile/test/features/hashtag_follows/`; update `mobile/lib/l10n/app_en.arb` and required translations/generated outputs.

**Interfaces:** Consume the account-scoped repository and Task 2 Cubit. Produce a full-screen `FollowedHashtagsPage` at `/followed-hashtags` and a reusable `HashtagFollowButton(hashtag:)`. Management rows navigate through the existing hashtag route using GoRouter path-parameter encoding.

- [x] Write widget tests asserting Follow becomes Following only after successful storage, a pending operation disables repeated taps, failure retains confirmed membership, and anonymous taps enter the existing sign-in flow without creating a follow automatically.
- [x] Write management tests asserting sorted follows, explicit unfollow actions, loading/error/retry/empty states, correct navigation for Japanese and percent-containing tags, and safe back navigation. Test both appearance modes and accessible control labels.
- [x] Run the new tests and confirm missing-widget failures.
- [x] Implement the Page/View split and shared follow control using Divine components and adaptive colors. Reuse the app's existing auth prompt and route behavior; returning from sign-in requires another explicit follow action.
- [x] Localize all new strings following repository localization rules. Run localization skills/checks, focused widget tests, and analysis; commit.

### Task 4: Hashtags as Home sources

**Files:** Modify `mobile/lib/blocs/video_feed/video_feed_state.dart`, `video_feed_event.dart`, `video_feed_bloc.dart`, `feed_mode_preference_store.dart`, `mobile/lib/screens/feed/video_feed_page.dart`, `feed_mode_switch.dart`; extend `mobile/test/blocs/video_feed/video_feed_bloc_test.dart` and `mobile/test/screens/feed/feed_mode_switch_test.dart`; add `mobile/test/blocs/video_feed/hashtag_source_test.dart`.

**Interfaces:** Add `VideoFeedSourceType.subscribedHashtag`, `VideoFeedSource.subscribedHashtag({required String hashtag, required String displayTag})`, canonical `hashtag`, and persisted `hashtag:<canonicalTag>`. Add immutable followed hashtags to feed state and `VideoFeedHashtagsChanged` events. Inject the Task 1 repository into VideoFeedBloc and FeedModePreferenceStore while preserving existing constructor callers through an optional dependency.

- [x] Write tests asserting followed tags appear after existing subscribed lists, selection changes the label and actual fetch, Manage hashtags opens its route, and the picker supports long lists.
- [x] Write bloc/preference tests for scoped restore, unknown/unfollowed source fallback, rejection of legacy-global hashtag migration, current-tag removal, other-tag removal, stale fetch completion, and account change during loading. Preserve existing list-source tests.
- [x] Write feed tests asserting a successful hashtag result has `hasMore: false`, load-more cannot append the first page again, failure differs from empty success, and failed refresh retains displayed videos.
- [x] Run the focused tests and observe pre-implementation failures.
- [x] Extend source equality, persistence parsing, exhaustive switches, state snapshots, and stream lifecycle. Load subscription state before restoring a saved hashtag source. Subscribe without dropping a change occurring during initial loading. Include account identity in the Home BlocProvider recreation key.
- [x] Adapt `VideosRepository.getHashtagFeedVideos(hashtag:)` to HomeFeedResult with explicit exhaustion; translate failure to the existing feed failure path rather than an empty successful result. Reuse repository filtering and trending/classic ordering. Exclude hashtags from cross-restart video cache while preserving account-scoped source selection. Invalidate pending results on source change or unfollow.
- [x] Add the stable analytics source detail `hashtag` through the existing contract generation workflow if the contract enumerates these values; inspect its canonical instructions before editing generated consumers. Do not include account identifiers in analytics labels.
- [x] Run the affected bloc, preference, picker, hashtag screen, and repository tests and analysis; commit.

### Task 5: Validate and publish

**Files:** Review the complete branch; update this plan's checkboxes with evidence as tasks finish.

- [ ] Run `flutter analyze` from `mobile`, all affected tests from Tasks 1–4, the repository's localization checks, and relevant generated-file and architecture guards. Resolve introduced failures without skips or weakened tests.
- [ ] Exercise the full follow → Home selection → restart → manage → unfollow sequence, account isolation, and light/dark appearance using a runnable local build. If runtime verification is unavailable, document the exact limitation without claiming it passed.
- [ ] Use the review-before-commit and verification-before-completion skills to review the full diff and verify commits. Fetch and rebase onto fresh origin/main, rerunning validation if changed dependencies or conflicts warrant it.
- [ ] Read the current PR review team mapping, push the task branch, and open a focused PR targeting main with a Conventional Commit title and explicit device-local limitation. Request the mapped team once and verify the request.
- [ ] Watch required CI to completion and inspect results. Fix failures introduced by this branch. Hand back the PR URL, validation evidence, and any precisely identified blockers; keep the worktree until the branch is merged.

## Plan self-review

All scope in the approved design maps to Tasks 1–4. Storage failure and normalization are covered by Task 1; account lifetime and write errors by Task 2; sign-in, localization, and management by Task 3; Home persistence, loading races, filtering reuse, analytics, and explicit feed exhaustion by Task 4. Task 5 covers publication and verification. The five review-focus conditions each have an owning test step above. Native execution in this session is the default recommendation because these tasks share repository and source-state interfaces.

## Implementation evidence

Tasks 1–4 are implemented. The affected app suite passed 242 tests before the final account-switch, adapter-failure, and long-picker tests; the final focused follow/picker suite passed 41 tests and the Home hashtag suite passed seven. The shared repository passed ten tests with 59/59 covered lines and clean package analysis. CI-equivalent app analysis passed. All 65 guards were exercised: 63 passed initially, and the two failures (test event-queue settling and typography helpers) were corrected and passed on focused reruns. An independent reviewer rechecked all three reported race fixes and found no remaining verified blockers.

A real authenticated-device manual pass has not been performed. The local checkout has no app environment file or signed-in device session; controlled widget tests exercise persistence, Home source selection, account changes during saves, management navigation, and light/dark long lists. Publication and remote CI results will be recorded on the pull request.
