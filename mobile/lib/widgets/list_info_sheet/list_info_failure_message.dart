// ABOUTME: The line a list info sheet shows above its fields when a save
// ABOUTME: failed, where the sheet cannot hide it.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';

/// Says a save failed, above the fields.
///
/// A snackbar would be drawn on the screen underneath and covered by the
/// sheet itself.
class ListInfoFailureMessage extends StatelessWidget {
  /// Creates the message.
  const ListInfoFailureMessage(this.message, {super.key});

  /// The localized failure line.
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Text(
          message,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onErrorContainer,
          ),
        ),
      ),
    );
  }
}
