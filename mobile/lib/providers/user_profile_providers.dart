// ABOUTME: Riverpod providers for user profile service with reactive state management
// ABOUTME: Pure @riverpod functions for user profile management and caching

import 'dart:async';

import 'package:openvine/models/user_profile.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/state/user_profile_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:openvine/providers/tab_visibility_provider.dart';

part 'user_profile_providers.g.dart';

// Helper function for safe pubkey truncation in logs
String _safePubkeyTrunc(String pubkey) => pubkey.length > 8 ? pubkey : pubkey;

/// Async provider for loading a single user profile
/// Delegates to UserProfileService which is the single source of truth
@riverpod
Future<UserProfile?> fetchUserProfile(Ref ref, String pubkey) async {
  // Use UserProfileService as single source of truth
  final userProfileService = ref.watch(userProfileServiceProvider);

  // Check if already cached or should skip
  final cached = userProfileService.getCachedProfile(pubkey);
  if (cached != null) {
    Log.debug(
      '✅ Found cached profile: ${cached.bestDisplayName}',
      name: 'UserProfileProvider',
      category: LogCategory.ui,
    );
    return cached;
  }

  if (userProfileService.shouldSkipProfileFetch(pubkey)) {
    Log.debug(
      'Skipping fetch for known missing profile: ${_safePubkeyTrunc(pubkey)}...',
      name: 'UserProfileProvider',
      category: LogCategory.ui,
    );
    return null;
  }

  Log.debug(
    '🔍 Loading profile for: ${_safePubkeyTrunc(pubkey)}...',
    name: 'UserProfileProvider',
    category: LogCategory.ui,
  );

  try {
    final profile = await userProfileService.fetchProfile(pubkey);

    if (profile != null) {
      Log.info(
        '✅ Fetched profile for ${_safePubkeyTrunc(pubkey)}: ${profile.bestDisplayName}',
        name: 'UserProfileProvider',
        category: LogCategory.ui,
      );
    }

    return profile;
  } catch (e) {
    Log.error(
      'Error loading profile: $e',
      name: 'UserProfileProvider',
      category: LogCategory.ui,
    );
    return null;
  }
}

// User profile state notifier with reactive state management
@riverpod
class UserProfileNotifier extends _$UserProfileNotifier {
  // UserProfileService handles all subscription management
  Timer? _batchDebounceTimer;

  @override
  UserProfileState build() {
    // Keep this provider alive to avoid repeated init/dispose thrash when accessed via ref.read
    // (AutoDispose is default for @riverpod; keep it alive explicitly.)
    // This prevents log spam like "User profile notifier initialized" on every rebuild.
    // ignore: unused_local_variable
    final keepAliveLink = ref.keepAlive();
    ref.onDispose(() {
      _batchDebounceTimer?.cancel();
    });

    return UserProfileState.initial;
  }

  /// Initialize the profile service
  Future<void> initialize() async {
    if (state.isInitialized) return;

    Log.verbose(
      'Initializing user profile notifier...',
      name: 'UserProfileNotifier',
      category: LogCategory.system,
    );

    final nostrService = ref.read(nostrServiceProvider);

    if (!nostrService.isInitialized) {
      Log.warning(
        'Nostr service not initialized, profile notifier will wait',
        name: 'UserProfileNotifier',
        category: LogCategory.system,
      );
      return;
    }

    state = state.copyWith(isInitialized: true);
    Log.info(
      'User profile notifier initialized',
      name: 'UserProfileNotifier',
      category: LogCategory.system,
    );
  }

  /// Get cached profile for a user
  /// Delegates to UserProfileService as single source of truth
  UserProfile? getCachedProfile(String pubkey) {
    final userProfileService = ref.read(userProfileServiceProvider);
    return userProfileService.getCachedProfile(pubkey);
  }

  /// Update a cached profile
  /// Delegates to UserProfileService which will notify listeners
  Future<void> updateCachedProfile(UserProfile profile) async {
    final userProfileService = ref.read(userProfileServiceProvider);
    await userProfileService.updateCachedProfile(profile);

    Log.debug(
      'Updated cached profile for ${_safePubkeyTrunc(profile.pubkey)}: ${profile.bestDisplayName}',
      name: 'UserProfileNotifier',
      category: LogCategory.system,
    );
  }

