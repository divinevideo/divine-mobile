import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';

/// Colour that flags a volume boosted above 100 %, or `null` at or below it.
///
/// Orange up to 200 %, red above, so the risk of clipping reads at a glance.
Color? volumeBoostColor(double volume) {
  if (volume <= 1) return null;
  if (volume <= 2) return VineTheme.accentOrange;
  return VineTheme.error;
}
