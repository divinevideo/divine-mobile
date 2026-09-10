// ABOUTME: Renders a category's SVG mascot, degrading to its emoji on a missing asset.
// ABOUTME: Prevents the asset-not-found crash (#4398) when backend category names lack a bundled SVG.

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// Renders the SVG at [assetPath], falling back to [emoji] when no bundled
/// asset is available.
///
/// Backend category names are an open-ended, uncurated stream (see #2547), so a
/// name can arrive with no matching `assets/categories/<name>.svg`. Callers pass
/// a `null` [assetPath] for those (see `CategoryVisuals.forCategory`), and the
/// emoji is rendered directly without ever asking flutter_svg to load a missing
/// file — a missing-asset load reports a non-fatal to the zone even though
/// `errorBuilder` handles the visual (#6116). The `errorBuilder` stays as a
/// belt-and-suspenders guard for a genuinely corrupt bundled asset.
class CategoryGlyph extends StatelessWidget {
  const CategoryGlyph({
    required this.assetPath,
    required this.emoji,
    this.height,
    this.width,
    super.key,
  });

  /// The bundled SVG asset path, e.g. `assets/categories/music.svg`, or `null`
  /// when no bundled asset exists for the category.
  final String? assetPath;

  /// The fallback glyph shown when [assetPath] is `null` or fails to load.
  final String emoji;

  /// Height for both the SVG and the emoji fallback.
  final double? height;

  /// Width for both the SVG and the emoji fallback.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final path = assetPath;
    if (path == null) {
      return _EmojiGlyph(emoji: emoji, height: height, width: width);
    }
    return SvgPicture.asset(
      path,
      height: height,
      width: width,
      errorBuilder: (context, error, stackTrace) =>
          _EmojiGlyph(emoji: emoji, height: height, width: width),
    );
  }
}

class _EmojiGlyph extends StatelessWidget {
  const _EmojiGlyph({required this.emoji, this.height, this.width});

  final String emoji;
  final double? height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final size = height ?? width ?? 48;
    // Decorative glyph in a fixed-size slot, replacing a scale-invariant SVG;
    // keep it fixed so large system text scales don't overflow the slot.
    return ExcludeSemantics(
      child: MediaQuery.withNoTextScaling(
        child: SizedBox(
          height: height,
          width: width,
          child: Center(
            child: Text(
              emoji,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: size * 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
