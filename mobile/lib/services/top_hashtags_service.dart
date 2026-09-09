// ABOUTME: Service for loading and managing current popular hashtags from JSON.
// ABOUTME: Provides popular hashtag suggestions for discovery and exploration.

import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:unified_logger/unified_logger.dart';

/// Minimal seam for loading hashtag suggestions.
abstract interface class TopHashtagsLoader {
  /// Loads the top hashtag data used by explore surfaces.
  Future<void> loadTopHashtags();
}

class HashtagData {
  HashtagData({
    required this.rank,
    required this.hashtag,
    required this.count,
    required this.percentage,
  });

  factory HashtagData.fromJson(Map<String, dynamic> json) {
    return HashtagData(
      rank: json['rank'] as int,
      hashtag: json['hashtag'] as String,
      count: json['count'] as int,
      percentage: (json['percentage'] as num).toDouble(),
    );
  }

  final int rank;
  final String hashtag;
  final int count;
  final double percentage;
}

class TopHashtagsService implements TopHashtagsLoader {
  TopHashtagsService() : _loadAssetString = rootBundle.loadString;

  @visibleForTesting
  TopHashtagsService.forTesting({
    required Future<String> Function(String key) loadAssetString,
  }) : _loadAssetString = loadAssetString;

  /// Default fallback hashtags shown when loading fails or is slow.
  /// These mirror the top current suggestions from the bundled JSON asset.
  static const List<String> defaultHashtags = [
    'funny',
    'comedy',
    'lol',
    'viral',
    'fyp',
    'warsaw',
    'poland',
    'humor',
    'traveltelly',
    'skit',
    'trending',
    'travel',
    'art',
    'popular',
    'lnic',
    'music',
    'europe',
    'dog',
    'latenightinsomniacsclub',
    'sitcom',
  ];

  List<HashtagData>? _topHashtags;
  bool _isLoaded = false;
  final Future<String> Function(String key) _loadAssetString;

  /// Get top hashtags (returns empty list if not loaded)
  List<HashtagData> get topHashtags => _topHashtags ?? [];

  /// Check if hashtags are loaded
  bool get isLoaded => _isLoaded;

  /// Load top hashtags from JSON file
  @override
  Future<void> loadTopHashtags() async {
    if (_isLoaded) {
      Log.debug(
        'Hashtags already loaded, skipping',
        name: 'TopHashtagsService',
        category: LogCategory.storage,
      );
      return;
    }

    try {
      Log.info(
        '🏷️ Loading current popular hashtags from JSON file',
        name: 'TopHashtagsService',
        category: LogCategory.storage,
      );

      // Load the JSON file from assets
      final jsonString = await _loadAssetString(
        'assets/top_1000_hashtags.json',
      );

      Log.debug(
        '🏷️ Loaded JSON string, length: ${jsonString.length}',
        name: 'TopHashtagsService',
        category: LogCategory.storage,
      );

      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      final hashtagsList = jsonData['hashtags'] as List<dynamic>;
      _topHashtags = hashtagsList
          .map((item) => HashtagData.fromJson(item as Map<String, dynamic>))
          .toList();

      _isLoaded = true;

      Log.info(
        '✅ Loaded ${_topHashtags!.length} top hashtags',
        name: 'TopHashtagsService',
        category: LogCategory.storage,
      );

      // Log first few for debugging
      if (_topHashtags!.isNotEmpty) {
        final preview = _topHashtags!
            .take(5)
            .map((h) => '#${h.hashtag}')
            .join(', ');
        Log.info(
          '🏷️ Top hashtags preview: $preview',
          name: 'TopHashtagsService',
          category: LogCategory.storage,
        );
      }
    } catch (e, stackTrace) {
      Log.error(
        '❌ Failed to load top hashtags: $e\nStack: $stackTrace',
        name: 'TopHashtagsService',
        category: LogCategory.storage,
      );
      _topHashtags = [];
      _isLoaded = false;
    }
  }

  /// Get top N hashtags.
  /// Returns fallback defaults if data hasn't loaded yet.
  List<String> getTopHashtags({int limit = 50}) {
    if (!_isLoaded || _topHashtags == null || _topHashtags!.isEmpty) {
      // Return default hashtags as fallback
      return defaultHashtags.take(limit).toList();
    }

    return _topHashtags!.take(limit).map((h) => h.hashtag).toList();
  }

  /// Search hashtags by prefix or substring
  List<String> searchHashtags(String query, {int limit = 20}) {
    if (!_isLoaded || _topHashtags == null || query.isEmpty) return [];

    final lowercase = query.toLowerCase();
    final results = <String>[];

    // First add exact matches
    for (final hashtagData in _topHashtags!) {
      if (hashtagData.hashtag.toLowerCase() == lowercase) {
        results.add(hashtagData.hashtag);
        if (results.length >= limit) break;
      }
    }

    // Then add prefix matches
    for (final hashtagData in _topHashtags!) {
      if (hashtagData.hashtag.toLowerCase().startsWith(lowercase) &&
          !results.contains(hashtagData.hashtag)) {
        results.add(hashtagData.hashtag);
        if (results.length >= limit) break;
      }
    }

    // Finally add substring matches
    for (final hashtagData in _topHashtags!) {
      if (hashtagData.hashtag.toLowerCase().contains(lowercase) &&
          !results.contains(hashtagData.hashtag)) {
        results.add(hashtagData.hashtag);
        if (results.length >= limit) break;
      }
    }

    return results;
  }

  /// Get hashtag statistics
  HashtagData? getHashtagStats(String hashtag) {
    if (!_isLoaded || _topHashtags == null) return null;

    try {
      return _topHashtags!.firstWhere(
        (h) => h.hashtag.toLowerCase() == hashtag.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}
