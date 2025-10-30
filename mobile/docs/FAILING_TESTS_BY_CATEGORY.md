# Failing Tests by Category

**Generated**: 2025-10-25


## Services (212 failures)


### `test/services/analytics_comprehensive_test.dart`

- [ ] Analytics Service Comprehensive Tests should send correct data structure to analytics endpoint
- [ ] Analytics Service Comprehensive Tests should batch track multiple videos with delay
- [ ] Analytics Service Comprehensive Tests should handle empty hashtags and null title correctly
- [ ] Analytics Service Comprehensive Tests should include all required fields in analytics payload
- [ ] Analytics Service Comprehensive Tests should handle concurrent tracking requests

### `test/services/analytics_service_batch_test.dart`

- [ ] AnalyticsService Batch Tracking should space out batch video views with proper rate limiting
- [ ] AnalyticsService Batch Tracking should handle empty video list

### `test/services/background_activity_manager_test.dart`

- [ ] BackgroundActivityManager should register and notify services

### `test/services/blossom_upload_service_test.dart`

- [ ] BlossomUploadService Real Blossom Upload Implementation should send PUT request with raw bytes and NIP-98 auth header

### `test/services/bookmark_sync_test.dart`

- [ ] BookmarkSyncWorker handles multiple pending sets
- [ ] BookmarkSyncWorker persists sync state across restarts

### `test/services/camera/enhanced_mobile_camera_interface_test.dart`

- [ ] EnhancedMobileCameraInterface Integration Tests Real Camera Initialization should initialize with actual camera hardware
- [ ] EnhancedMobileCameraInterface Integration Tests Real Camera Initialization should provide a valid preview widget after initialization
- [ ] EnhancedMobileCameraInterface Integration Tests Real Video Recording should record actual video to disk
- [ ] EnhancedMobileCameraInterface Integration Tests Real Video Recording should handle multiple recording segments
- [ ] EnhancedMobileCameraInterface Integration Tests Real Camera Switching should switch between available cameras
- [ ] EnhancedMobileCameraInterface Integration Tests Real Zoom Functionality should control actual camera zoom
- [ ] EnhancedMobileCameraInterface Integration Tests Real Zoom Functionality should respect device zoom limits
- [ ] EnhancedMobileCameraInterface Integration Tests Real Focus Functionality should set actual camera focus point
- [ ] EnhancedMobileCameraInterface Integration Tests Real Flash Functionality should toggle through actual flash modes
- [ ] EnhancedMobileCameraInterface Integration Tests Preview Widget Integration should show real camera preview after initialization
- [ ] EnhancedMobileCameraInterface Integration Tests Resource Cleanup should properly dispose camera resources

### `test/services/camera_service_macos_test.dart`

- [ ] CameraService macOS Support should list available cameras on macOS
- [ ] CameraService macOS Support should initialize camera on macOS
- [ ] CameraService macOS Support should support video recording on macOS
- [ ] CameraService macOS Support should handle resolution settings on macOS
- [ ] CameraService macOS Support should handle camera switching on macOS if multiple cameras exist
- [ ] CameraService macOS Support should properly dispose camera resources
- [ ] CameraService macOS Support should handle flash modes on macOS
- [ ] CameraService macOS Support should handle focus and exposure on macOS

### `test/services/curated_list_service_query_test.dart`

- [ ] CuratedListService - Query Operations Query Operations - Edge Cases search performance with many lists

### `test/services/curation_publish_test.dart`

- [ ] CurationService Publishing buildCurationEvent should create kind 30005 event with correct structure
- [ ] CurationService Publishing buildCurationEvent should handle optional fields correctly
- [ ] CurationService Publishing buildCurationEvent should add client tag for attribution
- [ ] CurationService Publishing publishCuration should publish event to Nostr and return success
- [ ] CurationService Publishing publishCuration should handle complete failure gracefully
- [ ] CurationService Publishing publishCuration should handle partial relay success
- [ ] CurationService Publishing Local Persistence should mark curation as published locally after success
- [ ] CurationService Publishing Local Persistence should persist publish status across service restarts
- [ ] CurationService Publishing Background Retry Worker should retry unpublished curations with exponential backoff
- [ ] CurationService Publishing Background Retry Worker should stop retrying after max attempts
- [ ] CurationService Publishing Publishing Status UI should report "Publishing..." status during publish
- [ ] CurationService Publishing Publishing Status UI should show relay success count in status

### `test/services/curation_service_create_test.dart`

- [ ] CurationService.createCurationSet() successfully creates and publishes curation set
- [ ] CurationService.createCurationSet() creates event with correct kind 30005
- [ ] CurationService.createCurationSet() creates event with correct tags
- [ ] CurationService.createCurationSet() uses curator pubkey from keyManager
- [ ] CurationService.createCurationSet() handles partial broadcast success
- [ ] CurationService.createCurationSet() creates curation set with empty video list
- [ ] CurationService.createCurationSet() creates curation set with minimal parameters

### `test/services/curation_service_editors_picks_test.dart`

- [ ] CurationService Editor's Picks should show videos from Classic Vines pubkey in Editor's Picks
- [ ] CurationService Editor's Picks should randomize Classic Vines order in Editor's Picks
- [ ] CurationService Editor's Picks should show default video when no Classic Vines available
- [ ] CurationService Editor's Picks should handle empty video list gracefully

### `test/services/curation_service_kind_30005_test.dart`

- [ ] CurationService - Kind 30005 Nostr Queries subscribeToCurationSets() subscribes to kind 30005 events
- [ ] CurationService - Kind 30005 Nostr Queries subscribeToCurationSets() processes incoming curation set events

### `test/services/curation_service_test.dart`

- [ ] CurationService should not automatically fetch trending data on initialization

### `test/services/deep_link_service_test.dart`

- [ ] DeepLinkService URL Parsing Profile URL Parsing rejects profile URL with extra path segments

### `test/services/embedded_relay_no_websocket_test.dart`

- [ ] Embedded Relay WITHOUT WebSocket should initialize WITHOUT starting WebSocket server on localhost:7447

### `test/services/embedded_relay_service_test.dart`

- [ ] NostrService Initialization should initialize embedded relay successfully
- [ ] NostrService Video Event Subscriptions should subscribe to video events (kind 34236)
- [ ] NostrService Video Event Subscriptions should handle subscription to home feed (following)
- [ ] NostrService Event Broadcasting should broadcast video events to embedded relay
- [ ] NostrService Relay Management should report correct relay status
- [ ] NostrService Cleanup should dispose cleanly

### `test/services/macos_camera_interface_test.dart`

- [ ] MacOSCameraInterface AsyncInitialization Fix macOS camera should allow immediate recording after initialization
- [ ] MacOSCameraInterface AsyncInitialization Fix macOS finishRecording should handle virtual segments correctly
- [ ] MacOSCameraInterface AsyncInitialization Fix macOS recording should handle single recording mode correctly

### `test/services/nostr_function_channel_test.dart`

- [ ] NostrService Function Channel should connect to embedded relay WITHOUT opening network port
- [ ] NostrService Function Channel should receive events through function callbacks, not WebSocket

### `test/services/nostr_service_publish_file_metadata_test.dart`

- [ ] NostrService.publishFileMetadata() - TDD Validation Tests should throw NIP94ValidationException for invalid metadata
- [ ] NostrService.publishFileMetadata() - TDD Validation Tests should throw StateError when no keys available
- [ ] NostrService.publishFileMetadata() - TDD Event Creation Tests should create NIP-94 event (kind 1063) with valid metadata
- [ ] NostrService.publishFileMetadata() - TDD Event Creation Tests should include all optional metadata fields when provided
- [ ] NostrService.publishFileMetadata() - TDD Edge Cases should handle metadata with minimal required fields only
- [ ] NostrService.publishFileMetadata() - TDD Edge Cases should validate all metadata fields before publishing

### `test/services/nostr_service_search_kinds_test.dart`

- [ ] NostrService Search Kinds Filter searchVideos should not return text notes or other non-video kinds

### `test/services/nostr_service_test.dart`

- [ ] NostrService NIP-94 Publishing should require valid metadata for publishing
- [ ] NostrService Error Handling should provide meaningful error messages

