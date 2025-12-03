// ABOUTME: Service for fetching and caching NIP-01 kind 0 user profile events
// ABOUTME: Manages user metadata including display names, avatars, and descriptions

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/profile_cache_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service for managing user profiles from Nostr kind 0 events
/// Reactive service that notifies listeners when profiles are updated
class UserProfileService extends ChangeNotifier {
  UserProfileService(
    this._nostrService, {
    required SubscriptionManager subscriptionManager,
  }) : _subscriptionManager = subscriptionManager;
  final INostrService _nostrService;
  final ConnectionStatusService _connectionService = ConnectionStatusService();

  final Map<String, UserProfile> _profileCache =
      {}; // In-memory cache for fast access
  final Map<String, String> _activeSubscriptionIds =
      {}; // pubkey -> subscription ID
  final Set<String> _pendingRequests = {};
  bool _isInitialized = false;

  // Batch fetching management
  String? _batchSubscriptionId;
  Timer? _batchTimeout;
  Timer? _batchDebounceTimer;
  final Set<String> _pendingBatchPubkeys = {};

  // Missing profile tracking to avoid relay spam
  final Set<String> _knownMissingProfiles = {};
  final Map<String, DateTime> _missingProfileRetryAfter = {};

  // Completers to track when profile fetches complete
  final Map<String, Completer<UserProfile?>> _profileFetchCompleters = {};

  // Prefetch tracking
  bool _prefetchActive = false;
  DateTime? _lastPrefetchAt;

  // Background refresh rate limiting
  DateTime? _lastBackgroundRefresh;

  final SubscriptionManager _subscriptionManager;
  ProfileCacheService? _persistentCache;

  /// Set persistent cache service for profile storage
  void setPersistentCache(ProfileCacheService cacheService) {
    _persistentCache = cacheService;
    Log.debug(
      '📱 ProfileCacheService attached to UserProfileService',
      name: 'UserProfileService',
      category: LogCategory.system,
    );
  }

  /// Get cached profile for a user
  UserProfile? getCachedProfile(String pubkey) {
    // First check in-memory cache
    var profile = _profileCache[pubkey];
    if (profile != null) {
      return profile;
    }

    // If not in memory, check persistent cache
    if (_persistentCache?.isInitialized == true) {
      profile = _persistentCache!.getCachedProfile(pubkey);
      if (profile != null) {
        // Load into memory cache for faster access
        _profileCache[pubkey] = profile;
        // Notify listeners that profile is now available
        notifyListeners();
        return profile;
      }
    }

    return null;
  }

  /// Check if profile is cached
  bool hasProfile(String? pubkey) {
    if (pubkey == null || pubkey.isEmpty) return false;
    if (_profileCache.containsKey(pubkey)) return true;

    // Also check persistent cache
    if (_persistentCache?.isInitialized == true) {
      return _persistentCache!.getCachedProfile(pubkey) != null;
    }

    return false;
  }

  /// Check if we should skip fetching this profile to avoid relay spam
  bool shouldSkipProfileFetch(String? pubkey) {
    if (pubkey == null || pubkey.isEmpty) return false;
    // Don't fetch if we know it's missing and retry time hasn't passed
    if (_knownMissingProfiles.contains(pubkey)) {
      final retryAfter = _missingProfileRetryAfter[pubkey];
      if (retryAfter != null && DateTime.now().isBefore(retryAfter)) {
        return true; // Still in cooldown period
      }
      // Cooldown expired, remove from missing list to allow retry
      _knownMissingProfiles.remove(pubkey);
      _missingProfileRetryAfter.remove(pubkey);
    }
    return false;
  }

