// ABOUTME: The settings panel the effects and filter editors show in their
// ABOUTME: bottom bar: a header, cards of settings and their controls.

import 'package:divine_ui/divine_ui.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/effect_setting.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/animation_picker_components.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_row.dart';

/// A settings panel in a sub-editor's bottom bar: a row with a button back
/// to the picker and the [title], over the [children], which scroll on under
/// the system navigation bar.
class VideoEditorSettingsPanel extends StatelessWidget {
  const VideoEditorSettingsPanel({
    required this.title,
    required this.onBack,
    required this.children,
    super.key,
  });

  /// The height of the row with the back button and the title.
  static const double headerHeight = 48;

  final String title;

  /// Goes back to the picker.
  final VoidCallback onBack;

  /// The cards of the panel, top to bottom.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        _Header(title: title, onBack: onBack),
        Expanded(
          child: SingleChildScrollView(
            padding: .fromLTRB(16, 8, 16, 16 + bottomInset),
            child: Column(
              crossAxisAlignment: .stretch,
              spacing: 8,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: VideoEditorSettingsPanel.headerHeight,
      ),
      child: ColoredBox(
        color: context.vineColors.surfaceContainerHigh,
        child: Padding(
          padding: const .symmetric(horizontal: 8),
          child: Row(
            spacing: 4,
            children: [
              DivineIconButton(
                icon: .caretLeft,
                type: .ghost,
                size: .small,
                semanticLabel: context.l10n.commonBack,
                onPressed: onBack,
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: VineTheme.titleSmallFont(
                      color: context.vineColors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A card of [settings] under its [title], each at its value in [values],
/// with a button that puts them back: enabled while [onReset] is not `null`.
///
/// Shows nothing when [settings] is empty.
class VideoEditorSettingsGroupCard extends StatelessWidget {
  const VideoEditorSettingsGroupCard({
    required this.title,
    required this.settings,
    required this.values,
    required this.onChanged,
    required this.resetLabel,
    required this.onReset,
    this.onShuffle,
    super.key,
  });

  final String title;

  /// The settings the card shows, top to bottom.
  final List<EffectSetting> settings;

  /// The value of each setting, as it is stored, by its key.
  final EffectSettingValues values;

  /// Sets the setting stored under the key to the value.
  final void Function(String key, Object value) onChanged;

  /// Gives the setting stored under the key a new random arrangement.
  final ValueChanged<String>? onShuffle;

  final String resetLabel;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    if (settings.isEmpty) return const SizedBox.shrink();
    return VideoEditorSettingsCard(
      child: Padding(
        padding: const .symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: .stretch,
          spacing: 8,
          children: [
            Padding(
              padding: const .symmetric(horizontal: 16),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: VineTheme.titleSmallFont(
                    color: context.vineColors.onSurface,
                  ),
                ),
              ),
            ),
            for (final setting in settings)
              VideoEditorSettingControl(
                key: ValueKey(setting.key),
                setting: setting,
                value: values[setting.key] ?? setting.defaultParam,
                onChanged: (value) => onChanged(setting.key, value),
                onShuffle: onShuffle == null
                    ? null
                    : () => onShuffle!(setting.key),
              ),
            Padding(
              padding: const .symmetric(horizontal: 16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: DivineButton(
                  label: resetLabel,
                  leadingIcon: DivineIconName.arrowCounterClockwise,
                  size: .small,
                  type: .secondary,
                  onPressed: onReset,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What [label] is called.
String effectSettingLabel(
  AppLocalizations l10n,
  EffectSettingLabel label,
) => switch (label) {
  EffectSettingLabel.duration => l10n.videoEditorEffectHitDuration,
  EffectSettingLabel.repeat => l10n.videoEditorEffectHitRepeat,
  EffectSettingLabel.interval => l10n.videoEditorEffectHitInterval,
  EffectSettingLabel.horizontal => l10n.videoEditorEffectHitHorizontal,
  EffectSettingLabel.vertical => l10n.videoEditorEffectHitVertical,
  EffectSettingLabel.reach => l10n.videoEditorEffectHitReach,
  EffectSettingLabel.size => l10n.videoEditorDropsSizeLabel,
  EffectSettingLabel.shake => l10n.videoEditorEffectHitShake,
  EffectSettingLabel.punch => l10n.videoEditorEffectHitPunch,
  EffectSettingLabel.fringes => l10n.videoEditorDropsFringesLabel,
  EffectSettingLabel.color => l10n.videoEditorTuneColor,
  EffectSettingLabel.count => l10n.videoEditorDropsCountLabel,
  EffectSettingLabel.speed => l10n.videoEditorDropsSpeedLabel,
  EffectSettingLabel.frost => l10n.videoEditorDropsFrostLabel,
  EffectSettingLabel.shuffle => l10n.videoEditorDropsShuffle,
  EffectSettingLabel.focus => l10n.videoEditorEffectSettingFocus,
  EffectSettingLabel.width => l10n.videoEditorEffectSettingWidth,
  EffectSettingLabel.direction => l10n.videoEditorEffectSettingDirection,
  EffectSettingLabel.spacing => l10n.videoEditorEffectSettingSpacing,
  EffectSettingLabel.angle => l10n.videoEditorEffectSettingAngle,
  EffectSettingLabel.hue => l10n.videoEditorEffectSettingHue,
  EffectSettingLabel.length => l10n.videoEditorEffectSettingLength,
  EffectSettingLabel.sensitivity => l10n.videoEditorEffectSettingSensitivity,
  EffectSettingLabel.position => l10n.videoEditorEffectSettingPosition,
  EffectSettingLabel.wind => l10n.videoEditorEffectSettingWind,
  EffectSettingLabel.dotSize => l10n.videoEditorEffectSettingDotSize,
  EffectSettingLabel.outline => l10n.videoEditorEffectSettingOutline,
  EffectSettingLabel.levels => l10n.videoEditorEffectSettingLevels,
  EffectSettingLabel.pixelSize => l10n.videoEditorEffectSettingPixelSize,
  EffectSettingLabel.offset => l10n.videoEditorEffectSettingOffset,
  EffectSettingLabel.brushSize => l10n.videoEditorEffectSettingBrushSize,
  EffectSettingLabel.density => l10n.videoEditorEffectSettingDensity,
  EffectSettingLabel.grain => l10n.videoEditorEffectSettingGrain,
  EffectSettingLabel.grid => l10n.videoEditorEffectSettingGrid,
  EffectSettingLabel.layers => l10n.videoEditorEffectSettingLayers,
  EffectSettingLabel.shadow => l10n.videoEditorEffectSettingShadow,
  EffectSettingLabel.firstInk => l10n.videoEditorEffectSettingFirstInk,
  EffectSettingLabel.secondInk => l10n.videoEditorEffectSettingSecondInk,
  EffectSettingLabel.colors => l10n.videoEditorEffectSettingColors,
  EffectSettingLabel.originalColors =>
    l10n.videoEditorEffectSettingOriginalColors,
  EffectSettingLabel.singleColor => l10n.videoEditorEffectSettingSingleColor,
  EffectSettingLabel.delay => l10n.videoEditorEffectSettingDelay,
  EffectSettingLabel.down => l10n.videoEditorEffectSettingDown,
  EffectSettingLabel.up => l10n.videoEditorEffectSettingUp,
  EffectSettingLabel.right => l10n.videoEditorEffectSettingRight,
  EffectSettingLabel.left => l10n.videoEditorEffectSettingLeft,
  EffectSettingLabel.frequency => l10n.videoEditorEffectSettingFrequency,
  EffectSettingLabel.distance => l10n.videoEditorEffectSettingDistance,
  EffectSettingLabel.scanlines => l10n.videoEditorEffectSettingScanlines,
  EffectSettingLabel.grainSize => l10n.videoEditorEffectSettingGrainSize,
  EffectSettingLabel.sepia => l10n.videoEditorEffectSettingSepia,
  EffectSettingLabel.flicker => l10n.videoEditorEffectSettingFlicker,
  EffectSettingLabel.vignette => l10n.videoEditorEffectSettingVignette,
  EffectSettingLabel.tempo => l10n.videoEditorEffectSettingTempo,
  EffectSettingLabel.wavelength => l10n.videoEditorEffectSettingWavelength,
  EffectSettingLabel.brightness => l10n.videoEditorTuneBrightness,
  EffectSettingLabel.contrast => l10n.videoEditorTuneContrast,
  EffectSettingLabel.saturation => l10n.videoEditorTuneSaturation,
  EffectSettingLabel.exposure => l10n.videoEditorTuneExposure,
  EffectSettingLabel.fade => l10n.videoEditorTuneFade,
  EffectSettingLabel.temperature => l10n.videoEditorTuneTemperature,
  EffectSettingLabel.tint => l10n.videoEditorTuneTint,
  EffectSettingLabel.strength => l10n.videoEditorEffectSettingStrength,
  EffectSettingLabel.horizontalOption =>
    l10n.videoEditorEffectSettingHorizontal,
  EffectSettingLabel.verticalOption => l10n.videoEditorEffectSettingVertical,
  EffectSettingLabel.clockwise => l10n.videoEditorEffectSettingClockwise,
  EffectSettingLabel.anticlockwise =>
    l10n.videoEditorEffectSettingAnticlockwise,
  EffectSettingLabel.zoomIn => l10n.videoEditorEffectSettingZoomIn,
  EffectSettingLabel.zoomOut => l10n.videoEditorEffectSettingZoomOut,
};

/// The control of one [setting] at [value], as it is stored: a slider, a
/// colour row, a switch, a row of options or a shuffle button.
///
/// [onChanged] gets the new value as it is stored; [onShuffle] runs when a
/// shuffle button is tapped.
class VideoEditorSettingControl extends StatelessWidget {
  const VideoEditorSettingControl({
    required this.setting,
    required this.value,
    required this.onChanged,
    this.onShuffle,
    super.key,
  });

  final EffectSetting setting;
  final Object value;
  final ValueChanged<Object> onChanged;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = effectSettingLabel(l10n, setting.label);
    const padding = EdgeInsets.symmetric(horizontal: 16);
    return switch (setting) {
      final EffectSliderSetting slider => Padding(
        padding: padding,
        child: _SettingsSlider(
          label: label,
          value: slider.valueOf(value),
          min: slider.min,
          max: slider.max,
          divisions: slider.divisions,
          format: switch (slider.unit) {
            EffectSliderUnit.share => null,
            EffectSliderUnit.count => (value) => '${value.round()}',
            EffectSliderUnit.seconds =>
              (value) => l10n.videoEditorEffectSeconds(
                NumberFormat.decimalPattern(l10n.localeName).format(value),
              ),
            EffectSliderUnit.degrees => (value) => '${value.round()}°',
          },
          onChanged: (value) => onChanged(slider.paramOf(value)),
        ),
      ),
      EffectColorSetting() => _ColorControl(
        label: label,
        color: colorFromArgb32(value as int),
        onChanged: (color) => onChanged(color.toARGB32()),
      ),
      final EffectToggleSetting toggle => DivineSwitchTile(
        title: label,
        subtitle: value == true
            ? null
            : switch (toggle.offHint) {
                EffectSettingHint.once => l10n.videoEditorEffectHitOnce,
                null => null,
              },
        value: value == true,
        onChanged: onChanged,
      ),
      final EffectChoiceSetting choice => Padding(
        padding: padding,
        child: _ChoiceControl(
          label: label,
          choices: choice.choices,
          selected: value as int,
          onChanged: onChanged,
        ),
      ),
      EffectShuffleSetting() => Padding(
        padding: padding,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: DivineButton(
            label: label,
            leadingIcon: DivineIconName.arrowsClockwise,
            size: .small,
            type: .secondary,
            onPressed: onShuffle,
          ),
        ),
      ),
    };
  }
}

/// The editor palette with a button to the custom colour picker.
class _ColorControl extends StatelessWidget {
  const _ColorControl({
    required this.label,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    Future<void> pickColor() async {
      final picked = await showFullColorPicker(context, initialColor: color);
      if (picked != null) onChanged(picked);
    }

    return Column(
      crossAxisAlignment: .stretch,
      spacing: 8,
      children: [
        // The row announces its label itself.
        ExcludeSemantics(
          child: Padding(
            padding: const .symmetric(horizontal: 16),
            child: Text(
              label,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.onSurface,
              ),
            ),
          ),
        ),
        VideoEditorColorRow(
          selected: color,
          onSelected: onChanged,
          onCustom: pickColor,
          padding: const .symmetric(horizontal: 16),
          semanticLabel: label,
        ),
      ],
    );
  }
}

/// A labelled row of options, the [selected] one marked.
class _ChoiceControl extends StatelessWidget {
  const _ChoiceControl({
    required this.label,
    required this.choices,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<EffectChoice> choices;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    return Column(
      crossAxisAlignment: .start,
      spacing: 8,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            style: VineTheme.bodyMediumFont(color: colors.onSurface),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final choice in choices)
              AnimationPickerChip(
                selected: choice.value == selected,
                onTap: () => onChanged(choice.value),
                semanticLabel:
                    '$label: ${effectSettingLabel(l10n, choice.label)}',
                child: ExcludeSemantics(
                  child: Text(
                    effectSettingLabel(l10n, choice.label),
                    maxLines: 1,
                    style: VineTheme.labelMediumFont(
                      color: choice.value == selected
                          ? colors.accentBrand
                          : colors.secondaryText,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// A rounded card a group of settings sits on.
class VideoEditorSettingsCard extends StatelessWidget {
  const VideoEditorSettingsCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainer,
        borderRadius: .circular(16),
      ),
      // The tiles' ink needs a surface of its own.
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// A labelled slider of an effect's settings, with its value on the right:
/// a share from 0 to 100 unless [format] says otherwise.
class _SettingsSlider extends StatelessWidget {
  const _SettingsSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    this.format,
    this.min = 0,
    this.max = 1,
    this.divisions,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  /// Writes the value, for the eye and for screen readers alike.
  final String Function(double value)? format;
  final double min;
  final double max;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        // The slider announces its label and value itself.
        ExcludeSemantics(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.onSurface,
                  ),
                ),
              ),
              Text(
                format?.call(value) ?? '${(value * 100).round()}',
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        DivineSlider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          semanticLabel: label,
          semanticValue: format,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
