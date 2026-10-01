// ABOUTME: The content warnings a draft is published with: the creator's own
// ABOUTME: picks plus the ones its video effects make mandatory.

import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_editor_history_extensions.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';

/// Content warnings derived from what a draft's edit contains.
extension DraftContentWarnings on DivineVideoDraft {
  /// The content warnings the draft's video effects make mandatory, read
  /// from the same editor metadata the render uses; see
  /// [requiredContentLabelsForEffects].
  Set<ContentLabel> get requiredContentWarnings {
    final meta = editorEditingParameters['meta'];
    if (meta is! Map) return const {};
    return requiredContentLabelsForEffects(
      videoEffectsFromMeta(meta[VideoEditorConstants.effectsStateHistoryKey]),
    );
  }

  /// The content warnings to publish: [contentWarnings], the creator's own
  /// picks, plus [requiredContentWarnings].
  Set<ContentLabel> get effectiveContentWarnings => {
    ...contentWarnings,
    ...requiredContentWarnings,
  };
}