### `test/services/notification_service_enhanced/event_handlers_simple_test.dart`

- [ ] NotificationServiceEnhanced - Basic Behavior initialization sets up service correctly
- [ ] NotificationServiceEnhanced - Basic Behavior reaction event with "+" creates like notification
- [ ] NotificationServiceEnhanced - Basic Behavior comment event creates comment notification
- [ ] NotificationServiceEnhanced - Basic Behavior follow event creates follow notification
- [ ] NotificationServiceEnhanced - Basic Behavior duplicate notifications are not added
- [ ] NotificationServiceEnhanced - Basic Behavior markAsRead marks notification as read
- [ ] NotificationServiceEnhanced - Basic Behavior markAllAsRead marks all notifications as read
- [ ] NotificationServiceEnhanced - Basic Behavior clearAll removes all notifications
- [ ] NotificationServiceEnhanced - Basic Behavior actor name resolution priority: name > displayName > nip05 > Unknown user

### `test/services/profile_cache_test.dart`

- [ ] ProfileCacheService should handle expired profiles

### `test/services/profile_editing_test.dart`

- [ ] Profile Editing Tests should retry failed publishes with exponential backoff

### `test/services/profile_update_test.dart`

- [ ] UserProfileService - Profile Update Tests should force refresh profile with forceRefresh parameter

### `test/services/proofmode_human_detection_test.dart`

- [ ] ProofModeHumanDetection Interaction Analysis should detect human-like interactions with natural variation
- [ ] ProofModeHumanDetection Interaction Analysis should reward natural pressure variation
- [ ] ProofModeHumanDetection Session Validation should validate human session with multiple segments
- [ ] ProofModeHumanDetection Session Validation should penalize suspicious session patterns
- [ ] ProofModeHumanDetection Timing Pattern Analysis should detect natural timing variation
- [ ] ProofModeHumanDetection Timing Pattern Analysis should analyze interaction frequency correctly
- [ ] ProofModeHumanDetection Coordinate Precision Analysis should detect natural coordinate imprecision
- [ ] ProofModeHumanDetection Coordinate Precision Analysis should handle single interaction gracefully

### `test/services/proofmode_session_service_test.dart`

- [ ] ProofModeSessionService Error Handling should handle key service errors gracefully
- [ ] ProofModeSessionService Error Handling should handle attestation service errors gracefully

### `test/services/social_service_test.dart`

- [ ] SocialService Like Functionality should not like when user is not authenticated
- [ ] SocialService Like Functionality should handle event creation failure
- [ ] SocialService Like Functionality should toggle like state locally on second tap
- [ ] SocialService Like Count Fetching should fetch like count from network
- [ ] SocialService Like Count Fetching should return cached like count when available
- [ ] SocialService Liked Events Fetching should fetch liked events for user
- [ ] SocialService Follow System (NIP-02) should fetch current user follow list from Kind 3 events
- [ ] SocialService Follow System (NIP-02) should follow user by creating Kind 3 event
- [ ] SocialService Follow System (NIP-02) should unfollow user by updating Kind 3 event
- [ ] SocialService Follow System (NIP-02) should not follow when user is not authenticated
- [ ] SocialService Follow System (NIP-02) should handle follow broadcast failure gracefully
- [ ] SocialService Follow System (NIP-02) should not follow already followed user
- [ ] SocialService Follow System (NIP-02) should not unfollow user that is not followed
- [ ] SocialService Follow System (NIP-02) should fetch follower stats from network
- [ ] SocialService Follow System (NIP-02) should return cached follower stats when available
- [ ] SocialService Profile Statistics should fetch user video count
- [ ] SocialService Profile Statistics should count videos using NIP-71 compliant kinds
- [ ] SocialService Profile Statistics should fetch user total likes across all videos
- [ ] SocialService NIP-62 Right to be Forgotten should publish NIP-62 deletion request event with correct format
- [ ] SocialService NIP-62 Right to be Forgotten should not publish deletion request when user is not authenticated
- [ ] SocialService NIP-62 Right to be Forgotten should handle event creation failure gracefully
- [ ] SocialService NIP-62 Right to be Forgotten should handle broadcast failure gracefully
- [ ] SocialService NIP-62 Right to be Forgotten should include all required event kinds in deletion request

### `test/services/video_event_service_deduplication_test.dart`

- [ ] VideoEventService Subscription Deduplication should generate different IDs for different subscription types
- [ ] VideoEventService Subscription Deduplication should generate different IDs for different authors
- [ ] VideoEventService Subscription Deduplication should generate same ID regardless of author order
- [ ] VideoEventService Subscription Deduplication should generate different IDs for different hashtags
- [ ] VideoEventService Subscription Deduplication should not create duplicate subscriptions for rapid calls
- [ ] VideoEventService Subscription Deduplication subscription count should stay reasonable
- [ ] VideoEventService Subscription Deduplication should generate same subscription ID for identical parameters
- [ ] VideoEventService Subscription Deduplication should handle subscription replacement correctly

### `test/services/video_event_service_pagination_test.dart`

- [ ] VideoEventService Pagination should use oldest timestamp from existing events after pagination reset

### `test/services/video_event_service_repost_test.dart`

- [ ] VideoEventService Kind 6 Repost Processing should include Kind 6 events in subscription filter
- [ ] VideoEventService Kind 6 Repost Processing should process Kind 6 repost event with cached original
- [ ] VideoEventService Kind 6 Repost Processing should fetch original event for Kind 6 repost when not cached
- [ ] VideoEventService Kind 6 Repost Processing should skip Kind 6 repost without e tag
- [ ] VideoEventService Kind 6 Repost Processing should handle Kind 6 repost when original is not a video
- [ ] VideoEventService Kind 6 Repost Processing should apply hashtag filter to Kind 6 reposts

### `test/services/video_sharing_service_test.dart`

- [ ] getShareableUsers returns recently shared users when no following list exists
- [ ] getShareableUsers returns following list with profile data
- [ ] getShareableUsers prioritizes recently shared users over following list
- [ ] getShareableUsers respects limit parameter
- [ ] searchUsersToShareWith searches by display name in following list
- [ ] searchUsersToShareWith searches by name field if displayName is null
- [ ] searchUsersToShareWith is case insensitive for display name search
- [ ] searchUsersToShareWith returns empty list when hex pubkey not found

### `test/services/vine_recording_controller_concatenation_test.dart`

- [ ] VineRecordingController Segment Concatenation Tests (TDD) Multi-segment recording flow should allow multiple start/stop cycles
- [ ] VineRecordingController Segment Concatenation Tests (TDD) Multi-segment recording flow should track total duration across segments
- [ ] VineRecordingController Segment Concatenation Tests (TDD) Multi-segment recording flow should respect maximum recording duration
- [ ] VineRecordingController Segment Concatenation Tests (TDD) FFmpeg concatenation should concatenate multiple video segments into single file
- [ ] VineRecordingController Segment Concatenation Tests (TDD) FFmpeg concatenation should handle single segment without concatenation
- [ ] VineRecordingController Segment Concatenation Tests (TDD) FFmpeg concatenation should throw error when no segments exist
- [ ] VineRecordingController Segment Concatenation Tests (TDD) FFmpeg concatenation should create valid concat list file
- [ ] VineRecordingController Segment Concatenation Tests (TDD) State management during multi-segment recording should transition states correctly
- [ ] VineRecordingController Segment Concatenation Tests (TDD) State management during multi-segment recording should update progress during recording
- [ ] VineRecordingController Segment Concatenation Tests (TDD) State management during multi-segment recording hasSegments should be true after recording

### `test/services/vine_recording_controller_macos_test.dart`

- [ ] VineRecordingController macOS Logic (TDD) RED: VineRecordingController should create virtual segments on macOS
- [ ] VineRecordingController macOS Logic (TDD) GREEN: Multiple recording segments should accumulate total duration
- [ ] VineRecordingController macOS Logic (TDD) GREEN: finishRecording should handle macOS single recording mode
- [ ] VineRecordingController macOS Logic (TDD) EDGE CASE: very short recording segments should be ignored
- [ ] VineRecordingController macOS Logic (TDD) REFACTOR: segment file paths should be consistent in single recording mode

