// ABOUTME: Localized names for the Adjust bar: its adjustments, the Color
// ABOUTME: section's bands and properties, and the Curve section's curves.

import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/adjust_color_controls.dart';

/// Localized display name for a tune adjustment [id].
String tuneAdjustmentLabel(BuildContext context, String id) {
  final l10n = context.l10n;
  return switch (id) {
    'brightness' => l10n.videoEditorTuneBrightness,
    'contrast' => l10n.videoEditorTuneContrast,
    'highlights' => l10n.videoEditorTuneHighlights,
    'shadows' => l10n.videoEditorTuneShadows,
    'saturation' => l10n.videoEditorTuneSaturation,
    'vibrance' => l10n.videoEditorTuneVibrance,
    'exposure' => l10n.videoEditorTuneExposure,
    'hue' => l10n.videoEditorTuneHue,
    'temperature' => l10n.videoEditorTuneTemperature,
    'tint' => l10n.videoEditorTuneTint,
    'fade' => l10n.videoEditorTuneFade,
    'sharpen' => l10n.videoEditorTuneSharpen,
    _ => id,
  };
}

/// Formats a tune adjustment [value] for display using its [labelMultiplier].
String tuneAdjustmentValueLabel(double value, double labelMultiplier) =>
    (value * labelMultiplier).round().toString();

/// Localized name of a colour [band].
String tuneColorBandLabel(BuildContext context, AdjustColorBand band) {
  final l10n = context.l10n;
  return switch (band) {
    .red => l10n.videoEditorTuneColorRed,
    .orange => l10n.videoEditorTuneColorOrange,
    .yellow => l10n.videoEditorTuneColorYellow,
    .green => l10n.videoEditorTuneColorGreen,
    .aqua => l10n.videoEditorTuneColorAqua,
    .blue => l10n.videoEditorTuneColorBlue,
    .purple => l10n.videoEditorTuneColorPurple,
    .magenta => l10n.videoEditorTuneColorMagenta,
  };
}

/// Localized name of what the Color section changes about a band.
String tuneColorPropertyLabel(
  BuildContext context,
  AdjustColorProperty property,
) {
  final l10n = context.l10n;
  return switch (property) {
    .hue => l10n.videoEditorTuneHue,
    .saturation => l10n.videoEditorTuneSaturation,
    .lightness => l10n.videoEditorTuneLightness,
  };
}

/// Localized name of a tone [channel]: RGB for the master curve, the colour
/// for the others.
String tuneCurveChannelLabel(BuildContext context, AdjustCurveChannel channel) {
  final l10n = context.l10n;
  return switch (channel) {
    .rgb => l10n.videoEditorTuneCurveRgb,
    .red => l10n.videoEditorTuneColorRed,
    .green => l10n.videoEditorTuneColorGreen,
    .blue => l10n.videoEditorTuneColorBlue,
  };
}

/// Localized name of a tone curve [point].
String tuneCurvePointLabel(BuildContext context, AdjustCurvePoint point) {
  final l10n = context.l10n;
  return switch (point) {
    .blacks => l10n.videoEditorTuneCurveBlacks,
    .shadows => l10n.videoEditorTuneShadows,
    .midtones => l10n.videoEditorTuneCurveMidtones,
    .highlights => l10n.videoEditorTuneHighlights,
    .whites => l10n.videoEditorTuneCurveWhites,
  };
}