  /// Fetch profile for a specific user
  /// Delegates to UserProfileService as single source of truth
  Future<UserProfile?> fetchProfile(
    String pubkey, {
    bool forceRefresh = false,
  }) async {
    if (!state.isInitialized) {
      await initialize();
    }

    // Check if already requesting
    if (state.isRequestPending(pubkey)) {
      Log.warning(
        '⏳ Profile request already pending for ${_safePubkeyTrunc(pubkey)}...',
        name: 'UserProfileNotifier',
        category: LogCategory.system,
      );
      return null;
    }

    try {
      // Mark as pending
      state = state.copyWith(
        pendingRequests: {...state.pendingRequests, pubkey},
        isLoading: true,
        totalProfilesRequested: state.totalProfilesRequested + 1,
      );

      // Delegate to UserProfileService
      final userProfileService = ref.read(userProfileServiceProvider);
      final profile = await userProfileService.fetchProfile(
        pubkey,
        forceRefresh: forceRefresh,
      );

      return profile;
    } finally {
      // Remove from pending
      final newPending = {...state.pendingRequests}..remove(pubkey);
      state = state.copyWith(
        pendingRequests: newPending,
        isLoading: newPending.isEmpty && state.pendingBatchPubkeys.isEmpty,
      );
    }
  }

  /// Aggressively pre-fetch profiles for immediate display (no debouncing)
  /// Delegates to UserProfileService which handles all caching
  Future<void> prefetchProfilesImmediately(List<String> pubkeys) async {
    // Only prefetch when a relevant UI tab is active to avoid background churn
    final isFeedActive = ref.read(isFeedTabActiveProvider);
    final isExploreActive = ref.read(isExploreTabActiveProvider);
    final isProfileActive = ref.read(isProfileTabActiveProvider);
    if (!(isFeedActive || isExploreActive || isProfileActive)) {
      Log.info(
        '🚫 Prefetch suppressed: Feed=$isFeedActive, Explore=$isExploreActive, Profile=$isProfileActive',
        name: 'UserProfileNotifier',
        category: LogCategory.system,
      );
      return;
    }

    Log.info(
      '✅ Prefetch allowed: Feed=$isFeedActive, Explore=$isExploreActive, Profile=$isProfileActive',
      name: 'UserProfileNotifier',
      category: LogCategory.system,
    );

    if (!state.isInitialized) {
      await initialize();
    }

    // Delegate to UserProfileService for prefetch
    final userProfileService = ref.read(userProfileServiceProvider);
    await userProfileService.prefetchProfilesImmediately(pubkeys);

    Log.debug(
      '⚡ Prefetch request sent to UserProfileService',
      name: 'UserProfileNotifier',
      category: LogCategory.system,
    );
  }

  /// Fetch multiple profiles with batching
  /// Delegates to UserProfileService which handles all caching and batching
  Future<void> fetchMultipleProfiles(
    List<String> pubkeys, {
    bool forceRefresh = false,
  }) async {
    if (!state.isInitialized) {
      await initialize();
    }

    Log.info(
      '📋 Batch fetching ${pubkeys.length} profiles',
      name: 'UserProfileNotifier',
      category: LogCategory.system,
    );

    // Delegate to UserProfileService for batch fetch
    final userProfileService = ref.read(userProfileServiceProvider);
    await userProfileService.fetchMultipleProfiles(
      pubkeys,
      forceRefresh: forceRefresh,
    );
  }

  /// Mark a profile as missing to avoid spam
  /// Delegates to UserProfileService which tracks missing profiles
  void markProfileAsMissing(String pubkey) {
    final userProfileService = ref.read(userProfileServiceProvider);
    userProfileService.markProfileAsMissing(pubkey);

    Log.debug(
      'Marked profile as missing: ${_safePubkeyTrunc(pubkey)}... (retry after 10 minutes)',
      name: 'UserProfileNotifier',
      category: LogCategory.system,
    );
  }

  /// Check if we have a cached profile
  /// Delegates to UserProfileService as single source of truth
  bool hasProfile(String pubkey) {
    final userProfileService = ref.read(userProfileServiceProvider);
    return userProfileService.hasProfile(pubkey);
  }
}