### `test/services/vine_recording_platform_behavior_test.dart`

- [ ] VineRecordingController Platform Behavior Tests Mobile/Desktop Platform Behavior should allow multiple segments on mobile
- [ ] VineRecordingController Platform Behavior Tests Mobile/Desktop Platform Behavior should track total duration across segments on mobile
- [ ] VineRecordingController Platform Behavior Tests Mobile/Desktop Platform Behavior should support pause and resume on mobile
- [ ] VineRecordingController Platform Behavior Tests FFmpeg Concatenation Platform Check should support FFmpeg concatenation on mobile
- [ ] VineRecordingController Platform Behavior Tests State Transitions should transition through states correctly
- [ ] VineRecordingController Platform Behavior Tests State Transitions should set canRecord correctly based on platform

### `test/services/vine_recording_segments_test.dart`

- [ ] Vine Recording Segment Constraints (TDD) web platform should prevent multiple segments
- [ ] Vine Recording Segment Constraints (TDD) mobile platform should allow multiple segments
- [ ] Vine Recording Segment Constraints (TDD) hasSegments should return true when segments exist
- [ ] Vine Recording Segment Constraints (TDD) canRecord should be false on web after one segment

### `test/unit/services/classic_vines_priority_test.dart`

- [ ] Classic Vines Priority Loading Tests should prioritize classic vines at top of feed
- [ ] Classic Vines Priority Loading Tests should maintain classic vines priority when adding new regular videos
- [ ] Classic Vines Priority Loading Tests should handle multiple classic vines with correct internal ordering
- [ ] Classic Vines Priority Loading Tests should correctly order all priority levels

### `test/unit/services/embedded_relay_performance_unit_test.dart`

- [ ] NostrService Performance Unit Tests relay status queries are fast
- [ ] NostrService Performance Unit Tests multiple relay operations are efficient
- [ ] NostrService Performance Unit Tests search interface responds quickly
- [ ] NostrService Performance Unit Tests performance comparison demonstrates embedded relay speed advantage

### `test/unit/services/embedded_relay_service_unit_test.dart`

- [ ] NostrService Unit Tests service has correct initial state
- [ ] NostrService Unit Tests service provides relay status information
- [ ] NostrService Unit Tests service can add external relays
- [ ] NostrService Unit Tests service can remove external relays but not embedded relay
- [ ] NostrService Unit Tests service provides relay status checks
- [ ] NostrService Unit Tests service can be disposed
- [ ] NostrService Unit Tests service provides search interface

### `test/unit/services/social_service_comment_test.dart`

- [ ] SocialService Comment Unit Tests postComment method should broadcast event to relays
- [ ] SocialService Comment Unit Tests postComment method should throw exception when event creation fails
- [ ] SocialService Comment Unit Tests postComment method should throw exception when broadcast fails
- [ ] SocialService Comment Unit Tests postComment method should trim whitespace from comment content
- [ ] SocialService Comment Unit Tests fetchCommentsForEvent method should return stream of comment events
- [ ] SocialService Comment Unit Tests fetchCommentsForEvent method should subscribe with correct filter for comments

### `test/unit/services/subscription_manager_filter_test.dart`

- [ ] SubscriptionManager Filter Preservation should preserve hashtag filters when optimizing
- [ ] SubscriptionManager Filter Preservation should preserve both hashtag and group filters
- [ ] SubscriptionManager Filter Preservation should optimize multiple filters independently

### `test/unit/services/upload_manager_get_by_path_test.dart`

- [ ] UploadManager.getUploadByFilePath should return first match when multiple uploads have same path

### `test/unit/services/video_cache_service_basic_test.dart`

- [ ] VideoCacheService Basic TDD should provide cache statistics

### `test/unit/services/video_event_processor_test.dart`

- [ ] VideoEventProcessor Event Processing should handle kind 6 repost events

### `test/unit/services/video_event_service_deduplication_test.dart`

- [ ] VideoEventService Deduplication Tests should not add duplicate events with same ID
- [ ] VideoEventService Deduplication Tests should add different events with unique IDs
- [ ] VideoEventService Deduplication Tests should handle mix of duplicates and unique events
- [ ] VideoEventService Deduplication Tests should maintain deduplication across multiple subscriptions
- [ ] VideoEventService Deduplication Tests should handle rapid duplicate events efficiently
- [ ] VideoEventService Deduplication Tests should handle events with invalid kind gracefully

### `test/unit/services/video_event_service_infinite_scroll_test.dart`

- [ ] Infinite Scroll with Until Filter should handle reaching true end of content gracefully

### `test/unit/services/video_event_service_subscription_test.dart`

- [ ] VideoEventService Subscription Duplicate Checking should allow different subscriptions with different parameters
- [ ] VideoEventService Subscription Duplicate Checking should reject truly duplicate subscriptions
- [ ] VideoEventService Subscription Duplicate Checking should allow multiple author-specific subscriptions
- [ ] VideoEventService Subscription Duplicate Checking should correctly handle replace parameter
- [ ] VideoEventService Subscription Duplicate Checking should track active subscription parameters
- [ ] VideoEventService Subscription Duplicate Checking should handle the classic vines -> open feed sequence correctly

## Screens (106 failures)


### `test/goldens/screens/settings_screen_golden_test.dart`

- [ ] SettingsScreen Golden Tests SettingsScreen light theme
- [ ] SettingsScreen Golden Tests SettingsScreen dark theme
- [ ] SettingsScreen Golden Tests SettingsScreen on multiple devices
- [ ] SettingsScreen Golden Tests SettingsScreen initial view
- [ ] SettingsScreen Golden Tests SettingsScreen tablet layouts

### `test/screens/explore_screen_missing_methods_test.dart`

- [ ] ExploreScreen Missing Methods (TDD) GREEN Phase: Tests for working methods ExploreScreen should have onScreenHidden method that works correctly
- [ ] ExploreScreen Missing Methods (TDD) GREEN Phase: Tests for working methods ExploreScreen should have onScreenVisible method that works correctly
- [ ] ExploreScreen Missing Methods (TDD) GREEN Phase: Tests for working methods ExploreScreen should have exitFeedMode method that works correctly
- [ ] ExploreScreen Missing Methods (TDD) GREEN Phase: Tests for working methods ExploreScreen should have showHashtagVideos method that works correctly
- [ ] ExploreScreen Missing Methods (TDD) GREEN Phase: Tests for working methods ExploreScreen should have isInFeedMode getter that works correctly
- [ ] ExploreScreen Missing Methods (TDD) GREEN Phase: Tests for working methods ExploreScreen should have playSpecificVideo method with correct signature

### `test/screens/explore_screen_pure_test.dart`

- [ ] ExploreScreen Pure (TDD) Phase 6: Widget Integration Tests (Basic) ExploreScreen renders correctly

### `test/screens/explore_screen_router_test.dart`

- [ ] ExploreScreen Router-Driven Tests initial URL /explore/0 renders first video
- [ ] ExploreScreen Router-Driven Tests URL /explore/1 renders second video
- [ ] ExploreScreen Router-Driven Tests changing URL updates PageView
- [ ] ExploreScreen Router-Driven Tests no provider mutations in widget lifecycle

### `test/screens/explore_screen_video_display_test.dart`

- [ ] ExploreScreen - Video Display Tests should display videos in grid when data is available
- [ ] ExploreScreen - Video Display Tests should show empty state when no videos available
- [ ] ExploreScreen - Video Display Tests should show loading state while fetching videos
- [ ] ExploreScreen - Video Display Tests should switch tabs correctly

### `test/screens/feature_flag_screen_test.dart`

- [ ] FeatureFlagScreen should display all flags
- [ ] FeatureFlagScreen should show override indicators
- [ ] FeatureFlagScreen should show flag states correctly

### `test/screens/feed_screen_scroll_test.dart`

- [ ] Feed Screen Scroll Animation Tests should refresh after scroll animation completes
- [ ] Feed Screen Scroll Animation Tests should use animation completion instead of Future.delayed
- [ ] Feed Screen Scroll Animation Tests should handle immediate refresh if already at top
- [ ] Animation-based Timing Patterns should use AnimationController for precise timing
- [ ] Animation-based Timing Patterns should use PageController notification for page transitions

