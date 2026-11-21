// ABOUTME: Explains why two flashing effects, or two Time effects, cannot run
// ABOUTME: at the same time.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';

/// Two sentences take longer to read than a snack bar's usual four seconds.
const _duration = Duration(seconds: 6);

/// Tells the user that an effect replaced another one of its [group] where
/// they overlapped, and why.
void showExclusiveEffectReplacedSnackBar(
  BuildContext context,
  EditorEffectExclusiveGroup group,
) {
  ScaffoldMessenger.of(context).showSnackBar(
    DivineSnackbarContainer.snackBar(
      switch (group) {
        EditorEffectExclusiveGroup.flashing =>
          context.l10n.videoEditorEffectsFlashingReplaced,
        EditorEffectExclusiveGroup.earlierFrames =>
          context.l10n.videoEditorEffectsTimeReplaced,
      },
      duration: _duration,
    ),
  );
}

/// Tells the user why an effect of [group] was not duplicated: the copy would
/// play on top of it.
void showExclusiveEffectNotDuplicatedSnackBar(
  BuildContext context,
  EditorEffectExclusiveGroup group,
) {
  ScaffoldMessenger.of(context).showSnackBar(
    DivineSnackbarContainer.snackBar(
      switch (group) {
        EditorEffectExclusiveGroup.flashing =>
          context.l10n.videoEditorEffectsFlashingNotDuplicated,
        EditorEffectExclusiveGroup.earlierFrames =>
          context.l10n.videoEditorEffectsTimeNotDuplicated,
      },
      duration: _duration,
    ),
  );
}
