// ABOUTME: Rules every published video's hashtags follow: length, count,
// ABOUTME: separators and lowercase normalization, plus fallback suggestions.

/// The hashtag rules shared by the editor, publishing and suggestions.
class HashtagExtractor {
  /// Maximum allowed length for a single hashtag.
  static const int maxHashtagLength = 50;

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
}