### `test/screens/hashtag_feed_embedded_callback_test.dart`

- [ ] HashtagFeedScreen embedded callback behavior invokes onVideoTap callback when embedded and video tapped
- [ ] HashtagFeedScreen embedded callback behavior accepts embedded=true with onVideoTap callback parameter
- [ ] HashtagFeedScreen embedded callback behavior works with embedded=false and no callback

### `test/screens/hashtag_feed_embedded_navigation_test.dart`

- [ ] HashtagFeedScreen embedded navigation calls onVideoTap callback when embedded and video tapped in grid
- [ ] HashtagFeedScreen embedded navigation uses Navigator.push when NOT embedded
- [ ] HashtagFeedScreen embedded navigation calls onVideoTap callback when embedded and video tapped in list view

### `test/screens/hashtag_feed_loading_test.dart`

- [ ] HashtagFeedScreen Per-Subscription Loading States shows loading indicator when per-subscription state is loading and cache is empty
- [ ] HashtagFeedScreen Per-Subscription Loading States does NOT show loading when global isLoading=true but per-subscription is false
- [ ] HashtagFeedScreen Per-Subscription Loading States subscribes to hashtag videos on screen initialization

### `test/screens/hashtag_feed_screen_tdd_test.dart`

- [ ] HashtagFeedScreen TDD Tests should show "Fetching from relays" message when loading hashtag videos
- [ ] HashtagFeedScreen TDD Tests should trigger hashtag subscription on screen load
- [ ] HashtagFeedScreen TDD Tests should show videos when hashtag subscription returns results
- [ ] HashtagFeedScreen TDD Tests should show "No videos found" only after loading completes with no results
- [ ] HashtagFeedScreen TDD Tests should update from loading to showing empty state

### `test/screens/home_screen_router_test.dart`

- [ ] HomeScreenRouter Router-Driven Tests initial URL /home/0 renders first video
- [ ] HomeScreenRouter Router-Driven Tests URL /home/1 renders second video
- [ ] HomeScreenRouter Router-Driven Tests changing URL updates PageView
- [ ] HomeScreenRouter Router-Driven Tests no provider mutations in widget lifecycle
- [ ] HomeScreenRouter Router-Driven Tests pull-to-refresh triggers refresh
- [ ] HomeScreenRouter Router-Driven Tests prefetches profiles around current index

### `test/screens/notifications_navigation_test.dart`

- [ ] NotificationsScreen Navigation tapping notification with video shows error when video not found
- [ ] NotificationsScreen Navigation tapping notification without video navigates to profile

### `test/screens/profile_screen_router_test.dart`

- [ ] PROFILE: URL ↔ PageView sync
- [ ] PROFILE: Empty state shows when no videos
- [ ] PROFILE: Prefetch ±1 profiles when URL index changes

### `test/screens/profile_screen_unfollow_test.dart`

- [ ] Profile Screen Unfollow Tests (TDD) RED: Unfollow button should trigger unfollowUser when tapped
- [ ] Profile Screen Unfollow Tests (TDD) GREEN: Follow button should trigger followUser when tapped
- [ ] Profile Screen Unfollow Tests (TDD) REFACTOR: Button should update UI after successful unfollow
- [ ] Profile Screen Unfollow Tests (TDD) ERROR HANDLING: Show error if unfollow fails
- [ ] Profile Screen Unfollow Tests (TDD) EDGE CASE: Cannot follow/unfollow when not authenticated

### `test/screens/profile_share_edit_buttons_test.dart`

- [ ] Profile Screen Share and Edit Buttons Share Profile and Edit Profile buttons exist on own profile
- [ ] Profile Screen Share and Edit Buttons Share Profile button should be tappable when it exists
- [ ] Profile Screen Share and Edit Buttons Edit Profile button should be tappable when it exists
- [ ] Profile Screen Share and Edit Buttons Buttons should not appear when viewing other users profile

### `test/screens/profile_video_deletion_test.dart`

- [ ] VideoEventService - removeVideoFromAuthorList should remove video from author list when called
- [ ] VideoEventService - removeVideoFromAuthorList should mark video as deleted to prevent pagination resurrection
- [ ] VideoEventService - removeVideoFromAuthorList should handle removing non-existent video gracefully
- [ ] VideoEventService - deleteVideoWithConfirmation integration should call ContentDeletionService and remove from feed on success
- [ ] VideoEventService - deleteVideoWithConfirmation integration should not remove video from feed if deletion fails
- [ ] VideoEventService - deleteVideoWithConfirmation integration should reject deletion of videos not owned by current user
- [ ] ContentDeletionService integration deleteContent should create NIP-09 kind 5 event
- [ ] Video deletion workflow complete deletion flow: UI → Service → Relay → UI update

### `test/screens/search_hashtag_navigation_test.dart`

- [ ] Search hashtag navigation tapping hashtag pushes route instead of replacing search
- [ ] Search hashtag navigation tapping hashtag pushes route instead of replacing search

### `test/screens/search_screen_hybrid_search_test.dart`

- [ ] SearchScreenPure Hybrid Search Tests should show local results immediately while searching remote
- [ ] SearchScreenPure Hybrid Search Tests should show local results immediately while searching remote
- [ ] SearchScreenPure Hybrid Search Tests should filter local videos by title, content, and hashtags
- [ ] SearchScreenPure Hybrid Search Tests should show loading indicator during remote search
- [ ] SearchScreenPure Hybrid Search Tests should extract unique users from search results
- [ ] SearchScreenPure Hybrid Search Tests should combine local and remote search results

### `test/screens/search_screen_navigation_test.dart`

- [ ] SearchScreenPure Navigation tapping user in search results navigates to profile screen
- [ ] SearchScreenPure Navigation tapping hashtag in search results navigates to hashtag feed

### `test/screens/search_screen_pure_url_test.dart`

- [ ] SearchScreenPure URL Integration updates search when URL changes

### `test/screens/universal_camera_recording_interaction_test.dart`

- [ ] Universal Camera Recording Interaction Tests (TDD) Mobile/Desktop Platform - Press-and-Hold Recording should use press-and-hold interaction on mobile
- [ ] Universal Camera Recording Interaction Tests (TDD) Mobile/Desktop Platform - Press-and-Hold Recording should support multiple press-and-hold segments on mobile
- [ ] Universal Camera Recording Interaction Tests (TDD) Mobile/Desktop Platform - Press-and-Hold Recording should show segment count UI on mobile
- [ ] Universal Camera Recording Interaction Tests (TDD) Platform-Agnostic Requirements should show publish button when recording is complete
- [ ] Universal Camera Recording Interaction Tests (TDD) Platform-Agnostic Requirements should show total recording duration
- [ ] Universal Camera Recording Interaction Tests (TDD) Platform-Agnostic Requirements should enforce 6.3 second maximum on both platforms

### `test/screens/video_metadata_screen_save_draft_test.dart`

- [ ] VideoMetadataScreenPure save draft should have a Save Draft button in app bar
- [ ] VideoMetadataScreenPure save draft should save draft when Save Draft button is tapped
- [ ] VideoMetadataScreenPure save draft should save draft without hashtags (UI interaction is complex)
- [ ] VideoMetadataScreenPure save draft should save draft with empty fields
- [ ] VideoMetadataScreenPure save draft should not disable Save Draft button when publishing

### `test/screens/vine_drafts_screen_future_delayed_test.dart`

- [ ] VineDraftsScreen Future.delayed elimination should load drafts without artificial delay
- [ ] VineDraftsScreen Future.delayed elimination should handle loading errors gracefully
- [ ] VineDraftsScreen Future.delayed elimination should transition states properly

### `test/screens/vine_preview_screen_save_draft_test.dart`

- [ ] VinePreviewScreenPure save draft should save draft when Save Draft button is tapped
- [ ] VinePreviewScreenPure save draft should save draft with empty fields

### `test/widget/screens/hashtag_feed_screen_test.dart`

