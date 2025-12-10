// ABOUTME: Comprehensive Riverpod providers for all application services
// ABOUTME: Replaces Provider MultiProvider setup with pure Riverpod dependency injection

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/geo_blocking_service.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/api_service.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/bookmark_service.dart';
import 'package:openvine/services/nostr_service_factory.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/curation_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/user_list_service.dart';
// Removed legacy explore_video_manager.dart import
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/services/mute_service.dart';
import 'package:openvine/services/nip05_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
// NostrService now includes embedded relay functionality
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/notification_service_enhanced.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/profile_cache_service.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/hashtag_cache_service.dart';
import 'package:openvine/services/blossom_auth_service.dart';
import 'package:openvine/services/media_auth_interceptor.dart';
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:openvine/services/broken_video_tracker.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/services/video_visibility_manager.dart';
import 'package:openvine/services/web_auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/services/nip17_message_service.dart';
import 'package:openvine/services/relay_capability_service.dart';
import 'package:openvine/services/video_filter_builder.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/services/event_router.dart';

part 'app_providers.g.dart';

// =============================================================================
// FOUNDATIONAL SERVICES (No dependencies)
// =============================================================================

/// Connection status service for monitoring network connectivity
@riverpod
ConnectionStatusService connectionStatusService(Ref ref) {
  return ConnectionStatusService();
}

/// Relay capability service for detecting NIP-11 divine extensions
@Riverpod(keepAlive: true)
RelayCapabilityService relayCapabilityService(Ref ref) {
  final service = RelayCapabilityService();
  ref.onDispose(() => service.dispose());
  return service;
}

/// Video filter builder for constructing relay-aware filters with server-side sorting
@riverpod
VideoFilterBuilder videoFilterBuilder(Ref ref) {
  final capabilityService = ref.watch(relayCapabilityServiceProvider);
  return VideoFilterBuilder(capabilityService);
}

/// Video visibility manager for controlling video playback based on visibility
@riverpod
VideoVisibilityManager videoVisibilityManager(Ref ref) {
  return VideoVisibilityManager();
}

/// Background activity manager singleton for tracking app foreground/background state
@Riverpod(keepAlive: true)
BackgroundActivityManager backgroundActivityManager(Ref ref) {
  return BackgroundActivityManager();
}

/// Analytics service with opt-out support
@Riverpod(keepAlive: true) // Keep alive to maintain singleton behavior
AnalyticsService analyticsService(Ref ref) {
  final service = AnalyticsService();

  // Ensure cleanup on disposal
  ref.onDispose(() {
    service.dispose();
  });

  // Initialize asynchronously but don't block the provider
  // Use a microtask to avoid blocking the provider creation
  Future.microtask(() => service.initialize());

  return service;
}

/// Age verification service for content creation restrictions
/// keepAlive ensures the service persists and maintains in-memory verification state
/// even when widgets that watch it dispose and rebuild
@Riverpod(keepAlive: true)
AgeVerificationService ageVerificationService(Ref ref) {
  final service = AgeVerificationService();
  service.initialize(); // Initialize asynchronously
  return service;
}

/// Geo-blocking service for regional compliance
@riverpod
GeoBlockingService geoBlockingService(Ref ref) {
  return GeoBlockingService();
}

/// Secure key storage service (foundational service)
@Riverpod(keepAlive: true)
SecureKeyStorage secureKeyStorage(Ref ref) {
  return SecureKeyStorage();
}

/// Web authentication service (for web platform only)
@riverpod
WebAuthService webAuthService(Ref ref) {
  return WebAuthService();
}

/// Nostr key manager for cryptographic operations
@Riverpod(keepAlive: true)
NostrKeyManager nostrKeyManager(Ref ref) {
  return NostrKeyManager();
}

/// Profile cache service for persistent profile storage
@riverpod
ProfileCacheService profileCacheService(Ref ref) {
  final service = ProfileCacheService();
  // Initialize asynchronously to avoid blocking UI
  service.initialize().catchError((e) {
    Log.error(
      'Failed to initialize ProfileCacheService',
      name: 'AppProviders',
      error: e,
    );
  });
  return service;
}

/// Hashtag cache service for persistent hashtag storage
@riverpod
HashtagCacheService hashtagCacheService(Ref ref) {
  final service = HashtagCacheService();
  // Initialize asynchronously to avoid blocking UI
  service.initialize().catchError((e) {
    Log.error(
      'Failed to initialize HashtagCacheService',
      name: 'AppProviders',
      error: e,
    );
  });
  return service;
}

