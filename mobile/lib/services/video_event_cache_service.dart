// ABOUTME: Manages in-memory caching of video events with priority-based ordering
// ABOUTME: Extracted from VideoEventService to follow Single Responsibility Principle

import 'dart:math';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service responsible for caching and managing video events in memory
///
/// Handles:
/// - Priority-based insertion (Classic Vines > Default Content > Regular)
/// - Duplicate prevention
/// - Memory management (500 video limit)
/// - Cache queries by author
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class VideoEventCacheService {
  final List<VideoEvent> _videoEvents = [];
  int _duplicateVideoEventCount = 0;

  static const int _maxCacheSize = 500;

  /// Get all video events as an unmodifiable list
  List<VideoEvent> get videoEvents => List.unmodifiable(_videoEvents);

  /// Check if there are any events in the cache
  bool get hasEvents => _videoEvents.isNotEmpty;

  /// Get the total number of events in the cache
  int get eventCount => _videoEvents.length;

  /// Get the count of duplicate events that were rejected
  int getDuplicateCount() => _duplicateVideoEventCount;

  /// Check if a video exists in the cache
  bool hasVideo(String videoId) =>
      _videoEvents.any((video) => video.id == videoId);

  /// Get videos by a specific author from the cache
  List<VideoEvent> getVideosByAuthor(String pubkey) =>
      _videoEvents.where((video) => video.pubkey == pubkey).toList();

  /// Add a video to the cache with priority-based ordering
  void addVideo(VideoEvent videoEvent) {
    _addVideoWithPriority(videoEvent);
    _trimCacheIfNeeded();
  }

  /// Clear all videos from the cache
  void clear() {
    _videoEvents.clear();
    _duplicateVideoEventCount = 0;
  }

  /// Add default videos if cache is empty or ensure they're prioritized
  void addDefaultVideosIfNeeded(List<VideoEvent> defaultVideos) {
    if (_videoEvents.isEmpty) {
      // No videos at all - add default videos as initial content
      Log.debug(
        'Adding default content for empty cache...',
        name: 'VideoEventCacheService',
        category: LogCategory.video,
      );

      for (final video in defaultVideos) {
        _videoEvents.add(video);
        Log.info(
          'Added default video: ${video.title ?? video.id}',
          name: 'VideoEventCacheService',
          category: LogCategory.video,
        );
      }
    } else {
      // We have videos - ensure default videos are present with correct priority
      final defaultVideoIds = defaultVideos.map((v) => v.id).toSet();
      final hasDefaultVideo = _videoEvents.any(
        (v) => defaultVideoIds.contains(v.id),
      );

      if (!hasDefaultVideo) {
        Log.debug(
          'Ensuring default videos appear with correct priority...',
          name: 'VideoEventCacheService',
          category: LogCategory.video,
        );

        // Add default videos with priority ordering
        defaultVideos.forEach(_addVideoWithPriority);

        _trimCacheIfNeeded();
      }
    }
  }

  /// Internal method to add video with priority-based ordering
  void _addVideoWithPriority(VideoEvent videoEvent) {
    // Check for duplicates
    final existingIndex = _videoEvents.indexWhere(
      (existing) => existing.id == videoEvent.id,
    );
    if (existingIndex != -1) {
      _duplicateVideoEventCount++;
      Log.verbose(
        'Duplicate video event detected: ${videoEvent.id}',
        name: 'VideoEventCacheService',
        category: LogCategory.video,
      );
      return;
    }

    // Determine video priority
    final isClassicVine = videoEvent.pubkey == AppConstants.classicVinesPubkey;

    // Priority order: 1) Classic Vines, 2) Everything else by timestamp
    if (isClassicVine) {
      _insertClassicVine(videoEvent);
    } else {
      _insertRegularVideo(videoEvent);
    }
  }

  void _insertClassicVine(VideoEvent videoEvent) {
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
      'Added CLASSIC VINE at position $insertIndex: ${videoEvent.title ?? videoEvent.id}',
      name: 'VideoEventCacheService',
      category: LogCategory.video,
    );
  }

  void _insertRegularVideo(VideoEvent videoEvent) {
    // Regular video - insert after classic vines
    var insertIndex = 0;

    // Skip past classic vines only
    for (var i = 0; i < _videoEvents.length; i++) {
      if (_videoEvents[i].pubkey == AppConstants.classicVinesPubkey) {
        insertIndex = i + 1;
      } else {
        // Found first regular video, insert here by timestamp
        break;
      }
    }

    // Insert at the calculated position (newest first among regular videos)
    if (insertIndex < _videoEvents.length) {
      _videoEvents.insert(insertIndex, videoEvent);
    } else {
      _videoEvents.add(videoEvent);
    }

    Log.verbose(
      'Added REGULAR VIDEO at position $insertIndex: ${videoEvent.title ?? videoEvent.id}',
      name: 'VideoEventCacheService',
      category: LogCategory.video,
    );
  }

  /// Trim cache to prevent memory issues while preserving priority content
  void _trimCacheIfNeeded() {
    if (_videoEvents.length > _maxCacheSize) {
      // Remove oldest regular videos first, preserving priority content
      final toRemove = _videoEvents.length - _maxCacheSize;
      _videoEvents.removeRange(_maxCacheSize, _videoEvents.length);

      Log.info(
        'Trimmed cache: removed $toRemove videos, keeping $_maxCacheSize',
        name: 'VideoEventCacheService',
        category: LogCategory.video,
      );
    }
  }
}