- [ ] HashtagFeedScreen Widget Tests should display hashtag in app bar
- [ ] HashtagFeedScreen Widget Tests should show loading indicator when videos are loading
- [ ] HashtagFeedScreen Widget Tests should show "No videos found" message when no videos exist
- [ ] HashtagFeedScreen Widget Tests should display video count and "viners" text when videos exist
- [ ] HashtagFeedScreen Widget Tests should display recent video count when available
- [ ] HashtagFeedScreen Widget Tests should not display recent count when zero
- [ ] HashtagFeedScreen Widget Tests should trigger hashtag subscription on init
- [ ] HashtagFeedScreen Widget Tests should display back button and navigate on tap
- [ ] HashtagFeedScreen Widget Tests should show correct UI elements without stats

## Integration (98 failures)


### `test/integration/analytics_api_endpoints_test.dart`

- [ ] Analytics API New Endpoints Integration Tests Trending Videos Endpoint GET /analytics/trending/vines - returns valid trending data
- [ ] Analytics API New Endpoints Integration Tests Trending Videos Endpoint GET /analytics/trending/vines - supports time windows
- [ ] Analytics API New Endpoints Integration Tests Trending Videos Endpoint GET /analytics/trending/vines - respects limit parameter
- [ ] Analytics API New Endpoints Integration Tests Trending Videos Endpoint GET /analytics/trending/vines - performance check
- [ ] Analytics API New Endpoints Integration Tests Trending Hashtags Endpoint GET /analytics/trending/hashtags - returns valid hashtag data
- [ ] Analytics API New Endpoints Integration Tests Top Creators Endpoint GET /analytics/trending/creators - returns valid creator data
- [ ] Analytics API New Endpoints Integration Tests Platform Metrics Endpoint GET /analytics/platform - returns platform statistics
- [ ] Analytics API New Endpoints Integration Tests Error Handling handles excessive limit parameter
- [ ] Analytics API New Endpoints Integration Tests Caching and Performance validates caching headers
- [ ] Analytics API New Endpoints Integration Tests Caching and Performance concurrent requests performance

### `test/integration/analytics_integration_test.dart`

- [ ] Analytics API Integration Tests Trending Endpoint (/analytics/trending/vines) returns valid trending data structure
- [ ] Analytics API Integration Tests Error Handling handles invalid endpoints gracefully
- [ ] Analytics API Integration Tests API Health & Performance trending endpoint responds within reasonable time

### `test/integration/auth_and_kind22_vine_relay_test.dart`

- [ ] AUTH and Kind 22 Event Retrieval - Real relay3.openvine.co Relay AUTH completion tracking works correctly

### `test/integration/blossom_live_upload_test.dart`

- [ ] Blossom Live Server Upload LIVE: Upload to cf-stream-service-prod.protestnet.workers.dev

### `test/integration/blossom_upload_live_test.dart`

- [ ] Blossom Upload Live Integration should successfully upload to staging server

### `test/integration/blossom_upload_spec_test.dart`

- [ ] Blossom BUD-01 Spec - Live Server Tests server URL should be cf-stream-service-prod.protestnet.workers.dev for upload

### `test/integration/camera_publish_flow_test.dart`

- [ ] Camera Publish Flow Integration Tests FAILING TEST: Recording and pressing publish should navigate to metadata screen
- [ ] Camera Publish Flow Integration Tests FAILING TEST: Publishing video should eventually navigate to profile
- [ ] Camera Publish Flow Integration Tests FAILING TEST: _isProcessing flag should prevent double-processing

### `test/integration/embedded_relay_disposal_race_test.dart`

- [ ] Embedded Relay Disposal Race Condition FAILING: should not throw "Cannot add new events after calling close" during disposal with active subscription

### `test/integration/embedded_relay_integration_test.dart`

- [ ] Flutter Embedded Nostr Relay Integration should initialize embedded relay with SQLite storage
- [ ] Flutter Embedded Nostr Relay Integration should support external relay synchronization
- [ ] Flutter Embedded Nostr Relay Integration should handle replaceable events correctly
- [ ] Flutter Embedded Nostr Relay Integration should discover relays from user profiles (NIP-65)
- [ ] Flutter Embedded Nostr Relay Integration should discover relays from event hints

### `test/integration/embedded_relay_performance_test.dart`

- [ ] Embedded Relay Performance Tests embedded relay connection status and metrics
- [ ] Embedded Relay Performance Tests subscription manager with embedded relay performs efficiently

### `test/integration/explore_screen_real_relay_test.dart`

- [ ] ExploreScreen Real Relay Integration ExploreScreen displays videos from real relay
- [ ] ExploreScreen Real Relay Integration ExploreScreen handles AsyncValue state correctly during tab navigation

### `test/integration/feature_flag_integration_test.dart`

- [ ] Feature Flag System Integration should provide complete feature flag management workflow
- [ ] Feature Flag System Integration should handle multiple flags independently
- [ ] Feature Flag System Integration should persist flag changes across app restarts
- [ ] Feature Flag System Integration should handle flag reset functionality
- [ ] Feature Flag System Integration should handle service errors gracefully

### `test/integration/hashtag_grid_view_simple_test.dart`

- [ ] HashtagFeedScreen grid view shows grid view when embedded
- [ ] HashtagFeedScreen grid view shows ListView when not embedded
- [ ] HashtagFeedScreen grid view shows empty state when no videos

### `test/integration/home_feed_display_bug_test.dart`

- [ ] Home Feed Display Bug FAILING: should NOT show empty state when contact list loads and videos are available

### `test/integration/home_feed_follows_test.dart`

- [ ] Home Feed Follows Integration Home feed shows videos from followed users even when discovery feed also receives them
- [ ] Home Feed Follows Integration Same video event appears in both discovery and home feed when author is followed

### `test/integration/nostr_relay_integration_test.dart`

- [ ] NostrService Real Relay Integration should connect to relay and publish/receive events

### `test/integration/profile_me_redirect_integration_test.dart`

- [ ] Profile /me/ Redirect Integration should redirect /profile/me/0 to actual user npub and render profile
- [ ] Profile /me/ Redirect Integration should redirect /profile/me/1 to grid view with actual npub

### `test/integration/profile_menu_drafts_navigation_test.dart`

- [ ] Profile menu drafts navigation integration should have Drafts menu item in profile options menu
- [ ] Profile menu drafts navigation integration should navigate to VineDraftsScreen when Drafts menu item is tapped
- [ ] Profile menu drafts navigation integration should close menu after tapping Drafts
- [ ] Profile menu drafts navigation integration should show Drafts menu item only for own profile

### `test/integration/profile_route_loads_test.dart`

- [ ] profile route renders videos & overlays

### `test/integration/profile_update_relay_test.dart`

- [ ] Profile Update Relay Integration profile update with UserProfileService integration

### `test/integration/proofmode_camera_integration_test.dart`

- [ ] ProofMode Camera Integration Tests Full Recording Workflow should complete full vine recording with ProofMode enabled
- [ ] ProofMode Camera Integration Tests Full Recording Workflow should complete recording without ProofMode when disabled
- [ ] ProofMode Camera Integration Tests Full Recording Workflow should handle segmented recording with pauses
- [ ] ProofMode Camera Integration Tests Error Handling and Recovery should continue recording when ProofMode services fail
- [ ] ProofMode Camera Integration Tests Error Handling and Recovery should handle cancellation correctly
- [ ] ProofMode Camera Integration Tests Proof Level Determination should assign verified_mobile for hardware-backed attestation
- [ ] ProofMode Camera Integration Tests Proof Level Determination should assign verified_web for web platform
- [ ] ProofMode Camera Integration Tests Proof Level Determination should assign basic_proof for signed but non-attested content
- [ ] ProofMode Camera Integration Tests Human Activity Integration should capture natural human interactions during recording
- [ ] ProofMode Camera Integration Tests Performance and Resources should cleanup resources properly on disposal

### `test/integration/reactive_pagination_test.dart`

- [ ] Reactive Pagination Tests loadMoreEvents calls subscription manager with correct parameters
- [ ] Reactive Pagination Tests loadMoreEvents creates correct filter structure
- [ ] Reactive Pagination Tests loadMoreEvents with empty list does not set until parameter

### `test/integration/real_nostr_video_integration_test.dart`

- [ ] Real Nostr Video Integration Tests can subscribe to real video events

### `test/integration/real_video_subscription_test.dart`

