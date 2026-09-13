# Code Simplicity Issues

Issues related to duplication, oversized files, unused code, and unnecessary complexity.

> **Historical audit.** This document started as the April 2026 #3530 audit.
> Sections describing completed work are retained as historical context, with
> their linked ticket status recorded below. Current maintainability work is
> tracked by
> [#4339](https://github.com/divinevideo/divine-mobile/issues/4339) and its
> GitHub Sub-issues list.

Newer features like `features/feature_flags/` demonstrate clean co-location,
and the BLoC migration has produced focused classes. The remaining issues cover
legacy complexity and newer growth pressure.

---

### Oversized files
**Problem**: Oversized files remain a visible maintainability backlog. The
broad file-size check for #4339 is intentionally advisory rather than a
blocking CI failure. Run `bash mobile/scripts/check_file_size_ceiling.sh` from
the repository root to derive the current `mobile/lib` inventory and identify
files added or grown relative to `origin/main`. The check deliberately avoids
a committed line-count snapshot, which becomes stale as soon as `main` moves.

The video editor and recorder remain a concentrated growth cluster spanning
widgets, BLoCs, providers, and rendering services. Large authentication,
publishing, upload, and event-processing services also remain expensive to
review and test. GitHub sub-issues, rather than this historical audit, are the
source of truth for current decomposition work.

**Impact**: High. These files are hard to test, review, and modify; they create
merge-conflict pressure when multiple engineers touch the same surface; and
large UI/BLoC/service files make architectural boundaries harder to see. The
branch-to-main advisory keeps that pressure visible without blocking unrelated
PRs.

**Effort**: High. Each oversized file requires a domain-specific decomposition
strategy. Track general maintainability work through #4339's Sub-issues list
and feature-specific work, such as the video-editor cluster, through the owning
product epic. Existing hard ratchets remain authoritative for the narrower
patterns they cover.

**GitHub ticket**: [#3594](https://github.com/divinevideo/divine-mobile/issues/3594)
— closed 2026-05-13; superseded by epic
[#4339](https://github.com/divinevideo/divine-mobile/issues/4339). Its GitHub
Sub-issues list is the current inventory.

---

### Resolved: `main.dart` was an oversized entry point
The April audit found that startup orchestration, dependency wiring, deep-link
handling, and application widgets were concentrated in `main.dart`. That work
landed through [#3337](https://github.com/divinevideo/divine-mobile/issues/3337),
which reduced `main.dart` to a small entrypoint and moved those responsibilities
behind focused boundaries. The old line counts and extraction recipe have been
removed because they no longer describe the code.

**GitHub ticket**: [#3595](https://github.com/divinevideo/divine-mobile/issues/3595) — closed 2026-05-13; superseded by [#3337](https://github.com/divinevideo/divine-mobile/issues/3337).

---

### Dual notification implementation
**Problem**: Old `NotificationsScreen` (765 lines, marked TODO-remove) coexists with new BLoC-based `lib/notifications/`. Both run simultaneously.

**Evidence**: Old: `screens/notifications_screen.dart` (765 lines, `// TODO(notifications-refactor): Remove after migration is verified`). Old provider: `providers/relay_notifications_provider.dart` (also marked TODO-remove). New: `lib/notifications/` feature (BLoC-based, correct architecture). The old screen is still wired into `screens/inbox/inbox_view.dart:93` as `const NotificationsScreen()`. The relay notifications provider is still referenced from `app_shell.dart` for unread badge count. Both systems run simultaneously.

**Done well**: The new `lib/notifications/` feature demonstrates the correct BLoC-based architecture. The replacement is built; it just needs to fully replace the old implementation.

**Impact**: Medium. Two notification systems running simultaneously; confusion about which is canonical; ~1,500 LOC of dual-system code in total (old screen + provider + wiring).

**Effort**: Low. Verify the new `lib/notifications/` BLoC system covers all functionality, update `inbox_view.dart` to use the new notifications page, delete old screen and provider. Estimated ~1,000 LOC net deletion after wiring updates.

**GitHub ticket**: [#3596](https://github.com/divinevideo/divine-mobile/issues/3596) — closed 2026-05-12; work landed.

---

### Duplicate `VideoFeedState` name collision
**Problem**: One Freezed sealed class in `state/video_feed_state.dart`, one Equatable class in `blocs/video_feed/video_feed_state.dart`. Same name, different types.

**Evidence**: `mobile/lib/state/video_feed_state.dart`: Freezed sealed class used by Riverpod providers. `mobile/lib/blocs/video_feed/video_feed_state.dart`: Equatable class used by `VideoFeedBloc`. Two classes called `VideoFeedState` with different structures and different base classes. Dart avoids conflicts only because they're in different import paths, but any new engineer will find both and be unsure which to use.

**Impact**: Low. Cognitive tax for contributors; risk of importing the wrong class; impediment to eventual consolidation of the video feed state management.

**Effort**: Low. Rename the BLoC-internal one to `VideoFeedBlocState` (it's a `part of` the bloc, only one file needs changing). ~5 minutes.

**GitHub ticket**: [#3597](https://github.com/divinevideo/divine-mobile/issues/3597)
— closed 2026-05-18; work landed.

---

### Content moderation: 8 services for one concern
**Problem**: 8 intertwined services called independently at every filter point instead of composed into a pipeline.

**Evidence**: 8 files, 2,458 LOC total: `content_moderation_service.dart` (705), `content_filter_service.dart` (281), `content_blocklist_service.dart` (713), `moderation_label_service.dart` (631), `blocklist_content_filter.dart` (15, a single function wrapping `ContentBlocklistService.shouldFilterFromFeeds` to match a typedef — adds no logic), `nsfw_content_filter.dart` (113), `divine_host_filter_service.dart`, `video_moderation_status_service.dart` (278). `VideoEventService` imports all of them and calls them in sequence at every filter point. No single place to understand the full moderation pipeline.

**Impact**: Medium. Callers must coordinate 6+ service calls independently at every filter point; no single place to understand the moderation pipeline; `VideoEventService` couples to all 8 services. The 15-line wrapper function adds no logic.

**Effort**: Medium. Introduce a `ModerationPipeline` that composes `ContentBlocklistService`, `NsfwContentFilter`, `ModerationLabelService`, and `DivineHostFilterService` into a single `shouldFilter(VideoEvent) → ModerationDecision` call. `ContentFilterService` already partially does this; expand it. Inline the 15-line wrapper.

**GitHub ticket**: [#3598](https://github.com/divinevideo/divine-mobile/issues/3598) — closed 2026-05-13; work landed.

---

### Non-app code ships in production `lib/`
**Problem**: Debug screen, operational scripts (`lib/scripts/`), and test infrastructure (`lib/nostr/transport/`) compiled into every build with no production call sites.

**Evidence**: Debug screen: `lib/screens/debug_video_test.dart` (~120 lines, `ConsumerStatefulWidget`, not wired to any route, only referenced by its own file). Scripts: `lib/scripts/` (3 files, ~300 lines: `bulk_thumbnail_generator.dart`, `debugprint_to_unified_logger_migration.dart`, `migrate_logging.dart`; developer tools importing `openvine/services/` and `openvine/constants/`). Test infra: `lib/nostr/transport/` (3 files, ~100 lines: `in_memory_transport.dart`, `nostr_fixture_pump.dart`, `nostr_transport.dart`; relay simulation utilities with zero production call sites, tested in `test/nostr/transport/`). All compiled into every production build.

**Impact**: Low. Increases binary size; debug/test code in production bundle is a code hygiene issue; `lib/scripts/` imports heavy service dependencies unnecessarily.

**Effort**: Low. Move debug screen behind `DeveloperOptionsScreen` or delete; move scripts to `mobile/tools/` (already exists); move transport utilities to `test/helpers/nostr/`. ~520 LOC relocated or removed.

**GitHub ticket**: [#3599](https://github.com/divinevideo/divine-mobile/issues/3599)

---

### `DivineTheme` shadows `VineTheme`
**Problem**: `lib/theme/app_theme.dart` defines `DivineTheme` used in only 3 places (all in `notification_list_item.dart`). The canonical design system is `VineTheme` in `divine_ui`.

**Evidence**: `mobile/lib/theme/app_theme.dart` defines `DivineTheme` with purple-tinted colors. Only used in 3 places (all in `notification_list_item.dart`). Canonical design system is `VineTheme` in `mobile/packages/divine_ui/lib/src/theme/vine_theme.dart` (601 lines). `DivineTheme` appears to be an earlier design iteration that was not removed after `VineTheme` became the standard.

**Impact**: Low. Only 3 references; creates confusion about which theme system to use; diverges from the project's `VineTheme`-first rule.

**Effort**: Low. Add a notification accent color to `VineTheme`, update `notification_list_item.dart` to use it, delete `lib/theme/app_theme.dart`. ~30 lines removed.

**GitHub ticket**: [#3600](https://github.com/divinevideo/divine-mobile/issues/3600)
— closed 2026-08-06; work landed.
