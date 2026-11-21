// ABOUTME: Explains why two flashing effects cannot run at the same time.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Two sentences take longer to read than a snack bar's usual four seconds.
const _duration = Duration(seconds: 6);

/// Tells the user that a flashing effect replaced another one where they
/// overlapped, and why.
void showFlashingEffectReplacedSnackBar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    DivineSnackbarContainer.snackBar(
      context.l10n.videoEditorEffectsFlashingReplaced,
      duration: _duration,
    ),
  );
}

/// Tells the user why a flashing effect was not duplicated: the copy would
/// flash on top of it.
void showFlashingEffectNotDuplicatedSnackBar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    DivineSnackbarContainer.snackBar(
      context.l10n.videoEditorEffectsFlashingNotDuplicated,
      duration: _duration,
    ),
  );
}