- [ ] Real Video Subscription Test (tearDownAll)

### `test/integration/relay_pagination_integration_test.dart`

- [ ] Real Relay Pagination Integration should get real kind 34236 video events from relay3.openvine.co
- [ ] Real Relay Pagination Integration should handle rapid pagination requests correctly

### `test/integration/search_navigation_integration_test.dart`

- [ ] Search Navigation Integration Tests Direct URL access to /search/bitcoin/3 loads video feed
- [ ] Search Navigation Integration Tests Back navigation from /search/bitcoin/1 returns to /search/bitcoin

### `test/integration/secure_key_storage_integration_test.dart`

- [ ] NostrKeyManager with SecureKeyStorageService Integration should migrate legacy keys from SharedPreferences

### `test/integration/simple_nostr_test.dart`

- [ ] NostrService Consolidation Test should create NostrService instance

### `test/integration/square_video_recording_test.dart`

- [ ] Square Video Recording Tests recorded video should have 1:1 (square) aspect ratio
- [ ] Square Video Recording Tests recorded segments should maintain square aspect ratio
- [ ] Square Video Recording Tests video metadata should report square dimensions

### `test/integration/subscription_fix_test.dart`

- [ ] Classic vines -> Open feed -> Editor picks sequence works correctly

### `test/integration/subscription_manager_real_relay_test.dart`

- [ ] SubscriptionManager Real Relay Tests - NO MOCKING SubscriptionManager should receive kind 22 events from relay3.openvine.co - REAL RELAY

### `test/integration/thumbnail_api_integration_test.dart`

- [ ] ThumbnailApiService Integration Tests Real API Server Tests getThumbnailWithFallback handles non-existent video gracefully
- [ ] ThumbnailApiService Integration Tests Error Handling Tests handles malformed video IDs gracefully
- [ ] ThumbnailApiService Integration Tests Error Handling Tests handles extremely long video IDs
- [ ] ThumbnailApiService Integration Tests Error Handling Tests handles empty video ID

### `test/integration/video_event_service_managed_test.dart`

- [ ] VideoEventService SubscriptionManager Integration VideoEventService should use SubscriptionManager for main video feed

### `test/integration/video_event_service_relay_test.dart`

- [ ] VideoEventService Live Relay Integration VideoEventService subscription management works correctly
- [ ] VideoEventService Live Relay Integration VideoEventService handles errors gracefully

### `test/integration/video_event_service_simple_test.dart`

- [ ] VideoEventService Event Reception Bug Investigation VideoEventService calls subscribeToEvents and processes events correctly
- [ ] VideoEventService Event Reception Bug Investigation VideoEventService handles stream errors gracefully
- [ ] VideoEventService Event Reception Bug Investigation VideoEventService filters non-video events correctly

### `test/integration/video_event_thumbnail_integration_test.dart`

- [ ] VideoEvent Thumbnail API Integration Error handling and edge cases async method handles network errors gracefully

### `test/integration/video_metrics_tracking_test.dart`

- [ ] VideoMetricsTracker Integration marks video as seen when playing
- [ ] VideoMetricsTracker Integration tracks loop count
- [ ] VideoMetricsTracker Integration does not mark as seen if video errors

### `test/integration/video_pipeline_debug_test.dart`

- [ ] Video Pipeline Debug - Complete Flow Complete video pipeline: VideoEventsProvider -> VideoEventService -> SubscriptionManager
- [ ] Video Pipeline Debug - Complete Flow Direct VideoEventService test for comparison

### `test/integration/video_record_publish_e2e_test.dart`

- [ ] Video Record → Publish → Relay E2E Test should upload video, publish to Nostr, and verify on relay
- [ ] Video Record → Publish → Relay E2E Test should handle upload errors gracefully

### `test/integration/video_upload_integration_test.dart`

- [ ] Video Upload Integration Test should create pending upload with real upload manager
- [ ] Video Upload Integration Test should create pending upload with real upload manager
- [ ] Video Upload Integration Test should accept video with full metadata
- [ ] Video Upload Integration Test should handle multiple uploads

## Widgets (63 failures)


### `test/goldens/widgets/video_thumbnail_golden_test.dart`

- [ ] VideoThumbnailWidget Golden Tests VideoThumbnailWidget states
- [ ] VideoThumbnailWidget Golden Tests VideoThumbnailWidget aspect ratios
- [ ] VideoThumbnailWidget Golden Tests VideoThumbnailWidget aspect ratios
- [ ] VideoThumbnailWidget Golden Tests VideoThumbnailWidget on multiple devices

### `test/widgets/camera_controls_overlay_comprehensive_test.dart`

- [ ] CameraControlsOverlay - Comprehensive TDD Tests Widget Structure and Visibility shows controls overlay for enhanced mobile camera interface
- [ ] CameraControlsOverlay - Comprehensive TDD Tests Zoom Control Functionality zoom gesture shows zoom slider
- [ ] CameraControlsOverlay - Comprehensive TDD Tests Platform Integration gracefully handles missing camera permissions

### `test/widgets/camera_preview_widget_test.dart`

- [ ] Camera Preview Widget Tests FAILING TEST: Camera preview widget should handle initialization race condition
- [ ] Camera Preview Widget Tests FAILING TEST: Camera preview should be accessible immediately after isInitialized=true
- [ ] Camera Preview Widget Tests FAILING TEST: Camera preview should show placeholder before initialization completes
- [ ] Camera Preview Widget Tests FAILING TEST: macOS camera preview texture should be created

### `test/widgets/comprehensive_clickable_hashtag_text_test.dart`

- [ ] ClickableHashtagText - Comprehensive Tests Styling uses default hashtag style when none provided
- [ ] ClickableHashtagText - Comprehensive Tests Navigation and Interactions calls onVideoStateChange when hashtag is tapped
- [ ] ClickableHashtagText - Comprehensive Tests Navigation and Interactions navigates to hashtag feed when hashtag is tapped
- [ ] ClickableHashtagText - Comprehensive Tests Navigation and Interactions handles tap on different hashtags correctly

### `test/widgets/feature_flag_widget_test.dart`

- [ ] FeatureFlagWidget should show child when flag enabled
- [ ] FeatureFlagWidget should update when flag changes
- [ ] FeatureFlagWidget should handle multiple flags independently

### `test/widgets/original_content_badge_test.dart`

- [ ] Original Content Badge Tests (TDD) ProofModeBadgeRow does NOT show OriginalContentBadge for vintage vines

### `test/widgets/proofmode_badge_test.dart`

- [ ] OriginalVineBadge Widget renders Original Vine badge correctly

### `test/widgets/settings_screen_scaffold_test.dart`

- [ ] Settings Screen Scaffold Structure SettingsScreen has back button when pushed

### `test/widgets/settings_screen_test.dart`

- [ ] SettingsScreen Tests Settings screen displays all sections
- [ ] SettingsScreen Tests Settings tiles display correctly
- [ ] SettingsScreen Tests Settings tiles have proper icons

### `test/widgets/share_video_menu_bookmark_sets_test.dart`

- [ ] ShareVideoMenu - Bookmark Sets Dialog (TDD) Dialog Rendering FAIL: should show bookmark sets dialog when "Add to Bookmark Set" is tapped
- [ ] ShareVideoMenu - Bookmark Sets Dialog (TDD) Dialog Rendering FAIL: bookmark sets dialog should show existing sets
- [ ] ShareVideoMenu - Bookmark Sets Dialog (TDD) Dialog Rendering FAIL: bookmark sets dialog should show "Create New Set" option
- [ ] ShareVideoMenu - Bookmark Sets Dialog (TDD) Creating New Bookmark Set FAIL: should allow creating new bookmark set from dialog
- [ ] ShareVideoMenu - Bookmark Sets Dialog (TDD) Creating New Bookmark Set FAIL: should validate bookmark set name is not empty
- [ ] ShareVideoMenu - Bookmark Sets Dialog (TDD) Adding to Existing Set FAIL: should add video to existing bookmark set when selected
- [ ] ShareVideoMenu - Bookmark Sets Dialog (TDD) Adding to Existing Set FAIL: should show checkmark for sets already containing video
- [ ] ShareVideoMenu - Bookmark Sets Dialog (TDD) Adding to Existing Set FAIL: should toggle video in/out of set when tapped multiple times
- [ ] ShareVideoMenu - Bookmark Sets Dialog (TDD) Empty State FAIL: should show helpful message when no bookmark sets exist
- [ ] ShareVideoMenu - Bookmark Sets Dialog (TDD) UI Feedback FAIL: should show success snackbar after adding to set
- [ ] ShareVideoMenu - Bookmark Sets Dialog (TDD) UI Feedback FAIL: should close share menu after successful add