/// Personal event cache service for ALL user's own events
@riverpod
PersonalEventCacheService personalEventCacheService(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  final service = PersonalEventCacheService();

  // Initialize with current user's pubkey when authenticated
  if (authService.isAuthenticated && authService.currentPublicKeyHex != null) {
    service.initialize(authService.currentPublicKeyHex!).catchError((e) {
      Log.error(
        'Failed to initialize PersonalEventCacheService',
        name: 'AppProviders',
        error: e,
      );
    });
  }

  return service;
}

/// Seen videos service for tracking viewed content
@riverpod
SeenVideosService seenVideosService(Ref ref) {
  return SeenVideosService();
}

/// Content blocklist service for filtering unwanted content from feeds
@riverpod
ContentBlocklistService contentBlocklistService(Ref ref) {
  return ContentBlocklistService();
}

/// NIP-05 service for username registration and verification
@riverpod
Nip05Service nip05Service(Ref ref) {
  return Nip05Service();
}

/// Draft storage service for persisting vine drafts
@riverpod
Future<DraftStorageService> draftStorageService(Ref ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return DraftStorageService(prefs);
}

// (Removed duplicate legacy provider for StreamUploadService)

// =============================================================================
// DEPENDENT SERVICES (With dependencies)
// =============================================================================

/// Authentication service depends on secure key storage
@Riverpod(keepAlive: true)
AuthService authService(Ref ref) {
  final keyStorage = ref.watch(secureKeyStorageProvider);
  return AuthService(keyStorage: keyStorage);
}

/// Stream provider for reactive auth state changes
/// Widgets should watch this instead of authService.authState to get rebuilds
@riverpod
Stream<AuthState> authStateStream(Ref ref) async* {
  final authService = ref.watch(authServiceProvider);

  // Emit current state immediately
  yield authService.authState;

  // Then emit all future changes
  yield* authService.authStateStream;
}

/// Core Nostr service with platform-aware embedded relay functionality and P2P capabilities
@Riverpod(keepAlive: true)
INostrService nostrService(Ref ref) {
  final keyManager = ref.watch(nostrKeyManagerProvider);

  // Use factory to create platform-appropriate service with initialization callback
  final service = NostrServiceFactory.create(
    keyManager,
    onInitialized: () {
      // Mark Nostr as initialized when the service completes initialization
      ref.read(nostrInitializationProvider.notifier).markInitialized();
    },
  );

  // Note: Initialization is handled explicitly in main.dart to ensure proper async timing
  // Do NOT call NostrServiceFactory.initialize(service) here as it causes double initialization

  // Cleanup on disposal - but only in production, not during development hot reloads
  ref.onDispose(() {
    // Skip disposal during debug mode to prevent embedded relay shutdown during hot reloads
    if (!kDebugMode) {
      service.dispose();
    } else {
      // In debug mode, just close subscriptions but keep the relay alive
      service.closeAllSubscriptions().catchError((e) {
        UnifiedLogger.warning(
          'Error closing subscriptions during hot reload: $e',
        );
      });
    }
  });

  return service;
}

/// Subscription manager for centralized subscription management
@Riverpod(keepAlive: true)
SubscriptionManager subscriptionManager(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  return SubscriptionManager(nostrService);
}

/// Video event service depends on Nostr, SeenVideos, Blocklist, AgeVerification, and SubscriptionManager services
@Riverpod(keepAlive: true)
VideoEventService videoEventService(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final subscriptionManager = ref.watch(subscriptionManagerProvider);
  final blocklistService = ref.watch(contentBlocklistServiceProvider);
  final ageVerificationService = ref.watch(ageVerificationServiceProvider);
  final userProfileService = ref.watch(userProfileServiceProvider);
  final videoFilterBuilder = ref.watch(videoFilterBuilderProvider);
  final db = ref.watch(databaseProvider);
  final eventRouter = EventRouter(db);

  final service = VideoEventService(
    nostrService,
    subscriptionManager: subscriptionManager,
    userProfileService: userProfileService,
    eventRouter: eventRouter,
    videoFilterBuilder: videoFilterBuilder,
  );
  service.setBlocklistService(blocklistService);
  service.setAgeVerificationService(ageVerificationService);
  return service;
}

/// Hashtag service depends on Video event service and cache service
@riverpod
HashtagService hashtagService(Ref ref) {
  final videoEventService = ref.watch(videoEventServiceProvider);
  final cacheService = ref.watch(hashtagCacheServiceProvider);
  return HashtagService(videoEventService, cacheService);
}

