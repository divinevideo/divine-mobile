# Changelog

All notable changes to the OpenVine mobile app will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed - Cache JSON Corruption Crash (2025-12-13)

#### Bug Fixes
- **Fixed app crash when cache JSON is corrupted** - App would crash with FormatException when cache metadata JSON file was empty or malformed (e.g., due to app crash during write)
  - Added `SafeJsonCacheInfoRepository` wrapper that catches FormatException and recovers gracefully
  - Deletes corrupted cache file and retries with fresh cache
  - Also handles malformed JSON in Nostr events database tags

#### Technical Details
- Added `lib/services/safe_json_cache_repository.dart`:
  - Wraps `JsonCacheInfoRepository` from flutter_cache_manager
  - Catches FormatException on `open()` and deletes corrupted JSON from `getApplicationSupportDirectory()`
  - Note: Cache metadata JSON is stored in app support dir, not temp dir (where cached files go)
- Modified `lib/services/video_cache_manager.dart` and `lib/services/image_cache_manager.dart`:
  - Use `SafeJsonCacheInfoRepository` instead of default repository
- Modified `lib/database/daos/nostr_events_dao.dart`:
  - Added try-catch around `jsonDecode` for event tags to prevent crash on malformed data

### Fixed - Profile Edit Navigation Crash (2025-12-11)

#### Bug Fixes
- **Fixed black screen of death when saving profile edits** - Navigation crash occurred when the edit-profile route became the root route
  - Changed from Flutter Navigator to GoRouter's `context.pop()` for consistency
  - Added `context.canPop()` check before attempting to pop
  - If can't pop (route is root), gracefully navigates to home with `context.go('/')` instead of crashing

#### Technical Details
- Modified `lib/screens/profile_setup_screen.dart`:
  - Success path (line ~1165): Use GoRouter `context.canPop()` and `context.pop()` with fallback to `context.go('/')`
  - Error path (line ~1212): Same defensive navigation pattern

### Fixed - macOS Segment Recording and Upload (2025-12-01)

#### Bug Fixes
- **Fixed macOS multi-segment recording failing to upload** - Videos were being rejected with "duration_exceeded" because pauses between segments were included in the final video
  - Implemented FFmpeg segment extraction to include only actively recorded portions
  - Removed AVFoundation wall-clock duration limit (users can take unlimited time between segments)
  - Fixed `hasSegments` state propagation from controller to UI for correct progress bar display

#### Technical Details
- Modified `macos/NativeCameraPlugin.swift`:
  - Set `maxRecordedDuration = CMTime.invalid` to disable native wall-clock limit
  - Virtual segments tracked in Flutter enforce the actual 6-second content limit
- Modified `lib/services/vine_recording_controller.dart`:
  - Added `_extractMacOSSegments()` method for FFmpeg-based segment extraction
  - Uses `-ss` (start offset) and `-t` (duration) to extract each virtual segment
  - Concatenates multiple segments if needed, applies aspect ratio crop
  - Updated `finishRecording()` for macOS single recording mode
- Modified `lib/providers/vine_recording_provider.dart`:
  - Fixed `updateState()` to preserve `cameraSwitchCount` for UI rebuilds

### Fixed - Video Processing Status Message (2025-11-28)

#### Bug Fixes
- **Fixed "Initializing camera..." showing during video processing** - Now correctly shows "Processing video..." during the entire FFmpeg encoding phase
  - Previously, the processing flag was set too late (after FFmpeg finished), causing the wrong message
  - Now sets processing state immediately when stop recording is triggered
  - Proper error handling resets processing state on failure

#### Technical Details
- Modified `lib/screens/pure/universal_camera_screen_pure.dart`:
  - Set `_isProcessing = true` at start of `_stopRecording()` before calling provider
  - Provider's `stopRecording()` auto-calls `finishRecording()` which runs FFmpeg
  - Added navigation to metadata screen after draft auto-creation
  - Added proper cleanup with `finally` block to reset processing state

### Fixed - Blossom Upload Authentication (2025-11-27)

#### Bug Fixes
- **Improved Blossom BUD-01 authentication compliance** - Fixed auth event construction for better compatibility with Blossom media servers
  - Added missing `size` tag to auth event (required by some servers for validation)
  - Confirmed standard base64 encoding (not base64url) per BUD-01 specification
  - Added explicit `Content-Length` header to upload requests
  - Added debug logging for auth event JSON to aid troubleshooting

#### Technical Details
- Modified `lib/services/blossom_upload_service.dart`:
  - Added `size` tag to auth event tags list: `['size', fileSize.toString()]`
  - Added `Content-Length` header to upload request headers
  - Added X-Reason header check for detailed error information from server
  - Added debug logging to print auth event JSON before encoding
  - Comment clarification: BUD-01 requires standard base64 encoding (not base64url)

### Fixed - Expiring Post Safety & Multiple Imeta Parsing (2025-11-25)

#### Safety Improvements
- **Added confirmation dialog for expiring posts** - Users must now explicitly confirm before enabling post expiration
  - Shows warning that video will be "permanently deleted from Nostr relays"
  - Warns "This action cannot be undone. Once expired, the video will be gone forever."
  - Requires clicking "Yes, Make It Expire" to enable (prevents accidental expiration)
  - Double-check safety: expiration tag only added if both toggle AND confirmation are true

#### Bug Fixes (Postel's Law)
- **Fixed video URL selection from multiple imeta tags** - Now correctly selects best working URL when events have multiple imeta tags with mixed working/broken URLs
  - Added handling for `hls`, `dash`, `stream`, `streaming`, `fallback`, `mp4`, `video` keys in imeta
  - Deprioritized known broken URL pattern: `cdn.divine.video/*/manifest/video.m3u8` (score: 5)
  - Prioritized reliable sources: direct MP4 from cdn.divine.video (115), stream.divine.video HLS (105)
  - Ensures working URLs from first imeta tag aren't overridden by broken URLs from second imeta tag

#### Technical Details
- Modified `lib/screens/pure/video_metadata_screen_pure.dart`:
  - Added `_expirationConfirmed` flag
  - Added `_showExpirationConfirmationDialog()` method
  - Updated switch handler to show confirmation before enabling
  - Updated publish logic to require both flags
- Modified `lib/models/video_event.dart`:
  - Extended imeta parsing to collect URLs from additional keys
  - Updated `_scoreVideoUrl()` with new scoring tiers
  - Added test: `test/unit/models/video_event_multiple_imeta_test.dart`

### Fixed - List Video Feed Layout (2025-11-25)

#### Bug Fixes
- **Fixed list header overlapping username/follow overlay** - When viewing videos in a list (e.g., Divine Team), the list header no longer overlaps with the video author info
  - Added contextTitle-aware positioning in VideoOverlayActions
  - Username/follow chip now positioned 80px below top when list header present
  - Applies to both UserListPeopleScreen and CuratedListFeedScreen

### Fixed - Video Playback on Navigation (2025-11-24)

#### Bug Fixes
- **Fixed videos continuing to play during navigation** - Videos now properly stop/pause when navigating away via Navigator.push
  - VideoStopNavigatorObserver only catches GoRouter navigation, not raw Navigator.push calls
  - Added explicit video cleanup before: opening comments, camera, lists, drawer screens
  - Videos stop when exiting video mode back to grid in list screens

#### Technical Details
- Modified `lib/widgets/video_feed_item.dart`: Pause video before opening comments
- Modified `lib/widgets/camera_fab.dart`: Stop videos before opening camera
- Modified `lib/widgets/vine_drawer.dart`: Stop videos before Relays/Media/Notifications
- Modified `lib/screens/explore_screen.dart`: Stop videos before list navigation
- Modified `lib/screens/discover_lists_screen.dart`: Stop videos before list navigation
- Modified `lib/screens/curated_list_feed_screen.dart`: Stop videos when exiting to grid
- Modified `lib/screens/user_list_people_screen.dart`: Stop videos when exiting to grid

### Fixed - Comments and NIP-71 Compliance (2025-11-24)