### `test/widgets/user_profile_tile_layout_test.dart`

- [ ] UserProfileTile - Layout & Display Bug Tests 🎯 LAYOUT STRUCTURE TESTS LAYOUT: maintains proper container structure and spacing
- [ ] UserProfileTile - Layout & Display Bug Tests 🎯 LAYOUT STRUCTURE TESTS LAYOUT: row structure with proper flex distribution
- [ ] UserProfileTile - Layout & Display Bug Tests 🎯 LAYOUT STRUCTURE TESTS LAYOUT: avatar positioning and sizing
- [ ] UserProfileTile - Layout & Display Bug Tests 🎯 LAYOUT STRUCTURE TESTS LAYOUT: follow button placement and sizing when visible
- [ ] UserProfileTile - Layout & Display Bug Tests 🎯 CONTENT DISPLAY TESTS CONTENT: displays profile name correctly
- [ ] UserProfileTile - Layout & Display Bug Tests 🎯 CONTENT DISPLAY TESTS CONTENT: displays bio when available
- [ ] UserProfileTile - Layout & Display Bug Tests 🎯 CONTENT DISPLAY TESTS CONTENT: hides bio when not available
- [ ] UserProfileTile - Layout & Display Bug Tests 🎯 CONTENT DISPLAY TESTS CONTENT: shows abbreviated pubkey when no display name
- [ ] UserProfileTile - Layout & Display Bug Tests 🎯 LONG CONTENT HANDLING TESTS LONG CONTENT: handles very long display name without overflow
- [ ] UserProfileTile - Layout & Display Bug Tests 🎯 LONG CONTENT HANDLING TESTS LONG CONTENT: properly truncates long bio text
- [ ] UserProfileTile - Layout & Display Bug Tests 🎯 LONG CONTENT HANDLING TESTS LONG CONTENT: maintains layout integrity with all long content
- [ ] UserProfileTile - Layout & Display Bug Tests 🎯 FOLLOW BUTTON VISIBILITY TESTS BUTTON VISIBILITY: shows follow button for other users
- [ ] UserProfileTile - Layout & Display Bug Tests 🎯 RESPONSIVE LAYOUT TESTS RESPONSIVE: adapts to narrow width constraints
- [ ] UserProfileTile - Layout & Display Bug Tests 🎯 RESPONSIVE LAYOUT TESTS RESPONSIVE: handles very wide layouts properly
- [ ] UserProfileTile - Layout & Display Bug Tests 🎯 RESPONSIVE LAYOUT TESTS RESPONSIVE: maintains consistent appearance across different content
- [ ] UserProfileTile - Layout & Display Bug Tests 🎯 INTERACTION TESTS INTERACTION: tap callbacks work correctly
- [ ] UserProfileTile - Layout & Display Bug Tests 🎯 INTERACTION TESTS INTERACTION: follow button is tappable when visible
- [ ] UserProfileTile - Layout & Display Bug Tests 🎯 ERROR STATE HANDLING ERROR: handles null profile gracefully
- [ ] UserProfileTile - Layout & Display Bug Tests 🎯 ERROR STATE HANDLING ERROR: handles empty pubkey edge case

### `test/widgets/video_overlay_context_title_simple_test.dart`

- [ ] VideoOverlayActions contextTitle shows contextTitle chip when provided
- [ ] VideoOverlayActions contextTitle shows both publisher chip and contextTitle chip

### `test/widgets/video_thumbnail_widget_test.dart`

- [ ] VideoThumbnailWidget builds widget tree correctly when thumbnail URL exists
- [ ] VideoThumbnailWidget displays blurhash when only blurhash is available
- [ ] VideoThumbnailWidget displays blurhash as background when both thumbnail and blurhash exist
- [ ] VideoThumbnailWidget displays icon placeholder when neither thumbnail nor blurhash exists
- [ ] VideoThumbnailWidget updates when video changes
- [ ] VideoThumbnailWidget does not try to generate thumbnails when URL is missing
- [ ] VideoThumbnailWidget handles empty thumbnail URL as null

## Router (55 failures)


### `test/router/all_routes_test.dart`

- [ ] App Router - All Routes /explore route works (grid mode)
- [ ] App Router - All Routes /explore/:index route works (feed mode)
- [ ] App Router - All Routes /notifications/:index route works
- [ ] App Router - All Routes /profile/:npub/:index route works
- [ ] App Router - All Routes /search/:term route works (grid mode)
- [ ] App Router - All Routes /search/:term/:index route works (feed mode)
- [ ] App Router - All Routes /hashtag/:tag route works (grid mode)
- [ ] App Router - All Routes /hashtag/:tag/:index route works (feed mode)
- [ ] App Router - All Routes /camera route works

### `test/router/app_shell_header_test.dart`

- [ ] Header shows Explore on explore
- [ ] Header shows #tag on hashtag
- [ ] Back button visibility Back button shown on hashtag route
- [ ] Back button visibility No back button on explore route
- [ ] Back button visibility No back button on notifications route

### `test/router/app_shell_integration_test.dart`

- [ ] B) Deep links land in correct tab navigating to /explore/5 selects Explore tab
- [ ] B) Deep links land in correct tab navigating to /hashtag/rust/3 selects Tags tab
- [ ] C) Tab switching preserves state switching tabs preserves route within each tab
- [ ] C) Tab switching preserves state per-tab navigators maintain separate state across tab switches
- [ ] D) Back behavior can navigate back within tab stack
- [ ] D) Back behavior bottom nav tap navigates to canonical tab path

### `test/router/consolidated_routes_test.dart`

- [ ] Consolidated Route Tests Navigate /explore → /explore/0 without GlobalKey conflict
- [ ] Consolidated Route Tests Navigate /hashtag/bitcoin → /hashtag/bitcoin/0 without GlobalKey conflict

### `test/router/explore_tab_tap_navigation_test.dart`

- [ ] Explore Tab Tap Navigation Test tapping explore tab navigates to /explore (grid mode), not /explore/0

### `test/router/hashtag_navigation_crash_test.dart`

- [ ] Hashtag Navigation Crash Test rapidly switching hashtags does not crash with ref-after-unmount
- [ ] Hashtag Navigation Crash Test navigating from hashtag grid to feed mode works
- [ ] Hashtag Navigation Crash Test navigating away from hashtag to explore does not crash

### `test/router/navigation_scenarios_test.dart`

- [ ] Real Navigation Scenarios Explore tab tap - grid mode
- [ ] Real Navigation Scenarios Explore grid → feed navigation
- [ ] Real Navigation Scenarios Hashtag grid mode
- [ ] Real Navigation Scenarios Hashtag feed mode
- [ ] Real Navigation Scenarios Search with term - grid mode
- [ ] Real Navigation Scenarios Search with term - feed mode
- [ ] Real Navigation Scenarios Camera route
- [ ] Real Navigation Scenarios Notifications navigation
- [ ] Real Navigation Scenarios Profile/me special route
- [ ] Real Navigation Scenarios Explore back to grid from feed
- [ ] Real Navigation Scenarios Hashtag back to grid from feed
- [ ] Real Navigation Scenarios Search back to grid from feed
- [ ] Real Navigation Scenarios URL-encoded hashtags
- [ ] Real Navigation Scenarios URL-encoded search terms
- [ ] Real Navigation Scenarios Back button navigates from hashtag feed to grid
- [ ] Real Navigation Scenarios Back button navigates from search feed to grid
- [ ] Real Navigation Scenarios Back button navigates from hashtag grid to explore

### `test/router/page_context_provider_test.dart`

- [ ] Page Context Provider updates context when router navigates
- [ ] Page Context Provider parses hashtag route correctly
- [ ] Page Context Provider parses camera route correctly

