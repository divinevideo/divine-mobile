# OpenVine Mobile Changelog

All notable changes to the OpenVine mobile application will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - 2025-12-02

### Added
- **REST Gateway Integration**: Added REST gateway service for faster video discovery feeds
  - New `RelayGatewayService` for REST-based queries
  - Gateway toggle in relay settings for user control
  - Riverpod providers for gateway service and settings
  - Comprehensive gateway integration tests
- **Zendesk Bug Reporting**: Added Zendesk REST API for bug reports on macOS/Windows
  - Desktop platforms now submit bug reports directly via Zendesk API
  - Automatic device info and logs included in reports

### Fixed
- **Share Video Menu**: Fixed null pubkey crash when sharing videos
  - Added proper null check for pubkeyToSearch parameter
- **Bug Report Dialog**: Fixed layout overflow in bug report form
- **Segment Recording**: Fixed macOS segment recording to extract only recorded portions
  - Videos with pauses now trim correctly
- **Recording Progress Bar**: Made recording progress bar much thicker and more visible

### Changed
- **Code Quality**: Applied `dart fix --apply` and `dart format` across codebase
- **CI/CD**: Upgraded to v4 of actions/upload-artifact
- **Dependencies**: Started tracking pubspec.lock in repository

## [Previous] - 2025-09-29

### Fixed
- **Video Loading Issues**: Fixed critical video loading failures by correcting URL routing
  - Removed hardcoded URL forcing logic that was overriding correct cdn.divine.video URLs
  - Videos now properly use URLs from Nostr event imeta tags instead of broken api.openvine.co endpoints
  - Supports any video server (nostr.build, self-hosted, etc.) without hardcoding domain restrictions
  - Videos now load and cache successfully from cdn.divine.video CDN
- **Video Overlay Positioning**: Fixed video metadata overlay overlapping with bottom navigation
  - Adjusted video overlay positioning from `bottom: 0` to `bottom: 80` to clear navigation bar
  - Video titles, author info, and action buttons now display properly above bottom navigation
  - Improved visual hierarchy and readability of video metadata
- **VideoFeedItem Architecture**: Updated video feed item to use modern individual controller architecture
  - Replaced old video manager system with individual video provider pattern
  - Each video now gets its own controller with automatic lifecycle management via Riverpod autoDispose
  - Fixed interface compatibility issues (updated constructor to use `index` instead of `isActive`)
  - Improved video state management and memory efficiency
- **Test Suite Compatibility**: Resolved 40+ analyzer errors from architectural changes
  - Updated imports and provider references to match new individual video architecture
  - Fixed interface mismatches across test files and widget implementations
  - Ensured consistent API usage throughout the codebase

### Technical Improvements
- Enhanced video URL selection logic to respect Nostr event specifications
- Improved error handling and logging for video loading diagnostics
- Better separation of concerns between video controllers and UI components
- More robust handling of different video URL formats and servers

## [Previous] - 2025-09-12

### Added
- **Multi-Account Support Planning**: Comprehensive implementation plan for multiple Nostr accounts
  - Created detailed architecture documentation at `docs/MULTI_ACCOUNT_IMPLEMENTATION.md`
  - Designed AccountManager service for managing multiple identities
  - Planned secure key storage using flutter_secure_storage with biometric protection
  - Architected account switching with <500ms target performance
  - Designed shared embedded relay infrastructure across all accounts
  - Planned account-specific subscriptions, settings, and state preservation
  - Created data models for UserAccount, AccountState, and RelayConfig
  - Designed migration strategy for existing single-account users
  - Documented complete API reference and testing strategies
  - Planned 5-phase implementation roadmap with security-first approach

### Added
- **Analytics-Driven Trending**: Implemented trending content based on real analytics data
  - Added `AnalyticsTrending` provider that fetches data from api.openvine.co/analytics API
  - Trending section now shows videos sorted by actual view counts instead of chronological order
  - Added pull-to-refresh functionality to trending tab for real-time analytics updates
  - Removed fallback behavior to ensure trending only shows analytics-driven content
