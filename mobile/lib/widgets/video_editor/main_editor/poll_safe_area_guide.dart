// ABOUTME: Outlines where a poll, quiz or slider may stand while it is moved,
// ABOUTME: so one let go outside the box is not pulled back without a reason.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/poll_sticker_placement.dart';

/// The box a poll, quiz or slider may stand in ([pollSafeRect]), outlined on
/// the canvas while the poll is moved, with a line saying why.
///
/// A poll let go outside the box moves back into it; with the box in sight,
/// that reads as the rule it is.
class PollSafeAreaGuide extends StatelessWidget {
  /// Creates the guide.
  const PollSafeAreaGuide({
    required this.isVisible,
    required this.targetAspectRatio,
    required this.fittedBoxScale,
    super.key,
  });

  /// Whether a poll is being moved.
  final bool isVisible;

  /// The aspect ratio of the exported video.
  final double targetAspectRatio;

  /// How much the editor body is scaled to fit the screen, so the outline and
  /// the line keep their size on screen.
  final double fittedBoxScale;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final unit = 1 / fittedBoxScale;
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 200),
        opacity: isVisible ? 1 : 0,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final box = pollSafeRect(
              bodySize: constraints.biggest,
              targetAspectRatio: targetAspectRatio,
            );
            return Stack(
              children: [
                Positioned.fromRect(
                  rect: box,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: VineTheme.whiteText.withValues(alpha: 0.08),
                      border: Border.all(
                        color: VineTheme.whiteText.withValues(alpha: 0.9),
                        width: 2 * unit,
                      ),
                      borderRadius: BorderRadius.circular(16 * unit),
                    ),
                  ),
                ),
                // Under the box, where a poll cannot stand, so the line never
                // covers the poll it explains.
                Positioned(
                  left: box.left,
                  top: box.bottom + 8 * unit,
                  width: box.width,
                  child: Center(
                    child: Transform.scale(
                      scale: unit,
                      child: _Hint(text: context.l10n.videoEditorPollAreaHint),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: VineTheme.scrim56,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: VineTheme.labelMediumFont(color: VineTheme.whiteText),
        ),
      ),
    );
  }
}
