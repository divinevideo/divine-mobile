# Skipped & Commented-Out Tests Report

**Generated:** 2026-02-24

---

## Summary

| Category | Count |
|----------|-------|
| Skipped tests (`skip: true` or `skip: 'reason'`) | ~300+ individual test cases across 100+ files |
| Entirely commented-out test files | 18 files (~60 tests) |
| Partially commented-out test files | 4 files (~9 tests) |

---

## Category 1: Skipped Tests

### test/goldens/

| File | Lines | Tests | Reason |
|------|-------|-------|--------|
| `screens/settings_screen_golden_test.dart` | 81 | 1 | `skip: true` |
| `widgets/upload_progress_golden_test.dart` | 161, 203, 247, 297 | 4 | `skip: true` |
| `widgets/user_avatar_golden_test.dart` | 175 | 1 | `skip: true` |
| `widgets/video_thumbnail_golden_test.dart` | 121, 160, 208 | 3 | `skip: true` |

### test/infrastructure/

| File | Lines | Tests | Reason |
|------|-------|-------|--------|
| `drift_setup_test.dart` | 97 | 1 | `skip: true` |
| `mass_test_generation_test.dart` | 61, 93, 130, 205, 247 | 5 | `skip: true` — `// TODO(any): Fix and re-enable` |
| `test_infrastructure_setup_test.dart` | 64, 115, 164, 191, 275 | 5 | `skip: true` |

### test/integration/

| File | Lines | Tests | Reason |
|------|-------|-------|--------|
| `account_deletion_flow_test.dart` | 159 | 1 | `skip: true` |
| `blossom_new_server_test.dart` | 14, 148 | 2 | `skip: true` |
| `blossom_upload_integration_test.dart` | 137 | 1 | `skip: true` |
| `blossom_upload_minimal_test.dart` | 175, 184 | 2 | `skip: true` |
| `blossom_upload_spec_test.dart` | 63 | 1 | `skip: true` |
| `blossom_upload_spec_test.dart` | 99 | 1 | `skip: !const bool.fromEnvironment('LIVE_TEST')` |
| `bug_report_blossom_upload_test.dart` | 273, 309 | 2 | `skip: true` |
| `cache_first_query_test.dart` | 405, 637 | 2 | `skip: true` |
| `explore_screen_real_relay_test.dart` | 259 | 1 | `skip: true` |
| `hashtag_grid_view_simple_test.dart` | 123 | 1 | `skip: true` |
| `hashtag_navigation_test.dart` | 56 | 1 | `skip: true` |
| `home_feed_display_bug_test.dart` | 154 | 1 | `skip: true` |
| `home_feed_seen_videos_test.dart` | 29 | 1 | `skip: 'HomeFeed provider does not implement seen video ordering'` |
| `nip42_auth_integration_test.dart` | 124 | 1 | `skip: true` |
| `profile_cache_sync_test.dart` | 136 | 1 | `skip: true` |
| `profile_me_redirect_integration_test.dart` | 224 | 1 | `skip: true` |
| `profile_route_loads_test.dart` | 160 | 1 | `skip: true` |
| `reactive_pagination_test.dart` | 179 | 1 | `skip: true` |
| `real_nostr_video_integration_test.dart` | 67, 97 | 2 | `skip: true` |
| `relay_pagination_integration_test.dart` | 332 | 1 | `skip: true` |
| `search_hybrid_relay_test.dart` | 205 | 1 | `skip: true` |
| `search_navigation_integration_test.dart` | 279 | 1 | `skip: true` |
| `subscription_fix_test.dart` | 142 | 1 | `skip: true` |
| `thumbnail_api_integration_test.dart` | 86, 180, 198, 216 | 4 | `skip: true` |
| `thumbnail_url_preservation_test.dart` | 71 | 1 | `skip: true` |
| `upload_publish_e2e_comprehensive_test.dart` | 336, 413 | 2 | `skip: true` |
| `video_event_service_managed_test.dart` | 97 | 1 | `skip: true` |
| `video_event_service_simple_test.dart` | 169, 193, 257 | 3 | `skip: true` |
| `video_event_service_with_event_router_test.dart` | 358 | 1 | `skip: true` |
| `video_event_thumbnail_integration_test.dart` | 240 | 1 | `skip: true` |
| `video_feed_double_load_debug_test.dart` | 101 | 1 | `skip: true` |
| `video_player_backend_test.dart` | 284, 301 | 2 | `skip: true` |
| `video_record_publish_e2e_test.dart` | 278 | 1 | `skip: true` |
| `video_thumbnail_publish_e2e_test.dart` | 470 | 1 | `skip: true` |
| `video_upload_integration_test.dart` | 181 | 1 (group) | `skip: true` |

