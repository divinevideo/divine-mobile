// ABOUTME: The settings of the picked video effect, shown in the effects
// ABOUTME: editor's bottom bar in place of the effects picker.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/effects_editor/video_editor_effects_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/effect_setting.dart';
import 'package:openvine/models/video_editor/effect_settings_catalog.dart';
import 'package:openvine/widgets/video_editor/effects_editor/video_editor_effects_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/video_editor_settings_panel.dart';

/// The settings of the picked effect: whether it fires on the beat, then one
/// card per [EffectSettingGroup] of the settings [effectSettingsOf] lists for
/// it, each only for an effect it applies to.
///
/// It fills the bottom bar of the effects editor, under a row with a button
/// back to the effects picker, and scrolls on under the system navigation
/// bar.
class VideoEditorEffectSettingsPanel extends StatelessWidget {
  const VideoEditorEffectSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final type = context.select(
      (VideoEditorEffectsCubit c) => c.state.selectedType,
    );
    if (type == null) return const SizedBox.shrink();
    return VideoEditorSettingsPanel(
      title: context.l10n.videoEditorEffectSettingsTitle(
        videoEffectLabel(context, type),
      ),
      onBack: () =>
          context.read<VideoEditorEffectsCubit>().setSettingsOpen(open: false),
      children: [
        if (type.supportsOnBeat) const _OnBeatTile(),
        for (final group in EffectSettingGroup.values)
          _SettingsGroup(group: group),
      ],
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
      child: VideoEditorSettingsCard(
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
    final cubit = context.read<VideoEditorEffectsCubit>();
    return VideoEditorSettingsGroupCard(
      title: switch (group) {
        EffectSettingGroup.timing => l10n.videoEditorEffectTimingTitle,
        EffectSettingGroup.look => l10n.videoEditorEffectLookTitle,
        EffectSettingGroup.motion => l10n.videoEditorEffectMotionTitle,
      },
      settings: visible,
      values: values,
      onChanged: cubit.setSetting,
      onShuffle: cubit.shuffle,
      resetLabel: switch (group) {
        EffectSettingGroup.timing => l10n.videoEditorEffectTimingReset,
        EffectSettingGroup.look => l10n.videoEditorEffectLookReset,
        EffectSettingGroup.motion => l10n.videoEditorEffectMotionReset,
      },
      onReset: changed ? () => cubit.resetSettings(group) : null,
    );
  }
}
