// ABOUTME: Readable sponsorship disclosure for fullscreen video feeds.
// ABOUTME: Uses fixed over-video chrome and allows text to wrap without clipping.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// A scrim-backed sponsorship label rendered over fullscreen video.
///
/// [sponsorName] must already be sanitized and clamped by the launching
/// surface. The text deliberately has no line ceiling so the disclosure stays
/// complete at large system text sizes.
///
/// The scrim is sized for the brightest frame rather than the average one.
/// At [VineTheme.scrim65], white text clears 7:1 against a pure-white shot,
/// while remaining quieter than the 80% media-chrome treatment.
///
/// It is deliberately small and quiet rather than sized like a control. This
/// is the one chrome layer that survives immersive viewing, so it is the only
/// thing on screen while the viewer holds the video — heavy enough to read on
/// any frame, light enough not to become the subject.
class FullscreenSponsorDisclosure extends StatelessWidget {
  const FullscreenSponsorDisclosure({required this.sponsorName, super.key});

  /// Horizontal padding around the localized disclosure text.
  static const horizontalPadding = 10.0;

  /// Vertical padding around the localized disclosure text.
  static const verticalPadding = 6.0;

  final String sponsorName;

  /// Height of one line plus its vertical padding at the current text scale.
  ///
  /// The fullscreen feed uses this only to center the first line in the app
  /// bar row; wrapped lines continue downward over the video without clipping.
  static double singleLineHeight(BuildContext context) {
    final style = VineTheme.bodyTinyFont(color: VineTheme.whiteText);
    final scaledFontSize = MediaQuery.textScalerOf(
      context,
    ).scale(style.fontSize!);
    return scaledFontSize * style.height! + verticalPadding * 2;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.scrim65,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Text(
            context.l10n.exploreFeaturedSponsoredBy(sponsorName),
            style: VineTheme.bodyTinyFont(
              color: VineTheme.whiteText,
            ).copyWith(shadows: _glyphShadows),
          ),
        ),
      ),
    );
  }
}

/// Adds local edge separation on top of the contrast-compliant scrim.
///
/// The scrim carries the required contrast. The tight shadow separates the
/// letters from detail immediately behind them and the wider one lifts the
/// whole word off visually busy footage.
///
/// Deliberately heavier than the single `shadow25` blur that `caption_pill`
/// uses over the same video. A caption that loses a word to a bright frame is
/// a cosmetic problem; a disclosure that does has stopped disclosing.
const _glyphShadows = <Shadow>[
  Shadow(color: VineTheme.scrim80, blurRadius: 4, offset: Offset(0, 1)),
  Shadow(color: VineTheme.scrim50, blurRadius: 12),
];