### test/performance/

| File | Lines | Tests | Reason |
|------|-------|-------|--------|
| `camera_initialization_benchmark_test.dart` | 129 | 1 | `skip: true` |
| `proofmode_performance_test.dart` | 124 | 1 | `skip: true` |

### test/providers/

| File | Lines | Tests | Reason |
|------|-------|-------|--------|
| `account_deletion_provider_test.dart` | 19 | 1 | `skip: true` |
| `curation_provider_lifecycle_test.dart` | 115, 155 | 2 | `skip: true` |
| `curation_provider_tab_refresh_test.dart` | 192 | 1 | `skip: true` |
| `explore_active_video_test.dart` | 107, 165 | 2 | `skip: true` |
| `hashtag_feed_providers_test.dart` | 155, 201, 250 | 3 | `skip: true` |
| `home_feed_provider_test.dart` | 261 | 1 | `skip: 'Complex mocking required: FollowRepository.followingStream and VideoEventService listeners'` |
| `profile_stats_calculation_test.dart` | 314 | 1 | `skip: true` |
| `profile_stats_provider_test.dart` | 96, 127 | 2 | `skip: true` |
| `readiness_gate_providers_test.dart` | 110 | 1 | `skip: true` |
| `seen_videos_notifier_test.dart` | 155 | 1 | `skip: true` |
| `video_controller_lifecycle_test.dart` | 198 | 1 | `skip: true` |
| `video_events_listener_simple_test.dart` | 78, 115, 205, 242 | 4 | `skip: true` |
| `video_events_provider_fresh_test.dart` | 158 | 1 | `skip: true` |
| `video_events_provider_test.dart` | 317 | 1 | `skip: true` |

### test/router/

| File | Lines | Tests | Reason |
|------|-------|-------|--------|
| `all_routes_test.dart` | 416 | 1 | `skip: true` |
| `app_shell_header_test.dart` | 32, 47, 59, 73, 170 | 5 | `skip: true` |
| `app_shell_integration_test.dart` | 77, 160, 241, 312 | 4 | `skip: true` |
| `consolidated_routes_test.dart` | 40, 71, 105 | 3 | `skip: true` |
| `explore_tab_navigation_test.dart` | 131 | 1 | `skip: true` |
| `explore_tab_tap_navigation_test.dart` | 63 | 1 | `skip: true` |
| `hashtag_navigation_crash_test.dart` | 114 | 1 | `skip: true` |
| `navigation_scenarios_test.dart` | 704 | 1 | `skip: true` |
| `page_context_provider_test.dart` | 179 | 1 | `skip: true` |
| `profile_me_redirect_test.dart` | 167 | 1 | `skip: true` |
| `router_location_provider_test.dart` | 103 | 1 | `skip: true` |
| `search_route_test.dart` | 51, 80, 104, 111 | 4 | `skip: true` |

### test/screens/

