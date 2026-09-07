import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Default shimmer effect for skeleton loaders, resolved for the appearance
/// mode of [context].
///
/// Uses the placeholder surface of the active palette with a 60 % alpha
/// highlight and a 1 500 ms sweep, matching the design-system skeleton spec.
PaintingEffect vineSkeletonEffectOf(BuildContext context) {
  final base = context.vineColors.skeleton;
  if (MediaQuery.disableAnimationsOf(context)) {
    return SolidColorEffect(color: base);
  }
  return ShimmerEffect(
    baseColor: base,
    highlightColor: base.withValues(alpha: 0.6),
    duration: VineTheme.skeletonDuration,
  );
}