- **New Vines Section**: Renamed "Popular Now" to "New Vines" with chronological content
  - "New Vines" tab now shows latest Nostr content in chronological order
  - Designed to generate view data that feeds into analytics for trending calculations
  - Added pull-to-refresh functionality to New Vines tab
- **Enhanced Explore Screen**: Improved explore screen with comprehensive pull-to-refresh
  - All three tabs (Editor's Picks, New Vines, Trending) now support pull-to-refresh
  - Added proper refresh indicators and user feedback for all content sections
  - Updated tab labels and functionality to reflect new content strategy
- **Blurhash Support**: Implemented blurhash generation and display for Kind 22 video events
  - Videos now publish with blurhash tags for progressive image loading
  - Added blurhash generation from video thumbnails during upload
  - Created BlurhashDisplay widget for rendering blurhash placeholders
  - Updated VideoThumbnailWidget to show blurhash while loading thumbnails
  - Provides instant visual feedback with smooth transitions to actual thumbnails
- **Improved Tab Navigation**: Enhanced explore screen tab bar navigation behavior
  - Single tap on current tab now exits feed mode and returns to grid view
  - Double-tap detection on tabs for quick navigation back to root
  - Consistent navigation behavior across Editor's Picks, New Vines, and Trending tabs

### Changed
- **Explore Screen Architecture**: Completely restructured explore content strategy
  - Trending tab now exclusively uses api.openvine.co/analytics data (no fallback to random content)
  - "Popular Now" renamed to "New Vines" to better reflect chronological content purpose
  - Content flow designed: New Vines → generates views → feeds analytics → drives Trending
- **Provider System**: Updated Riverpod providers for new content architecture
  - Enhanced `AnalyticsTrending` provider with proper error handling and refresh logic
  - Updated `curationProvider` to support pull-to-refresh for Editor's Picks
  - Improved provider invalidation and refresh patterns across all explore tabs
- **Relay Configuration**: Switched to using relay3.openvine.co as primary relay
- Enhanced VideoEvent model to parse and store blurhash from Kind 22 events
- Updated video publishing to include blurhash tag following NIP-71 standards

### Fixed
- **CRITICAL**: Resolved relay subscription limit (50 subscriptions) that was preventing video comments and interactions from loading on web platform
- Fixed video comment lazy loading to prevent subscription leaks when scrolling through feed
- Improved subscription management with proper cleanup when videos scroll out of view
- Enhanced error handling for comment count fetching with better timeout management

### Added  
- Implemented lazy comment loading in video feed items - comments only load when user taps comment button
- Added proper subscription management through SubscriptionManager for all comment-related operations
- Added `cancelCommentSubscriptions()` method in SocialService for cleaning up video-specific subscriptions
- Added subscription limits and priority handling to prevent relay overload
- Added enhanced error handling and logging for subscription management debugging

### Changed
- Modified `SocialService.fetchCommentsForEvent()` to use managed subscriptions instead of direct Nostr service calls
- Updated `getCommentCount()` to use SubscriptionManager with proper timeout and priority settings
- Increased SubscriptionManager concurrent subscription limit from 20 to 30 for better comment handling
- Enhanced video feed item UI to show lazy-loaded comment counts (shows "?" until loaded)
- Improved subscription cleanup patterns throughout social interaction services

### Technical Details
- Refactored comment subscription pattern from direct `_nostrService.subscribeToEvents()` to managed `_subscriptionManager.createSubscription()`
- Implemented StreamController pattern for proper event stream management in comment fetching
- Added subscription limits (50-100 events) to prevent excessive relay load
- Enhanced subscription timeout and priority management for different operation types
- Improved logging and debugging for subscription lifecycle management

### Web Platform
- Deployed subscription management fixes to resolve "Maximum number of subscriptions (50) reached" errors
- Fixed video interaction loading issues on web deployment
- Improved web performance through better subscription resource management