| File | Lines | Tests | Reason |
|------|-------|-------|--------|
| `explore_screen_pull_to_refresh_test.dart` | 124 | 1 | `skip: true` |
| `explore_screen_pure_test.dart` | 168 | 1 | `skip: true` |
| `explore_screen_router_test.dart` | 113, 178 | 2 | `skip: true` |
| `explore_screen_video_display_test.dart` | 234 | 1 | `skip: true` |
| `feature_flag_screen_test.dart` | 57, 188 | 2 | `skip: true` |
| `feed_screen_scroll_test.dart` | 57, 92, 108, 135, 166 | 5 | `skip: true` |
| `hashtag_feed_embedded_callback_test.dart` | 109 | 1 | `skip: true` |
| `hashtag_feed_embedded_navigation_test.dart` | 208 | 1 | `skip: true` |
| `hashtag_feed_loading_test.dart` | 119 | 1 | `skip: true` |
| `hashtag_feed_screen_tdd_test.dart` | 146 | 1 | `skip: true` |
| `notifications_navigation_test.dart` | 164 | 1 | `skip: true` |
| `profile_edit_video_navigation_test.dart` | 196 | 1 | `skip: true` |
| `profile_grid_tap_navigation_test.dart` | 326 | 1 | `skip: true` |
| `profile_screen_router_test.dart` | 150, 174, 210, 238 | 4 | `skip: true` |
| `profile_share_edit_buttons_test.dart` | 171 | 1 | `skip: true` |
| `profile_video_deletion_test.dart` | 46, 85, 106, 131 | 4 | `skip: true` |
| `relay_settings_nip11_info_test.dart` | 338 | 1 | `skip: true` |
| `safety_settings_screen_test.dart` | 77, 92, 101, 110, 119, 128 | 6 | `skip: true` |
| `search_hashtag_navigation_test.dart` | 40 | 1 | `skip: true` |
| `search_screen_navigation_test.dart` | 172 | 1 | `skip: true` |
| `search_screen_pure_url_test.dart` | 225 | 1 | `skip: true` |
| `sounds_screen_test.dart` | 332, 358 | 2 | `skip: true` |
| `video_editor_route_test.dart` | 188 | 1 | `skip: true` |
| `video_editor/video_text_editor_screen_test.dart` | 149, 173, 203 | 3 | `skip: true` |

### test/services/

| File | Lines | Tests | Reason |
|------|-------|-------|--------|
| `audio_extraction_service_test.dart` | 202, 229 | 2 | `skip: 'Requires test video file with/without audio track'` |
| `curated_list_service_persistence_test.dart` | 94 | 1 | `skip: true` |
| `curated_list_service_persistence_test.dart` | 344 | 1 | `skip: 'Flaky: timestamp-based ID collision in concurrent creation'` |
| `curated_list_service_query_test.dart` | 89, 127, 493, 505, 562 | 5 | `skip: true` |
| `curation_service_editors_picks_test.dart` | 216 | 1 | `skip: true` |
| `curation_service_kind_30005_test.dart` | 76, 146 | 2 | `skip: true` |
| `curation_service_test.dart` | 71 | 1 | `skip: true` |
| `deep_link_service_test.dart` | 109 | 1 | `skip: true` |
| `feature_flag_service_test.dart` | 78 | 1 | `skip: true` |
| `m3u8_resolver_service_test.dart` | 108 | 1 | `skip: 'Network test - run manually'` |
| `nostr_key_manager_contacts_fetch_test.dart` | 108 | 1 | `skip: 'Same as above: _setupUserSession uses real WebSocket in test env.'` |
| `nostr_key_manager_profile_fetch_test.dart` | 69, 200, 231 | 3 | `skip: true` |
| `profile_cache_test.dart` | 234 | 1 | `skip: true` |
| `profile_editing_test.dart` | 389 | 1 | `skip: true` |
| `seed_media_preload_service_test.dart` | 247 | 1 | `skip: true` |
| `subtitle_generation_service_test.dart` | 31 | 1 | `skip: 'See: github issue #1568'` |
| `upload_initialization_helper_web_test.dart` | 60, 92, 116, 128, 151, 165, 175, 190 | 8 | `skip: !kIsWeb ? 'Web-only test' : null` |
| `upload_manager_thumbnail_test.dart` | 67, 129 | 2 | `skip: true` |
| `upload_manager_web_test.dart` | 67, 81, 95, 109, 124, 138, 155, 165, 181 | 9 | `skip: !kIsWeb ? 'Web-only test' : null` |
| `video_event_publisher_native_proof_test.dart` | 344 | 1 | `skip: true` |
| `video_event_service_replaceable_test.dart` | 276 | 1 | `skip: true` |
| `video_event_service_repost_test.dart` | 420 | 1 | `skip: true` |
| `video_event_service_reposters_test.dart` | 157, 251 | 2 | `skip: true` |

