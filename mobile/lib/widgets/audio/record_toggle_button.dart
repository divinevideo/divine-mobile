// ABOUTME: Round record/stop button shared by the microphone recorders: a red
// ABOUTME: dot that morphs into a stop square while recording.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// The round record button of the voice-over recorder and the library's
/// sound recorder.
///
/// Shows a red dot while idle and morphs it into a stop square while
/// [isRecording]; the morph is skipped under the reduced-motion preference.
class RecordToggleButton extends StatelessWidget {
  /// Creates a record/stop button.
  const RecordToggleButton({
    required this.isRecording,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  static const double _size = 76;

  /// Whether the stop shape is shown instead of the record dot.
  final bool isRecording;

  /// What tapping does, e.g. "Start recording" or "Stop recording".
  final String semanticLabel;

  /// Called on tap; null disables the button.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: context.vineColors.onSurface, width: 4),
          ),
          child: Center(
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              width: isRecording ? 30 : 60,
              height: isRecording ? 30 : 60,
              decoration: BoxDecoration(
                color: VineTheme.error,
                borderRadius: BorderRadius.circular(isRecording ? 8 : 30),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
