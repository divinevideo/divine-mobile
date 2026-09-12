// ABOUTME: WCAG contrast helper for asserting text stays legible on a fill.
// ABOUTME: Composites the foreground first so translucent tokens score honestly.

import 'package:material_ui/material_ui.dart';

/// WCAG 2.1 contrast ratio between [foreground] composited over [background]
/// and that background.
///
/// The foreground is alpha-blended first: `Color.computeLuminance` ignores
/// alpha, so a translucent token such as `VineTheme.onSurfaceVariant`
/// (75% white) would otherwise score as if it were opaque.
double contrastRatio(Color foreground, Color background) {
  final blended = Color.alphaBlend(foreground, background);
  final first = blended.computeLuminance();
  final second = background.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}
