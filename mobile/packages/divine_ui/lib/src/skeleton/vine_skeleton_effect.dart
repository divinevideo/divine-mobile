import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Default shimmer effect for skeleton loaders, resolved for the appearance
/// mode of [context].
///
/// Uses the placeholder surface of the active palette — or [baseColor], for
/// a surface whose placeholders already have a colour of their own — with a
/// 60 % alpha highlight and a 1 500 ms sweep, matching the design-system
/// skeleton spec. The sweep runs from [begin] to [end] across each
/// skeletonized region; the default is Skeletonizer's shallow diagonal,
/// which reads at a different angle in regions of different shapes, so a
/// surface that mixes shapes can pass a horizontal or vertical pair
/// instead. [stops] places the base, highlight and base colours along the
/// sweep; Skeletonizer's default keeps the highlight a narrow band, and a
/// surface can spread the three across the whole sweep for a wider one.
PaintingEffect vineSkeletonEffectOf(
  BuildContext context, {
  Color? baseColor,
  AlignmentGeometry begin = const AlignmentDirectional(-1, -0.3),
  AlignmentGeometry end = const AlignmentDirectional(1, 0.3),
  List<double>? stops,
}) {
  final base = baseColor ?? context.vineColors.skeleton;
  if (MediaQuery.disableAnimationsOf(context)) {
    return SolidColorEffect(color: base);
  }
  final highlight = base.withValues(alpha: 0.6);
  if (stops == null) {
    return ShimmerEffect(
      baseColor: base,
      highlightColor: highlight,
      begin: begin,
      end: end,
      duration: VineTheme.skeletonDuration,
    );
  }
  return ShimmerEffect.raw(
    colors: [base, highlight, base],
    stops: stops,
    begin: begin,
    end: end,
    duration: VineTheme.skeletonDuration,
  );
}
