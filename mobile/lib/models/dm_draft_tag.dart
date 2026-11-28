// ABOUTME: Rumor tag that names an editable draft shared in a DM.
// ABOUTME: Lets the chat card show the draft's title before it is imported.

import 'package:models/models.dart';

/// The `title` rumor tag on a NIP-17 kind 15 editable-draft message.
///
/// The title travels inside the gift wrap with the rest of the rumor, so it
/// is as private as the draft. It is a display hint only: the imported copy
/// takes its title from the project itself.
abstract final class DmDraftTag {
  /// Tag name, written as `['title', '<draft title>']`.
  static const String name = 'title';

  /// Builds the tag for [title], or null when the draft has no title.
  static List<String>? build(String? title) {
    final trimmed = title?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return [name, trimmed];
  }

  /// The title carried by [tags], or null when there is none.
  static String? titleIn(List<List<String>> tags) {
    for (final tag in tags) {
      if (tag.length < 2 || tag.first != name) continue;
      final title = tag[1].trim();
      return title.isEmpty ? null : title;
    }
    return null;
  }
}

/// Editable-draft view of a [DmMessage].
extension DmDraftMessage on DmMessage {
  /// Whether this is a kind 15 message carrying an editable draft project.
  bool get isEditableDraft =>
      isFileMessage && fileMetadata?.isEditableDraft == true;

  /// The shared draft's title, or null when the sender named none.
  String? get draftTitle => isEditableDraft ? DmDraftTag.titleIn(tags) : null;
}
