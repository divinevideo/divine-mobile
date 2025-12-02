// ABOUTME: Service for tracking and persisting broken video URLs
// ABOUTME: Prevents repeated display of videos with non-functional URLs

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/utils/unified_logger.dart';

class BrokenVideoTracker {
  static const String _storageKey = 'broken_video_urls';
  static const String _timestampKey = 'broken_video_timestamps';
  static const Duration _cleanupDuration = Duration(
    days: 7,
  ); // Clean up old entries after 7 days

  late SharedPreferences _prefs;
  Set<String> _brokenVideoIds = {};
  Map<String, DateTime> _brokenTimestamps = {};

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadBrokenVideos();
    await _cleanupOldEntries();

    Log.info(
      '🚫 BrokenVideoTracker initialized with ${_brokenVideoIds.length} broken videos',
      name: 'BrokenVideoTracker',
      category: LogCategory.system,
    );
  }

  Future<void> _loadBrokenVideos() async {
    try {
      final brokenVideosJson = _prefs.getString(_storageKey);
      final timestampsJson = _prefs.getString(_timestampKey);

      if (brokenVideosJson != null) {
        final brokenList = List<String>.from(jsonDecode(brokenVideosJson));
        _brokenVideoIds = Set<String>.from(brokenList);
      }

      if (timestampsJson != null) {
        final timestampMap = Map<String, dynamic>.from(
          jsonDecode(timestampsJson),
        );
        _brokenTimestamps = timestampMap.map(
          (key, value) =>
              MapEntry(key, DateTime.fromMillisecondsSinceEpoch(value)),
        );
      }
    } catch (e) {
      Log.error(
        'Failed to load broken videos from storage: $e',
        name: 'BrokenVideoTracker',
        category: LogCategory.system,
      );
      _brokenVideoIds = {};
      _brokenTimestamps = {};
    }
  }

  Future<void> _saveBrokenVideos() async {
    try {
      final brokenList = _brokenVideoIds.toList();
      final timestampMap = _brokenTimestamps.map(
        (key, value) => MapEntry(key, value.millisecondsSinceEpoch),
      );

      await _prefs.setString(_storageKey, jsonEncode(brokenList));
      await _prefs.setString(_timestampKey, jsonEncode(timestampMap));
    } catch (e) {
      Log.error(
        'Failed to save broken videos to storage: $e',
        name: 'BrokenVideoTracker',
        category: LogCategory.system,
      );
    }
  }

  Future<void> _cleanupOldEntries() async {
    final now = DateTime.now();
    final cutoff = now.subtract(_cleanupDuration);

    final toRemove = <String>[];
    for (final entry in _brokenTimestamps.entries) {
      if (entry.value.isBefore(cutoff)) {
        toRemove.add(entry.key);
      }
    }

    for (final videoId in toRemove) {
      _brokenVideoIds.remove(videoId);
      _brokenTimestamps.remove(videoId);
    }

    if (toRemove.isNotEmpty) {
      await _saveBrokenVideos();
      Log.info(
        '🧹 Cleaned up ${toRemove.length} old broken video entries',
        name: 'BrokenVideoTracker',
        category: LogCategory.system,
      );
    }
  }

  /// Mark a video as broken (non-functional URLs)
  Future<void> markVideoBroken(String videoId, String reason) async {
    if (!_brokenVideoIds.contains(videoId)) {
      _brokenVideoIds.add(videoId);
      _brokenTimestamps[videoId] = DateTime.now();

      await _saveBrokenVideos();

      Log.warning(
        '🚫 Marked video as broken: ${videoId}... (reason: $reason)',
        name: 'BrokenVideoTracker',
        category: LogCategory.system,
      );
    }
  }

  /// Check if a video is known to be broken
  bool isVideoBroken(String videoId) {
    return _brokenVideoIds.contains(videoId);
  }

  /// Remove a video from broken list (for retry or recovery)
  Future<void> unmarkVideoBroken(String videoId) async {
    if (_brokenVideoIds.remove(videoId)) {
      _brokenTimestamps.remove(videoId);
      await _saveBrokenVideos();

      Log.info(
        '✅ Unmarked video as broken: ${videoId}...',
        name: 'BrokenVideoTracker',
        category: LogCategory.system,
      );
    }
  }

  /// Get count of broken videos
  int get brokenVideoCount => _brokenVideoIds.length;

  /// Get all broken video IDs (for debugging)
  List<String> get brokenVideoIds => _brokenVideoIds.toList();

  /// Clear all broken video records
  Future<void> clearAll() async {
    _brokenVideoIds.clear();
    _brokenTimestamps.clear();
    await _saveBrokenVideos();

    Log.info(
      '🧹 Cleared all broken video records',
      name: 'BrokenVideoTracker',
      category: LogCategory.system,
    );
  }
}

// Riverpod provider for BrokenVideoTracker
final brokenVideoTrackerProvider = Provider<BrokenVideoTracker>((ref) {
  return BrokenVideoTracker();
});
