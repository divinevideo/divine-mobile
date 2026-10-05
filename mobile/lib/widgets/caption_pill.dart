// ABOUTME: The caption pill rendered over video for closed-caption text.
// ABOUTME: Shared by feed playback and the editor's CC preview overlay.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/media_chrome_backdrop.dart';

/// The rounded scrim pill that renders one caption cue's text over video.
///
/// Blurs the video behind it like the playback toggles pill, but keeps its
/// darker scrim-65 tint so white caption text stays legible over light frames.
class CaptionPill extends StatelessWidget {
  /// Creates the pill with the cue [text].
  const CaptionPill({required this.text, super.key});

  /// The caption text to display.
  final String text;

  @override
  Widget build(BuildContext context) {
    return MediaChromeBackdrop(
      borderRadius: BorderRadius.circular(12),
      color: VineTheme.scrim65,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          text,
          style: VineTheme.captionPillFont(color: VineTheme.whiteText).copyWith(
            shadows: const [Shadow(blurRadius: 4, color: VineTheme.shadow25)],
          ),
        ),
      ),
    );
  }
}
