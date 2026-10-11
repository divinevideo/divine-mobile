// ABOUTME: Utility for extracting and validating hashtags from vine captions
// ABOUTME: Provides hashtag parsing and validation for Nostr event tagging

/// Utility class for hashtag extraction and validation
class HashtagExtractor {
  /// Maximum allowed length for a single hashtag.
  static const int maxHashtagLength = 50;

  /// Maximum number of hashtags extracted from a single piece of text.
  static const int maxHashtagCount = 20;

  /// Maximum number of hashtags a single video may carry.
  static const int maxHashtagsPerVideo = 10;

  /// Separators between hashtags in typed or pasted text: any whitespace
  /// (including line breaks and non-breaking or other Unicode spaces), commas
  /// and `#`.
  static final RegExp separatorPattern = RegExp(r'[\s,#]+');

  static final RegExp _nonTagCharacters = RegExp('[^a-zA-Z0-9]');

  /// Whether [hashtag] is short enough to be published, linked or suggested.
  ///
  /// Events from older app versions and other clients can still carry longer
  /// tags, so display and search paths filter with this too.
  static bool isWithinLengthLimit(String hashtag) =>
      hashtag.isNotEmpty && hashtag.length <= maxHashtagLength;

  /// Turns one raw token into the tag a video publishes.
  ///
  /// Strips everything except ASCII letters and digits and lowercases the
  /// rest, because NIP-24 requires `t` tag values to be lowercase. Returns
  /// `null` when nothing is left or the result is longer than
  /// [maxHashtagLength]; an over-long tag is rejected rather than truncated,
  /// since a cut-off tag is just a different, meaningless tag.
  static String? normalizeVideoHashtag(String raw) {
    final tag = raw.replaceAll(_nonTagCharacters, '').toLowerCase();
    return isWithinLengthLimit(tag) ? tag : null;
  }

  /// Normalizes every tag with [normalizeVideoHashtag], drops invalid ones
  /// and duplicates, and keeps at most [maxHashtagsPerVideo], in order.
  static List<String> normalizeVideoHashtags(Iterable<String> rawTags) {
    final result = <String>{};
    for (final raw in rawTags) {
      if (result.length >= maxHashtagsPerVideo) break;
      final tag = normalizeVideoHashtag(raw);
      if (tag != null) result.add(tag);
    }
    return result.toList();
  }

  /// Common hashtags for Divine content, used as a fallback when the
  /// Funnelcake API is unavailable.
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
  /// Creates a [HashtagStats] instance.
  const HashtagStats({
    required this.totalCount,
    required this.validCount,
    required this.invalidCount,
    required this.averageLength,
    this.mostCommon,
  });

  /// Total number of hashtags.
  final int totalCount;

  /// Number of valid hashtags.
  final int validCount;

  /// Number of invalid hashtags.
  final int invalidCount;

  /// Average length of all hashtags.
  final double averageLength;

  /// The most frequently occurring hashtag, or `null` if the list is empty.
  final String? mostCommon;

  /// Whether any hashtags failed validation.
  bool get hasInvalidHashtags => invalidCount > 0;

  /// Fraction of hashtags that are valid, in the range `[0.0, 1.0]`.
  double get validPercentage => totalCount > 0 ? validCount / totalCount : 0.0;

  @override
  String toString() =>
      'HashtagStats(total: $totalCount, valid: $validCount, '
      'invalid: $invalidCount, avgLength: ${averageLength.toStringAsFixed(1)})';
}