#### Bug Fixes
- **Fixed comments not loading on videos** - Comments now properly load when opening the comments panel
  - Fixed `subscription_manager.dart` to preserve `e` and `p` tags when reconstructing filters
  - Comment subscriptions require `e` tag to filter comments for specific videos
  - Added comprehensive debug logging to trace comment loading flow
- **Enforced NIP-71 kind 34236 only** - OpenVine now exclusively uses addressable short videos
  - Updated `NIP71VideoKinds.getAllVideoKinds()` to return only `[34236]`
  - Removed deprecated kinds 22, 21, 34235 from all subscription filters
  - Fixed hardcoded kind arrays in relay diagnostics, search, and video queries

#### Technical Details
- Modified `lib/services/subscription_manager.dart`:
  - Added `e: filter.e` and `p: filter.p` to all filter reconstruction points
  - Prevents critical tag loss when filters are modified for cache optimization
  - Added debug logging for subscription filter inspection
- Modified `lib/constants/nip71_migration.dart`:
  - `getAllVideoKinds()` now returns `[34236]` only
  - `getPrimaryVideoKinds()` returns `[34236]` only
  - `getPreferredKind()` returns `34236` instead of `22`
- Modified `lib/providers/comments_provider.dart`:
  - Added debug logging for comment loading flow tracing
- Updated filter kinds in:
  - `lib/screens/relay_diagnostic_screen.dart`
  - `lib/services/nostr_service.dart`
  - `lib/services/video_event_service.dart`

### Added - Seed Data Preloading (2025-11-11)

#### Features
- **Added seed data preloading for first-launch experience** - New users see popular videos immediately
  - Pre-bundled SQL seed events database with 50 popular videos
  - Pre-downloaded media files (videos + thumbnails) bundled in app
  - Automatic import on first launch when no events exist in local database
  - Seamless integration with existing NostrEventsDao and video playback
  - Generated from real relay data using `scripts/generate_seed_data.dart`

#### Technical Details
- Created `lib/services/seed_data_preload_service.dart`:
  - Detects first-launch condition via event count check
  - Imports seed events SQL file into SQLite database
  - Verifies media file availability for each video
  - Only runs once per installation
  - Non-blocking background initialization
- Created `scripts/generate_seed_data.dart`:
  - Fetches top 50 videos by loop count from relay
  - Downloads all media files (videos + thumbnails) to local bundle
  - Generates SQL INSERT statements for seed database
  - Creates manifest.json for media file tracking
- Added bundled assets in `assets/seed_data/` and `assets/seed_media/`
- Modified `pubspec.yaml`: Added seed data assets
- Modified `lib/main.dart`: Integrated preload service into app startup

#### User Experience
- New users see engaging content immediately instead of empty state
- No network request required for initial video viewing
- Smooth transition to live relay content as user browses
- Videos play instantly with bundled media files

### Fixed - UI Design Consistency (2025-11-11)

#### Bug Fixes
- **Merged upstream UI/UX improvements** - Applied design fixes from remote main branch
  - Updated icon assets (White cropped.png, White on transparent.png)
  - Added user-avatar.png placeholder for default profile images
  - Updated iOS launch screen images and storyboard
  - Improved widget styling in multiple screens (follow actions, user profile, drawer)
  - Router improvements for better navigation state management
  - Settings screen layout enhancements

#### Technical Details
- Merged 21 commits from origin/main into feature branch
- Resolved merge conflict in pubspec.yaml by keeping both seed data and design assets
- Updated files:
  - Navigation: `lib/router/app_router.dart`, `lib/router/app_shell.dart`, `lib/router/route_utils.dart`
  - Screens: `lib/screens/*_screen.dart` (blossom, explore, notifications, profile, relay, settings, drafts)
  - Widgets: `lib/widgets/user_avatar.dart`, `lib/widgets/proofmode_badge_row.dart`, `lib/widgets/vine_drawer.dart`
  - Assets: iOS launch images, app icons

### Added - Account Deletion (2025-11-10)

#### Features
- **Added complete account deletion feature with NIP-62 support** - Users can permanently delete their Nostr identity and all content
  - New "Delete Account" option in Settings under Account section
  - Multi-step confirmation with clear permanence warning
  - NIP-62 "Request to Vanish" event broadcast to all relays
  - Immediate local key deletion from device storage
  - Automatic sign out after deletion
  - Optional "Create New Account" flow post-deletion
  - Strong visual warnings with red UI to emphasize irreversibility

#### Technical Details
- Created `lib/services/account_deletion_service.dart`:
  - Handles NIP-62 kind 62 event creation with ALL_RELAYS tag
  - Broadcasts deletion request to all configured relays
  - Manages deletion result state (success/failure)
  - Custom reason support (defaults to "User requested account deletion via diVine app")
- Created `lib/widgets/delete_account_dialog.dart`:
  - Warning dialog with clear consequences explanation
  - Completion dialog with new account creation option
  - Dark mode compliant design with red danger accents
  - Cancel/Delete button layout following platform conventions
- Modified `lib/screens/settings_screen.dart`:
  - Added new "Account" section after Profile section
  - "Delete Account" tile with red icon and text for visual warning
  - Integrated dialog flow for deletion confirmation
- Modified `lib/providers/app_providers.dart`:
  - Added `accountDeletionServiceProvider` for dependency injection
- Error handling for network failures and broadcast issues
  - Graceful fallback when relays are unreachable
  - Clear error messages for retry scenarios
  - No local key deletion unless NIP-62 broadcast succeeds

#### Test Coverage
- Created `test/services/account_deletion_service_test.dart`:
  - 15 comprehensive unit tests for deletion service
  - NIP-62 event format validation
  - Broadcast success/failure scenarios
  - Custom reason support
- Created `test/widgets/delete_account_dialog_test.dart`:
  - 8 widget tests for dialog behavior
  - Warning and completion dialog rendering
  - Button tap handlers and navigation
- Created `test/integration/account_deletion_flow_test.dart`:
  - 6 integration tests for complete deletion flow
  - Settings navigation to deletion completion
  - Key removal verification
  - Sign out state validation
  - Create new account flow
- All 29 tests passing

#### NIP-62 Implementation
- Event structure follows NIP-62 specification exactly
- `["relay", "ALL_RELAYS"]` tag requests network-wide deletion
- Relays SHOULD delete all events from the user's pubkey
- Relays MAY retain signed deletion request for compliance
- No guarantees about relay compliance (protocol limitation)

#### User Experience
- Clear communication about deletion permanence
- Honest disclosure about relay compliance variability
- No false promises of complete erasure
- Quick 3-tap flow: Settings → Delete Account → Confirm
- Minimal friction for legitimate deletion requests

### Fixed - Comments Loading (2025-11-08)

#### Bug Fixes
- **Fixed infinite loading spinner in comments screen** - Comments now load immediately instead of waiting up to 2 minutes
  - Root cause: CommentsProvider used blocking `await for` loop to consume Nostr event stream
  - Nostr relays may never send EOSE (End Of Stored Events), causing 2-minute timeout waits
  - Solution: Replaced with reactive `stream.listen()` + Completer pattern
  - UI updates immediately as each comment event arrives
  - Shows "Classic Vine" message immediately when no comments exist
  - Shows empty state promptly instead of waiting for stream completion

#### Technical Details
- Modified `lib/providers/comments_provider.dart`:
  - Replaced blocking `await for` with reactive `stream.listen()`
  - Added `Completer<void>` to track stream completion for proper async behavior
  - Sets `isLoading = false` after first event or when stream completes with no events
  - Added `dart:async` import for Completer
  - Updates UI reactively via state updates in event handler
  - Maintains proper cleanup with `ref.onDispose()` for subscription cancellation

#### Test Coverage
- All 13 comments provider tests pass
- No new analyzer issues introduced
- Verified all other Nostr stream consumers already use correct reactive patterns

### Added - Video Buffering & UX Improvements (2025-11-08)

#### Features
- **Added video buffering to prevent jarring auto-updates** - New videos buffer while browsing
  - New videos arriving via Nostr subscriptions are buffered instead of auto-inserting
  - Shows banner with count of buffered videos
  - User can tap banner to load buffered videos at top of feed
  - Buffering enabled when browsing Explore tabs, disabled when hidden
  - Prevents feed jumping while user is watching videos