### test/startup/

| File | Lines | Tests | Reason |
|------|-------|-------|--------|
| `startup_diagnostics_test.dart` | 232 | 1 | `skip: true` |

### test/tools/

| File | Lines | Tests | Reason |
|------|-------|-------|--------|
| `future_delayed_detector_test.dart` | 380 | 1 | `skip: true` |
| `naming_convention_test.dart` | 69, 111 | 2 | `skip: true` |

### test/unit/

| File | Lines | Tests | Reason |
|------|-------|-------|--------|
| `services/bug_report_service_test.dart` | 93, 235 | 2 | `skip: !(Platform.isIOS \|\| Platform.isAndroid)` (mobile-only) |
| `services/classic_vines_priority_test.dart` | 118, 393 | 2 | `skip: true` |
| `services/video_cache_service_basic_test.dart` | 161 | 1 | `skip: true` |
| `services/video_event_service_deduplication_test.dart` | 131, 183, 254, 309, 351, 400, 491 | 7 | `skip: true` |
| `services/video_event_service_infinite_scroll_test.dart` | 113, 159, 339, 388 | 4 | `skip: true` |
| `services/video_event_service_subscription_test.dart` | 270 | 1 | `skip: true` — `// TODO(any): Fix and re-enable` |

### test/widgets/

| File | Lines | Tests | Reason |
|------|-------|-------|--------|
| `all_settings_screens_scaffold_test.dart` | 28, 68 | 2 | `skip: true` |
| `bug_report_dialog_test.dart` | 333, 471 | 2 | `skip: true` |
| `composable_video_grid_test.dart` | 107, 136, 198, 228, 254 | 5 | `skip: true` |
| `comprehensive_clickable_hashtag_text_test.dart` | 180, 234, 261, 304 | 4 | `skip: true` |
| `comprehensive_user_avatar_test.dart` | golden group | 4 | `skip: 'Golden tests require golden file generation and are maintained separately'` |
| `original_content_badge_test.dart` | 157, 228 | 2 | `skip: true` |
| `proofmode_badge_test.dart` | 177 | 1 | `skip: true` |
| `settings_bottom_nav_test.dart` | 93 | 1 | `skip: true` |
| `settings_delete_account_test.dart` | 55, 114, 152 | 3 | `skip: true` |
| `settings_screen_scaffold_test.dart` | 110 | 1 | `skip: true` |
| `settings_screen_test.dart` | 55, 83, 109 | 3 | `skip: true` |
| `share_menu_safety_section_test.dart` | 247 | 1 | `skip: true` |
| `sound_list_item_test.dart` | 78, 98, 177, 230 | 4 | `skip: true` |
| `subtitle_generation_sheet_test.dart` | 25 | 1 | `skip: 'See: github issue #1568'` |
| `user_profile_tile_layout_test.dart` | 660 | 1 | `skip: true` |
| `video_error_overlay_test.dart` | 181 | 1 | `skip: true` |
| `video_feed_item_aspect_ratio_test.dart` | 103 | 1 | `skip: true` |
| `video_feed_item_moderation_icon_test.dart` | 68, 100 | 2 | `skip: true` |
| `video_feed_item_repost_header_test.dart` | 156 | 1 | `skip: true` |
| `video_feed_item_unmount_safety_test.dart` | 74 | 1 | `skip: true` |
| `video_metadata/video_metadata_tags_input_test.dart` | 215 | 1 | `skip: !VideoEditorConstants.enableTagLimit` (conditional) |
| `video_overlay_context_title_simple_test.dart` | 92 | 1 | `skip: true` |

### test/widget/

| File | Lines | Tests | Reason |
|------|-------|-------|--------|
| `screens/hashtag_feed_screen_test.dart` | 381 | 1 | `skip: true` |

---

## Category 2: Entirely Commented-Out Test Files