  /// Mark a pubkey as having no profile to avoid future requests
  void markProfileAsMissing(String? pubkey) {
    if (pubkey == null || pubkey.isEmpty) return;
    _knownMissingProfiles.add(pubkey);
    // Retry after 10 minutes for missing profiles (reduced from 1 hour)
    _missingProfileRetryAfter[pubkey] = DateTime.now().add(
      const Duration(minutes: 10),
    );
    Log.debug(
      'Marked profile as missing: ${pubkey}... (retry after 10 minutes)',
      name: 'UserProfileService',
      category: LogCategory.system,
    );
  }

  /// Get all cached profiles
  Map<String, UserProfile> get allProfiles => Map.unmodifiable(_profileCache);

  /// Update a cached profile (e.g., after editing)
  Future<void> updateCachedProfile(UserProfile profile) async {
    // Update in-memory cache
    _profileCache[profile.pubkey] = profile;

    // Update persistent cache
    if (_persistentCache?.isInitialized == true) {
      await _persistentCache!.updateCachedProfile(profile);
    }

    // Notify listeners that profile was updated
    notifyListeners();

    Log.debug(
      'Updated cached profile for ${profile.pubkey}: ${profile.bestDisplayName}',
      name: 'UserProfileService',
      category: LogCategory.system,
    );
  }

