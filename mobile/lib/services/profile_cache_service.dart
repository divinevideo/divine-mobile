// ABOUTME: Persistent cache service for user profiles using Hive storage
// ABOUTME: Provides fast local storage and retrieval of Nostr user profiles with automatic cleanup

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service for persistent caching of user profiles
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class ProfileCacheService {
  static const String _boxName = 'user_profiles';
  // Removed cache size limits - Kind 0 events are small, cache everything
  static const Duration _cacheExpiry = Duration(
    days: 365,
  ); // Cache profiles for 1 year - they rarely change
  static const Duration _refreshInterval = Duration(
    days: 7,
  ); // Check for updates after 7 days

  Box<UserProfile>? _profileBox;
  Box<DateTime>? _fetchTimestamps; // Track when each profile was last fetched
  bool _isInitialized = false;

  /// Check if the cache service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the profile cache
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Register the UserProfile adapter if not already registered
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(UserProfileAdapter());
      }

      // Open the profiles box
      _profileBox = await Hive.openBox<UserProfile>(_boxName);

      // Open the timestamps box
      _fetchTimestamps = await Hive.openBox<DateTime>(
        'profile_fetch_timestamps',
      );

      _isInitialized = true;

      Log.info(
        'ProfileCacheService initialized with ${_profileBox!.length} cached profiles',
        name: 'ProfileCacheService',
        category: LogCategory.storage,
      );

      // Clean up old profiles on startup
      await _cleanupExpiredProfiles();
    } catch (e) {
      Log.error(
        'Failed to initialize ProfileCacheService: $e',
        name: 'ProfileCacheService',
        category: LogCategory.storage,
      );
      rethrow;
    }
  }

  /// Get a cached profile by pubkey
  UserProfile? getCachedProfile(String pubkey) {
    if (!_isInitialized || _profileBox == null) return null;

    try {
      final profile = _profileBox!.get(pubkey);

      if (profile == null) return null;

      // Check when this profile was last fetched
      final lastFetched = _fetchTimestamps?.get(pubkey);

      // If we have no fetch timestamp or it's older than 7 days, consider it expired
      if (lastFetched == null ||
          DateTime.now().difference(lastFetched) > _cacheExpiry) {
        debugPrint(
          '🗑️ Removing expired profile for ${pubkey}... (last fetched: ${lastFetched ?? 'never'})',
        );
        _profileBox!.delete(pubkey);
        _fetchTimestamps?.delete(pubkey);
        return null;
      }

      Log.debug(
        '📱 Retrieved cached profile for ${pubkey}... (${profile.bestDisplayName})',
        name: 'ProfileCacheService',
        category: LogCategory.storage,
      );
      return profile;
    } catch (e) {
      Log.error(
        'Error retrieving cached profile for $pubkey: $e',
        name: 'ProfileCacheService',
        category: LogCategory.storage,
      );
      return null;
    }
  }

  /// Check if a profile should be refreshed (soft expiry)
  bool shouldRefreshProfile(String pubkey) {
    if (!_isInitialized || _fetchTimestamps == null) return true;

    final lastFetched = _fetchTimestamps!.get(pubkey);
    if (lastFetched == null) return true;

    return DateTime.now().difference(lastFetched) > _refreshInterval;
  }

  /// Cache a profile
  Future<void> cacheProfile(UserProfile profile) async {
    if (!_isInitialized || _profileBox == null) {
      Log.warning(
        'ProfileCacheService not initialized, cannot cache profile',
        name: 'ProfileCacheService',
        category: LogCategory.storage,
      );
      return;
    }

    try {
      // No cache size limits - Kind 0 events are small, cache everything

      await _profileBox!.put(profile.pubkey, profile);

      // Track when this profile was fetched
      await _fetchTimestamps?.put(profile.pubkey, DateTime.now());

      Log.debug(
        '📱 Cached profile for ${profile.pubkey}... (${profile.bestDisplayName})',
        name: 'ProfileCacheService',
        category: LogCategory.storage,
      );
    } catch (e) {
      Log.error(
        'Error caching profile for ${profile.pubkey}: $e',
        name: 'ProfileCacheService',
        category: LogCategory.storage,
      );
    }
  }

  /// Update an existing cached profile
  Future<void> updateCachedProfile(UserProfile profile) async {
    if (!_isInitialized || _profileBox == null) return;

    try {
      final existing = _profileBox!.get(profile.pubkey);

      // Only update if the new profile is newer
      if (existing == null || profile.createdAt.isAfter(existing.createdAt)) {
        await _profileBox!.put(profile.pubkey, profile);
        Log.debug(
          'Updated cached profile for ${profile.pubkey}... (${profile.bestDisplayName})',
          name: 'ProfileCacheService',
          category: LogCategory.storage,
        );
      } else {
        Log.warning(
          '⏩ Skipping update for ${profile.pubkey}... - cached version is newer',
          name: 'ProfileCacheService',
          category: LogCategory.storage,
        );
      }
    } catch (e) {
      Log.error(
        'Error updating cached profile for ${profile.pubkey}: $e',
        name: 'ProfileCacheService',
        category: LogCategory.storage,
      );
    }
  }

  /// Remove a profile from cache
  Future<void> removeCachedProfile(String pubkey) async {
    if (!_isInitialized || _profileBox == null) return;

    try {
      await _profileBox!.delete(pubkey);
      Log.debug(
        '📱️ Removed cached profile for ${pubkey}...',
        name: 'ProfileCacheService',
        category: LogCategory.storage,
      );
    } catch (e) {
      Log.error(
        'Error removing cached profile for $pubkey: $e',
        name: 'ProfileCacheService',
        category: LogCategory.storage,
      );
    }
  }

  /// Get all cached pubkeys
  List<String> getCachedPubkeys() {
    if (!_isInitialized || _profileBox == null) return [];
    return _profileBox!.keys.cast<String>().toList();
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    if (!_isInitialized || _profileBox == null) {
      return {'isInitialized': false, 'totalProfiles': 0, 'expiredProfiles': 0};
    }

    final allProfiles = _profileBox!.values.toList();
    final expiredCount = allProfiles.where(_isProfileExpired).length;

    return {
      'isInitialized': true,
      'totalProfiles': allProfiles.length,
      'expiredProfiles': expiredCount,
      'cacheHitRate': 0.0, // TODO: Track hit rate
    };
  }

  /// Clear all cached profiles
  Future<void> clearCache() async {
    if (!_isInitialized || _profileBox == null) return;

    try {
      await _profileBox!.clear();
      Log.debug(
        '📱️ Cleared all cached profiles',
        name: 'ProfileCacheService',
        category: LogCategory.storage,
      );
    } catch (e) {
      Log.error(
        'Error clearing profile cache: $e',
        name: 'ProfileCacheService',
        category: LogCategory.storage,
      );
    }
  }

  /// Check if a profile is expired based on fetch timestamp
  bool _isProfileExpired(UserProfile profile) {
    if (_fetchTimestamps == null) return true;

    final lastFetched = _fetchTimestamps!.get(profile.pubkey);
    if (lastFetched == null) return true;

    return DateTime.now().difference(lastFetched) > _cacheExpiry;
  }

  /// Clean up expired profiles
  Future<void> _cleanupExpiredProfiles() async {
    if (!_isInitialized || _profileBox == null) return;

    try {
      final expiredKeys = <String>[];

      for (final entry in _profileBox!.toMap().entries) {
        if (_isProfileExpired(entry.value)) {
          expiredKeys.add(entry.key);
        }
      }

      if (expiredKeys.isNotEmpty) {
        for (final key in expiredKeys) {
          await _profileBox!.delete(key);
        }
        Log.debug(
          '📱️ Cleaned up ${expiredKeys.length} expired profiles',
          name: 'ProfileCacheService',
          category: LogCategory.storage,
        );
      }
    } catch (e) {
      Log.error(
        'Error cleaning up expired profiles: $e',
        name: 'ProfileCacheService',
        category: LogCategory.storage,
      );
    }
  }

  void dispose() {
    _profileBox?.close();
  }
}
