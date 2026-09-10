// ABOUTME: Top-left close affordance shared by the full-screen takeovers
// ABOUTME: Keeps the TV-static, loading, and permission screens in step

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// The top-left X that dismisses a full-screen takeover.
///
/// Lives in one place so the TV-static dead ends, the video-detail spinner,
/// and the camera permission gate cannot drift apart on the next design tweak.
class TakeoverCloseButton extends StatelessWidget {
  const TakeoverCloseButton({
    required this.onPressed,
    this.semanticLabel,
    super.key,
  });

  final VoidCallback onPressed;

  /// Accessibility label. Screens that name the thing being closed should
  /// pass one; the button is unlabelled without it.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // topLeft, not centerLeft: inside a Column the two are identical, but
    // these screens also place the button directly in an expanded Stack,
    // where centerLeft would drop it to the middle of the screen.
    return Align(
      alignment: .topLeft,
      child: Padding(
        padding: const .fromLTRB(16, 16, 0, 8),
        child: DivineIconButton(
          icon: .x,
          onPressed: onPressed,
          size: .small,
          type: .ghost,
          semanticLabel: semanticLabel,
        ),
      ),
    );
  }
}
