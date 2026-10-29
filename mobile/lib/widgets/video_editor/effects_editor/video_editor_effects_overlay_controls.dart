// ABOUTME: Overlay controls of the video effects editor: close/done toolbar,
// ABOUTME: intensity slider, on-the-beat switch, the drops' settings and the
// ABOUTME: play/pause tap area.

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/effects_editor/video_editor_effects_cubit.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/drops_effect_settings.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/widgets/video_editor/effects_editor/flashing_effect_snack_bar.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';
import 'package:openvine/widgets/video_editor/video_editor_vertical_slider.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show VideoEffectPreview;

/// Overlay controls for the effects editor.
///
/// Shows a vertical intensity slider on the right while an effect is picked,
/// a switch to fire it on the beat when it can, the settings of the drops
/// while they are picked, and says so when this device cannot preview effects
/// at all.
class VideoEditorEffectsOverlayControls extends StatelessWidget {
  const VideoEditorEffectsOverlayControls({super.key});

  @override
  Widget build(BuildContext context) {
    final hasEffect = context.select(
      (VideoEditorEffectsCubit c) => c.state.selectedType != null,
    );
    return Stack(
      fit: .expand,
      children: [
        Semantics(
          button: true,
          label: context.l10n.videoEditorPlayPauseSemanticLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.read<VideoEditorMainBloc>().add(
              const VideoEditorPlaybackToggleRequested(),
            ),
          ),
        ),
        Column(
          children: [
            const _TopBarContent(),
            // Everything else sits under the toolbar: the bar under the
            // preview is tall, so nothing may reach up behind it.
            Expanded(
              child: Stack(
                fit: .expand,
                children: [
                  const Align(
                    alignment: .bottomCenter,
                    child: _OnBeatSwitch(),
                  ),
                  const Align(
                    alignment: .bottomCenter,
                    child: _DropsSettingsCard(),
                  ),
                  // Centered between the toolbar and the bottom of the
                  // preview, where the on-the-beat switch sits.
                  Padding(
                    padding: const .only(
                      bottom: VideoEditorConstants.bottomBarHeight,
                    ),
                    child: Align(
                      alignment: .centerRight,
                      child: AnimatedSwitcher(
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween(
                                begin: const Offset(1, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        switchInCurve: Curves.easeInOut,
                        duration: const Duration(milliseconds: 220),
                        child: hasEffect
                            ? const _IntensitySlider()
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _IntensitySlider extends StatelessWidget {
  const _IntensitySlider();

  @override
  Widget build(BuildContext context) {
    final intensity = context.select(
      (VideoEditorEffectsCubit c) => c.state.intensity,
    );
    return Padding(
      padding: const .only(right: 16),
      child: LayoutBuilder(
        builder: (_, constraints) => VideoEditorVerticalSlider(
          height: min(300, constraints.maxHeight * 0.8),
          value: intensity,
          onChanged: context.read<VideoEditorEffectsCubit>().setIntensity,
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

/// Fires the picked effect on the beat of the music, for an effect that
/// [EditorEffectType.supportsOnBeat], with a line saying when there is no
/// beat to follow.
class _OnBeatSwitch extends StatelessWidget {
  const _OnBeatSwitch();

  @override
  Widget build(BuildContext context) {
    final canFire = context.select((VideoEditorEffectsCubit c) {
      final type = c.state.selectedType;
      return type != null && type.supportsOnBeat;
    });
    if (!canFire) return const SizedBox.shrink();
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
      child: Padding(
        padding: const .all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.vineColors.surfaceContainer,
              borderRadius: .circular(16),
            ),
            // The tile's ink needs a surface of its own over the video.
            child: Material(
              type: MaterialType.transparency,
              child: DivineSwitchTile(
                title: l10n.videoEditorEffectsOnBeat,
                subtitle: status,
                value: onBeat,
                onChanged: (value) => context
                    .read<VideoEditorEffectsCubit>()
                    .setOnBeat(onBeat: value),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The settings of the drops while they are picked: a card that opens to
/// sliders for how many drops there are, how large, how fast and how frosted
/// they are and how strong their colour fringes are, and a button that gives
/// them a new arrangement.
class _DropsSettingsCard extends StatelessWidget {
  const _DropsSettingsCard();

  /// Around the card, clear of the intensity slider on the right.
  static const EdgeInsets _margin = EdgeInsets.fromLTRB(16, 16, 72, 16);
  static const EdgeInsets _childrenPadding = EdgeInsets.fromLTRB(16, 0, 16, 16);

  /// A one-line [ListTile]'s height and the padding it keeps around a title
  /// taller than that, which the card's title row is.
  static const double _titleRowMinHeight = 56;
  static const double _titleRowVerticalPadding = 8;

  @override
  Widget build(BuildContext context) {
    final isDrops = context.select(
      (VideoEditorEffectsCubit c) =>
          c.state.selectedType == EditorEffectType.drops,
    );
    if (!isDrops) return const SizedBox.shrink();
    final l10n = context.l10n;
    final titleStyle = VineTheme.titleSmallFont(
      color: context.vineColors.onSurface,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final titleLine =
            MediaQuery.textScalerOf(context).scale(titleStyle.fontSize!) *
            (titleStyle.height ?? 1.2);
        final titleRow = max(
          _titleRowMinHeight,
          titleLine + 2 * _titleRowVerticalPadding,
        );
        // The settings scroll in what the area under the toolbar leaves
        // them, and never take more than 40% of the screen, so most of the
        // video stays in view.
        final settingsHeight = max(
          0.0,
          min(
            MediaQuery.sizeOf(context).height * 0.4,
            constraints.maxHeight -
                _margin.vertical -
                titleRow -
                _childrenPadding.vertical,
          ),
        );
        return Padding(
          padding: _margin,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.vineColors.surfaceContainer,
                borderRadius: .circular(16),
              ),
              // The tile's ink needs a surface of its own over the video.
              child: Material(
                type: MaterialType.transparency,
                child: ExpansionTile(
                  title: Text(
                    l10n.videoEditorDropsSettingsTitle,
                    style: titleStyle,
                  ),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  iconColor: context.vineColors.onSurface,
                  collapsedIconColor: context.vineColors.onSurface,
                  childrenPadding: _childrenPadding,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: settingsHeight),
                      child: const SingleChildScrollView(
                        child: _DropsSettings(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

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
    return Column(
      crossAxisAlignment: .start,
      spacing: 8,
      children: [
        _DropsSlider(
          label: l10n.videoEditorDropsCountLabel,
          value: settings.count.toDouble(),
          format: (value) => '${value.round()}',
          min: DropsEffectSettings.minCount.toDouble(),
          max: DropsEffectSettings.maxCount.toDouble(),
          divisions:
              DropsEffectSettings.maxCount - DropsEffectSettings.minCount,
          onChanged: (value) => update((s) => s.copyWith(count: value.round())),
        ),
        _DropsSlider(
          label: l10n.videoEditorDropsSizeLabel,
          value: settings.size,
          onChanged: (value) => update((s) => s.copyWith(size: value)),
        ),
        _DropsSlider(
          label: l10n.videoEditorDropsSpeedLabel,
          value: settings.speed,
          onChanged: (value) => update((s) => s.copyWith(speed: value)),
        ),
        _DropsSlider(
          label: l10n.videoEditorDropsFrostLabel,
          value: settings.frost,
          onChanged: (value) => update((s) => s.copyWith(frost: value)),
        ),
        _DropsSlider(
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
    );
  }
}

/// A labelled slider of the drops' settings, with its value on the right:
/// a share from 0 to 100 unless [format] says otherwise.
class _DropsSlider extends StatelessWidget {
  const _DropsSlider({
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

class _TopBarContent extends StatelessWidget {
  const _TopBarContent();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VideoEditorEffectsCubit>();
    final mainBloc = context.read<VideoEditorMainBloc>();
    final scope = VideoEditorScope.of(context);
    final toolName = context.l10n.videoEditorEffectsLabel;

    return Align(
      alignment: .topCenter,
      child: Column(
        mainAxisSize: .min,
        children: [
          VideoEditorToolbar(
            closeSemanticLabel: context.l10n
                .videoEditorDiscardToolChangesSemanticLabel(toolName),
            doneSemanticLabel: context.l10n
                .videoEditorApplyToolChangesSemanticLabel(toolName),
            onClose: () {
              cubit.cancel();
              mainBloc.add(const VideoEditorMainSubEditorClosed());
            },
            onDone: () {
              final result = cubit.confirm();
              scope.editor?.setVideoEffectEntries(result.effects);
              if (result.replacedFlashing) {
                showFlashingEffectReplacedSnackBar(context);
              }
              mainBloc.add(const VideoEditorMainSubEditorClosed());
            },
          ),
          const _PreviewUnavailableNotice(),
        ],
      ),
    );
  }
}

/// Says so when this device cannot show effects in the preview.
///
/// Without it the preview would quietly show the plain video, which reads as
/// "the effect does nothing" rather than "you can't see it here".
class _PreviewUnavailableNotice extends StatefulWidget {
  const _PreviewUnavailableNotice();

  @override
  State<_PreviewUnavailableNotice> createState() =>
      _PreviewUnavailableNoticeState();
}

class _PreviewUnavailableNoticeState extends State<_PreviewUnavailableNotice> {
  late final Future<bool> _canPreview = VideoEffectPreview.precache();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _canPreview,
      builder: (context, snapshot) {
        if (snapshot.data != false) return const SizedBox.shrink();
        return Padding(
          padding: const .symmetric(horizontal: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.vineColors.surfaceContainer,
              borderRadius: .circular(12),
            ),
            child: Padding(
              padding: const .symmetric(horizontal: 12, vertical: 8),
              child: Text(
                context.l10n.videoEditorChromaKeyPreviewUnavailable,
                textAlign: .center,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
