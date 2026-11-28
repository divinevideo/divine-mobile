// ABOUTME: The settings of a colour filter: which values of its preset can be
// ABOUTME: changed, on which card, and the filter the changed values make.

import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:openvine/models/video_editor/editor_filter_category.dart';
import 'package:openvine/models/video_editor/effect_setting.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// The cards of the filter settings panel, in panel order.
enum FilterSettingsCardKind {
  /// Brightness, exposure, contrast and fade.
  light,

  /// Temperature, tint, saturation, hue and sepia.
  color,

  /// A colour laid over the picture, and how much of it.
  overlay,

  /// A colour added to the picture, and how strongly.
  cast,

  /// How much of each colour the picture keeps.
  balance,
}

/// A card of the filter settings panel: its [settings], and its [number]
/// among the cards of the same [kind] when there is more than one, else 0.
class FilterSettingsCard extends Equatable {
  const FilterSettingsCard({
    required this.kind,
    required this.settings,
    this.number = 0,
  });

  final FilterSettingsCardKind kind;
  final List<EffectSetting> settings;
  final int number;

  @override
  List<Object?> get props => [kind, settings, number];
}

/// A value of a filter step that a slider sets, on the card it shows in.
typedef _Slider = ({
  ColorFilterStepType type,
  EffectSettingLabel label,
  FilterSettingsCardKind card,
  double min,
  double max,
  EffectSliderUnit unit,
});

/// The sliders every filter has, in panel order. Each sets the value of the
/// filter's step of its type, or adds that step after the preset's own.
const List<_Slider> _sliders = [
  (
    type: .brightness,
    label: .brightness,
    card: .light,
    min: -0.3,
    max: 0.3,
    unit: .share,
  ),
  (
    type: .exposure,
    label: .exposure,
    card: .light,
    min: -1,
    max: 1,
    unit: .share,
  ),
  (
    type: .contrast,
    label: .contrast,
    card: .light,
    min: -0.5,
    max: 0.5,
    unit: .share,
  ),
  (type: .fade, label: .fade, card: .light, min: 0, max: 1, unit: .share),
  (
    type: .temperature,
    label: .temperature,
    card: .color,
    min: -0.5,
    max: 0.5,
    unit: .share,
  ),
  (type: .tint, label: .tint, card: .color, min: -0.3, max: 0.3, unit: .share),
  (
    type: .saturation,
    label: .saturation,
    card: .color,
    min: -1,
    max: 1,
    unit: .share,
  ),
  // Stored in degrees: a step's hue of 1 turns the colours by 180°.
  (
    type: .hue,
    label: .hue,
    card: .color,
    min: -180,
    max: 180,
    unit: .degrees,
  ),
  (type: .sepia, label: .sepia, card: .color, min: 0, max: 1, unit: .share),
];

/// What a slider's stored value is in the values of its step.
double _stepValueOf(_Slider slider, double value) =>
    slider.unit == EffectSliderUnit.degrees ? value / 180 : value;

/// What a step's value is on its slider.
double _sliderValueOf(_Slider slider, double stepValue) =>
    slider.unit == EffectSliderUnit.degrees ? stepValue * 180 : stepValue;

/// The card a colour step of [type] shows on, or `null` for a step that is
/// no colour.
FilterSettingsCardKind? _colorCardOf(ColorFilterStepType type) =>
    switch (type) {
      ColorFilterStepType.colorOverlay => FilterSettingsCardKind.overlay,
      ColorFilterStepType.addictiveColor => FilterSettingsCardKind.cast,
      ColorFilterStepType.rgbScale => FilterSettingsCardKind.balance,
      _ => null,
    };

/// The range of the strength slider of a colour step of [type].
({double min, double max}) _strengthRangeOf(ColorFilterStepType type) =>
    switch (type) {
      // How much of the overlay colour the picture takes.
      ColorFilterStepType.colorOverlay => (min: 0, max: 1),
      // How much is added to the strongest channel, out of 255.
      ColorFilterStepType.addictiveColor => (min: 0, max: 0.5),
      // The factor of the strongest channel.
      _ => (min: 0.5, max: 2),
    };

/// The key of the colour of the step at [index].
String _colorKey(int index) => 'step$index.color';

/// The key of the strength of the step at [index].
String _strengthKey(int index) => 'step$index.strength';

