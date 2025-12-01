// ABOUTME: Caching service for video events with priority-based insertion and deduplication
// ABOUTME: Extracted from VideoEventService to follow single responsibility principle

import 'dart:math';

import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service responsible for caching and managing video events in memory
///
/// This service handles:
/// - Priority-based video insertion (Classic Vines > Regular)
/// - Duplicate detection and prevention
/// - Query operations by author, hashtags, etc.
/// - Cache management and clearing
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class VideoCacheService {
  final List<VideoEvent> _videoEvents = [];
  int _duplicateVideoEventCount = 0;
  DateTime? _lastDuplicateVideoLogTime;

  /// Get all cached videos (read-only)
  List<VideoEvent> get cachedVideos => List.unmodifiable(_videoEvents);

  /// Get current cache size
  int get cacheSize => _videoEvents.length;

  /// Get count of duplicate attempts
  int get duplicateCount => _duplicateVideoEventCount;

  /// Add a single video to cache with priority-based insertion
  void addVideo(VideoEvent videoEvent) {
    // Check for duplicates - CRITICAL to prevent the same event being added multiple times
    final existingIndex = _videoEvents.indexWhere(
      (existing) => existing.id == videoEvent.id,
    );
    if (existingIndex != -1) {
      _duplicateVideoEventCount++;
      _logDuplicateVideoEventsAggregated();
      return; // Don't add duplicate events
    }

    // Classic Vines account has HIGHEST priority
    final isClassicVine = videoEvent.pubkey == AppConstants.classicVinesPubkey;

    // Priority order: 1) Classic Vines, 2) Everything else
    if (isClassicVine) {
      // Classic vine - keep at the very top but randomize their order
      var insertIndex = 0;
      var classicVineEndIndex = 0;

      // Find the range of classic vines
      for (var i = 0; i < _videoEvents.length; i++) {
        if (_videoEvents[i].pubkey == AppConstants.classicVinesPubkey) {
          classicVineEndIndex = i + 1;
        } else {
          break;
        }
      }

      // Insert at a random position within the classic vines section
      if (classicVineEndIndex > 0) {
        insertIndex = Random().nextInt(classicVineEndIndex + 1);
      }

      _videoEvents.insert(insertIndex, videoEvent);
      Log.verbose(
        'Added CLASSIC VINE at random position $insertIndex: ${videoEvent.title ?? videoEvent.id}',
        name: 'VideoCacheService',
        category: LogCategory.video,
      );
    } else {
      // Regular video - add to the end
      _videoEvents.add(videoEvent);
      Log.verbose(
        'Added regular video to cache: ${videoEvent.title ?? videoEvent.id}',
        name: 'VideoCacheService',
        category: LogCategory.video,
      );
    }
  }

  /// Add multiple videos to cache
  void addVideos(List<VideoEvent> videos) {
    for (final video in videos) {
      addVideo(video);
    }
  }

  /// Get video by ID
  VideoEvent? getVideoById(String id) {
    try {
      return _videoEvents.firstWhere((event) => event.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get videos by author
  List<VideoEvent> getVideosByAuthor(String pubkey) =>
      _videoEvents.where((event) => event.pubkey == pubkey).toList();

  /// Get videos by hashtags (any match)
  List<VideoEvent> getVideosByHashtags(List<String> hashtags) => _videoEvents
      .where((event) => hashtags.any((tag) => event.hashtags.contains(tag)))
      .toList();

  /// Get video by vine ID (d tag)
  VideoEvent? getVideoByVineId(String vineId) {
    try {
      return _videoEvents.firstWhere((event) => event.vineId == vineId);
    } catch (e) {
      return null;
    }
  }

  /// Check if video exists in cache
  bool containsVideo(String id) => _videoEvents.any((event) => event.id == id);

  /// Clear all cached videos
  void clearCache() {
    _videoEvents.clear();
    _duplicateVideoEventCount = 0;
    _lastDuplicateVideoLogTime = null;
  }

  /// Remove a specific video from cache
  void removeVideo(String id) {
    _videoEvents.removeWhere((event) => event.id == id);
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    final classicVineCount = _videoEvents
        .where((v) => v.pubkey == AppConstants.classicVinesPubkey)
        .length;
    return {
      'totalVideos': _videoEvents.length,
      'classicVines': classicVineCount,
      'regularVideos': _videoEvents.length - classicVineCount,
      'duplicateAttempts': _duplicateVideoEventCount,
    };
  }

  /// Log duplicate video events in an aggregated manner
  void _logDuplicateVideoEventsAggregated() {
    final now = DateTime.now();

    // Log every 10 seconds or every 10 duplicates
    if (_lastDuplicateVideoLogTime == null ||
        now.difference(_lastDuplicateVideoLogTime!).inSeconds > 10 ||
        _duplicateVideoEventCount % 10 == 0) {
      Log.verbose(
        'Duplicate video events detected: $_duplicateVideoEventCount total',
        name: 'VideoCacheService',
        category: LogCategory.video,
      );
      _lastDuplicateVideoLogTime = now;
    }
  }
}