/// User profile service depends on Nostr service, SubscriptionManager, and ProfileCacheService
@Riverpod(keepAlive: true)
UserProfileService userProfileService(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final subscriptionManager = ref.watch(subscriptionManagerProvider);
  final profileCache = ref.watch(profileCacheServiceProvider);

  final service = UserProfileService(
    nostrService,
    subscriptionManager: subscriptionManager,
  );
  service.setPersistentCache(profileCache);

  // Inject profile cache lookup into SubscriptionManager to avoid redundant relay requests
  subscriptionManager.setCacheLookup(hasProfileCached: service.hasProfile);

  // Ensure cleanup on disposal
  ref.onDispose(() {
    service.dispose();
  });

  return service;
}

/// Social service depends on Nostr service, Auth service, and SubscriptionManager
@Riverpod(keepAlive: true)
SocialService socialService(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final subscriptionManager = ref.watch(subscriptionManagerProvider);
  final personalEventCache = ref.watch(personalEventCacheServiceProvider);

  return SocialService(
    nostrService,
    authService,
    subscriptionManager: subscriptionManager,
    personalEventCache: personalEventCache,
  );
}

// ProfileStatsProvider is now handled by profile_stats_provider.dart with pure Riverpod

// ProfileVideosProvider is now handled by profile_videos_provider.dart with pure Riverpod

/// Enhanced notification service with Nostr integration (lazy loaded)
@riverpod
NotificationServiceEnhanced notificationServiceEnhanced(Ref ref) {
  final service = NotificationServiceEnhanced();

  // Delay initialization until after critical path is loaded
  if (!kIsWeb) {
    // Initialize on mobile - wait for keys to be available
    final nostrService = ref.watch(nostrServiceProvider);
    final profileService = ref.watch(userProfileServiceProvider);
    final videoService = ref.watch(videoEventServiceProvider);

    Future.microtask(() async {
      try {
        // Wait for Nostr keys to be loaded before initializing notifications
        // Keys may take a moment to load from secure storage
        var retries = 0;
        while (!nostrService.hasKeys && retries < 30) {
          // Wait 500ms between checks, up to 15 seconds total
          await Future.delayed(const Duration(milliseconds: 500));
          retries++;
        }

        if (!nostrService.hasKeys) {
          Log.warning(
            'Notification service initialization skipped - no Nostr keys available after 15s',
            name: 'AppProviders',
            category: LogCategory.system,
          );
          return;
        }

        await service.initialize(
          nostrService: nostrService,
          profileService: profileService,
          videoService: videoService,
        );
      } catch (e) {
        Log.error(
          'Failed to initialize enhanced notification service: $e',
          name: 'AppProviders',
          category: LogCategory.system,
        );
      }
    });
  } else {
    // On web, delay initialization by 3 seconds to allow main UI to load first
    Timer(const Duration(seconds: 3), () async {
      try {
        final nostrService = ref.read(nostrServiceProvider);
        final profileService = ref.read(userProfileServiceProvider);
        final videoService = ref.read(videoEventServiceProvider);

        await service.initialize(
          nostrService: nostrService,
          profileService: profileService,
          videoService: videoService,
        );
      } catch (e) {
        Log.error(
          'Failed to initialize enhanced notification service: $e',
          name: 'AppProviders',
          category: LogCategory.system,
        );
      }
    });
  }

  return service;
}

// VideoManagerService removed - using pure Riverpod VideoManager provider instead

/// NIP-98 authentication service
@riverpod
Nip98AuthService nip98AuthService(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  return Nip98AuthService(authService: authService);
}

/// Blossom BUD-01 authentication service for age-restricted content
@riverpod
BlossomAuthService blossomAuthService(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  return BlossomAuthService(authService: authService);
}

/// Media authentication interceptor for handling 401 unauthorized responses
@riverpod
MediaAuthInterceptor mediaAuthInterceptor(Ref ref) {
  final ageVerificationService = ref.watch(ageVerificationServiceProvider);
  final blossomAuthService = ref.watch(blossomAuthServiceProvider);
  return MediaAuthInterceptor(
    ageVerificationService: ageVerificationService,
    blossomAuthService: blossomAuthService,
  );
}

/// Blossom upload service (uses user-configured Blossom server)
/// Blossom upload service (uses user-configured Blossom server)
@riverpod
BlossomUploadService blossomUploadService(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  final nostrService = ref.watch(nostrServiceProvider);
  return BlossomUploadService(
    authService: authService,
    nostrService: nostrService,
  );
}