  /// Initialize the profile service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      Log.verbose(
        'Initializing user profile service...',
        name: 'UserProfileService',
        category: LogCategory.system,
      );

      if (!_nostrService.isInitialized) {
        Log.warning(
          'Nostr service not initialized, profile service will wait',
          name: 'UserProfileService',
          category: LogCategory.system,
        );
        return;
      }

      _isInitialized = true;
      Log.info(
        'User profile service initialized',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to initialize user profile service: $e',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Fetch profile for a specific user
  Future<UserProfile?> fetchProfile(
    String pubkey, {
    bool forceRefresh = false,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // If forcing refresh, clean up existing state first
    if (forceRefresh) {
      Log.debug(
        '🔄 Force refresh requested for ${pubkey}... - clearing cache and subscriptions',
        name: 'UserProfileService',
        category: LogCategory.system,
      );

      // Clear cached profile
      _profileCache.remove(pubkey);
      if (_persistentCache?.isInitialized == true) {
        _persistentCache!.removeCachedProfile(pubkey);
      }

      // Notify listeners that profile was removed for refresh
      notifyListeners();

      // Cancel any existing subscriptions for this pubkey
      _cleanupProfileRequest(pubkey);

      // Cancel and remove any pending completers for this pubkey
      final completer = _profileFetchCompleters.remove(pubkey);
      if (completer != null && !completer.isCompleted) {
        completer.complete(null); // Complete with null to unblock any waiters
      }
    }

    // Return cached profile if available and not forcing refresh
    if (!forceRefresh && hasProfile(pubkey)) {
      final cachedProfile = getCachedProfile(pubkey);

      // Check if we should do a soft refresh (background update)
      if (cachedProfile != null &&
          _persistentCache?.shouldRefreshProfile(pubkey) == true) {
        Log.debug(
          'Profile cached but stale for ${pubkey}... - will refresh in background',
          name: 'UserProfileService',
          category: LogCategory.system,
        );
        // Do a background refresh without blocking the UI
        Future.microtask(() => _backgroundRefreshProfile(pubkey));
      }

      Log.verbose(
        'Returning cached profile for ${pubkey}...',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      return cachedProfile;
    }

    // Check if already requesting this profile - return existing completer's future
    // (Note: forceRefresh already cleaned up existing requests above)
    if (_pendingRequests.contains(pubkey)) {
      // Return existing completer's future if available
      if (_profileFetchCompleters.containsKey(pubkey)) {
        Log.debug(
          'Reusing existing fetch request for ${pubkey}...',
          name: 'UserProfileService',
          category: LogCategory.system,
        );
        return _profileFetchCompleters[pubkey]!.future;
      }
      return null;
    }

    // Check if we already have an active subscription for this pubkey
    // (Note: forceRefresh already cleaned up existing subscriptions above)
    if (_activeSubscriptionIds.containsKey(pubkey)) {
      Log.warning(
        'Active subscription already exists for ${pubkey}... (skipping duplicate)',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      return null;
    }

    // Check connection
    if (!_connectionService.isOnline) {
      Log.debug(
        'Offline - cannot fetch profile for ${pubkey}...',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      return null;
    }

    try {
      _pendingRequests.add(pubkey);

      // Create a completer to track this fetch request
      final completer = Completer<UserProfile?>();
      _profileFetchCompleters[pubkey] = completer;

      // Add to batch instead of creating individual subscription
      _pendingBatchPubkeys.add(pubkey);

      // Cancel existing debounce timer and create new one
      _batchDebounceTimer?.cancel();
      _batchDebounceTimer = Timer(const Duration(milliseconds: 100), () {
        _executeBatchFetch();
      });

      // Return the completer's future - it will complete when batch fetch finishes
      return completer.future;
    } catch (e) {
      Log.error(
        'Failed to fetch profile for ${pubkey}: $e',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      _pendingRequests.remove(pubkey);
      _pendingBatchPubkeys.remove(pubkey);

      // Complete completer with error if it exists
      final completer = _profileFetchCompleters.remove(pubkey);
      if (completer != null && !completer.isCompleted) {
        completer.completeError(e);
      }

      return null;
    }
  }

  /// Handle incoming profile event
  void _handleProfileEvent(Event event) {
    try {
      if (event.kind != 0) return;

      // Parse profile data from event content
      final profile = UserProfile.fromNostrEvent(event);

      // Check if this is newer than existing cached profile
      final existingProfile = _profileCache[event.pubkey];
      if (existingProfile != null) {
        // Accept the new profile if:
        // 1. It has a different event ID (definitely a new event)
        // 2. OR it has a newer or equal timestamp (allow same-second updates)
        final isDifferentEvent = existingProfile.eventId != profile.eventId;
        final isNewerOrSame = !existingProfile.createdAt.isAfter(
          profile.createdAt,
        );

        if (!isDifferentEvent && !isNewerOrSame) {
          Log.debug(
            '⚠️ Received older profile event, ignoring',
            name: 'UserProfileService',
            category: LogCategory.system,
          );
          _cleanupProfileRequest(event.pubkey);
          return;
        }
      }

      // Cache the profile in memory
      _profileCache[event.pubkey] = profile;

      // Also save to persistent cache
      if (_persistentCache?.isInitialized == true) {
        _persistentCache!.cacheProfile(profile);
      }

      // Notify listeners that profile is now available
      notifyListeners();

      // Complete any pending fetch requests for this profile
      final completer = _profileFetchCompleters.remove(event.pubkey);
      if (completer != null && !completer.isCompleted) {
        completer.complete(profile);
        Log.debug(
          '✅ Completed fetch request for ${event.pubkey}',
          name: 'UserProfileService',
          category: LogCategory.system,
        );
      }

      _cleanupProfileRequest(event.pubkey);
    } catch (e) {
      Log.error(
        'Error parsing profile event: $e',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
    }
  }

  // TODO: Use for error handling if needed
  /*
  /// Handle profile fetch error
  void _handleProfileError(String pubkey, dynamic error) {
    Log.error('Profile fetch error for ${pubkey}: $error',
        name: 'UserProfileService', category: LogCategory.system);
    _cleanupProfileRequest(pubkey);
  }
  */

  // TODO: Use for completion handling if needed
  /*
  /// Handle profile fetch completion
  void _handleProfileComplete(String pubkey) {
    _cleanupProfileRequest(pubkey);
  }
  */

  /// Cleanup profile request
  void _cleanupProfileRequest(String pubkey) {
    _pendingRequests.remove(pubkey);

    // Clean up managed subscription
    final subscriptionId = _activeSubscriptionIds.remove(pubkey);
    if (subscriptionId != null) {
      _subscriptionManager.cancelSubscription(subscriptionId);
    }
  }

  /// Aggressively pre-fetch profiles for immediate display (no debouncing)
  Future<void> prefetchProfilesImmediately(List<String> pubkeys) async {
    if (pubkeys.isEmpty) return;

    // Filter out already cached profiles and pending requests
    final pubkeysToFetch = pubkeys
        .where(
          (pubkey) =>
              !_profileCache.containsKey(pubkey) &&
              !_pendingRequests.contains(pubkey) &&
              !shouldSkipProfileFetch(pubkey),
        )
        .toList();

    if (pubkeysToFetch.isEmpty) return;

    Log.debug(
      '⚡ Immediate pre-fetch for ${pubkeysToFetch.length} profiles',
      name: 'UserProfileService',
      category: LogCategory.system,
    );

    // Prevent flooding: if a prefetch is currently active, skip co-incident calls
    if (_prefetchActive) {
      Log.debug(
        'Prefetch suppressed: another prefetch is active',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      return;
    }

    // Simple rate-limit: ignore if last prefetch finished very recently (< 1s)
    if (_lastPrefetchAt != null &&
        DateTime.now().difference(_lastPrefetchAt!) <
            const Duration(seconds: 1)) {
      Log.debug(
        'Prefetch suppressed: rate limit within 1s',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      return;
    }

    // Add to pending requests
    _pendingRequests.addAll(pubkeysToFetch);

    try {
      // Create filter for kind 0 events from these users
      final filter = Filter(
        kinds: [0],
        authors: pubkeysToFetch,
        limit: math.min(
          pubkeysToFetch.length,
          100,
        ), // Smaller batches for immediate fetch
      );

      // Track which profiles we're fetching in this batch
      final thisBatchPubkeys = Set<String>.from(pubkeysToFetch);

      // Subscribe to profile events using SubscriptionManager with highest priority
      _prefetchActive = true;
      await _subscriptionManager.createSubscription(
        name: 'profile_prefetch_${DateTime.now().millisecondsSinceEpoch}',
        filters: [filter],
        onEvent: _handleProfileEvent,
        onError: (error) => Log.error(
          'Prefetch profile error: $error',
          name: 'UserProfileService',
          category: LogCategory.system,
        ),
        onComplete: () => _completePrefetch(thisBatchPubkeys),
        priority: 0, // Highest priority for immediate prefetch
      );

      Log.debug(
        '⚡ Sent immediate prefetch request for ${pubkeysToFetch.length} profiles',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to prefetch profiles: $e',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      _pendingRequests.removeAll(pubkeysToFetch);
      _prefetchActive = false;
      _lastPrefetchAt = DateTime.now();
    }
  }

  /// Complete the prefetch and clean up
  void _completePrefetch(Set<String> batchPubkeys) {
    // Mark unfetched profiles as missing
    final unfetchedPubkeys = batchPubkeys
        .where((pubkey) => !_profileCache.containsKey(pubkey))
        .toSet();
    final fetchedCount = batchPubkeys.length - unfetchedPubkeys.length;

    if (unfetchedPubkeys.isNotEmpty) {
      Log.debug(
        '⚡ Prefetch completed - fetched $fetchedCount/${batchPubkeys.length}, ${unfetchedPubkeys.length} missing',
        name: 'UserProfileService',
        category: LogCategory.system,
      );

      // Mark unfetched profiles as missing
      for (final pubkey in unfetchedPubkeys) {
        markProfileAsMissing(pubkey);
      }
    } else {
      Log.debug(
        '⚡ Prefetch completed - all ${batchPubkeys.length} profiles fetched',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
    }

    // Clean up pending requests for this batch
    _pendingRequests.removeAll(batchPubkeys);

    // Mark cycle done and set last timestamp
    _prefetchActive = false;
    _lastPrefetchAt = DateTime.now();
  }

  /// Batch fetch profiles for multiple users
  Future<void> fetchMultipleProfiles(
    List<String> pubkeys, {
    bool forceRefresh = false,
  }) async {
    if (pubkeys.isEmpty) return;

    // Filter out already cached profiles unless forcing refresh
    final filteredPubkeys = forceRefresh
        ? pubkeys
        : pubkeys
              .where(
                (pubkey) =>
                    !_profileCache.containsKey(pubkey) &&
                    !_pendingRequests.contains(pubkey),
              )
              .toList();

    // Further filter out known missing profiles to avoid relay spam
    final pubkeysToFetch = filteredPubkeys
        .where((pubkey) => forceRefresh || !shouldSkipProfileFetch(pubkey))
        .toList();

    final skippedCount = filteredPubkeys.length - pubkeysToFetch.length;
    if (skippedCount > 0) {
      Log.debug(
        'Skipping $skippedCount known missing profiles to avoid relay spam',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
    }

    if (pubkeysToFetch.isEmpty) {
      return;
    }

    // Add to pending batch
    _pendingBatchPubkeys.addAll(pubkeysToFetch);
    _pendingRequests.addAll(pubkeysToFetch);

    // Cancel existing debounce timer
    _batchDebounceTimer?.cancel();

    // If we already have an active subscription, let it complete
    if (_batchSubscriptionId != null) {
      Log.debug(
        '📦 Added ${pubkeysToFetch.length} profiles to pending batch (total pending: ${_pendingBatchPubkeys.length})',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      return;
    }

    // Debounce: reduced delay for faster profile loading
    _batchDebounceTimer = Timer(
      const Duration(milliseconds: 50),
      _executeBatchFetch,
    );
  }

  /// Execute the actual batch fetch
  Future<void> _executeBatchFetch() async {
    if (_pendingBatchPubkeys.isEmpty) return;

    // Move pending to current batch
    final batchPubkeys = _pendingBatchPubkeys.toList();
    _pendingBatchPubkeys.clear();

    Log.debug(
      '🔄 Executing batch fetch for ${batchPubkeys.length} profiles...',
      name: 'UserProfileService',
      category: LogCategory.system,
    );
    Log.debug(
      '📋 Sample pubkeys: ${batchPubkeys.take(3).map((p) => p).join(", ")}...',
      name: 'UserProfileService',
      category: LogCategory.system,
    );

    try {
      // Create filter for kind 0 events from these users
      final filter = Filter(
        kinds: [0],
        authors: batchPubkeys,
        limit: math.min(
          batchPubkeys.length,
          500,
        ), // Nostr protocol recommended limit
      );

      // Track which profiles we're fetching in this batch
      final thisBatchPubkeys = Set<String>.from(batchPubkeys);

      // Subscribe to profile events using SubscriptionManager
      final subscriptionId = await _subscriptionManager.createSubscription(
        name: 'profile_batch_${DateTime.now().millisecondsSinceEpoch}',
        filters: [filter],
        onEvent: _handleProfileEvent,
        onError: (error) => Log.error(
          'Batch profile fetch error: $error',
          name: 'UserProfileService',
          category: LogCategory.system,
        ),
        onComplete: () => _completeBatchFetch(thisBatchPubkeys),
        priority: 1, // High priority for profile fetches
      );

      // Store subscription ID for cleanup
      _batchSubscriptionId = subscriptionId;
    } catch (e) {
      Log.error(
        'Failed to batch fetch profiles: $e',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      _completeBatchFetch(batchPubkeys.toSet());
    }
  }

  /// Complete the batch fetch and clean up
  void _completeBatchFetch(Set<String> batchPubkeys) {
    // Cancel managed subscription
    if (_batchSubscriptionId != null) {
      _subscriptionManager.cancelSubscription(_batchSubscriptionId!);
      _batchSubscriptionId = null;
    }

    _batchTimeout?.cancel();
    _batchTimeout = null;

    // Check which profiles were not found and mark them as missing
    final unfetchedPubkeys = batchPubkeys
        .where((pubkey) => !_profileCache.containsKey(pubkey))
        .toSet();
    final fetchedCount = batchPubkeys.length - unfetchedPubkeys.length;

    if (unfetchedPubkeys.isNotEmpty) {
      Log.debug(
        '⏰ Batch profile fetch completed - fetched $fetchedCount/${batchPubkeys.length} profiles, ${unfetchedPubkeys.length} not found',
        name: 'UserProfileService',
        category: LogCategory.system,
      );

      // Mark unfetched profiles as missing to avoid future relay spam
      for (final pubkey in unfetchedPubkeys) {
        markProfileAsMissing(pubkey);

        // Complete pending fetch requests with null for missing profiles
        final completer = _profileFetchCompleters.remove(pubkey);
        if (completer != null && !completer.isCompleted) {
          completer.complete(null);
          Log.debug(
            '❌ Completed fetch request for missing profile ${pubkey}',
            name: 'UserProfileService',
            category: LogCategory.system,
          );
        }
      }
    } else {
      Log.info(
        '✅ Batch profile fetch completed - fetched all ${batchPubkeys.length} profiles',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
    }

    // Clean up pending requests for this batch
    _pendingRequests.removeAll(batchPubkeys);

    // If we have more pending profiles, start a new batch
    if (_pendingBatchPubkeys.isNotEmpty) {
      Log.debug(
        '📦 Starting next batch for ${_pendingBatchPubkeys.length} pending profiles...',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      Timer(const Duration(milliseconds: 50), _executeBatchFetch);
    }
  }

  /// Get display name for a user (with fallback)
  String getDisplayName(String pubkey) {
    final profile = _profileCache[pubkey];
    if (profile?.displayName?.isNotEmpty == true) {
      return profile!.displayName!;
    }
    if (profile?.name?.isNotEmpty == true) {
      return profile!.name!;
    }
    // Immediate fallback to user-friendly shortened pubkey
    return pubkey.length > 16
        ? 'User ${pubkey.substring(0, 6)}...'
        : 'User $pubkey';
  }

  /// Get avatar URL for a user
  String? getAvatarUrl(String pubkey) => _profileCache[pubkey]?.picture;

  /// Get user bio/description
  String? getUserBio(String pubkey) => _profileCache[pubkey]?.about;

  /// Clear profile cache
  void clearCache() {
    _profileCache.clear();

    // Notify listeners that all profiles are gone
    notifyListeners();

    Log.debug(
      '🧹 Profile cache cleared',
      name: 'UserProfileService',
      category: LogCategory.system,
    );
  }

  /// Remove specific profile from cache
  void removeProfile(String pubkey) {
    if (_profileCache.remove(pubkey) != null) {
      // Notify listeners that profile was removed
      notifyListeners();

      Log.debug(
        '📱️ Removed profile from cache: ${pubkey}...',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
    }
  }

  /// Background refresh for stale profiles
  Future<void> _backgroundRefreshProfile(String pubkey) async {
    // Don't refresh if already pending
    if (_pendingRequests.contains(pubkey) ||
        _activeSubscriptionIds.containsKey(pubkey)) {
      return;
    }

    // Rate limit background refreshes to avoid overwhelming the UI
    final now = DateTime.now();
    if (_lastBackgroundRefresh != null &&
        now.difference(_lastBackgroundRefresh!).inSeconds < 30) {
      Log.debug(
        'Rate limiting background refresh for ${pubkey}...',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      return;
    }

    try {
      Log.debug(
        'Background refresh for stale profile ${pubkey}...',
        name: 'UserProfileService',
        category: LogCategory.system,
      );

      _lastBackgroundRefresh = now;

      // Use a longer timeout for background refreshes to reduce urgency
      await fetchProfile(pubkey, forceRefresh: true);
    } catch (e) {
      Log.error(
        'Background refresh failed for ${pubkey}: $e',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
    }
  }

  /// Search for users using NIP-0 search capability
  Future<List<UserProfile>> searchUsers(String query, {int? limit}) async {
    if (query.trim().isEmpty) {
      throw ArgumentError('Search query cannot be empty');
    }

    try {
      Log.info(
        '🔍 Starting users search for: "$query"',
        name: 'UserProfileService',
        category: LogCategory.system,
      );

      // Create completer to track search completion
      final searchCompleter = Completer<void>();

      // Use the NostrService searchUsers method
      final searchStream = _nostrService.searchUsers(query, limit: limit ?? 50);

      final foundUsers = <UserProfile>{};

      late final StreamSubscription<Event> subscription;

      // Subscribe to search results
      subscription = searchStream.listen(
        (event) {
          // Parse user event
          final userEvent = UserProfile.fromNostrEvent(event);
          _profileCache[event.pubkey] = userEvent;
          foundUsers.add(userEvent);
        },
        onError: (error) {
          Log.error(
            'Search error: $error',
            name: 'UserProfileService',
            category: LogCategory.system,
          );
          // Search subscriptions can fail without affecting main feeds
          if (!searchCompleter.isCompleted) {
            searchCompleter.completeError(error);
          }
        },
        onDone: () {
          // Search completed naturally - this is expected behavior
          Log.info(
            'Search completed. Found ${foundUsers.length} results',
            name: 'UserProfileService',
            category: LogCategory.system,
          );
          // Search subscription clean up - remove from tracking
          subscription.cancel();
          if (!searchCompleter.isCompleted) {
            searchCompleter.complete();
          }
        },
      );

      // Wait for search to complete with timeout
      await searchCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          Log.warning(
            'Search timed out after 10 seconds',
            name: 'UserProfileService',
            category: LogCategory.system,
          );
          // Don't throw - return partial results
        },
      );

      return foundUsers.toList();
    } catch (e) {
      Log.error(
        'Failed to start search: $e',
        name: 'UserProfileService',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() => {
    'cachedProfiles': _profileCache.length,
    'pendingRequests': _pendingRequests.length,
    'activeSubscriptions': _activeSubscriptionIds.length,
    'managedSubscriptions': _activeSubscriptionIds.length,
    'isInitialized': _isInitialized,
  };

  /// Test helper method to process profile events directly
  /// Only for testing purposes
  void handleProfileEventForTesting(Event event) {
    _handleProfileEvent(event);
  }

  @override
  void dispose() {
    // Cancel batch operations
    _batchDebounceTimer?.cancel();
    _batchTimeout?.cancel();

    // Cancel batch subscription
    if (_batchSubscriptionId != null) {
      _subscriptionManager.cancelSubscription(_batchSubscriptionId!);
      _batchSubscriptionId = null;
    }

    // Cancel all active managed subscriptions
    for (final subscriptionId in _activeSubscriptionIds.values) {
      _subscriptionManager.cancelSubscription(subscriptionId);
    }
    _activeSubscriptionIds.clear();

    // Complete any pending fetch completers
    for (final completer in _profileFetchCompleters.values) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }
    _profileFetchCompleters.clear();

    // Dispose connection service to cancel its timer
    _connectionService.dispose();

    // Clean up remaining state
    _pendingRequests.clear();
    _profileCache.clear();
    _pendingBatchPubkeys.clear();
    _knownMissingProfiles.clear();
    _missingProfileRetryAfter.clear();

    Log.debug(
      '🗑️ UserProfileService disposed',
      name: 'UserProfileService',
      category: LogCategory.system,
    );

    // Call super.dispose() to properly clean up ChangeNotifier
    super.dispose();
  }
}

/// Exception thrown by user profile service operations
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class UserProfileServiceException implements Exception {
  const UserProfileServiceException(this.message);
  final String message;

  @override
  String toString() => 'UserProfileServiceException: $message';
}
