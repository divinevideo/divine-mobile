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

  /// Normalizes and deduplicates tags in order without applying a count limit.
  ///
  /// Existing videos can exceed the current publish limit. Editing must expose
  /// every valid tag so creators choose which ones to remove.
  static List<String> normalizeHashtags(Iterable<String> rawTags) =>
      rawTags.map(normalizeVideoHashtag).whereType<String>().toSet().toList();

  /// Normalizes tags and keeps at most [maxHashtagsPerVideo] for a new publish.
  static List<String> normalizeVideoHashtags(Iterable<String> rawTags) =>
      normalizeHashtags(rawTags).take(maxHashtagsPerVideo).toList();

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
