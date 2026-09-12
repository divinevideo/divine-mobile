// ABOUTME: The caption pill rendered over video for closed-caption text.
// ABOUTME: Shared by feed playback and the editor's CC preview overlay.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// The rounded scrim pill that renders one caption cue's text over video.
class CaptionPill extends StatelessWidget {
  /// Creates the pill with the cue [text].
  const CaptionPill({required this.text, super.key});

  /// The caption text to display.
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: VineTheme.scrim65,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: VineTheme.captionPillFont(color: VineTheme.whiteText).copyWith(
          shadows: const [Shadow(blurRadius: 4, color: VineTheme.shadow25)],
        ),
      ),
    );
  }
}
