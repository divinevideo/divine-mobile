// ABOUTME: Rumor tag that marks an encrypted video DM as a Divine camera clip.
// ABOUTME: Carries the clip's target aspect ratio so it lands in its crop.

import 'package:models/models.dart';

/// The `divine-clip` rumor tag on a NIP-17 kind 15 video message.
///
/// The tag says the sender shared a raw clip from their library, not a
/// finished video, so the recipient is offered "Add to clips". Its value is
/// the clip's [AspectRatio] name: a recording keeps the camera's full frame,
/// and the square or vertical crop is applied later, so the file alone cannot
/// tell the recipient which crop the clip was recorded for.
///
/// The tag is sender-asserted and therefore only a display hint. Whether the
/// clip may enter the library is decided by its C2PA credential, never by
/// this tag.
abstract final class DmClipTag {
  /// Tag name, written as `['divine-clip', '<aspect ratio>']`.
  static const String name = 'divine-clip';

  /// Builds the tag for a clip recorded for [targetAspectRatio].
  static List<String> build(AspectRatio targetAspectRatio) => [
    name,
    targetAspectRatio.name,
  ];

  /// Whether [tags] carry a `divine-clip` tag.
  static bool isPresentIn(List<List<String>> tags) =>
      tags.any((tag) => tag.isNotEmpty && tag.first == name);

  /// The target aspect ratio named by the `divine-clip` tag in [tags].
  ///
  /// Null when the tag is absent or names a ratio this build does not know,
  /// in which case the recipient derives the crop from the file itself.
  static AspectRatio? targetAspectRatioIn(List<List<String>> tags) {
    for (final tag in tags) {
      if (tag.length < 2 || tag.first != name) continue;
      return AspectRatio.values.asNameMap()[tag[1]];
    }
    return null;
  }
}

/// Clip-sharing view of a [DmMessage].
extension DmClipMessage on DmMessage {
  /// Whether this is an encrypted video message the sender marked as a clip.
  bool get isDivineClip =>
      isFileMessage &&
      fileMetadata?.isVideo == true &&
      DmClipTag.isPresentIn(tags);

  /// The crop the clip was recorded for, or null when the sender named none.
  AspectRatio? get clipTargetAspectRatio =>
      isDivineClip ? DmClipTag.targetAspectRatioIn(tags) : null;
}
