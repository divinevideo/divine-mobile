// ABOUTME: Utility for extracting and validating hashtags from vine captions
// ABOUTME: Provides hashtag parsing and validation for Nostr event tagging

/// Utility class for hashtag extraction and validation
class HashtagExtractor {
  static const int maxHashtagLength = 50;
  static const int maxHashtagCount = 20;

  // Common hashtags for divine content
  static const List<String> suggestedHashtags = [
    'openvine',
    'nostr',
    'vine',
    'video',
    'shortform',
    'funny',
    'creative',
    'art',
    'meme',
    'dance',
    'music',
    'comedy',
    'tutorial',
    'lifestyle',
    'nature',
    'food',
    'sports',
    'tech',
    'bitcoin',
    'decentralized',
  ];

  /// Extract hashtags from text content
  static List<String> extractHashtags(String text) {
    if (text.isEmpty) return [];

    final hashtagRegex = RegExp(r'#(\w+)', caseSensitive: false);
    final matches = hashtagRegex.allMatches(text);

    final hashtags = <String>[];
    for (final match in matches) {
      final hashtag = match.group(1);
      if (hashtag != null && isValidHashtag(hashtag)) {
        // Convert to lowercase and add if not already present
        final normalizedTag = hashtag.toLowerCase();
        if (!hashtags.contains(normalizedTag)) {
          hashtags.add(normalizedTag);
        }
      }

      // Limit hashtag count
      if (hashtags.length >= maxHashtagCount) {
        break;
      }
    }

    return hashtags;
  }

  /// Validate a single hashtag
  static bool isValidHashtag(String hashtag) {
    if (hashtag.isEmpty || hashtag.length > maxHashtagLength) {
      return false;
    }

    // Must contain only alphanumeric characters and underscores
    final validCharacters = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!validCharacters.hasMatch(hashtag)) {
      return false;
    }

    // Must start with a letter
    if (!RegExp('^[a-zA-Z]').hasMatch(hashtag)) {
      return false;
    }

    return true;
  }

  /// Clean and normalize hashtags
  static List<String> normalizeHashtags(List<String> hashtags) {
    final normalized = <String>[];

    for (final hashtag in hashtags) {
      final cleaned = hashtag.toLowerCase().replaceAll(
        RegExp('[^a-z0-9_]'),
        '',
      );

      if (isValidHashtag(cleaned) && !normalized.contains(cleaned)) {
        normalized.add(cleaned);
      }

      // Limit count
      if (normalized.length >= maxHashtagCount) {
        break;
      }
    }

    return normalized;
  }

  /// Combine caption hashtags with additional hashtags
  static List<String> combineHashtags({
    required String caption,
    List<String> additionalHashtags = const [],
  }) {
    final captionHashtags = extractHashtags(caption);
    final normalizedAdditional = normalizeHashtags(additionalHashtags);

    // Combine without duplicates
    final combined = <String>[...captionHashtags];
    for (final tag in normalizedAdditional) {
      if (!combined.contains(tag)) {
        combined.add(tag);
      }

      if (combined.length >= maxHashtagCount) {
        break;
      }
    }

    return combined;
  }

  /// Get suggested hashtags based on content analysis
  static List<String> getSuggestedHashtags({
    String? caption,
    int maxSuggestions = 5,
  }) {
    final suggestions = <String>[];

    if (caption != null && caption.isNotEmpty) {
      final lowerCaption = caption.toLowerCase();

      // Find relevant hashtags based on content
      for (final hashtag in suggestedHashtags) {
        if (lowerCaption.contains(hashtag) ||
            _isContentRelated(lowerCaption, hashtag)) {
          suggestions.add(hashtag);

          if (suggestions.length >= maxSuggestions) {
            break;
          }
        }
      }
    }

    // Fill remaining suggestions with popular hashtags
    if (suggestions.length < maxSuggestions) {
      for (final hashtag in suggestedHashtags) {
        if (!suggestions.contains(hashtag)) {
          suggestions.add(hashtag);

          if (suggestions.length >= maxSuggestions) {
            break;
          }
        }
      }
    }

    return suggestions;
  }

  /// Check if content is related to a hashtag
  static bool _isContentRelated(String content, String hashtag) {
    // Define keyword associations for better hashtag suggestions
    final associations = <String, List<String>>{
      'funny': ['laugh', 'joke', 'hilarious', 'comedy', 'humor'],
      'dance': ['dancing', 'moves', 'choreography', 'rhythm'],
      'music': ['song', 'beat', 'melody', 'sound', 'audio'],
      'food': ['recipe', 'cooking', 'eating', 'delicious', 'meal'],
      'nature': ['outdoor', 'wildlife', 'landscape', 'plants', 'animals'],
      'tech': ['technology', 'programming', 'coding', 'digital', 'software'],
      'bitcoin': ['crypto', 'blockchain', 'btc', 'satoshi', 'lightning'],
    };

    final keywords = associations[hashtag];
    if (keywords != null) {
      return keywords.any((keyword) => content.contains(keyword));
    }

    return false;
  }

  /// Format hashtags for display
  static String formatHashtagsForDisplay(List<String> hashtags) {
    if (hashtags.isEmpty) return '';

    return hashtags.map((tag) => '#$tag').join(' ');
  }

  /// Extract hashtag statistics
  static HashtagStats getHashtagStats(List<String> hashtags) => HashtagStats(
    totalCount: hashtags.length,
    validCount: hashtags.where(isValidHashtag).length,
    invalidCount: hashtags.where((tag) => !isValidHashtag(tag)).length,
    averageLength: hashtags.isEmpty
        ? 0.0
        : hashtags.map((tag) => tag.length).reduce((a, b) => a + b) /
              hashtags.length,
    mostCommon: _findMostCommon(hashtags),
  );

  /// Find most common hashtag (for analytics)
  static String? _findMostCommon(List<String> hashtags) {
    if (hashtags.isEmpty) return null;

    final frequency = <String, int>{};
    for (final tag in hashtags) {
      frequency[tag] = (frequency[tag] ?? 0) + 1;
    }

    return frequency.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}

/// Statistics about hashtag usage
class HashtagStats {
  const HashtagStats({
    required this.totalCount,
    required this.validCount,
    required this.invalidCount,
    required this.averageLength,
    this.mostCommon,
  });
  final int totalCount;
  final int validCount;
  final int invalidCount;
  final double averageLength;
  final String? mostCommon;

  bool get hasInvalidHashtags => invalidCount > 0;
  double get validPercentage => totalCount > 0 ? validCount / totalCount : 0.0;

  @override
  String toString() =>
      'HashtagStats(total: $totalCount, valid: $validCount, '
      'invalid: $invalidCount, avgLength: ${averageLength.toStringAsFixed(1)})';
}
