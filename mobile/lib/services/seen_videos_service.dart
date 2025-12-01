// ABOUTME: Service for tracking which videos have been viewed by the user with engagement metrics
// ABOUTME: Stores view history with timestamps, loop counts, and watch duration for smart feed ordering

import 'dart:async';
import 'dart:convert';

import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Engagement metrics for a seen video
class SeenVideoMetrics {
  SeenVideoMetrics({
    required this.videoId,
    required this.firstSeenAt,
    required this.lastSeenAt,
    this.loopCount = 0,
    this.totalWatchDuration = Duration.zero,
    this.lastWatchDuration = Duration.zero,
  });

  final String videoId;
  final DateTime firstSeenAt;
  DateTime lastSeenAt;
  int loopCount;
  Duration totalWatchDuration;
  Duration lastWatchDuration;

  /// Update metrics with new viewing session
  void updateSession({
    required DateTime timestamp,
    int? loops,
    Duration? watchDuration,
  }) {
    lastSeenAt = timestamp;
    if (loops != null) loopCount += loops;
    if (watchDuration != null) {
      lastWatchDuration = watchDuration;
      totalWatchDuration += watchDuration;
    }
  }

  Map<String, dynamic> toJson() => {
    'videoId': videoId,
    'firstSeenAt': firstSeenAt.millisecondsSinceEpoch,
    'lastSeenAt': lastSeenAt.millisecondsSinceEpoch,
    'loopCount': loopCount,
    'totalWatchDurationMs': totalWatchDuration.inMilliseconds,
    'lastWatchDurationMs': lastWatchDuration.inMilliseconds,
  };

  factory SeenVideoMetrics.fromJson(Map<String, dynamic> json) =>
      SeenVideoMetrics(
        videoId: json['videoId'] as String,
        firstSeenAt: DateTime.fromMillisecondsSinceEpoch(json['firstSeenAt']),
        lastSeenAt: DateTime.fromMillisecondsSinceEpoch(json['lastSeenAt']),
        loopCount: json['loopCount'] ?? 0,
        totalWatchDuration: Duration(
          milliseconds: json['totalWatchDurationMs'] ?? 0,
        ),
        lastWatchDuration: Duration(
          milliseconds: json['lastWatchDurationMs'] ?? 0,
        ),
      );
}

/// Service for tracking seen videos with engagement metrics
/// REFACTORED: Extended to store timestamps, loop counts, and watch duration
class SeenVideosService {
  static const String _seenVideosKey = 'seen_video_ids'; // Legacy key
  static const String _seenVideosMetricsKey = 'seen_video_metrics'; // New key
  static const int _maxSeenVideos =
      1000; // Limit storage to prevent unbounded growth

  final Map<String, SeenVideoMetrics> _seenVideos = {};
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  /// Whether the service has been initialized
  bool get isInitialized => _isInitialized;

  /// Get count of seen videos
  int get seenVideoCount => _seenVideos.length;

  /// Initialize the service and load seen videos from storage
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSeenVideos();
      _isInitialized = true;