/// Upload manager uses only Blossom upload service
@Riverpod(keepAlive: true)
UploadManager uploadManager(Ref ref) {
  final blossomService = ref.watch(blossomUploadServiceProvider);
  return UploadManager(blossomService: blossomService);
}

/// API service depends on auth service
@riverpod
ApiService apiService(Ref ref) {
  final authService = ref.watch(nip98AuthServiceProvider);
  return ApiService(authService: authService);
}

/// Video event publisher depends on multiple services
@Riverpod(keepAlive: true)
VideoEventPublisher videoEventPublisher(Ref ref) {
  final uploadManager = ref.watch(uploadManagerProvider);
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final personalEventCache = ref.watch(personalEventCacheServiceProvider);
  final videoEventService = ref.watch(videoEventServiceProvider);

  return VideoEventPublisher(
    uploadManager: uploadManager,
    nostrService: nostrService,
    authService: authService,
    personalEventCache: personalEventCache,
    videoEventService: videoEventService,
  );
}

/// Curation Service - manages NIP-51 video curation sets
@Riverpod(keepAlive: true)
CurationService curationService(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final videoEventService = ref.watch(videoEventServiceProvider);
  final socialService = ref.watch(socialServiceProvider);
  final authService = ref.watch(authServiceProvider);

  return CurationService(
    nostrService: nostrService,
    videoEventService: videoEventService,
    socialService: socialService,
    authService: authService,
  );
}

// Legacy ExploreVideoManager removed - functionality replaced by pure Riverpod video providers

/// Content reporting service for NIP-56 compliance
@riverpod
Future<ContentReportingService> contentReportingService(Ref ref) async {
  final nostrService = ref.watch(nostrServiceProvider);
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final service = ContentReportingService(
    nostrService: nostrService,
    prefs: prefs,
  );

  // Initialize the service to enable reporting
  await service.initialize();

  return service;
}

/// Curated list service for NIP-51 kind 30005 video lists
@riverpod
Future<CuratedListService> curatedListService(Ref ref) async {
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final prefs = await ref.watch(sharedPreferencesProvider.future);

  final service = CuratedListService(
    nostrService: nostrService,
    authService: authService,
    prefs: prefs,
  );

  // Initialize the service to create default list and sync with relays
  await service.initialize();

  return service;
}

/// User list service for NIP-51 kind 30000 people lists
@riverpod
Future<UserListService> userListService(Ref ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);

  final service = UserListService(prefs: prefs);

  // Initialize the service to load lists
  await service.initialize();

  return service;
}

/// Bookmark service for NIP-51 bookmarks
@riverpod
Future<BookmarkService> bookmarkService(Ref ref) async {
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final prefs = await ref.watch(sharedPreferencesProvider.future);

  return BookmarkService(
    nostrService: nostrService,
    authService: authService,
    prefs: prefs,
  );
}

/// Mute service for NIP-51 mute lists
@riverpod
Future<MuteService> muteService(Ref ref) async {
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final prefs = await ref.watch(sharedPreferencesProvider.future);

  return MuteService(
    nostrService: nostrService,
    authService: authService,
    prefs: prefs,
  );
}

/// Video sharing service
@riverpod
VideoSharingService videoSharingService(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final userProfileService = ref.watch(userProfileServiceProvider);

  return VideoSharingService(
    nostrService: nostrService,
    authService: authService,
    userProfileService: userProfileService,
  );
}

/// Content deletion service for NIP-09 delete events
@riverpod
Future<ContentDeletionService> contentDeletionService(Ref ref) async {
  final nostrService = ref.watch(nostrServiceProvider);
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final service = ContentDeletionService(
    nostrService: nostrService,
    prefs: prefs,
  );

  // Initialize the service to enable content deletion
  await service.initialize();

  return service;
}

/// Account Deletion Service for NIP-62 Request to Vanish
@riverpod
AccountDeletionService accountDeletionService(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  return AccountDeletionService(
    nostrService: nostrService,
    authService: authService,
  );
}

/// Broken video tracker service for filtering non-functional videos
@riverpod
Future<BrokenVideoTracker> brokenVideoTracker(Ref ref) async {
  final tracker = BrokenVideoTracker();
  await tracker.initialize();
  return tracker;
}

/// Bug report service for collecting diagnostics and sending encrypted reports
@riverpod
BugReportService bugReportService(Ref ref) {
  final keyManager = ref.watch(nostrKeyManagerProvider);
  final nostrService = ref.watch(nostrServiceProvider);

  final nip17Service = NIP17MessageService(
    keyManager: keyManager,
    nostrService: nostrService,
  );

  return BugReportService(nip17MessageService: nip17Service);
}
