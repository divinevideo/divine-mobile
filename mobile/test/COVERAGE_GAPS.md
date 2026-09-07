Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This generated coverage report is not maintained as a current source of truth.

# Test Coverage Gaps

**Generated**: 2025-10-20
**Overall Coverage**: 45.0% (11,857/26,335 lines)
**Total lib files**: 253

---

## Executive Summary

The codebase has **253 files in lib/** with an overall test coverage of **45.0%**. This analysis identifies critical gaps in test coverage, prioritized by user impact and complexity.

### Critical Findings
- **20+ services** with 0% or near-zero coverage
- **15+ screens** with <60% coverage including core user flows
- **9 widgets** with <60% coverage including video playback components

---

## Critical User Flows (E2E + Unit Tests Required)

### 1. Video Upload & Publish
- **E2E test exists**: Yes (`test/integration/upload_publish_e2e_comprehensive_test.dart`)
- **Service unit tests**:
  - ✅ `blossom_upload_service.dart` - Has integration tests
  - ❌ `personal_event_cache_service.dart` - **0% coverage**
  - ❌ `content_moderation_service.dart` - **0.5% coverage**
- **Coverage**: ~15-25% (based on related services)
- **Missing Scenarios**:
  - [ ] Upload failure retry logic
  - [ ] Network interruption during upload
  - [ ] Blossom server timeout handling
  - [ ] Video processing pipeline errors
  - [ ] Nostr event publishing failures

### 2. Home Feed Loading & Playback
- **E2E test exists**: Yes (`test/integration/home_feed_follows_test.dart`, `home_feed_display_bug_test.dart`)
- **Service unit tests**:
  - ⚠️ `video_event_service.dart` - Has extensive tests but coverage not in critical list
  - ⚠️ `video_subscription_service.dart` - Coverage unknown
  - ❌ `personal_event_cache_service.dart` - **0% coverage**
- **Screen coverage**: `video_feed_screen.dart` - **36.2% coverage**
- **Widget coverage**: `video_feed_item.dart` - **56.2% coverage**
- **Missing Scenarios**:
  - [ ] Empty feed state handling
  - [ ] Video player error recovery
  - [ ] Feed pagination edge cases
  - [ ] Video caching failures
  - [ ] Relay connection timeouts

### 3. Profile Viewing
- **E2E test exists**: Yes (`test/integration/profile_route_loads_test.dart`)
- **Service unit tests**:
  - ⚠️ `profile_repository` package - Has tests but coverage needs verification
  - ❌ `mute_service.dart` - **0% coverage**
- **Screen coverage**: `profile_screen_router.dart` - **9.5% coverage**
- **Missing Scenarios**:
  - [ ] Profile not found handling
  - [ ] Profile cache expiration
  - [ ] Following/unfollowing edge cases
  - [ ] Profile picture loading failures
  - [ ] NIP-05 verification display

### 4. Hashtag Feed
- **E2E test exists**: Yes (`test/integration/hashtag_filtering_integration_test.dart`, `hashtag_navigation_test.dart`)
- **Service unit tests**:
  - ❌ `hashtag_cache_service.dart` - **12.9% coverage**
  - ⚠️ `hashtag_service.dart` - Coverage unknown
- **Screen coverage**: `hashtag_feed_screen.dart` - **36.0% coverage**
- **Missing Scenarios**:
  - [ ] Invalid hashtag handling
  - [ ] Empty hashtag feed
  - [ ] Hashtag cache miss scenarios
  - [ ] Multiple hashtag filtering
  - [ ] Hashtag search performance

### 5. Video Sharing/Reposting
- **E2E test exists**: Partial (`test/integration/revine_end_to_end_test.dart`)
- **Service unit tests**:
  - ⚠️ `video_sharing_service.dart` - Has unit tests
- **Widget coverage**: Live share sheet coverage should be verified against
  the current share action widgets.
- **Missing Scenarios**:
  - [ ] Share to external app flows
  - [ ] Repost with comment
  - [ ] Share URL generation
  - [ ] Deep link handling
  - [ ] Share permission errors

---

## Files with <50% Coverage (Critical)

### Services (0-25% Coverage) - **HIGHEST PRIORITY**

| Coverage | Lines | File | User Impact | Complexity |
|----------|-------|------|-------------|------------|
| 0.0% | 0/263 | `analytics_api_service.dart` | Medium | Medium |
| 0.0% | 0/150 | `startup_performance_service.dart` | Low | Low |
| 0.0% | 0/132 | `personal_event_cache_service.dart` | **HIGH** | High |
| 0.0% | 0/188 | `mute_service.dart` | Medium | Medium |
| 0.0% | 0/134 | `p2p_discovery_service.dart` | Low | High |
| 0.0% | 0/116 | `content_deletion_service.dart` | Medium | Medium |
| 0.0% | 0/106 | `p2p_video_sync_service.dart` | Low | High |
| 0.0% | 0/67 | `cache_recovery_service.dart` | Medium | Medium |
| 0.5% | 1/215 | `content_moderation_service.dart` | **HIGH** | **High** |
| 0.7% | 1/135 | `feature_flag_service.dart` | Medium | Low |
| 1.0% | 1/104 | `nip98_auth_service.dart` | High | Medium |
| 3.8% | 7/185 | `camera/enhanced_mobile_camera_interface.dart` | **HIGH** | **High** |
| 4.1% | 6/147 | `content_reporting_service.dart` | Medium | Medium |
| 8.0% | 9/112 | `camera_service_impl.dart` | **HIGH** | **High** |
| 12.9% | 4/31 | `hashtag_cache_service.dart` | Medium | Low |

### Screens (<40% Coverage) - **HIGH PRIORITY**

| Coverage | Lines | File | User Impact | Complexity |
|----------|-------|------|-------------|------------|
| 0.0% | 0/128 | `comments_screen.dart` | **HIGH** | Medium |
| 0.2% | 1/584 | `profile_setup_screen.dart` | **HIGH** | **High** |
| 0.6% | 1/173 | `web_auth_screen.dart` | High | Medium |
| 1.0% | 1/99 | `key_import_screen.dart` | High | Medium |
| 9.5% | 35/369 | `profile_screen_router.dart` | **HIGH** | High |
| 13.2% | 17/129 | `blossom_settings_screen.dart` | Medium | Low |
| 26.8% | 38/142 | `vine_drafts_screen.dart` | Medium | Medium |
| 28.1% | 27/96 | `relay_settings_screen.dart` | Medium | Medium |
| 35.9% | 83/231 | `pure/video_metadata_screen_pure.dart` | **HIGH** | Medium |
| 36.0% | 41/114 | `hashtag_feed_screen.dart` | **HIGH** | Medium |
| 36.2% | 72/199 | `video_feed_screen.dart` | **CRITICAL** | **High** |
| 36.8% | 152/413 | `pure/universal_camera_screen_pure.dart` | **CRITICAL** | **High** |

### Widgets (<60% Coverage)

| Coverage | Lines | File | User Impact | Complexity |
|----------|-------|------|-------------|------------|
| 0.0% | 0/35 | `app_lifecycle_handler.dart` | Medium | Low |
| 0.8% | 1/118 | `video_overlay_modal_compact.dart` | Medium | Medium |
| 15.8% | 3/19 | `camera_fab.dart` | Low | Low |
| 40.2% | 45/112 | `blurhash_display.dart` | Medium | Low |
| 50.4% | 60/119 | `notification_list_item.dart` | Medium | Low |
| 55.1% | 59/107 | `video_metrics_tracker.dart` | Low | Low |
| 56.2% | 150/267 | `video_feed_item.dart` | **CRITICAL** | Medium |
| 57.1% | 44/77 | `camera_controls_overlay.dart` | High | Low |

---

## Recommended Test Scenarios (Top 10 Priority Files)

### 1. `personal_event_cache_service.dart` (0/132 lines, 0%)
**User Impact**: HIGH - Affects video loading performance
**Complexity**: High - Caching logic with invalidation

**Test Scenarios**:
- [ ] Cache hit for recent video event
- [ ] Cache miss triggers relay fetch
- [ ] Cache invalidation on new publish
- [ ] Cache size limit enforcement (LRU eviction)
- [ ] Concurrent cache read/write safety
- [ ] Cache corruption recovery

### 2. `content_moderation_service.dart` (1/215 lines, 0.5%)
**User Impact**: HIGH - User safety and content filtering
**Complexity**: High - Complex filtering logic

**Test Scenarios**:
- [ ] NSFW content detection and filtering
- [ ] User-reported content flagging
- [ ] Muted user content filtering
- [ ] Content label application (NIP-32)
- [ ] Moderation queue processing
- [ ] Appeal/unflag workflow

### 3. `video_feed_screen.dart` (72/199 lines, 36.2%)
**User Impact**: CRITICAL - Primary app interface
**Complexity**: High - Complex state management

**Test Scenarios**:
- [ ] Initial feed load with 10+ videos
- [ ] Infinite scroll pagination
- [ ] Pull-to-refresh behavior
- [ ] Video autoplay when visible
- [ ] Video pause when not visible
- [ ] Empty feed state display
- [ ] Error state recovery (retry button)
- [ ] Navigation to profile from feed item
- [ ] Like/comment interaction

### 4. `universal_camera_screen_pure.dart` (152/413 lines, 36.8%)
**User Impact**: CRITICAL - Video creation workflow
**Complexity**: High - Camera, recording, and UI state

**Test Scenarios**:
- [ ] Camera permission denied handling
- [ ] Camera initialization success/failure
- [ ] Video recording start/stop
- [ ] Recording time limit (6 seconds)
- [ ] Flash toggle behavior
- [ ] Camera flip (front/back)
- [ ] Recording cancellation (discard)
- [ ] Recording preview playback
- [ ] Navigation to metadata screen after recording

### 5. Live share sheet
**User Impact**: HIGH - Social sharing features
**Complexity**: High - External integrations

**Test Scenarios**:
- [ ] Share button opens sheet
- [ ] Copy video link to clipboard
- [ ] Share to Twitter/X
- [ ] Share to native platform (iOS/Android)
- [ ] Repost (revine) video
- [ ] Quote post with comment
- [ ] Share URL format validation
- [ ] Deep link generation
- [ ] Share analytics tracking

### 6. `comments_screen.dart` (0/128 lines, 0%)
**User Impact**: HIGH - User engagement
**Complexity**: Medium - Comment thread display

**Test Scenarios**:
- [ ] Load comments for video
- [ ] Display comment thread hierarchy
- [ ] Post new comment
- [ ] Reply to existing comment
- [ ] Delete own comment
- [ ] Report inappropriate comment
- [ ] Comment pagination (load more)
- [ ] Real-time comment updates via relay

### 7. `profile_screen_router.dart` (35/369 lines, 9.5%)
**User Impact**: HIGH - User discovery
**Complexity**: High - Complex routing and data loading

**Test Scenarios**:
- [ ] Load profile by npub
- [ ] Load profile by NIP-05 identifier
- [ ] Display user's videos grid
- [ ] Follow/unfollow user
- [ ] Navigate to follower list
- [ ] Navigate to following list
- [ ] Handle non-existent profile (404)
- [ ] Profile cache hit/miss
- [ ] Edit own profile

### 8. `camera_service_impl.dart` (9/112 lines, 8.0%)
**User Impact**: HIGH - Video recording
**Complexity**: High - Platform-specific camera APIs

**Test Scenarios**:
- [ ] Initialize camera controller
- [ ] Handle camera permission denied
- [ ] Start video recording
- [ ] Stop video recording
- [ ] Dispose camera resources
- [ ] Handle camera errors gracefully
- [ ] Switch camera (front/back)
- [ ] Set flash mode
- [ ] Set focus/exposure

### 9. `video_feed_item.dart` (150/267 lines, 56.2%)
**User Impact**: CRITICAL - Individual video display
**Complexity**: Medium - Video player + UI

**Test Scenarios**:
- [ ] Display video metadata (title, author)
- [ ] Video player initialization
- [ ] Autoplay when visible in viewport
- [ ] Pause when scrolled out of view
- [ ] Loop video playback
- [ ] Display like count
- [ ] Display comment count
- [ ] Tap to open video detail
- [ ] Double-tap to like
- [ ] Blurhash placeholder display

### 10. `nip98_auth_service.dart` (1/104 lines, 1.0%)
**User Impact**: High - Blossom upload authentication
**Complexity**: Medium - Cryptographic signing

**Test Scenarios**:
- [ ] Generate NIP-98 auth header
- [ ] Sign upload request with user key
- [ ] Validate signature format
- [ ] Handle missing/invalid keys
- [ ] Timestamp validation
- [ ] Auth header expiration

---

## Test Coverage Improvement Plan

### Phase 1: Critical Services (Week 1-2)
1. `personal_event_cache_service.dart` - Add unit tests for caching logic
2. `content_moderation_service.dart` - Add unit tests for filtering rules
3. `nip98_auth_service.dart` - Add unit tests for auth header generation

**Target**: Bring all critical services to ≥70% coverage

### Phase 2: Core User Flows (Week 3-4)
1. `video_feed_screen.dart` - Add widget tests for feed interactions
2. `universal_camera_screen_pure.dart` - Add widget tests for recording flow
3. `comments_screen.dart` - Add widget tests for comment interactions
4. `profile_screen_router.dart` - Add widget tests for profile display

**Target**: Bring all core screens to ≥70% coverage

### Phase 3: Critical Widgets (Week 5)
1. Live share sheet - Add widget tests for sharing actions
2. `video_feed_item.dart` - Add widget tests for video item interactions
3. `camera_controls_overlay.dart` - Add widget tests for camera controls

**Target**: Bring all critical widgets to ≥80% coverage

### Phase 4: E2E Test Enhancement (Week 6)
1. Enhance upload E2E test with failure scenarios
2. Add E2E test for complete feed → video detail → comment flow
3. Add E2E test for profile viewing and following
4. Add E2E test for hashtag navigation
5. Add E2E test for video sharing

**Target**: 100% E2E coverage of critical user journeys

---

## Notes

- **Overall coverage target**: 70% (currently 45%)
- **Critical service target**: 80% (currently <10% for many)
- **Screen coverage target**: 70% (currently 36% average for critical screens)
- **TDD violations**: Many new features added without tests-first approach
- **Integration test gaps**: Limited relay integration scenarios, missing error cases

### Codebase Health Issues
- Multiple services with 0% coverage indicate tests were not written during development
- Core screens (video_feed, camera) have <40% coverage despite being critical paths
- Many generated files (`.g.dart`) artificially inflate file count
- Need stricter pre-commit hooks to enforce minimum coverage thresholds

### Recommendations
1. **Enforce TDD**: Require tests before merging new services/screens
2. **Add pre-commit hooks**: Block commits with <60% coverage on modified files
3. **Prioritize by user impact**: Focus testing effort on video_feed, camera, and sharing flows
4. **Add E2E smoke tests**: Quick regression suite for critical paths
5. **Document test patterns**: Create examples for common scenarios (mocking Nostr, camera, etc.)
