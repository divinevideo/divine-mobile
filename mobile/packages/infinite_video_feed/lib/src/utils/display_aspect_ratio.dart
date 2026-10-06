/// Width / height of the 1280x720 and 854x480 targets the pre-fix
/// transcoder forced every derivative into.
const double _legacyDerivativeAspectRatio = 16 / 9;

/// Relative difference below which two aspect ratios count as equal.
///
/// Absorbs encoder padding (1080x1920 vs 1088x1920) and the float32 rounding
/// Media3 applies to pixel ratios.
const _aspectRatioTolerance = 0.02;

/// Returns the aspect ratio the feed should lay a video out at.
///
/// [decodedAspectRatio] is what the native player reports for the file it is
/// playing; [declaredWidth] / [declaredHeight] come from the event's `dim`.
///
/// Derivatives written before the transcoder preserved aspect ratio were
/// scaled to a fixed 16:9 regardless of the source, so a 480x480 classic Vine
/// decodes as 1280x720 with the stretch baked into the pixels. Laying that
/// frame out at the declared ratio scales it back to the original geometry.
/// Any other mismatch keeps the decoded ratio, so a wrong `dim` cannot
/// distort a correctly encoded file.
// TODO(any): Remove once divinevideo/divine-blossom#161 re-transcodes the
// legacy derivatives.
double displayAspectRatio({
  required double decodedAspectRatio,
  int? declaredWidth,
  int? declaredHeight,
}) {
  if (decodedAspectRatio <= 0) return decodedAspectRatio;
  if (declaredWidth == null || declaredHeight == null) {
    return decodedAspectRatio;
  }
  if (declaredWidth <= 0 || declaredHeight <= 0) return decodedAspectRatio;

  final declaredAspectRatio = declaredWidth / declaredHeight;
  final isLegacyDerivative = _roughlyEqual(
    decodedAspectRatio,
    _legacyDerivativeAspectRatio,
  );
  if (!isLegacyDerivative) return decodedAspectRatio;
  if (_roughlyEqual(declaredAspectRatio, decodedAspectRatio)) {
    return decodedAspectRatio;
  }
  return declaredAspectRatio;
}

bool _roughlyEqual(double a, double b) =>
    (a - b).abs() / b < _aspectRatioTolerance;