/// The colour a colour [step] starts at, and its strength.
///
/// An overlay's colour is its red, green and blue as they are. A cast's and
/// a balance's are the direction of their red, green and blue, scaled so the
/// strongest channel is full, and the strength is how strong that channel
/// is.
({int color, double strength}) _colorOf(ColorFilterStep step) {
  final [r, g, b, ...] = step.values;
  if (step.type == ColorFilterStepType.colorOverlay) {
    return (color: _argb(r, g, b), strength: step.values[3]);
  }
  final strongest = math.max(r, math.max(g, b));
  if (strongest <= 0) return (color: _argb(0, 0, 0), strength: 0);
  return (
    color: _argb(r / strongest * 255, g / strongest * 255, b / strongest * 255),
    strength: step.type == ColorFilterStepType.addictiveColor
        ? strongest / 255
        : strongest,
  );
}

int _argb(double r, double g, double b) =>
    0xFF000000 |
    (r.round().clamp(0, 255) << 16) |
    (g.round().clamp(0, 255) << 8) |
    b.round().clamp(0, 255);

/// The colour step [step] becomes with [color] and [strength], keeping the
/// direction of its own colour when [color] is `null`.
ColorFilterStep _colorStepWith(
  ColorFilterStep step, {
  required int? color,
  required double strength,
}) {
  final List<double> direction;
  if (color == null) {
    final [r, g, b, ...] = step.values;
    final strongest = step.type == ColorFilterStepType.colorOverlay
        ? 255.0
        : math.max(r, math.max(g, b));
    direction = strongest <= 0
        ? const [0, 0, 0]
        : [r / strongest, g / strongest, b / strongest];
  } else {
    direction = [
      ((color >> 16) & 0xFF) / 255,
      ((color >> 8) & 0xFF) / 255,
      (color & 0xFF) / 255,
    ];
  }
  final [r, g, b] = direction;
  return switch (step.type) {
    ColorFilterStepType.colorOverlay => step.copyWith(
      values: [r * 255, g * 255, b * 255, strength],
    ),
    ColorFilterStepType.addictiveColor => step.copyWith(
      values: [r * strength * 255, g * strength * 255, b * strength * 255],
    ),
    _ => step.copyWith(values: [r * strength, g * strength, b * strength]),
  };
}

/// The settings [filter] has, one card each in panel order; none for a
/// filter without steps, which cannot be rebuilt.
///
/// Every filter has the light and colour sliders, starting at its own values
/// or at neutral for a value it does not set, except that a black-and-white
/// filter that sets no saturation or hue has no slider for them: they cannot
/// change a grey picture. Each colour step of the filter adds a card with
/// its colour and strength.
List<FilterSettingsCard> filterSettingsCardsOf(FilterModel filter) {
  final steps = filter.steps;
  if (steps.isEmpty) return const [];
  final isGrey = steps.any(
    (step) => step.type == ColorFilterStepType.grayscale,
  );
  EffectSliderSetting? sliderSetting(_Slider slider) {
    final step = steps.where((step) => step.type == slider.type).firstOrNull;
    if (step == null &&
        isGrey &&
        (slider.type == ColorFilterStepType.saturation ||
            slider.type == ColorFilterStepType.hue)) {
      return null;
    }
    return EffectSliderSetting(
      key: slider.type.name,
      label: slider.label,
      defaultValue: step == null ? 0 : _sliderValueOf(slider, step.values[0]),
      min: slider.min,
      max: slider.max,
      unit: slider.unit,
    );
  }

  final colorSteps = [
    for (final (index, step) in steps.indexed)
      if (_colorCardOf(step.type) case final card?)
        (index: index, step: step, card: card),
  ];
  return [
    for (final kind in const [
      FilterSettingsCardKind.light,
      FilterSettingsCardKind.color,
    ])
      FilterSettingsCard(
        kind: kind,
        settings: [
          for (final slider in _sliders)
            if (slider.card == kind) ?sliderSetting(slider),
        ],
      ),
    for (final (:index, :step, :card) in colorSteps)
      FilterSettingsCard(
        kind: card,
        number: colorSteps.where((other) => other.card == card).length > 1
            ? colorSteps
                  .where((other) => other.card == card && other.index <= index)
                  .length
            : 0,
        settings: [
          EffectColorSetting(
            key: _colorKey(index),
            label: EffectSettingLabel.color,
            defaultColor: _colorOf(step).color,
          ),
          EffectSliderSetting(
            key: _strengthKey(index),
            label: EffectSettingLabel.strength,
            defaultValue: _colorOf(step).strength,
            min: _strengthRangeOf(step.type).min,
            max: _strengthRangeOf(step.type).max,
          ),
        ],
      ),
  ];
}

/// The setting of [filter] stored under [key], or `null` for a key it has no
/// setting for.
EffectSetting? filterSettingOf(FilterModel filter, String key) {
  for (final card in filterSettingsCardsOf(filter)) {
    for (final setting in card.settings) {
      if (setting.key == key) return setting;
    }
  }
  return null;
}

