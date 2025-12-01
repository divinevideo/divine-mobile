// ABOUTME: Persistent cache service for hashtag statistics using Hive storage
// ABOUTME: Provides fast local storage and retrieval of trending hashtags with automatic updates

import 'package:hive_ce/hive.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service for persistent caching of hashtag statistics
class HashtagCacheService {
  static const String _boxName = 'hashtag_stats';
  static const String _popularHashtagsKey = 'popular_hashtags';
  static const String _lastUpdateKey = 'last_update';
  static const Duration _cacheExpiry = Duration(hours: 1); // Cache for 1 hour

  Box? _hashtagBox;
  bool _isInitialized = false;

  /// Check if the cache service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the hashtag cache
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Open the hashtag box
      _hashtagBox = await Hive.openBox(_boxName);
      _isInitialized = true;

      Log.info(
        'HashtagCacheService initialized',
        name: 'HashtagCacheService',
        category: LogCategory.storage,
      );
    } catch (e) {
      Log.error(
        'Failed to initialize HashtagCacheService: $e',
        name: 'HashtagCacheService',
        category: LogCategory.storage,
      );
      rethrow;
    }
  }

  /// Get cached popular hashtags sorted by video count
  List<String>? getCachedPopularHashtags() {
    if (!_isInitialized || _hashtagBox == null) return null;

    try {
      // Check if cache is expired
      final lastUpdate = _hashtagBox!.get(_lastUpdateKey) as DateTime?;
      if (lastUpdate == null ||
          DateTime.now().difference(lastUpdate) > _cacheExpiry) {
        Log.debug(
          'Hashtag cache expired or not found',
          name: 'HashtagCacheService',
          category: LogCategory.storage,
        );
        return null;
      }

      final cachedHashtags =
          _hashtagBox!.get(_popularHashtagsKey) as List<dynamic>?;
      if (cachedHashtags == null) return null;

      final hashtags = cachedHashtags.cast<String>().toList();
      Log.debug(
        'Retrieved ${hashtags.length} cached popular hashtags',
        name: 'HashtagCacheService',
        category: LogCategory.storage,
      );
      return hashtags;
    } catch (e) {
      Log.error(
        'Error retrieving cached hashtags: $e',
        name: 'HashtagCacheService',
        category: LogCategory.storage,
      );
      return null;
    }
  }

  /// Cache popular hashtags
  Future<void> cachePopularHashtags(List<String> hashtags) async {
    if (!_isInitialized || _hashtagBox == null) return;

    try {
      await _hashtagBox!.put(_popularHashtagsKey, hashtags);
      await _hashtagBox!.put(_lastUpdateKey, DateTime.now());

      Log.info(
        'Cached ${hashtags.length} popular hashtags',
        name: 'HashtagCacheService',
        category: LogCategory.storage,
      );
    } catch (e) {
      Log.error(
        'Error caching hashtags: $e',
        name: 'HashtagCacheService',
        category: LogCategory.storage,
      );
    }
  }

  /// Clear the hashtag cache
  Future<void> clearCache() async {
    if (!_isInitialized || _hashtagBox == null) return;

    try {
      await _hashtagBox!.clear();
      Log.info(
        'Hashtag cache cleared',
        name: 'HashtagCacheService',
        category: LogCategory.storage,
      );
    } catch (e) {
      Log.error(
        'Error clearing hashtag cache: $e',
        name: 'HashtagCacheService',
        category: LogCategory.storage,
      );
    }
  }

  /// Close the cache service
  Future<void> dispose() async {
    if (_hashtagBox != null) {
      await _hashtagBox!.close();
      _isInitialized = false;
    }
  }
}