### `test/router/profile_me_redirect_test.dart`

- [ ] Profile /me/ Redirect should redirect /profile/me/0 to current user npub
- [ ] Profile /me/ Redirect should handle /profile/me/1 (grid tab) redirect
- [ ] Profile /me/ Redirect should NOT redirect when npub is not "me"

### `test/router/route_normalization_test.dart`

- [ ] normalizes unknown path -> /home/0
- [ ] encodes hashtag param consistently

### `test/router/router_location_provider_test.dart`

- [ ] Router Location Provider emits initial location immediately
- [ ] Router Location Provider emits new location when router navigates
- [ ] Router Location Provider cleans up listener on dispose

### `test/router/search_navigation_test.dart`

- [ ] Search Navigation Back button returns from search screen

## Other (40 failures)


### `test/cross_platform/platform_compatibility_test.dart`

- [ ] Cross-Platform Camera Compatibility Platform-specific camera interface selection
- [ ] Cross-Platform Camera Compatibility Consistent state transitions across platforms
- [ ] Cross-Platform Camera Compatibility File format consistency across platforms

### `test/edge_cases/camera_error_recovery_test.dart`

- [ ] Camera Error Recovery & Edge Cases Recovery from camera permission denial
- [ ] Camera Error Recovery & Edge Cases Recovery from camera already in use
- [ ] Camera Error Recovery & Edge Cases Handling of corrupted video files

### `test/hashtag_functionality_test.dart`

- [ ] Hashtag Sorting Tests should sort hashtags by video count in descending order
- [ ] Hashtag Sorting Tests should combine and sort hashtags from JSON and local cache

### `test/infrastructure/mass_test_generation_test.dart`

- [ ] Mass Test Generation can generate service tests
- [ ] Mass Test Generation can generate widget tests
- [ ] Mass Test Generation can generate integration tests
- [ ] Mass Test Generation follows test patterns from examples
- [ ] Mass Test Generation generates performance benchmarks

### `test/infrastructure/test_infrastructure_setup_test.dart`

- [ ] Test Infrastructure Setup analysis_options.yaml has strict quality rules
- [ ] Test Infrastructure Setup in-memory service implementations exist
- [ ] Test Infrastructure Setup max file length enforcer exists

### `test/performance/camera_initialization_benchmark_test.dart`

- [ ] Camera Initialization Performance Benchmarks Camera initialization should complete within acceptable time limits
- [ ] Camera Initialization Performance Benchmarks Rapid camera switching performance
- [ ] Camera Initialization Performance Benchmarks Memory leak detection during long recording session

### `test/performance/proofmode_performance_test.dart`

- [ ] ProofMode Performance Benchmarks Frame Capture Performance should capture 180 frames (6s at 30fps) within 500ms
- [ ] ProofMode Performance Benchmarks Frame Capture Performance should handle reduced sample rate (every 3rd frame)
- [ ] ProofMode Performance Benchmarks Frame Capture Performance should respect max frame hash limit
- [ ] ProofMode Performance Benchmarks Hash Performance should compute SHA256 hash in under 5ms per frame
- [ ] ProofMode Performance Benchmarks Device Attestation Performance should generate device attestation in under 1 second
- [ ] ProofMode Performance Benchmarks Memory Usage should not exceed 50KB for 180 frame hashes
- [ ] ProofMode Performance Benchmarks Full Recording Simulation should handle complete 6-second recording lifecycle

### `test/profile_fetching_test.dart`

- [ ] Profile Fetching on Video Display should fetch profile when video is displayed without cached profile

### `test/startup/startup_diagnostics_test.dart`

- [ ] Startup Diagnostics should provide detailed startup metrics report

### `test/tools/future_delayed_detector_test.dart`

- [ ] FutureDelayedDetector detects simple Future.delayed usage
- [ ] FutureDelayedDetector detects Future.delayed with const Duration
- [ ] FutureDelayedDetector detects Future.delayed in expression
- [ ] FutureDelayedDetector counts total Future.delayed occurrences
- [ ] FutureDelayedDetector suggests AsyncUtils replacements
- [ ] FutureDelayedDetector can output results in JSON format
- [ ] FutureDelayedDetector excludes test files by default
- [ ] FutureDelayedDetector can include test files with flag
- [ ] FutureDelayedDetector provides fix option to replace with AsyncUtils

### `test/tools/naming_convention_test.dart`

- [ ] Naming Convention Tests should follow feature_component_type.dart naming pattern for screens
- [ ] Naming Convention Tests should follow PascalCase for class names matching file names

### `test/widget_test.dart`

- [ ] divine app UI validation test

## Providers (29 failures)


### `test/providers/analytics_provider_test.dart`

- [ ] AnalyticsProvider should track video view when analytics enabled
- [ ] AnalyticsProvider should track multiple video views

### `test/providers/curation_provider_lifecycle_test.dart`

- [ ] CurationProvider Lifecycle curation provider initialization completes and populates editor picks

### `test/providers/curation_provider_tab_refresh_test.dart`

- [ ] CurationProvider Tab Refresh refreshAll() picks up videos added to cache after provider initialization
- [ ] CurationProvider Tab Refresh navigating from video back to Editor's Pick tab triggers refresh

### `test/providers/feature_flag_provider_test.dart`

- [ ] FeatureFlagProvider should update when service notifies

### `test/providers/hashtag_feed_providers_test.dart`

- [ ] HashtagFeedProvider selects videos from pre-populated hashtag bucket
- [ ] HashtagFeedProvider shows videos from service hashtag bucket
- [ ] HashtagFeedProvider only shows videos for the specific hashtag

### `test/providers/home_feed_provider_test.dart`

- [ ] HomeFeedProvider should subscribe to videos from followed authors
- [ ] HomeFeedProvider should sort videos by creation time (newest first)
- [ ] HomeFeedProvider should handle load more when user is following people

### `test/providers/home_feed_refresh_on_follow_test.dart`

- [ ] HomeFeed refresh on follow/unfollow BUG: should rebuild home feed when following list changes even if count stays same
- [ ] HomeFeed refresh on follow/unfollow should rebuild home feed when following count increases
- [ ] HomeFeed refresh on follow/unfollow should rebuild home feed when following count decreases

### `test/providers/seen_videos_notifier_test.dart`

- [ ] SeenVideosNotifier persists state across notifier instances

### `test/providers/user_profile_provider_test.dart`

- [ ] UserProfileProvider should fetch profile using async provider with real data
- [ ] UserProfileProvider should use notifier for basic profile management
- [ ] UserProfileProvider should handle multiple individual profile fetches
- [ ] UserProfileProvider should force refresh cached profile

### `test/providers/video_events_provider_fresh_test.dart`

- [ ] VideoEventsProvider - Fresh First emits videos with unseen first on initial load

### `test/providers/video_events_provider_test.dart`

- [ ] VideoEventsProvider should create subscription based on feed mode
- [ ] VideoEventsProvider should filter events based on following mode
- [ ] VideoEventsProvider should use classic vines fallback when no following
- [ ] VideoEventsProvider should parse video events from stream
- [ ] VideoEventsProvider should handle stream errors gracefully

### `test/providers/video_feed_provider_test.dart`

- [ ] VideoFeedProvider should use Classic Vines as fallback when no following list
- [ ] VideoFeedProvider should filter videos by following list
- [ ] VideoFeedProvider should update feed when following list changes

## Unit (6 failures)


### `test/unit/error_widget_test.dart`

- [ ] Error Widget Builder Tests ErrorWidget.builder shows user-friendly error in release mode
- [ ] Error Widget Builder Tests Custom error widget has proper styling
- [ ] Error Widget Builder Tests Error widget displays exception message in debug mode

### `test/unit/global_error_handler_test.dart`

- [ ] Global Error Handler TDD - Error Boundary Tests FAIL FIRST: OpenVineApp should show user-friendly error when widget throws exception
- [ ] Global Error Handler TDD - Error Boundary Tests FAIL FIRST: Error widget should show debug information in debug mode only
- [ ] Global Error Handler TDD - Error Boundary Tests FAIL FIRST: Error boundary should allow retry after error recovery