/// [filter] with the settings in [values] changed from its own.
///
/// A slider value replaces the value of the filter's step of its type, or
/// adds that step after the filter's own when it has none; a colour or
/// strength rebuilds its colour step. Steps without a changed setting keep
/// their values exactly, so a filter with no changed setting is [filter]
/// itself.
FilterModel filterWithSettings(FilterModel filter, EffectSettingValues values) {
  if (values.isEmpty || filter.steps.isEmpty) return filter;
  final settings = {
    for (final card in filterSettingsCardsOf(filter))
      for (final setting in card.settings) setting.key: setting,
  };
  final steps = [...filter.steps];
  final added = <ColorFilterStep>[];
  for (final slider in _sliders) {
    final setting = settings[slider.type.name];
    final stored = values[slider.type.name];
    if (setting is! EffectSliderSetting || stored == null) continue;
    final value = _stepValueOf(slider, setting.valueOf(stored));
    final index = steps.indexWhere((step) => step.type == slider.type);
    if (index >= 0) {
      steps[index] = steps[index].copyWith(values: [value]);
    } else if (value != 0) {
      added.add(ColorFilterStep(slider.type, [value]));
    }
  }
  for (final (index, step) in filter.steps.indexed) {
    if (_colorCardOf(step.type) == null) continue;
    final color = values[_colorKey(index)];
    final strength = values[_strengthKey(index)];
    if (color == null && strength == null) continue;
    final colorSetting = settings[_colorKey(index)];
    final strengthSetting = settings[_strengthKey(index)];
    steps[index] = _colorStepWith(
      step,
      color: color == null ? null : colorSetting?.read(color) as int?,
      strength: strengthSetting is EffectSliderSetting
          ? strengthSetting.valueOf(strength ?? strengthSetting.defaultParam)
          : 0,
    );
  }
  return filter.copyWith(steps: [...steps, ...added]);
}

/// A filter as the filter editor commits it: the [preset] it started from,
/// the settings changed from the preset's own [values], and its [opacity].
///
/// Stored in the filter's `FilterState.meta` under [metaKey], so the filter
/// can be opened again with the values it was left at.
class EditedFilter extends Equatable {
  const EditedFilter({
    required this.preset,
    this.values = const {},
    this.opacity = 1,
  });

  /// The `FilterState.meta` key [toMeta] is stored under.
  static const String metaKey = 'divineFilterSettings';

  /// The filter stored in [meta] by [toMeta], or `null` when there is none
  /// or its preset is no longer offered. Unknown settings are dropped and the
  /// rest brought into range.
  static EditedFilter? fromMeta(Map<String, dynamic> meta) {
    final stored = meta[metaKey];
    if (stored is! Map) return null;
    final name = stored['preset'];
    final preset = name is String ? editorFilterNamed(name) : null;
    if (preset == null) return null;
    final rawValues = stored['values'];
    final values = <String, Object>{
      if (rawValues is Map)
        for (final MapEntry(:key, :value) in rawValues.entries)
          if (key is String && value != null)
            if (filterSettingOf(preset, key) case final setting?)
              key: setting.read(value),
    };
    final opacity = stored['opacity'];
    return EditedFilter(
      preset: preset,
      values: Map.unmodifiable(values),
      opacity: opacity is num ? opacity.toDouble().clamp(0.0, 1.0) : 1,
    );
  }

  final FilterModel preset;
  final EffectSettingValues values;
  final double opacity;

  /// The filter [preset] becomes with [values].
  FilterModel get filter => filterWithSettings(preset, values);

  /// This filter as `FilterState.meta` stores it.
  Map<String, Object> toMeta() => {
    metaKey: {'preset': preset.name, 'values': values, 'opacity': opacity},
  };

  @override
  List<Object?> get props => [preset.name, values, opacity];
}

/// [active] with [filter] committed at [matrices]: in place of the filter
/// with [editingId], keeping its id, window on the timeline and transitions,
/// or after the others when there is none.
List<FilterState> commitEditedFilter({
  required List<FilterState> active,
  required EditedFilter filter,
  required FilterMatrix matrices,
  String? editingId,
}) {
  final filters = [for (final state in active) state.copy()];
  final meta = filter.toMeta();
  final index = editingId == null
      ? -1
      : filters.indexWhere((state) => state.id == editingId);
  if (index < 0) {
    return [
      ...filters,
      FilterState(name: filter.preset.name, matrices: matrices, meta: meta),
    ];
  }
  filters[index] = filters[index].copyWith(
    name: filter.preset.name,
    matrices: matrices,
    meta: {...filters[index].meta, ...meta},
  );
  return filters;
}
