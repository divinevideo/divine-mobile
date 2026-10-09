// ABOUTME: The caption pill rendered over video for closed-caption text.
// ABOUTME: Shared by feed playback and the editor's CC preview overlay.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/media_chrome_backdrop.dart';

/// The rounded scrim pill that renders one caption cue's text over video.
///
/// Blurs the video behind it like the playback toggles pill, but keeps a
/// darker scrim-56 tint: the lightest that holds white caption text at 5:1
/// contrast even over a pure-white frame. The glyph shadow is extra; the
/// contrast comes from the tint alone.
class CaptionPill extends StatelessWidget {
  /// Creates the pill with the cue [text].
  const CaptionPill({required this.text, super.key});

  /// The caption text to display.
  final String text;

  @override
  Widget build(BuildContext context) {
    // Display-only: a tap, double-tap or hold on a caption belongs to the
    // video beneath it. Screen readers still read the text.
    return IgnorePointer(
      child: MediaChromeBackdrop(
        borderRadius: BorderRadius.circular(12),
        color: VineTheme.scrim56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            text,
            style: VineTheme.captionPillFont(color: VineTheme.whiteText)
                .copyWith(
                  shadows: const [
                    Shadow(blurRadius: 4, color: VineTheme.shadow25),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}