These files have all test code commented out, leaving only `void main() {}`. Most have a `// TODO(any): Fix and re-enable this test` header.

| File | Commented Tests | Description |
|------|-----------------|-------------|
| `test/router/route_normalization_test.dart` | 5 | Route normalization (negative indices, unknown paths, hashtag encoding) |
| `test/integration/camera_draft_autosave_test.dart` | 3 | Camera draft auto-save (navigation, cleanup, race conditions) |
| `test/integration/camera_publish_flow_test.dart` | 3 | Camera publish flow (recording, publishing, processing flag) |
| `test/integration/composable_video_grid_test.dart` | 4 | ComposableVideoGrid integration (display, tapping, aspect ratio) |
| `test/integration/home_feed_follows_test.dart` | 2 | Home feed follows (videos from followed users, cross-feed events) |
| `test/integration/relay_video_subscription_test.dart` | 1 | Real relay video subscription |
| `test/integration/video_event_service_relay_test.dart` | 3 | Live relay integration (event receiving, subscription mgmt, error handling) |
| `test/integration/video_loading_flow_test.dart` | 5 | Video loading flow (service->provider->state, cleanup, empty state) |
| `test/integration/video_pipeline_debug_test.dart` | 2 | Video pipeline debugging (complete flow, direct service test) |
| `test/providers/home_feed_refresh_on_follow_test.dart` | 4 | Home feed refresh on follow/unfollow changes |
| `test/providers/profile_feed_pagination_test.dart` | 6 | Profile feed cursor pagination (load, append, hasMore, dedup) |
| `test/screens/explore_screen_missing_methods_test.dart` | 6 | ExploreScreen method TDD (hidden, visible, feed mode, hashtags) |
| `test/services/event_router_test.dart` | multiple | EventRouter TDD tests (centralized event caching) |
| `test/widgets/share_video_menu_comprehensive_test.dart` | multiple | ShareVideoMenu comprehensive TDD tests |

---

## Category 3: Partially Commented-Out Test Files

These files have some tests commented out while others remain active.

| File | Commented Tests | Description |
|------|-----------------|-------------|
| `test/services/subscription_manager_cache_test.dart` | 3 | Event cache pruning tests |
| `test/services/video_event_service_pagination_test.dart` | 2 | Pagination tests |
| `test/unit/curated_list_relay_sync_test.dart` | 1 | Kind 30005 relay sync subscription test |
| `test/unit/services/subscription_manager_filter_test.dart` | 3 | Filter preservation (hashtag, group, combined) |

---

## Skip Reasons Breakdown

| Reason | Count | Notes |
|--------|-------|-------|
| `skip: true` (no reason) | ~270+ | Vast majority — typically preceded by `// TODO(any): Fix and re-enable` |
| `skip: !kIsWeb ? 'Web-only test' : null` | 17 | Conditional — only runs on web platform |
| `skip: !(Platform.isIOS \|\| Platform.isAndroid)` | 2 | Conditional — only runs on mobile |
| `skip: !const bool.fromEnvironment('LIVE_TEST')` | 1 | Conditional — requires live test env |
| `skip: !VideoEditorConstants.enableTagLimit` | 1 | Conditional — feature flag gated |
| `skip: 'Requires test video file...'` | 2 | Missing test fixtures |
| `skip: 'Network test - run manually'` | 1 | Manual network test |
| `skip: 'Complex mocking required...'` | 1 | Mocking complexity |
| `skip: 'HomeFeed provider does not implement...'` | 1 | Missing feature |
| `skip: 'Flaky: timestamp-based ID collision...'` | 1 | Known flaky test |
| `skip: 'See: github issue #1568'` | 2 | Linked to issue |
| `skip: 'Same as above: uses real WebSocket...'` | 1 | Test env limitation |

---

## Hotspots (Files with Most Skipped Tests)

| File | Skipped |
|------|---------|
| `test/widgets/comprehensive_user_avatar_test.dart` | 4 (golden tests only) |
| `test/services/upload_manager_web_test.dart` | 9 (web-only) |
| `test/services/upload_initialization_helper_web_test.dart` | 8 (web-only) |
