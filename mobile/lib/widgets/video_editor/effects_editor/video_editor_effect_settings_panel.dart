// ABOUTME: The settings of the picked video effect, shown in the effects
// ABOUTME: editor's bottom bar in place of the effects picker.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/effects_editor/video_editor_effects_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/drops_effect_settings.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/models/video_editor/hit_look_settings.dart';
import 'package:openvine/models/video_editor/hit_timing_settings.dart';
import 'package:openvine/widgets/video_editor/effects_editor/video_editor_effects_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_row.dart';

/// The settings of the picked effect: whether it fires on the beat, how long
/// its hits last and how often they come, where and how hard they hit and in
/// which colour, and how the drops look, each only for an effect it applies
/// to.
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
                if (type.hitTiming != null) ...const [
                  _HitTimingSettings(),
                  _HitLookSettings(),
                ],
                if (type == EditorEffectType.drops) const _DropsSettings(),
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

/// How long the hits of the picked effect last and, when it does not follow
/// the beat, whether it hits again and again or once where it starts.
class _HitTimingSettings extends StatelessWidget {
  const _HitTimingSettings();

  @override
  Widget build(BuildContext context) {
    final timing = context.select(
      (VideoEditorEffectsCubit c) => c.state.selectedHitTiming,
    );
    final onBeat = context.select(
      (VideoEditorEffectsCubit c) => c.state.selectionOnBeat,
    );
    if (timing == null) return const SizedBox.shrink();
    final cubit = context.read<VideoEditorEffectsCubit>();
    final l10n = context.l10n;
    // Each change starts from the cubit's latest settings, so quick drags on
    // one slider never undo another.
    void update(HitTimingSettings Function(HitTimingSettings) change) {
      final current = cubit.state.selectedHitTiming;
      if (current != null) cubit.setHitTiming(change(current));
    }

    String seconds(double value) => l10n.videoEditorEffectSeconds(value);
    return Column(
      crossAxisAlignment: .stretch,
      spacing: 8,
      children: [
        _Card(
          child: Padding(
            padding: const .fromLTRB(16, 12, 16, 4),
            child: _SettingsSlider(
              label: l10n.videoEditorEffectHitDuration,
              value: timing.duration.inMilliseconds / 1000,
              min: HitTimingSettings.minDuration.inMilliseconds / 1000,
              max: HitTimingSettings.maxDuration.inMilliseconds / 1000,
              divisions: 28,
              format: seconds,
              onChanged: (value) => update(
                (t) => t.copyWith(duration: _secondsToDuration(value)),
              ),
            ),
          ),
        ),
        if (!onBeat)
          _Card(
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                DivineSwitchTile(
                  title: l10n.videoEditorEffectHitRepeat,
                  subtitle: timing.repeats
                      ? null
                      : l10n.videoEditorEffectHitOnce,
                  value: timing.repeats,
                  onChanged: (value) =>
                      update((t) => t.copyWith(repeats: value)),
                ),
                if (timing.repeats)
                  Padding(
                    padding: const .fromLTRB(16, 0, 16, 4),
                    child: _SettingsSlider(
                      label: l10n.videoEditorEffectHitInterval,
                      value: timing.interval.inMilliseconds / 1000,
                      min: HitTimingSettings.minInterval.inMilliseconds / 1000,
                      max: HitTimingSettings.maxInterval.inMilliseconds / 1000,
                      divisions: 36,
                      format: seconds,
                      onChanged: (value) => update(
                        (t) => t.copyWith(interval: _secondsToDuration(value)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// [seconds] rounded to the tenth the sliders step in.
  static Duration _secondsToDuration(double seconds) =>
      Duration(milliseconds: (seconds * 10).round() * 100);
}

/// Where the picked effect that hits comes from, how far it spreads, how hard
/// it shakes the picture and punches in, and, for a blast, its colour; with
/// a button that puts it all back.
class _HitLookSettings extends StatelessWidget {
  const _HitLookSettings();

  @override
  Widget build(BuildContext context) {
    final look = context.select(
      (VideoEditorEffectsCubit c) => c.state.selectedHitLook,
    );
    final type = context.select(
      (VideoEditorEffectsCubit c) => c.state.selectedType,
    );
    if (look == null || type == null) return const SizedBox.shrink();
    final cubit = context.read<VideoEditorEffectsCubit>();
    final l10n = context.l10n;
    // Each change starts from the cubit's latest settings, so quick drags on
    // one slider never undo another.
    void update(HitLookSettings Function(HitLookSettings) change) {
      final current = cubit.state.selectedHitLook;
      if (current != null) cubit.setHitLook(change(current));
    }

    final ownColor = type.hitColor;
    final color = colorFromArgb32(look.color ?? ownColor ?? 0xFFFFFFFF);
    Future<void> pickColor() async {
      final picked = await showFullColorPicker(context, initialColor: color);
      if (picked != null) update((l) => l.copyWith(color: picked.toARGB32()));
    }

    final isSubwoofer = type == EditorEffectType.subwoofer;
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
                  l10n.videoEditorEffectLookTitle,
                  style: VineTheme.titleSmallFont(
                    color: context.vineColors.onSurface,
                  ),
                ),
              ),
            ),
            if (ownColor != null)
              VideoEditorColorRow(
                selected: color,
                onSelected: (picked) =>
                    update((l) => l.copyWith(color: picked.toARGB32())),
                onCustom: pickColor,
                padding: const .symmetric(horizontal: 16),
                semanticLabel: l10n.videoEditorTuneColor,
              ),
            Padding(
              padding: const .symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: .start,
                spacing: 8,
                children: [
                  _SettingsSlider(
                    label: l10n.videoEditorEffectHitHorizontal,
                    value: look.centerX,
                    onChanged: (value) =>
                        update((l) => l.copyWith(centerX: value)),
                  ),
                  _SettingsSlider(
                    label: l10n.videoEditorEffectHitVertical,
                    value: look.centerY,
                    onChanged: (value) =>
                        update((l) => l.copyWith(centerY: value)),
                  ),
                  _SettingsSlider(
                    label: isSubwoofer
                        ? l10n.videoEditorDropsSizeLabel
                        : l10n.videoEditorEffectHitReach,
                    value: look.reach,
                    min: HitLookSettings.minReach,
                    onChanged: (value) =>
                        update((l) => l.copyWith(reach: value)),
                  ),
                  _SettingsSlider(
                    label: l10n.videoEditorEffectHitShake,
                    value: look.shake,
                    max: HitLookSettings.maxScale,
                    onChanged: (value) =>
                        update((l) => l.copyWith(shake: value)),
                  ),
                  // The subwoofer's cone is its punch.
                  if (!isSubwoofer)
                    _SettingsSlider(
                      label: l10n.videoEditorEffectHitPunch,
                      value: look.punch,
                      max: HitLookSettings.maxScale,
                      onChanged: (value) =>
                          update((l) => l.copyWith(punch: value)),
                    ),
                  if (type == EditorEffectType.shockwave)
                    _SettingsSlider(
                      label: l10n.videoEditorDropsFringesLabel,
                      value: look.fringe,
                      max: HitLookSettings.maxScale,
                      onChanged: (value) =>
                          update((l) => l.copyWith(fringe: value)),
                    ),
                  DivineButton(
                    label: l10n.videoEditorEffectLookReset,
                    leadingIcon: DivineIconName.arrowCounterClockwise,
                    size: .small,
                    type: .secondary,
                    onPressed: cubit.resetHitLook,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How the drops look: sliders for how many drops there are, how large, how
/// fast and how frosted they are and how strong their colour fringes are,
/// and a button that gives them a new arrangement.
class _DropsSettings extends StatelessWidget {
  const _DropsSettings();

  @override
  Widget build(BuildContext context) {
    final settings = context.select(
      (VideoEditorEffectsCubit c) => c.state.dropsSettings,
    );
    final cubit = context.read<VideoEditorEffectsCubit>();
    final l10n = context.l10n;
    // Each change starts from the cubit's latest settings, so quick drags on
    // one slider never undo another.
    void update(DropsEffectSettings Function(DropsEffectSettings) change) =>
        cubit.setDropsSettings(change(cubit.state.dropsSettings));
    return _Card(
      child: Padding(
        padding: const .all(16),
        child: Column(
          crossAxisAlignment: .start,
          spacing: 8,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.videoEditorDropsSettingsTitle,
                style: VineTheme.titleSmallFont(
                  color: context.vineColors.onSurface,
                ),
              ),
            ),
            _SettingsSlider(
              label: l10n.videoEditorDropsCountLabel,
              value: settings.count.toDouble(),
              format: (value) => '${value.round()}',
              min: DropsEffectSettings.minCount.toDouble(),
              max: DropsEffectSettings.maxCount.toDouble(),
              divisions:
                  DropsEffectSettings.maxCount - DropsEffectSettings.minCount,
              onChanged: (value) =>
                  update((s) => s.copyWith(count: value.round())),
            ),
            _SettingsSlider(
              label: l10n.videoEditorDropsSizeLabel,
              value: settings.size,
              onChanged: (value) => update((s) => s.copyWith(size: value)),
            ),
            _SettingsSlider(
              label: l10n.videoEditorDropsSpeedLabel,
              value: settings.speed,
              onChanged: (value) => update((s) => s.copyWith(speed: value)),
            ),
            _SettingsSlider(
              label: l10n.videoEditorDropsFrostLabel,
              value: settings.frost,
              onChanged: (value) => update((s) => s.copyWith(frost: value)),
            ),
            _SettingsSlider(
              label: l10n.videoEditorDropsFringesLabel,
              value: settings.fringes,
              onChanged: (value) => update((s) => s.copyWith(fringes: value)),
            ),
            DivineButton(
              label: l10n.videoEditorDropsShuffle,
              leadingIcon: DivineIconName.arrowsClockwise,
              size: .small,
              type: .secondary,
              onPressed: cubit.shuffleDrops,
            ),
          ],
        ),
      ),
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
