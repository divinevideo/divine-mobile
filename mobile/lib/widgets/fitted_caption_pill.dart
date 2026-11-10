// ABOUTME: The caption pill for a small preview: at the bottom of its space,
// ABOUTME: wrapping at its width and shrinking to fit its height.

import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/text_scale_limits.dart';
import 'package:openvine/widgets/caption_pill.dart';

/// A [CaptionPill] at the bottom of the space it is given, wrapping at its
/// width and shrinking to fit its height.
///
/// Editor previews are short on a small phone, so a long cue would otherwise
/// run off their top. The pill floats over the preview like the toolbar
/// chips, so its text also stops growing where theirs does.
class FittedCaptionPill extends StatelessWidget {
  /// Creates the pill with the cue [text].
  const FittedCaptionPill({required this.text, super.key});

  /// The caption text to display.
  final String text;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: chipLabelTextScaleLimit,
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.bottomCenter,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: CaptionPill(text: text),
            ),
          ),
        ),
      ),
    );
  }
}
