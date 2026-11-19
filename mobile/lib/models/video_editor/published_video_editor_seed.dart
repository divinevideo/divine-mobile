// ABOUTME: The editor state an edit of a published video starts from, shared
// ABOUTME: by the editor and by a republish rebasing an edit onto a newer one.

import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:models/models.dart'
    show VideoEvent, stripInspiredByAttribution, stripSoundCredit;
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/npub_hex.dart';

/// The editor fields [video] seeds when its owner opens it for editing.
VideoEditorProviderState editorStateFromPublishedVideo(VideoEvent video) {
  // The sound credit line is the publisher's, not part of the caption;
  // the update service puts it back on save.
  final content = stripSoundCredit(stripInspiredByAttribution(video.content));

  return VideoEditorProviderState(
    // Getter falls back to rawTags so the toggle survives a cache round-trip.
    allowAudioReuse: video.allowAudioReuse,
    allowVideoReuse: video.allowVideoReuse,
    title: video.title ?? '',
    description: content,
    // Older events can carry mixed-case or over-long tags, and caption
    // hashtag extraction compares against normalized ones.
    tags: HashtagExtractor.normalizeVideoHashtags(video.hashtags).toSet(),
    contentWarnings: video.contentWarningLabels
        .map(ContentLabel.fromValue)
        .whereType<ContentLabel>()
        .toSet(),
    collaboratorPubkeys: video.collaboratorPubkeys.toSet(),
    inspiredByVideo: video.inspiredByVideo,
    inspiredByNpubs: _inspiredByNpubsFor(video),
  );
}

List<String> _inspiredByNpubsFor(VideoEvent video) {
  final npubs = <String>[];
  final seenHex = <String>{};

  void add(String? hex, String? npub) {
    final normalizedHex = hex?.trim().toLowerCase();
    if (normalizedHex == null || normalizedHex.isEmpty) return;
    if (!seenHex.add(normalizedHex)) return;
    npubs.add(npub ?? NostrKeyUtils.encodePubKey(normalizedHex));
  }

  final contentNpub = video.inspiredByNpub;
  if (contentNpub != null) {
    add(npubToHexOrNull(contentNpub), contentNpub);
  }
  for (final hex in video.inspiredByPubkeys) {
    add(hex, null);
  }
  return npubs;
}