- **Added pull-to-refresh on Explore tabs** - Refresh Popular Now, Trending, and Editor's Pick
  - Pull down gesture refreshes current tab
  - Shows loading indicator during refresh
  - Invalidates and reloads appropriate provider (videoEventsProvider or curationProvider)

- **Renamed "Trending" to "Popular Vines"** - More descriptive tab name in Explore screen

- **Added followers/following screen navigation** - New routes for social graph views

#### Technical Details
- Modified `lib/providers/video_events_providers.dart`:
  - Added buffering state management with `_bufferedEvents` list
  - Added `enableBuffering()` / `disableBuffering()` methods
  - Added `loadBufferedVideos()` to flush buffer into main feed
  - Added `bufferedCount` getter for banner display
  - Created `bufferedVideoCountProvider` for reactive count updates

- Modified `lib/screens/explore_screen.dart`:
  - Added `_buildNewVideosBanner()` widget for buffered videos indicator
  - Added `onRefresh` callback to ComposableVideoGrid
  - Integrated buffering enable/disable in screen lifecycle (onScreenVisible/onScreenHidden)
  - Changed tab text from "Trending" to "Popular Vines"

- Modified `lib/router/app_router.dart`:
  - Split navigator keys for search modes (empty, grid, feed)
  - Split navigator keys for hashtag modes (grid, feed)
  - Added routes for followers/following screens
  - Improved navigation stack isolation

- Modified `lib/widgets/composable_video_grid.dart`:
  - Added optional `onRefresh` callback parameter
  - Integrated RefreshIndicator when callback provided

### Added - Mutual Mute Blocking (2025-11-08)

#### Features
- **Added mutual mute list blocking (NIP-51 kind 10000)** - Reciprocally hide content from users who mute you
  - Background sync of kind 10000 events tagging your pubkey
  - Automatic filtering of mutual muters across all feeds (home, discovery, hashtag, search, comments)
  - "This account is not available" message when navigating to blocked user's profile or video
  - Persistent storage via embedded relay's SQLite between sessions
  - Non-blocking startup - runs as low priority background process

#### Technical Details
- Created comprehensive design document: `docs/plans/2025-11-08-mutual-mute-blocking-design.md`
- Extended `lib/services/content_blocklist_service.dart`:
  - Added `_mutualMuteBlocklist` Set for tracking mutual muters
  - Added `syncMuteListsInBackground()` method to subscribe to kind 10000 events
  - Added `_handleMuteListEvent()` to process mute/unmute events
  - Modified `shouldFilterFromFeeds()` to check all three blocklists
  - Handles replaceable events (unmuting when user removes you from their list)
- Modified `lib/main.dart`:
  - Integrated mutual mute sync into app startup via `Future.microtask()`
  - Runs after AuthService ready but before feeds load
  - Graceful error handling for non-critical feature
- Modified `lib/screens/profile_screen_router.dart`:
  - Added blocked user check before rendering profile
  - Shows "This account is not available" message for mutual muters
- Modified `lib/screens/video_detail_screen.dart`:
  - Added blocked user check before playing video
  - Shows "This account is not available" message for mutual muters

#### Test Coverage
- Created `test/services/content_blocklist_service_test.dart`:
  - 11 comprehensive tests for mutual mute functionality
  - Tests subscription creation, event handling, unmuting, and filtering
  - All tests passing
- Uses mock NostrService and StreamControllers for async testing

### Added - Advanced Share Menu (2025-11-08)

#### Features
- **Added developer/power-user features to share menu** - View source and copy event IDs
  - New "Advanced" section in video share menu
  - "View Source" shows raw Nostr event JSON in dialog
  - "Copy Event ID" copies full Nostr event ID to clipboard
  - Pretty-printed JSON with syntax highlighting
  - Copy entire JSON or just event ID

#### Technical Details
- Modified `lib/widgets/share_video_menu.dart`:
  - Added `_buildAdvancedSection()` with View Source and Copy Event ID options
  - Created `_ViewSourceDialog` widget for displaying event JSON
  - Added `_showViewSourceDialog()` and `_copyEventId()` methods
  - Uses `JsonEncoder.withIndent()` for readable formatting
  - Fetches raw event from NostrService via `fetchEventById()`

### Fixed - Database Migration Resilience (2025-11-08)

#### Bug Fixes
- **Fixed video_metrics backfill migration to handle malformed events** - Migration now completes successfully even with bad data
  - Changed from `INSERT` to `INSERT OR IGNORE` to skip events with invalid tags
  - Added NULL checks before CAST operations to prevent SQL errors
  - Added logging for backfill success rate (shows X/Y events backfilled)
  - Wrapped backfill in try-catch to prevent migration failure
  - Empty video_metrics table is acceptable - new events will populate going forward

#### Root Cause
- Some events have malformed tag structures or missing tag values
- Direct CAST operations threw SQL errors on NULL values
- Migration would fail completely, preventing app startup
- Users stuck on old schema version

#### Technical Details
- Modified `lib/database/app_database.dart`:
  - Lines 90-180: Updated migration step 2 backfill logic
  - Added CASE/WHEN checks before CAST operations
  - Added event count logging before/after backfill
  - Added comprehensive error handling with stack traces
  - Migration completes successfully even if backfill fails
  - Future events still get metrics via `upsertEvent()`

### Fixed - Relay Migration (2025-10-31)

#### Bug Fixes
- **Added automatic migration from relay3.openvine.co to relay.divine.video**
  - Root cause: Embedded relay stores external relay URLs persistently across app sessions
  - Symptom: Users who installed before relay change continued using old relay despite code updates
  - Impact: Users' settings showed relay.divine.video but app connected to relay3.openvine.co
  - Solution: Added migration logic to detect and remove old relay on startup

#### Files Modified
- `lib/services/nostr_service.dart` - Added migration check before relay connection
- `lib/services/nostr_service_function.dart` - Added migration check for function-channel variant

#### Technical Details
- Migration runs on every app startup before relay connection loop
- Checks if `relay3.openvine.co` is in embedded relay's connected relays list
- If found, calls `removeExternalRelay()` to clean up old configuration
- Normal initialization then adds new default relay from `AppConstants.defaultRelayUrl`
- Idempotent operation (safe to run multiple times)
- Zero overhead if user doesn't have old relay configured
- Pattern can be extended for future relay migrations

### Fixed - Video Grid Thumbnail Layout (2025-10-25)

#### Bug Fixes
- **Fixed video thumbnails being squished in explore grid**
  - Root cause: Grid used `childAspectRatio: 1.0` (square) for entire tile including video + labels
  - This made video thumbnails appear horizontally compressed
  - Symptom: Video thumbnails were not square, labels were inside the square tile
  - Solution: Force video to square aspect ratio, adjust grid tile to be vertical rectangle

#### Files Modified
- `lib/widgets/composable_video_grid.dart` - Changed layout structure and aspect ratios

#### Technical Details
- Replaced `Expanded(flex: 5)` with `AspectRatio(aspectRatio: 1.0)` to force video thumbnails square
- Added `mainAxisSize: MainAxisSize.min` to Column to only take needed space
- Adjusted `childAspectRatio` from `1.0` to `0.85` (vertical rectangle tiles)
- Video thumbnail is now guaranteed 1:1 square, labels appear cleanly below
- Removed excess blank space under stats by optimizing tile height
- Added `StringUtils.formatCompactNumber()` for likes/loops display (shows 1K, 1M instead of raw numbers)

### Fixed - Explore Feed Sort Order Mismatch (2025-10-25)

#### Bug Fixes
- **Fixed video playback issues caused by sort order mismatch between grid and feed**
  - Root cause: ExploreScreen grid used tab-specific sorting (New Vines=date, Trending=loops) but activeVideoIdProvider used default loop-count sorting
  - Symptom 1: Videos wouldn't play when tapped in grid
  - Symptom 2: Wrong video would play (tapping New Vines video played Trending video)
  - Symptom 3: Feed displayed different order than grid (confusing UX)
  - Solution: Created shared state provider to synchronize video lists across all components

