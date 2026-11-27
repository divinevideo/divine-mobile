// ABOUTME: The settings of the picked video effect, shown in the effects
// ABOUTME: editor's bottom bar in place of the effects picker.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/effects_editor/video_editor_effects_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/models/video_editor/effect_setting.dart';
import 'package:openvine/models/video_editor/effect_settings_catalog.dart';
import 'package:openvine/widgets/video_editor/effects_editor/video_editor_effects_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/animation_picker_components.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_row.dart';

/// The settings of the picked effect: whether it fires on the beat, then one
/// card per [EffectSettingGroup] of the settings [effectSettingsOf] lists for
/// it, each only for an effect it applies to.
///
/// It fills the bottom bar of the effects editor, under a row with a button
/// back to the effects picker, and scrolls on under the system navigation
/// bar.
class VideoEditorEffectSettingsPanel extends StatelessWidget {
  const VideoEditorEffectSettingsPanel({super.key});

  /// The height of the row with the back button and the title.
  static const double headerHeight = 48;

  @override
  Widget build(BuildContext context) {
    final type = context.select(
      (VideoEditorEffectsCubit c) => c.state.selectedType,
    );
    if (type == null) return const SizedBox.shrink();
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        _Header(type: type),
        Expanded(
          child: SingleChildScrollView(
            padding: .fromLTRB(16, 8, 16, 16 + bottomInset),
            child: Column(
              crossAxisAlignment: .stretch,
              spacing: 8,
              children: [
                if (type.supportsOnBeat) const _OnBeatTile(),
                for (final group in EffectSettingGroup.values)
                  _SettingsGroup(group: group),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.type});

  final EditorEffectType type;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: VideoEditorEffectSettingsPanel.headerHeight,
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
                semanticLabel: l10n.commonBack,
                onPressed: () => context
                    .read<VideoEditorEffectsCubit>()
                    .setSettingsOpen(open: false),
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.videoEditorEffectSettingsTitle(
                      videoEffectLabel(context, type),
                    ),
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

/// What finding the beats for an effect on the beat came to, for the line
/// under the switch, or `null` when there is nothing to say.
String? onBeatStatusLabel(
  AppLocalizations l10n,
  VideoEditorEffectsState state,
) {
  if (!state.selectionOnBeat) return null;
  return switch (state.beatStatus) {
    VideoEditorBeatStatus.idle => null,
    VideoEditorBeatStatus.loading => l10n.videoEditorEffectsOnBeatFinding,
    VideoEditorBeatStatus.noSound => l10n.videoEditorEffectsOnBeatNoSound,
    VideoEditorBeatStatus.failed => l10n.videoEditorEffectsOnBeatNoBeat,
    VideoEditorBeatStatus.ready =>
      state.beats.isEmpty ? l10n.videoEditorEffectsOnBeatNoBeat : null,
  };
}

/// Fires the picked effect on the beat of the music, with a line saying when
/// there is no beat to follow.
class _OnBeatTile extends StatelessWidget {
  const _OnBeatTile();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onBeat = context.select(
      (VideoEditorEffectsCubit c) => c.state.onBeat,
    );
    final status = context.select(
      (VideoEditorEffectsCubit c) => onBeatStatusLabel(l10n, c.state),
    );
    return BlocListener<VideoEditorEffectsCubit, VideoEditorEffectsState>(
      // Finding the beat ends somewhere the screen reader would not notice:
      // say so when there turns out to be nothing to follow.
      listenWhen: (previous, current) =>
          onBeatStatusLabel(l10n, previous) !=
              onBeatStatusLabel(l10n, current) &&
          current.beatStatus != VideoEditorBeatStatus.loading &&
          onBeatStatusLabel(l10n, current) != null,
      listener: (context, state) => SemanticsService.sendAnnouncement(
        View.of(context),
        onBeatStatusLabel(l10n, state)!,
        Directionality.of(context),
      ),
      child: _Card(
        child: DivineSwitchTile(
          title: l10n.videoEditorEffectsOnBeat,
          subtitle: status,
          value: onBeat,
          onChanged: (value) =>
              context.read<VideoEditorEffectsCubit>().setOnBeat(onBeat: value),
        ),
      ),
    );
  }
}

/// The settings of the picked effect in [group], on one card under its
/// title, with a button that puts them back to their defaults.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.group});

  final EffectSettingGroup group;

  @override
  Widget build(BuildContext context) {
    final type = context.select(
      (VideoEditorEffectsCubit c) => c.state.selectedType,
    );
    // The overrides only change when a setting does, so the cards rebuild no
    // more often than that.
    final overrides = context.select(
      (VideoEditorEffectsCubit c) => c.state.settingValues,
    );
    final onBeat = context.select(
      (VideoEditorEffectsCubit c) => c.state.selectionOnBeat,
    );
    if (type == null) return const SizedBox.shrink();
    final values = effectSettingValuesOf(type, overrides);
    final settings = [
      for (final setting in effectSettingsOf(type))
        if (setting.group == group) setting,
    ];
    final visible = [
      for (final setting in settings)
        if (setting.isShown(values, onBeat: onBeat)) setting,
    ];
    if (visible.isEmpty) return const SizedBox.shrink();
    final changed = settings.any(
      (setting) => values[setting.key] != setting.defaultParam,
    );
    final l10n = context.l10n;
    return _Card(
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
                  switch (group) {
                    EffectSettingGroup.timing =>
                      l10n.videoEditorEffectTimingTitle,
                    EffectSettingGroup.look => l10n.videoEditorEffectLookTitle,
                    EffectSettingGroup.motion =>
                      l10n.videoEditorEffectMotionTitle,
                  },
                  style: VineTheme.titleSmallFont(
                    color: context.vineColors.onSurface,
                  ),
                ),
              ),
            ),
            for (final setting in visible)
              _SettingControl(
                key: ValueKey(setting.key),
                setting: setting,
                value: values[setting.key]!,
              ),
            Padding(
              padding: const .symmetric(horizontal: 16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: DivineButton(
                  label: switch (group) {
                    EffectSettingGroup.timing =>
                      l10n.videoEditorEffectTimingReset,
                    EffectSettingGroup.look => l10n.videoEditorEffectLookReset,
                    EffectSettingGroup.motion =>
                      l10n.videoEditorEffectMotionReset,
                  },
                  leadingIcon: DivineIconName.arrowCounterClockwise,
                  size: .small,
                  type: .secondary,
                  onPressed: changed
                      ? () => context
                            .read<VideoEditorEffectsCubit>()
                            .resetSettings(group)
                      : null,
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
  EffectSettingLabel.horizontalOption =>
    l10n.videoEditorEffectSettingHorizontal,
  EffectSettingLabel.verticalOption => l10n.videoEditorEffectSettingVertical,
  EffectSettingLabel.clockwise => l10n.videoEditorEffectSettingClockwise,
  EffectSettingLabel.anticlockwise =>
    l10n.videoEditorEffectSettingAnticlockwise,
  EffectSettingLabel.zoomIn => l10n.videoEditorEffectSettingZoomIn,
  EffectSettingLabel.zoomOut => l10n.videoEditorEffectSettingZoomOut,
};

/// The control of one [setting] of the picked effect, at [value], as it is
/// stored: a slider, a colour row, a switch, a row of options or a shuffle
/// button.
class _SettingControl extends StatelessWidget {
  const _SettingControl({
    required this.setting,
    required this.value,
    super.key,
  });

  final EffectSetting setting;
  final Object value;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = effectSettingLabel(l10n, setting.label);
    final cubit = context.read<VideoEditorEffectsCubit>();
    void set(Object value) => cubit.setSetting(setting.key, value);
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
          onChanged: (value) => set(slider.paramOf(value)),
        ),
      ),
      EffectColorSetting() => _ColorControl(
        label: label,
        color: colorFromArgb32(value as int),
        onChanged: (color) => set(color.toARGB32()),
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
        onChanged: set,
      ),
      final EffectChoiceSetting choice => Padding(
        padding: padding,
        child: _ChoiceControl(
          label: label,
          choices: choice.choices,
          selected: value as int,
          onChanged: set,
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
            onPressed: () => cubit.shuffle(setting.key),
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
class _Card extends StatelessWidget {
  const _Card({required this.child});

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
