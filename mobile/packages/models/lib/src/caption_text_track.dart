// ABOUTME: Which text-track tags carry captions a viewer reads along with the
// ABOUTME: video, so a chapters or metadata track never plays as captions.

/// Whether a `text-track` tag whose type element is [type] carries captions:
/// `captions`, `subtitles`, or no type at all, as older tags carry.
///
/// Chapters, descriptions and metadata tracks name no caption text, so
/// playback must not fall back to one when the caption refs fail.
bool isCaptionTextTrackType(String? type) {
  final normalized = type?.trim().toLowerCase() ?? '';
  return normalized.isEmpty ||
      normalized == 'captions' ||
      normalized == 'subtitles';
}