#### Files Modified
- `lib/providers/route_feed_providers.dart` - Added exploreTabVideosProvider and legacy Riverpod import
- `lib/providers/active_video_provider.dart` - Added debug logging for troubleshooting
- `lib/screens/explore_screen.dart` - Set/clear tab videos provider on enter/exit feed mode
- `lib/screens/pure/explore_video_screen_pure.dart` - Use tab-specific list from parent

#### Technical Details
- Created `exploreTabVideosProvider` (StateProvider) to hold tab-specific sorted video lists
- ExploreScreen sets this provider when entering feed mode with the grid's sorted list
- videosForExploreRouteProvider uses tab list when available, falls back to loop-count sorting
- activeVideoIdProvider uses videosForExploreRouteProvider, now containing correct tab list
- All three components (grid, feed UI, active video logic) now use same sorted list
- Requires `import 'package:flutter_riverpod/legacy.dart'` for StateProvider in Riverpod 3.0
- Ensures New Vines maintains date sort, Trending maintains loop sort, Editor's Pick maintains curation

### Fixed - NIP-71 imeta Tag Parsing (2025-10-25)

#### Bug Fixes
- **Fixed video URL extraction from new imeta tag format**
  - Root cause: imeta tag format changed from space-separated key-value pairs to positional pairs
  - OLD FORMAT: `["imeta", "url https://...", "m video/mp4"]` (space within element)
  - NEW FORMAT: `["imeta", "url", "https://...", "m", "video/mp4"]` (separate elements)
  - Parser only supported old format, causing video URLs to not be extracted
  - Database had 1953 events but only 2 displayed because URLs weren't being parsed
  - Now supports BOTH formats for backward compatibility

#### Files Modified
- `lib/models/video_event.dart` - Updated `_parseImetaTag()` to handle both imeta formats

#### Technical Details
- Parser now detects format by checking if first element contains a space
- OLD FORMAT: Loop through elements, split on space to get key-value pairs
- NEW FORMAT: Loop in steps of 2, treat consecutive elements as key-value pairs
- Fixes issue where 1953 events in database appeared as "no videos" in explore feed
- Enables proper video display from relay.divine.video and other relays using new format

### Fixed - Video Display Crash (2025-10-25)

#### Bug Fixes
- **Fixed "Invalid argument(s): 0" crash preventing videos from displaying**
  - Root cause: `clamp(0, videos.length - 1)` when `videos.length` is 0 produces `clamp(0, -1)` which throws error
  - Previously calculated clamp before checking if videos list was empty
  - Now checks for empty videos first, only calculates clamp when videos exist
  - Prevents crash when home feed is loading or has no videos

#### Files Modified
- `lib/screens/home_screen_router.dart` - Reordered empty check before clamp calculation

#### Technical Details
- Moved `urlIndex = (ctx.videoIndex ?? 0).clamp(0, videos.length - 1)` to AFTER empty videos check
- When videos is empty, sets `urlIndex = 0` and displays "No videos available" UI
- When videos exist, safely clamps index because `videos.length - 1 >= 0`
- Fix resolves issue where NostrService was successfully fetching events but UI crashed before displaying them

### Fixed - Trending Hashtags Fallback (2025-10-25)

#### Bug Fixes
- **Added fallback default hashtags when analytics API is unavailable**
  - Root cause: Backend `/analytics/trending/hashtags` endpoint doesn't exist (returns 404)
  - Previously returned empty list when API failed, showing no hashtags to users
  - Now falls back to curated list from `HashtagExtractor.suggestedHashtags`
  - Provides 20 default trending hashtags: openvine, nostr, vine, funny, art, dance, music, comedy, etc.
  - Fallback hashtags include placeholder stats (views, video count, viral score) for consistent UI

#### Files Modified
- `lib/services/analytics_api_service.dart` - Added `_getDefaultTrendingHashtags()` fallback method
- Changed error behavior from returning `[]` to returning default hashtags
- Changed log level from ERROR to WARNING when API is unavailable (expected condition)

#### Technical Details
- Default hashtags generated from `HashtagExtractor.suggestedHashtags` list
- Maintains consistent UI experience even when backend API is down
- Stats decrease naturally (1000→550 views, 50→12 videos) to simulate trending order
- Fallback is transparent to UI - same `TrendingHashtag` object structure

### Changed - Default Relay (2025-10-25)

#### Configuration Changes
- **Changed default Nostr relay from `wss://relay3.openvine.co` to `wss://relay.divine.video`**
  - Centralized relay URL in `AppConstants.defaultRelayUrl` constant
  - Updated all service files to use the constant instead of hardcoded URLs
  - Ensures consistency across native app, web version, and background scripts

#### Files Modified
- `lib/constants/app_constants.dart` - Added `defaultRelayUrl` constant
- `lib/services/nostr_service.dart` - Uses `AppConstants.defaultRelayUrl`
- `lib/services/nostr_service_web.dart` - Uses `AppConstants.defaultRelayUrl`
- `lib/services/nostr_service_function.dart` - Uses `AppConstants.defaultRelayUrl`
- `lib/services/analytics_api_service.dart` - Uses `AppConstants.defaultRelayUrl`
- `lib/scripts/bulk_thumbnail_generator.dart` - Uses `AppConstants.defaultRelayUrl`

#### Technical Benefits
- Single source of truth for default relay configuration
- Easier to update relay URL in future (change one constant)
- Consistent relay usage across all app implementations
- No more scattered hardcoded relay URLs throughout codebase

### Fixed - iOS Build Failure (2025-10-25)

#### Bug Fixes
- **Fixed iOS build failing with "No podspec found for wakelock_plus"**
  - Root cause: Stale explicit pod reference in `ios/Podfile` for plugin that was never actually a dependency
  - Someone had manually added `pod 'wakelock_plus'` to Podfile, causing CocoaPods to fail
  - The `flutter_install_all_ios_pods` command already handles all actual plugin dependencies automatically
  - Fixed by removing the explicit wakelock_plus line from Podfile (line 43)
  - iOS release builds now complete successfully and can be distributed via TestFlight

#### Technical Details
- Modified `ios/Podfile`:
  - Removed explicit `pod 'wakelock_plus', :path => '.symlinks/plugins/wakelock_plus/ios'` line
  - Kept `pod 'libwebp'` which is still required
  - Flutter's auto-generated plugin list handles all actual dependencies

### Fixed - Critical Log Export Bug (2025-10-21)

#### Bug Fixes
- **Fixed log export capturing only 25 lines instead of thousands** - Category filtering was incorrectly applied to file capture
  - Root cause: Logger was filtering logs by category BEFORE writing to persistent storage
  - Default categories (only `system` and `auth`) meant 90% of logs were discarded
  - Critical debugging logs (`relay`, `video`, `ui`, `api`, `storage`) were never saved to files
  - Users exporting logs for support received only 25 lines instead of 2,200+ lines

  - Fixed by separating console output filtering from file capture:
    - Console output: Still filtered by category/level (reduces development noise)
    - File capture: ALWAYS happens regardless of category or level settings
    - Ensures comprehensive diagnostic data for debugging remote user issues

  - Impact: Log exports now include ALL categories for complete debugging context
    - Before: 25 lines, only `system`/`auth` categories, 0.00 MB
    - After: 2,200+ lines, ALL categories (relay: 116, video: 319, ui: 132, etc.), 0.18 MB
    - **88x more logs** with full relay connection debugging information

- **Fixed relay diagnostic network test using port 0** - WebSocket URLs now use correct default ports
  - `wss://` URLs now correctly use port 443 (not 0)
  - `ws://` URLs now correctly use port 80 (not 0)
  - `uri.port` returns 0 when port not explicitly specified in URL
  - Fixed by checking `uri.hasPort` and using scheme-appropriate defaults

#### Test Coverage
- Created `test/unit/utils/unified_logger_test.dart`:
  - 5 comprehensive tests following TDD methodology
  - Tests verified failing before fix, passing after fix
  - Tests log capture independence from category/level filtering
  - Tests all categories captured (relay, video, ui, api, storage, system, auth)
  - Tests all log levels captured (verbose, debug, info, warning, error)
  - Tests real-world bug report export scenario