      Log.info(
        '📱️ SeenVideosService initialized with ${_seenVideos.length} seen videos',
        name: 'SeenVideosService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to initialize SeenVideosService: $e',
        name: 'SeenVideosService',
        category: LogCategory.system,
      );
    }
  }

  /// Load seen videos from persistent storage with migration from legacy format
  Future<void> _loadSeenVideos() async {
    if (_prefs == null) return;

    try {
      // Try loading new format first
      final metricsJson = _prefs!.getString(_seenVideosMetricsKey);
      if (metricsJson != null) {
        final List<dynamic> metricsList = jsonDecode(metricsJson);
        _seenVideos.clear();
        for (final json in metricsList) {
          final metrics = SeenVideoMetrics.fromJson(json);
          _seenVideos[metrics.videoId] = metrics;
        }
        Log.debug(
          '📱 Loaded ${_seenVideos.length} seen videos with metrics',
          name: 'SeenVideosService',
          category: LogCategory.system,
        );
        return;
      }

      // Migrate from legacy format (Set<String> with no metrics)
      final legacyList = _prefs!.getStringList(_seenVideosKey);
      if (legacyList != null && legacyList.isNotEmpty) {
        _seenVideos.clear();
        final now = DateTime.now();
        for (final videoId in legacyList) {
          _seenVideos[videoId] = SeenVideoMetrics(
            videoId: videoId,
            firstSeenAt: now,
            lastSeenAt: now,
          );
        }
        Log.info(
          '📱 Migrated ${_seenVideos.length} videos from legacy format',
          name: 'SeenVideosService',
          category: LogCategory.system,
        );

        // Save in new format and remove legacy key
        await _saveSeenVideos();
        await _prefs!.remove(_seenVideosKey);
      }
    } catch (e) {
      Log.error(
        'Error loading seen videos: $e',
        name: 'SeenVideosService',
        category: LogCategory.system,
      );
    }
  }

  /// Save seen videos to persistent storage
  Future<void> _saveSeenVideos() async {
    if (_prefs == null) return;

    try {
      // Sort by lastSeenAt to keep most recent
      final sortedVideos = _seenVideos.values.toList()
        ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));

      // Limit size if needed (keep most recent)
      final videosToSave = sortedVideos.length > _maxSeenVideos
          ? sortedVideos.sublist(0, _maxSeenVideos)
          : sortedVideos;

      // Update in-memory map if we trimmed
      if (videosToSave.length < _seenVideos.length) {
        _seenVideos.clear();
        for (final metrics in videosToSave) {
          _seenVideos[metrics.videoId] = metrics;
        }
      }

      // Serialize to JSON
      final metricsList = videosToSave.map((m) => m.toJson()).toList();
      await _prefs!.setString(_seenVideosMetricsKey, jsonEncode(metricsList));

      Log.debug(
        '📱 Saved ${videosToSave.length} seen videos with metrics',
        name: 'SeenVideosService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error saving seen videos: $e',
        name: 'SeenVideosService',
        category: LogCategory.system,
      );
    }
  }

  /// Check if a video has been seen
  bool hasSeenVideo(String videoId) => _seenVideos.containsKey(videoId);

  /// Get all seen video IDs
  Set<String> getSeenVideoIds() => _seenVideos.keys.toSet();

  /// Get metrics for a specific video (null if never seen)
  SeenVideoMetrics? getVideoMetrics(String videoId) => _seenVideos[videoId];

  /// Mark a video as seen (simple version without metrics)
  Future<void> markVideoAsSeen(String videoId) async {
    await recordVideoView(videoId);
  }

  /// Record a video view with engagement metrics
  Future<void> recordVideoView(
    String videoId, {
    int? loopCount,
    Duration? watchDuration,
  }) async {
    final now = DateTime.now();
    final existing = _seenVideos[videoId];

    if (existing != null) {
      // Update existing metrics
      existing.updateSession(
        timestamp: now,
        loops: loopCount,
        watchDuration: watchDuration,
      );
      Log.debug(
        '📱 Updated video metrics: ${videoId.substring(0, videoId.length > 8 ? 8 : videoId.length)}... (loops: ${existing.loopCount}, watch: ${existing.totalWatchDuration.inSeconds}s)',
        name: 'SeenVideosService',
        category: LogCategory.system,
      );
    } else {
      // Create new metrics
      _seenVideos[videoId] = SeenVideoMetrics(
        videoId: videoId,
        firstSeenAt: now,
        lastSeenAt: now,
        loopCount: loopCount ?? 0,
        totalWatchDuration: watchDuration ?? Duration.zero,
        lastWatchDuration: watchDuration ?? Duration.zero,
      );
      Log.debug(
        '📱️ Marking video as seen: ${videoId.substring(0, videoId.length > 8 ? 8 : videoId.length)}...',
        name: 'SeenVideosService',
        category: LogCategory.system,
      );
    }

    // Save to storage asynchronously
    await _saveSeenVideos();
  }

  /// Mark multiple videos as seen (batch operation)
  Future<void> markVideosAsSeen(List<String> videoIds) async {
    var hasChanges = false;
    final now = DateTime.now();

    for (final videoId in videoIds) {
      if (!_seenVideos.containsKey(videoId)) {
        _seenVideos[videoId] = SeenVideoMetrics(
          videoId: videoId,
          firstSeenAt: now,
          lastSeenAt: now,
        );
        hasChanges = true;
      }
    }

    if (hasChanges) {
      await _saveSeenVideos();
    }
  }

  /// Get videos sorted by most recently seen
  List<SeenVideoMetrics> getVideosByRecency({int? limit}) {
    final sorted = _seenVideos.values.toList()
      ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
    return limit != null && limit < sorted.length
        ? sorted.sublist(0, limit)
        : sorted;
  }

  /// Get videos not seen within a time period (for "show fresh content")
  List<String> getVideosNotSeenSince(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    return _seenVideos.values
        .where((metrics) => metrics.lastSeenAt.isBefore(cutoff))
        .map((metrics) => metrics.videoId)
        .toList();
  }

  /// Check if video was seen recently
  bool wasSeenRecently(
    String videoId, {
    Duration within = const Duration(hours: 24),
  }) {
    final metrics = _seenVideos[videoId];
    if (metrics == null) return false;

    final cutoff = DateTime.now().subtract(within);
    return metrics.lastSeenAt.isAfter(cutoff);
  }

  /// Clear all seen videos (for testing or user preference)
  Future<void> clearSeenVideos() async {
    Log.debug(
      '📱️ Clearing all seen videos',
      name: 'SeenVideosService',
      category: LogCategory.system,
    );
    _seenVideos.clear();

    if (_prefs != null) {
      await _prefs!.remove(_seenVideosMetricsKey);
      await _prefs!.remove(_seenVideosKey); // Also remove legacy key
    }
  }

  /// Remove a specific video from seen list (mark as unseen)
  Future<void> markVideoAsUnseen(String videoId) async {
    if (!_seenVideos.containsKey(videoId)) {
      return; // Not in seen list
    }

    Log.debug(
      '📱️ Marking video as unseen: ${videoId.substring(0, videoId.length > 8 ? 8 : videoId.length)}...',
      name: 'SeenVideosService',
      category: LogCategory.system,
    );
    _seenVideos.remove(videoId);

    await _saveSeenVideos();
  }

  /// Get statistics about seen videos
  Map<String, dynamic> getStatistics() {
    final totalLoops = _seenVideos.values.fold<int>(
      0,
      (sum, metrics) => sum + metrics.loopCount,
    );
    final totalWatchTime = _seenVideos.values.fold<Duration>(
      Duration.zero,
      (sum, metrics) => sum + metrics.totalWatchDuration,
    );

    return {
      'totalSeen': _seenVideos.length,
      'storageLimit': _maxSeenVideos,
      'percentageFull': (_seenVideos.length / _maxSeenVideos * 100)
          .toStringAsFixed(1),
      'totalLoops': totalLoops,
      'totalWatchTimeMinutes': totalWatchTime.inMinutes,
      'averageLoopsPerVideo': _seenVideos.isEmpty
          ? 0
          : (totalLoops / _seenVideos.length).toStringAsFixed(1),
    };
  }

  void dispose() {
    // Save any pending changes before disposing
    _saveSeenVideos();
  }
}
