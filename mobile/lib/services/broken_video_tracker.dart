// ABOUTME: Service for tracking and persisting broken video URLs
// ABOUTME: Prevents repeated display of videos with non-functional URLs

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

class BrokenVideoTracker {
  BrokenVideoTracker({String? ownerPubkey})
    : _storageKey = _scopedKey('broken_video_urls', ownerPubkey),
      _timestampKey = _scopedKey('broken_video_timestamps', ownerPubkey);

  static const Duration _cleanupDuration = Duration(
    days: 7,
  ); // Clean up old entries after 7 days

  final String _storageKey;
  final String _timestampKey;
  late SharedPreferences _prefs;
  Set<String> _brokenVideoIds = {};
  Map<String, DateTime> _brokenTimestamps = {};
  final StreamController<String> _markedVideoIdsController =
      StreamController<String>.broadcast();

  static String _scopedKey(String baseKey, String? ownerPubkey) {
    final scope = ownerPubkey == null || ownerPubkey.isEmpty
        ? 'anonymous'
        : ownerPubkey;
    return '${baseKey}_$scope';
  }

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _dropLegacyUnscopedEntries();
    await _loadBrokenVideos();
    await _cleanupOldEntries();

    Log.info(
      '🚫 BrokenVideoTracker initialized with ${_brokenVideoIds.length} broken videos',
      name: 'BrokenVideoTracker',
      category: LogCategory.system,
    );
  }

  /// Pre-#6251 marks were stored under unscoped keys that no scope reads and
  /// the 7-day sweep never visits, so they would sit in storage forever. Those
  /// marks are already unreachable — dropping them reclaims the bytes without
  /// changing what is filtered.
  Future<void> _dropLegacyUnscopedEntries() async {
    for (final key in const ['broken_video_urls', 'broken_video_timestamps']) {
      if (_prefs.containsKey(key)) {
        await _prefs.remove(key);
      }
    }
  }

  Future<void> _loadBrokenVideos() async {
    try {
      final brokenVideosJson = _prefs.getString(_storageKey);
      final timestampsJson = _prefs.getString(_timestampKey);

      if (brokenVideosJson != null) {
        final brokenList = List<String>.from(
          jsonDecode(brokenVideosJson) as Iterable,
        );
        _brokenVideoIds = Set<String>.from(brokenList);
      }

      if (timestampsJson != null) {
        final timestampMap = Map<String, dynamic>.from(
          jsonDecode(timestampsJson) as Map,
        );
        _brokenTimestamps = timestampMap.map(
          (key, value) =>
              MapEntry(key, DateTime.fromMillisecondsSinceEpoch(value as int)),
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
      _markedVideoIdsController.add(videoId);

      await _saveBrokenVideos();

      Log.warning(
        '🚫 Marked video as broken: $videoId (reason: $reason)',
        name: 'BrokenVideoTracker',
        category: LogCategory.system,
      );
    }
  }

  /// Each id as it is newly marked, so a feed already showing it can drop it.
  Stream<String> get markedVideoIds => _markedVideoIdsController.stream;

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
        '✅ Unmarked video as broken: $videoId',
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