#### Technical Details
- Modified `lib/utils/unified_logger.dart`:
  - Separated console filtering from file capture in `_log()` method
  - Console output uses `shouldPrintToConsole` check (filtered by category/level)
  - File capture happens unconditionally for ALL logs
  - Added comprehensive comments explaining the separation

- Modified `lib/screens/relay_diagnostic_screen.dart`:
  - Fixed `_testNetworkConnectivity()` port selection logic
  - Uses `uri.hasPort` to detect explicit port vs default
  - Applies correct default ports: 443 for wss://, 80 for ws://

### Added - Universal Deep Link System (2025-10-20)

#### Features
- **Comprehensive deep linking for divine.video URLs** - Share any app content via universal links
  - Video links: `https://divine.video/video/{eventId}` - Opens specific video in player
  - Profile links: `https://divine.video/profile/{npub}[/{index}]` - Opens user profile (grid or feed view)
  - Hashtag links: `https://divine.video/hashtag/{tag}[/{index}]` - Opens hashtag feed (grid or feed view)
  - Search links: `https://divine.video/search/{term}[/{index}]` - Opens search results (grid or feed view)
  - Feed pagination support: Optional index parameter for all feed views (0-based)
  - iOS Universal Links and Android App Links fully configured

#### Mobile Behavior
- Links open app automatically (no "open with" dialog)
- Grid view (2-segment URLs): Shows thumbnail grid of videos
- Feed view (3-segment URLs): Opens full-screen video player at specified index
- Seamless navigation to correct screen with proper context

#### Technical Implementation
- Created `lib/services/deep_link_service.dart`:
  - URL parsing for all 7 deep link patterns
  - Stream-based link event handling
  - Timing-safe initialization (listener setup before service init)
- Created `lib/providers/deep_link_provider.dart`:
  - Riverpod integration for deep link service
  - Reactive stream provider for incoming links
- Created `lib/screens/video_detail_screen.dart`:
  - Fetches video by Nostr event ID
  - Displays in full-screen player
  - Handles video not found gracefully
- Modified `lib/main.dart`:
  - Deep link listener with comprehensive logging
  - GoRouter integration for navigation
  - Fixed race condition: listener setup → then service initialization
- Modified `lib/router/app_router.dart`:
  - Added `/video/:id` route for direct video access
  - Existing routes support optional index parameter
- Modified `lib/services/video_event_service.dart`:
  - Added `getVideoById()` for cache lookup
- Modified `lib/services/nostr_service_interface.dart`, `nostr_service.dart`, `nostr_service_web.dart`:
  - Added `fetchEventById()` method to all implementations
  - Fetches single event by ID from Nostr relays

#### Platform Configuration
- **iOS (Universal Links)**:
  - Modified `ios/Runner/Runner.entitlements`: Added `applinks:divine.video`
  - Created `docs/apple-app-site-association`: Server verification file with Team ID GZCZBKH7MY
  - Paths: `/video/*`, `/profile/*`, `/hashtag/*`, `/search/*`
- **Android (App Links)**:
  - Modified `android/app/src/main/AndroidManifest.xml`: Added autoVerify intent filters
  - Created `docs/assetlinks.json`: Server verification file with debug SHA-256 fingerprint
  - All paths configured for automatic app opening

#### Server Deployment
- Created `docs/SERVER_DEPLOYMENT_CHECKLIST.md`:
  - Complete deployment guide for divine.video server
  - Web server configuration (nginx/apache)
  - Verification commands and troubleshooting
- Created `docs/DEEP_LINK_TESTING_GUIDE.md`:
  - Step-by-step testing procedures for iOS/Android
  - Console log debugging with emoji markers
  - Common issues and fixes
  - Production readiness checklist
- Created `docs/DEEP_LINK_URL_REFERENCE.md`:
  - Comprehensive specification of all 7 URL patterns
  - Mobile behavior descriptions for each pattern
  - Web app implementation guidelines
  - URL encoding and special character handling
  - Implementation checklist for web parity

#### Test Coverage
- Created `test/services/deep_link_service_test.dart`:
  - 19 unit tests for URL parsing
  - Tests all URL patterns (video, profile, hashtag, search)
  - Tests grid vs feed view detection
  - Tests index parameter parsing
  - Tests invalid URLs and unknown paths
- Created `test/services/nostr_service_fetch_event_test.dart`:
  - 11 unit tests for `fetchEventById()` functionality
  - Tests event fetching by ID
  - Tests cache behavior
  - Tests error handling
- All 30 tests passing

#### Documentation
- Complete URL reference for web app parity
- Deployment checklist with verification steps
- Testing guide with device testing procedures
- Server configuration examples

#### Bug Fixes
- **Fixed deep link timing race condition** - Initial link now correctly triggers navigation
  - Service initialization moved AFTER listener setup
  - Prevents broadcast stream event loss
  - Ensures app navigates correctly when opened via URL

### Added - Comprehensive Log Export and Persistent Logging (2025-10-20)

#### Features
- **Added manual log export feature** - Users can now save comprehensive diagnostic logs to file and share manually
  - New "Save Logs" option in Settings menu and navigation drawer
  - Exports ALL logs from persistent storage (hundreds of thousands of entries)
  - Includes comprehensive header with app version, device info, and log statistics
  - Opens native share dialog for easy email/messaging attachment
  - Automatically sanitizes sensitive data (nsec keys, passwords, auth tokens)

