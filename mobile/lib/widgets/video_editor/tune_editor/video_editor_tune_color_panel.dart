// ABOUTME: The Color section of the Adjust bar: a swatch per colour band and
// ABOUTME: the picked band's hue, saturation and lightness sliders.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/adjust_color_controls.dart';
import 'package:openvine/widgets/video_editor/tune_editor/tune_labels.dart';
import 'package:openvine/widgets/video_editor/tune_editor/tune_slider_theme.dart';
import 'package:openvine/widgets/video_editor/tune_editor/tune_value_changes.dart';

/// The Color section of the Adjust bar.
///
/// A row of swatches picks one of the eight colour bands; below it, one
/// slider each turns the band's hue, mutes or strengthens it, and darkens or
/// lightens it. A band with a value set carries a dot under its swatch.
class VideoEditorTuneColorPanel extends StatelessWidget {
  const VideoEditorTuneColorPanel({super.key});

  static const double _bandsHeight = 44;
  static const double _sliderHeight = 34;

  /// The panel's height.
  static const double height =
      _bandsHeight + _sliderHeight * 3; // One slider per property.

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      children: [
        const SizedBox(height: _bandsHeight, child: _BandSwatches()),
        for (final property in AdjustColorProperty.values)
          SizedBox(
            height: _sliderHeight,
            child: _BandSlider(property: property),
          ),
      ],
    );
  }
}

/// The swatch of [band].
Color _swatchOf(AdjustColorBand band) =>
    VineTheme.adjustColorBandSwatches[band.index];

/// The colour at [hue] (in degrees) between the band swatches, blended from
/// the two bands it lies between.
Color _swatchAt(double hue) {
  final h = hue % 360;
  const bands = AdjustColorBand.values;
  for (var i = 0; i < bands.length; i++) {
    final start = bands[i].centre;
    final end = i + 1 < bands.length ? bands[i + 1].centre : 360.0;
    if (h >= start && h < end) {
      return Color.lerp(
        _swatchOf(bands[i]),
        _swatchOf(bands[(i + 1) % bands.length]),
        (h - start) / (end - start),
      )!;
    }
  }
  return _swatchOf(AdjustColorBand.red);
}

/// What the slider of [property] does to [band], from its lowest value to
/// its highest.
List<Color> _trackColorsOf(AdjustColorBand band, AdjustColorProperty property) {
  final swatch = _swatchOf(band);
  return switch (property) {
    .hue => [_swatchAt(band.centre - 30), swatch, _swatchAt(band.centre + 30)],
    // Halfway to the opposite hue is grey.
    .saturation => [
      Color.lerp(swatch, _swatchAt(band.centre + 180), 0.5)!,
      swatch,
    ],
    .lightness => [
      Color.lerp(VineTheme.backgroundColor, swatch, 0.5)!,
      swatch,
      Color.lerp(swatch, VineTheme.whiteText, 0.5)!,
    ],
  };
}

class _BandSwatches extends StatelessWidget {
  const _BandSwatches();

  @override
  Widget build(BuildContext context) {
    final (selected, values) = context.select(
      (VideoEditorTuneBloc b) => (b.state.colorBand, b.state.values),
    );
    return Padding(
      padding: const .symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final band in AdjustColorBand.values)
            Expanded(
              child: _BandSwatch(
                band: band,
                isSelected: band == selected,
                isAdjusted: AdjustColorProperty.values.any(
                  (property) => (values[band.kindOf(property)] ?? 0) != 0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BandSwatch extends StatelessWidget {
  const _BandSwatch({
    required this.band,
    required this.isSelected,
    required this.isAdjusted,
  });

  final AdjustColorBand band;
  final bool isSelected;
  final bool isAdjusted;

  @override
  Widget build(BuildContext context) {
    final label = tuneColorBandLabel(context, band);
    return Semantics(
      button: true,
      selected: isSelected,
      label: isAdjusted
          ? '$label, ${context.l10n.videoEditorTuneChanged}'
          : label,
      child: GestureDetector(
        behavior: .opaque,
        onTap: () => context.read<VideoEditorTuneBloc>().add(
          VideoEditorTuneColorBandSelected(band),
        ),
        child: ExcludeSemantics(
          child: Column(
            mainAxisAlignment: .center,
            spacing: 3,
            children: [
              Container(
                width: 32,
                height: 32,
                padding: const .all(3),
                decoration: BoxDecoration(
                  shape: .circle,
                  border: .all(
                    color: isSelected
                        ? context.vineColors.accentPositive
                        : VineTheme.transparent,
                    width: 2,
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: .circle,
                    color: _swatchOf(band),
                  ),
                ),
              ),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: .circle,
                  color: isAdjusted
                      ? context.vineColors.onSurface
                      : VineTheme.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BandSlider extends StatelessWidget {
  const _BandSlider({required this.property});

  final AdjustColorProperty property;

  @override
  Widget build(BuildContext context) {
    final band = context.select((VideoEditorTuneBloc b) => b.state.colorBand);
    final kind = band.kindOf(property);
    final value = context.select(
      (VideoEditorTuneBloc b) => b.state.valueOf(kind),
    );
    final adjustment = context.select(
      (VideoEditorTuneBloc b) => b.state.adjustments[b.state.indexOf(kind)],
    );
    final label = tuneColorPropertyLabel(context, property);
    final valueLabel = tuneAdjustmentValueLabel(
      value,
      adjustment.labelMultiplier,
    );

    return Padding(
      padding: const .symmetric(horizontal: 16),
      child: Row(
        spacing: 4,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              maxLines: 1,
              overflow: .ellipsis,
              style: VineTheme.bodySmallFont(
                color: context.vineColors.onSurface,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: tuneSliderTheme(context).copyWith(
                trackHeight: 6,
                trackShape: TuneGradientTrackShape(
                  _trackColorsOf(band, property),
                ),
              ),
              child: Slider(
                min: adjustment.min,
                max: adjustment.max,
                divisions: adjustment.divisions,
                value: value.clamp(adjustment.min, adjustment.max),
                label: valueLabel,
                semanticFormatterCallback: (v) =>
                    '${tuneColorBandLabel(context, band)} $label '
                    '${tuneAdjustmentValueLabel(v, adjustment.labelMultiplier)}',
                onChangeStart: (v) => TuneValueChanges.start(context, kind, v),
                onChanged: (v) => TuneValueChanges.update(context, kind, v),
                onChangeEnd: (v) => TuneValueChanges.end(context, kind, v),
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              value == 0 ? '—' : valueLabel,
              textAlign: .end,
              style: VineTheme.labelSmallFont(
                color: value == 0
                    ? context.vineColors.secondaryText
                    : context.vineColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
