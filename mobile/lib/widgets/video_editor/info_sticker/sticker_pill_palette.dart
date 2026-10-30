// ABOUTME: The pill looks of info and social stickers: their colors and the
// ABOUTME: pill a line of sticker text sits in.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';

/// The colors of a pill look.
class StickerPillPalette {
  const StickerPillPalette({
    required this.ink,
    this.background,
    this.border,
    this.glow,
  }) : _isCovering = false;

  const StickerPillPalette._covering({
    required this.ink,
    this.background,
    this.border,
  }) : glow = null,
       _isCovering = true;

  factory StickerPillPalette.of(InfoStickerStyle style) => switch (style) {
    InfoStickerStyle.dark => const StickerPillPalette(
      background: VineTheme.scrim65,
      ink: VineTheme.whiteText,
    ),
    InfoStickerStyle.glass => StickerPillPalette(
      background: VineTheme.whiteText.withValues(alpha: 0.24),
      border: VineTheme.whiteText.withValues(alpha: 0.5),
      ink: VineTheme.whiteText,
    ),
    InfoStickerStyle.brand => const StickerPillPalette(
      background: VineTheme.vineGreen,
      ink: VineTheme.onPrimary,
    ),
    InfoStickerStyle.highlight => const StickerPillPalette(
      background: VineTheme.accentYellow,
      ink: VineTheme.onPrimary,
    ),
    InfoStickerStyle.neon => const StickerPillPalette(
      ink: VineTheme.whiteText,
      glow: VineTheme.vineGreen,
    ),
    InfoStickerStyle.plain => const StickerPillPalette(
      ink: VineTheme.whiteText,
    ),
    InfoStickerStyle.outline => const StickerPillPalette(
      border: VineTheme.whiteText,
      ink: VineTheme.whiteText,
    ),
    _ => const StickerPillPalette(
      background: VineTheme.whiteText,
      ink: VineTheme.onPrimary,
    ),
  };

  final Color? background;
  final Color? border;
  final Color ink;

  /// The color the text glows in, for the neon look.
  final Color? glow;

  final bool _isCovering;

  /// Only the parts of these colors that hide what is beneath: the ink, and
  /// the background and border where they are solid.
  ///
  /// For drawing a sticker again, sharp, over the same sticker in a video's
  /// frames. A see-through fill, a glow or a shadow is in the frames already
  /// and would come out twice as strong.
  StickerPillPalette get covering => StickerPillPalette._covering(
    ink: ink,
    background: _solid(background),
    border: _solid(border),
  );

  static Color? _solid(Color? color) =>
      color != null && color.a == 1 ? color : null;

  /// A glow for neon; otherwise, without an opaque background, a shadow so
  /// the ink reads on a light video. None in [covering] colors.
  List<Shadow> get shadows => switch (glow) {
    _ when _isCovering => const [],
    final glow? => [
      Shadow(color: glow, blurRadius: 6),
      Shadow(color: glow, blurRadius: 18),
      Shadow(color: glow.withValues(alpha: 0.6), blurRadius: 36),
    ],
    null when background == null || background!.a < 1 => const [
      Shadow(color: VineTheme.scrim50, blurRadius: 12),
    ],
    null => const [],
  };

  /// The text of a sticker line in these colors, [fontSize] high.
  TextStyle textStyle({double fontSize = 48}) =>
      VineTheme.titleLargeFont(color: ink)
          .copyWith(fontSize: fontSize, height: 1.15, shadows: shadows);
}

/// A sticker's pill in [palette]: solid, see-through, outlined or bare.
class StickerPill extends StatelessWidget {
  const StickerPill({
    required this.palette,
    required this.child,
    super.key,
  });

  final StickerPillPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final border = palette.border;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
        border: border == null ? null : Border.all(color: border, width: 5),
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 32, vertical: 16),
        child: child,
      ),
    );
  }
}