- **Redesigned log storage architecture** - Replaced in-memory buffer with persistent file-based logging
  - Logs written continuously to rotating files (10 files × 1MB each = 10MB total)
  - Supports hundreds of thousands of log entries per session
  - Small 1,000-entry memory buffer for fast access to recent logs
  - Automatic file rotation when files exceed 1MB
  - Automatic cleanup of old files when exceeding 10 file limit
  - Platform-appropriate storage locations:
    - macOS: `~/Library/Application Support/openvine/logs/` (hidden)
    - iOS: App's private support directory
    - Android: App-specific internal storage
    - Linux: `~/.local/share/openvine/logs/`
    - Windows: `%APPDATA%\openvine\logs\`

#### Bug Fixes
- **Fixed videos playing during hamburger menu navigation** - Videos now pause when drawer opens
  - Added `VideoVisibilityManager.pauseAllVideos()` call when menu button pressed
  - Prevents audio/video interference during navigation

- **Fixed Firebase test failures in ErrorAnalyticsTracker** - Implemented lazy initialization
  - Firebase Analytics no longer initialized during singleton construction
  - Uses nullable field + getter pattern for deferred initialization
  - All 10 BugReportService tests now pass
  - All 10 LogCaptureService tests pass

#### Technical Details
- Created `lib/services/log_capture_service.dart`:
  - Persistent file-based logging with rotating files
  - `getAllLogsAsText()` returns complete log history from all files
  - `getLogStatistics()` provides storage metrics
  - Fire-and-forget async writes with periodic flush
  - Graceful fallback to memory-only on file system errors

- Modified `lib/services/bug_report_service.dart`:
  - Added `exportLogsToFile()` method
  - Exports comprehensive logs with detailed header
  - Sanitizes sensitive data before export
  - Uses SharePlus for native file sharing

- Modified `lib/router/app_shell.dart`:
  - Added video pause when hamburger menu opens
  - Integrated with VideoVisibilityManager

- Modified `lib/services/error_analytics_tracker.dart`:
  - Changed from eager to lazy Firebase Analytics initialization
  - Updated all 7 `logEvent()` calls to use lazy getter
  - Prevents Firebase dependency during construction

- Modified `lib/widgets/vine_drawer.dart` and `lib/screens/settings_screen.dart`:
  - Added "Save Logs" menu items with export functionality

- Modified `lib/utils/unified_logger.dart`:
  - Added `unawaited()` for non-blocking log writes
  - Log capture no longer blocks main thread

- Updated `test/unit/services/log_capture_service_test.dart`:
  - Updated tests for new file-based API
  - Changed `clearBuffer()` to `clearAllLogs()`

#### Test Coverage
- BugReportService: 10/10 tests pass
- LogCaptureService: 10/10 tests pass
- All code passes flutter analyze with no issues

### Fixed - Hashtag Navigation and Event Deduplication (2025-10-17)

#### Bug Fixes
- **Fixed hashtag navigation from search removing search screen** - Hashtag now pushes on navigation stack
  - Search screen previously disappeared when tapping hashtag (used GoRouter's `go()` method)
  - Changed to `Navigator.push()` to keep search in the stack
  - Back button now correctly returns to search results
  - Hashtag screen shows proper AppBar with back button
- **Fixed hashtag feeds not showing videos after search** - Removed global event deduplication
  - Events seen in search were dropped as "globally-duplicate" when hashtag subscription tried to deliver them
  - Removed `_rememberGlobalEvent()` global deduplication logic from NostrService
  - Per-subscription deduplication (via `seenEventIds` Set) prevents duplicates within same subscription
  - Same event can now appear in different contexts (search results, hashtag feed, home feed)
  - Relay queries successfully but events were being dropped at service layer

#### Technical Details
- Modified `lib/screens/pure/search_screen_pure.dart`:
  - Lines 521-543: Changed hashtag tap handler to use `Navigator.push()` with `MaterialPageRoute`
  - Added import for `HashtagScreenRouter`
  - Hashtag screen wrapped in Scaffold with AppBar for proper back navigation
- Modified `lib/services/nostr_service.dart`:
  - Lines 363-366: Removed global deduplication check, replaced with explanatory comment
  - Removed lines 440-450: Deleted `_rememberGlobalEvent()` method entirely
  - Removed lines 38-41: Deleted global deduplication state (`_recentEventQueue`, `_recentEventSet`)
  - Removed unused `dart:collection` import
  - Per-subscription deduplication retained (line 313: `seenEventIds` Set per subscription)

#### Tests
- Created `test/screens/search_hashtag_navigation_test.dart`:
  - Tests that tapping hashtag from search results uses Navigator.push (keeps search in stack)
  - Verifies search screen remains accessible via back button
- Created `test/services/hashtag_duplicate_events_test.dart`:
  - Documents expected behavior: same event should appear in multiple subscription contexts
  - Verifies per-subscription deduplication prevents true duplicates

### Added - Profile Feed Architecture Refactor (2025-10-17)

#### Features
- **Added unified profile feed provider with pagination** - Replaces multiple scattered profile providers
  - New `ProfileFeedProvider` consolidates profile video loading logic
  - Supports both grid and feed modes with proper route-based selection
  - Implements pagination mixin for infinite scroll
  - Handles sort order (chronological vs loop count)
  - Manages selection state for multi-video operations

#### Technical Details
- Created `lib/providers/profile_feed_provider.dart`:
  - Unified provider for all profile video feeds
  - Route-aware: automatically selects correct video when navigating to /profile/:npub/:index
  - Pagination support via `PaginationMixin`
  - Sort order management (newest first vs most loops)
- Updated `lib/screens/profile_screen_router.dart`:
  - Now uses unified `ProfileFeedProvider` instead of scattered providers
  - Simplified video selection logic
  - Better grid/feed mode switching

#### Tests
- Created `test/providers/profile_feed_provider_selects_test.dart` - Tests video selection from routes
- Created `test/providers/profile_feed_pagination_test.dart` - Tests infinite scroll pagination
- Created `test/providers/profile_feed_sort_order_test.dart` - Tests chronological vs loop count sorting

### Added - Router Enhancements (2025-10-17)

#### Features
- **Added search routes with grid/feed modes** - Search now has proper routing structure
  - `/search` - Grid mode showing search results
  - `/search/:index` - Feed mode showing video at index
  - Search keeps explore tab active in bottom nav (tab index 1)
- **Added /profile/me/:index redirect** - Shortcut for current user's profile
  - Redirects `/profile/me/:index` to `/profile/{user-npub}/:index`
  - Automatically encodes authenticated user's pubkey to npub
  - Falls back to home if not authenticated

#### Technical Details
- Modified `lib/router/app_router.dart`:
  - Lines 28-29: Added `_searchGridKey` and `_searchFeedKey` navigator keys
  - Lines 48: Search returns tab index -1 to hide bottom nav (has its own AppBar)
  - Lines 58-93: Added redirect logic for `/profile/me/*` routes
  - Lines 191-218: Added search-grid and search-feed routes
- Created `lib/utils/public_identifier_normalizer.dart` - Utility for npub/hex conversion

#### Tests
- Created `test/router/profile_me_redirect_test.dart` - Tests /profile/me redirect
- Created `test/router/search_route_parsing_test.dart` - Tests search URL parsing
- Created `test/router/search_navigation_test.dart` - Tests search navigation
- Created `test/router/search_bottom_nav_test.dart` - Tests search hides bottom nav

### Added - New Services and Utilities (2025-10-17)

#### Services
- **Created BlossomAuthService** - Handles BUD-01 authentication for Blossom servers
  - Generates auth tokens for media uploads
  - Signs requests with Nostr keys
  - Created `lib/services/blossom_auth_service.dart`
  - Tests: `test/services/blossom_auth_service_test.dart`

- **Created MediaAuthInterceptor** - HTTP interceptor for authenticated media requests
  - Automatically adds Blossom auth headers to requests
  - Integrates with BlossomAuthService
  - Created `lib/services/media_auth_interceptor.dart`
  - Tests: `test/services/media_auth_interceptor_test.dart`

- **Created BookmarkSyncWorker** - Background sync for bookmark sets (NIP-51)
  - Syncs user's bookmark collections
  - Handles kind 30003 events
  - Created `lib/services/bookmark_sync_worker.dart`
  - Tests: `test/services/bookmark_sync_test.dart`

- **Created VideoPrewarmer** - Proactive video caching service
  - Prewarms upcoming videos in feed for smooth playback
  - Replaces old provider-based approach
  - Created `lib/services/video_prewarmer.dart`
  - Removed: `lib/providers/video_prewarmer_provider.dart`

- **Created VisibilityTracker** - Tracks video visibility for analytics
  - Monitors which videos are actually watched
  - Integrates with analytics service
  - Created `lib/services/visibility_tracker.dart`

#### Widgets
- **Created ComposableVideoGrid** - Reusable video grid component
  - Consistent grid layout across explore, search, profile
  - Supports custom tap handlers and empty states
  - Created `lib/widgets/composable_video_grid.dart`
  - Tests: `test/widgets/composable_video_grid_test.dart`

- **Created VideoErrorOverlay** - Error state display for failed videos
  - Shows user-friendly error messages
  - Retry functionality
  - Created `lib/widgets/video_error_overlay.dart`
  - Tests: `test/widgets/video_error_overlay_test.dart`

### Added - Video Editor Screen (2025-10-17)

#### Features
- **Created video editor screen** - Edit video metadata after recording
  - Edit title, description, hashtags
  - Route: `/edit-video` (requires VideoEvent passed via `extra`)
  - Integrated with profile screen for editing user's videos

#### Technical Details
- Created `lib/screens/video_editor_screen.dart` - Video metadata editor
- Modified `lib/router/app_router.dart`: Added `/edit-video` route
- Tests:
  - `test/screens/video_editor_route_test.dart` - Route integration
  - `test/screens/profile_edit_video_navigation_test.dart` - Edit from profile
  - `test/screens/profile_video_deletion_test.dart` - Delete after edit

### Added - Curation Publishing (2025-10-17)

#### Features
- **Added curation set publishing** - Users can create and publish curated video collections
  - NIP-51 kind 30005 events for video curation
  - Draft/published status tracking
  - Integration with bookmark system

#### Technical Details
- Created `lib/models/curation_publish_status.dart` - Publish state model
- Modified `lib/services/curation_service.dart` - Added publishing methods
- Tests: `test/services/curation_publish_test.dart`

### Added - Comprehensive Test Coverage (2025-10-17)

#### New Tests
- **Search functionality**:
  - `test/screens/search_results_sorting_test.dart` - Tests sorting (new vines chronologically, originals by loops)
  - `test/providers/search_active_video_test.dart` - Active video in search feed

- **Explore functionality**:
  - `test/providers/explore_active_video_test.dart` - Active video in explore feed

- **Home feed**:
  - `test/providers/home_feed_double_watch_test.dart` - Prevents double-watching same video

- **Navigation**:
  - `test/widgets/video_feed_item_navigation_test.dart` - Video tap navigation

- **Services**:
  - `test/services/notification_service_test.dart` - Notification handling
  - `test/services/secure_key_storage_nip46_test.dart` - NIP-46 key storage
  - `test/services/upload_initialization_helper_test.dart` - Upload initialization
  - `test/services/upload_manager_sandbox_test.dart` - Upload manager
  - `test/services/video_cache_nsfw_auth_test.dart` - NSFW content auth

- **Widgets**:
  - `test/widgets/share_video_menu_bookmark_sets_test.dart` - Bookmark set sharing

### Changed - Provider Cleanup (2025-10-17)

#### Refactoring
- **Consolidated video feed providers** - Unified architecture reduces duplication
  - Removed scattered route-specific providers
  - Centralized logic in route-aware providers
  - Better separation of concerns

#### Technical Details
- Updated `lib/providers/hashtag_feed_providers.dart` - Route-aware provider
- Modified `lib/providers/route_feed_providers.dart` - Unified feed management
- Removed `lib/screens/profile_screen_scrollable.dart` - Obsolete implementation
- Updated numerous provider files for consistency

### Added - Real End-to-End Upload and Publishing Tests (2025-10-14)

#### Tests
- **Added comprehensive E2E tests for video upload → thumbnail → Nostr publishing with REAL services** - Validates complete flow with no mocks
  - Tests use actual Blossom server at `https://blossom.divine.video`
  - Tests publish to real Nostr relays (`wss://relay3.openvine.co`, `wss://relay.damus.io`)
  - Generates real MP4 videos using ffmpeg for testing
  - Validates BUD-01 authentication (Nostr kind 24242 events)
  - Confirms thumbnail extraction and upload
  - Verifies NIP-71 kind 34236 event creation and broadcasting
  - Tests CDN accessibility and video streaming

#### Test Coverage
- Created `integration_test/upload_publish_real_e2e_test.dart`:
  - **Test 1**: Complete upload → publish flow validation
    - Generates 5-second test video with ffmpeg (640x480, blue color)
    - Uploads video and thumbnail to Blossom CDN
    - Creates signed Nostr event with video metadata
    - Publishes to multiple relays and verifies success
    - Validates upload state transitions (readyToPublish → published)
  - **Test 2**: CDN video retrieval verification
    - Confirms uploaded videos are immediately accessible
    - Validates HTTP 200 response and proper content-type headers
    - Tests video streaming compatibility

#### Technical Details
- Uses `IntegrationTestWidgetsFlutterBinding` for real network requests (not `TestWidgetsFlutterBinding`)
- Authenticates test users with generated Nostr keypairs via `AuthService.importFromHex()`
- Initializes NostrService with custom relay list for publishing
- Generates test videos dynamically with ffmpeg (no committed test files)
- Falls back to minimal MP4 if ffmpeg unavailable
- Disables macOS sandbox in `DebugProfile.entitlements` to allow ffmpeg execution
- Test timeout: 5 minutes (allows for real network operations)

#### Test Results
- ✅ All tests passing (2/2)
- ✅ Video upload to Blossom CDN working
- ✅ Thumbnail extraction and upload working
- ✅ Nostr event publishing to relays working
- ✅ CDN video retrieval working (HTTP 200)
- ✅ Complete state management verified

#### Production Readiness
- Upload → publish flow validated with real services
- BUD-01 authentication working correctly
- NIP-71 event format correct and accepted by relays
- CDN serving files with proper headers for video streaming
- No mocks - tests use actual production infrastructure

### Fixed - Tab Visibility Listener for Video Clearing (2025-10-13)

#### Bug Fixes
- **Added tab visibility listeners to clear active video when switching tabs** - Prevents video playback in background tabs
  - `MainScreen` now listens for tab changes and clears active video when navigating away from video feeds
  - Ensures videos stop playing when user switches to Profile, Camera, or Explore tabs
  - Uses `_currentTabIndex` tracking to detect tab navigation events
  - Calls `VideoOverlayManager.clearActiveVideo()` on tab switches away from video content

#### Technical Details
- Modified `lib/screens/main_screen.dart`:
  - Added tab visibility tracking in `_onTabSelected()` method
  - Detects navigation away from Home and Explore tabs (indices 0 and 2)
  - Clears active video controller to stop background playback
  - Logs tab changes for debugging video lifecycle issues

### Added - Phase 1 App Lifecycle Video Pause Tests (2025-10-13)

#### Tests
- **Added comprehensive app lifecycle video pause tests** - Validates video behavior during app state changes
  - Tests video pause/resume on app backgrounding and foregrounding
  - Validates proper WidgetsBindingObserver registration and cleanup
  - Ensures VideoOverlayManager responds correctly to lifecycle events
  - Confirms video state transitions through pause, resume, and inactive states

#### Technical Details
- Created `test/integration/app_lifecycle_video_pause_test.dart`:
  - Tests observer registration in VideoOverlayManager
  - Validates video pause when app enters background (AppLifecycleState.paused)
  - Confirms video resume when app returns to foreground (AppLifecycleState.resumed)
  - Tests cleanup on VideoOverlayManager disposal
  - Uses proper async/await patterns for lifecycle state changes

### Fixed - Video Playback During Camera Recording (2025-10-08)

#### Bug Fixes
- **Fixed videos playing in background during camera recording** - Videos now fully disposed when opening camera
  - `VideoStopNavigatorObserver` now detects camera screen navigation and disposes all video controllers
  - Previous behavior only cleared active video, allowing background playback to continue
  - Camera screen navigation now triggers `VideoOverlayManager.disposeAllControllers()`
  - Ensures complete cleanup of video state when entering camera mode

#### Technical Details
- Modified `lib/services/video_stop_navigator_observer.dart`:
  - Added import for `video_overlay_manager_provider.dart`
  - Lines 27-44: Added camera screen detection logic
  - Checks if route name contains "Camera" to identify camera navigation
  - Calls `disposeAllControllers()` for camera routes vs `clearActiveVideo()` for other routes
  - Logs differentiate between disposal actions for debugging

### Fixed - iOS Camera Permissions on Fresh App Launch (2025-10-08)

#### Bug Fixes
- **Fixed iOS camera permission detection on fresh app launch** - Permissions now correctly detected without requiring Settings visit
  - iOS `permission_handler` plugin has persistent caching bug that returns stale status across app launches
  - Solution: Bypass `permission_handler` entirely, attempt camera initialization directly
  - Native `AVCaptureDevice` checks real system permissions, not cached values
  - Works correctly for both returning from Settings AND fresh app launches

#### Root Cause
- `permission_handler` caches permission status in memory and persists it across app sessions
- Even after granting permissions in Settings, `Permission.camera.status` returns stale `false` value
- Calling `.request()` also returns cached status instead of checking actual system state
- Only way to get accurate status is to let native AVFoundation attempt initialization

#### Technical Details
- Modified `lib/screens/pure/universal_camera_screen_pure.dart`:
  - Lines 175-238: Updated `_performAsyncInitialization()` to bypass `permission_handler`
  - Attempts camera initialization first before checking cached permission status
  - If initialization succeeds → permissions already granted
  - If initialization fails with permission error → request permissions via dialog
  - After granting → retry initialization
  - Lines 84-135: Previously fixed `_recheckPermissions()` for Settings return flow

#### Manual Testing Protocol
- Fresh app launch with permissions already granted: Camera preview appears immediately
- Fresh app launch without permissions: Permission dialog appears, camera initializes after grant
- Returning from Settings after granting: Camera preview appears immediately (already fixed)
- No longer requires visiting Settings on every app launch

### Fixed - Thumbnail Generation on macOS (2025-10-08)

#### Bug Fixes
- **Fixed video thumbnail generation on macOS** - Hybrid approach ensures cross-platform compatibility
  - Primary strategy: `fc_native_video_thumbnail` plugin (fast, native performance)
  - Fallback strategy: FFmpeg (universal, works on ALL platforms)
  - macOS previously failed with `MissingPluginException` from plugin
  - Now successfully generates thumbnails via FFmpeg fallback

#### Implementation
- Modified `lib/services/video_thumbnail_service.dart`:
  - Lines 98-125: Try `fc_native_video_thumbnail` first
  - Lines 127-136: Fallback to FFmpeg on plugin failure
  - Lines 20-67: Added `_extractThumbnailWithFFmpeg()` method
  - FFmpeg command: Extract frame at 100ms, resize to 640x640, JPEG quality 2

#### Platform Support Matrix
| Platform | fc_native_video_thumbnail | FFmpeg | Result |
|----------|--------------------------|--------|--------|
| Android  | ✅ Works                 | ✅ Available | Uses plugin |
| iOS      | ✅ Works                 | ✅ Available | Uses plugin |
| macOS    | ❌ MissingPluginException | ✅ Works | Uses FFmpeg |
| Windows  | ✅ Should work           | ✅ Available | Uses plugin or FFmpeg |
| Linux    | ❓ Unknown              | ✅ Works | Uses FFmpeg |

#### Test Results
- Unit tests: 17/17 PASS (`test/services/video_thumbnail_service_test.dart`)
- Integration tests: 8/8 PASS (`test/services/video_event_publisher_embedded_thumbnail_test.dart`)
- E2E tests: 3/3 PASS (`test/integration/video_thumbnail_publish_e2e_test.dart`)

#### Documentation
- Created `THUMBNAIL_SOLUTION.md` with comprehensive implementation details
- Includes FFmpeg command reference, testing protocol, and future improvements

### Fixed - Home Feed Empty State (2025-10-04)

#### Bug Fixes
- **Fixed home feed showing empty state despite following users with videos** - Resolved provider disposal race condition
  - Changed `socialProvider` from `keepAlive: false` to `keepAlive: true`
  - Provider was being disposed during async initialization (fetching contact list and reactions)
  - Home feed now correctly receives following list (14 users) and loads their videos (33 videos loaded)
  - Social state (following list, likes, reposts) now persists in memory as app-wide state

#### Root Cause
- `socialProvider` used `@Riverpod(keepAlive: false)` which caused auto-disposal when not actively watched
- `homeFeedProvider` reads it with `ref.read()` which doesn't keep the provider alive
- During async operations (`fetchCurrentUserFollowList()`, `fetchAllUserReactions()`), provider would dispose
- Result: Following list never populated, home feed incorrectly showed "Your Feed, Your Choice" empty state

#### Technical Details
- Modified `lib/providers/social_providers.dart`:
  - Line 20: Changed `@Riverpod(keepAlive: false)` to `@Riverpod(keepAlive: true)`
  - Updated comment to reflect disposal prevention and state caching
- Regenerated `lib/providers/social_providers.g.dart`:
  - Line 29: `isAutoDispose: false` (previously `true`)
- Provider still receives updates via state mutations and `ref.invalidate()`
- `keepAlive: true` only prevents disposal, doesn't affect reactivity

### Fixed - Video Controller Memory Management (2025-10-03)

#### Bug Fixes
- **Fixed video controller disposal when entering camera** - Improved memory management for camera transitions
  - Camera screen now force-disposes all video controllers on entry (prevents ghost videos)
  - Additional disposal before navigating to profile after recording
  - Ensures no stale video controllers exist during tab switches
  - Prevents background video playback when camera is active

#### Technical Details
- Modified `lib/screens/pure/universal_camera_screen_pure.dart`:
  - Lines 44-54: Force dispose all controllers in initState
  - Lines 807-809: Additional disposal before profile navigation
  - Improved cleanup prevents IndexedStack widget lifecycle issues

### Changed - iOS Build Process (2025-10-03)

#### Improvements
- **Auto-increment build number for release builds** - Ensures App Store compliance
  - Release builds (`./build_ios.sh release`) now automatically increment build number
  - Debug builds only increment when `--increment` flag is explicitly passed
  - Updated usage documentation to reflect new behavior

#### Technical Details
- Modified `build_ios.sh`:
  - Lines 14-22: Conditional auto-increment logic for release vs debug
  - Lines 136-143: Updated usage documentation

### Fixed - Home Feed Video Loading (2025-01-30)

#### Bug Fixes
- **Fixed home feed only loading 1 video** - Resolved race condition in video batch loading
  - Home feed provider now waits for complete video batch from relay instead of completing on first video
  - Implemented stability-based waiting: monitors video count and completes when stable for 300ms
  - Added 3-second maximum timeout as safety for slow connections
  - Uses proper event-driven pattern with Completer and ChangeNotifier listeners
- **Fixed home feed auto-refresh behavior**
  - Automatically refreshes when contact list changes (follow/unfollow)
  - Added 10-minute auto-refresh timer for background updates
  - Maintains proper keepAlive behavior to prevent unnecessary rebuilds
- **Fixed video swiping gesture conflicts**
  - Changed `enableLifecycleManagement` to `false` in home feed to match explore feed
  - Added missing `controller` parameter to VideoPageView for proper state management
- **Code quality improvements**
  - Removed unused imports and fields in home_feed_provider.dart
  - Fixed syntax error (trailing comma) in video_feed_screen.dart

#### Technical Details
- Modified `lib/providers/home_feed_provider.dart`:
  - Lines 126-163: Stability-based video loading with proper cleanup
  - Lines 80-93: Reactive listening for contact list changes
  - Lines 69-78: 10-minute auto-refresh timer
- Modified `lib/screens/video_feed_screen.dart`:
  - Added `controller: _pageController` to VideoPageView
  - Changed `enableLifecycleManagement: false`
- Enhanced debug logging in `lib/widgets/video_page_view.dart`

### Changed - Riverpod 3 Migration (2025-01-30)

#### Breaking Changes
- **Upgraded to Riverpod 3.0.0** - Complete migration from Riverpod 2.x
- **Upgraded to Freezed 3.2.3** - Added required `sealed` keyword to all state classes
- **Updated Firebase dependencies** - firebase_core ^4.1.1, firebase_crashlytics ^5.0.2, firebase_analytics ^12.0.2
- **Updated Flutter Lints** - ^6.0.0 for latest linting rules

#### Fixed
- All freezed state classes now use `sealed` keyword required by Freezed 3.x
  - `AnalyticsState`, `SocialState`, `UserProfileState`, `VideoFeedState`
  - `VideoMetadata`, `VideoContent`, `SingleVideoState`, `VideoContentBufferState`, `CurationState`
- Fixed provider access patterns for Riverpod 3
  - Changed `videoOverlayManagerProvider.notifier` to `videoOverlayManagerProvider`
  - Updated `searchStateProvider` references in tests
- Fixed Hive imports to use `hive_ce` package
- Updated UserProfile constructor calls with required parameters (`rawData`, `createdAt`, `eventId`)
- Regenerated all `.g.dart` and `.freezed.dart` files with Riverpod 3 generators

#### Dependencies Updated
- firebase_core: ^3.15.1 → ^4.1.1
- firebase_crashlytics: ^4.1.2 → ^5.0.2
- firebase_analytics: ^11.3.5 → ^12.0.2
- flutter_launcher_icons: ^0.13.1 → ^0.14.4
- flutter_lints: ^5.0.0 → ^6.0.0
- Plus 44 transitive dependency updates

#### Production Code Status
- ✅ **0 compilation errors** in production code
- ✅ App compiles and runs successfully with Riverpod 3
- ✅ All state management patterns updated
- ✅ All providers properly generated

#### Test Status
- 370 test errors remaining (down from 408)
  - 341 in TODO test files (intentionally incomplete)
  - 27 in visual regression tests (require golden_toolkit)
  - ~2 in core integration/unit tests
- Production code unaffected by test errors

#### Technical Details
- Dart SDK constraint updated: `>=3.8.0 <4.0.0` (required for json_serializable 6.8.0)
- Legacy Riverpod 2 providers maintained compatibility via `package:flutter_riverpod/legacy.dart`
- Build runner successfully generates 120+ files
- All Riverpod 3 code generation working correctly
