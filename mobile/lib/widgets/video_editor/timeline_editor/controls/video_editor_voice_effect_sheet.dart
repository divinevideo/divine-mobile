// ABOUTME: Bottom sheet for giving a timeline sound a voice effect and noise
// ABOUTME: reduction, looping each setting; pops the processed track or null.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show AudioEvent, VoiceEffect;
import 'package:openvine/blocs/video_editor/voice_effect/voice_effect_bloc.dart';
import 'package:openvine/blocs/video_editor/voice_effect/voice_effect_preset.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/voice_effect_providers.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/animation_picker_components.dart';

/// Lets the creator hear and pick a voice effect and noise reduction for the
/// timeline sound [track] — a voice-over, music or any other track.
///
/// Every setting loops while the sheet is open, so it is heard before it is
/// kept. The sound is processed when the creator confirms, while the sheet
/// stays open; it then pops the processed [AudioEvent], or `null` when the
/// pick matches what the track already plays or the sheet is dismissed.
class VideoEditorVoiceEffectSheet extends ConsumerWidget {
  /// Creates the sheet for [track].
  const VideoEditorVoiceEffectSheet({required this.track, super.key});

  /// Opens the sheet with cancellation controlled by its saving state.
  static Future<AudioEvent?> show({
    required BuildContext context,
    required AudioEvent track,
  }) => VineBottomSheet.show<AudioEvent>(
    context: context,
    expanded: false,
    scrollable: false,
    isScrollControlled: true,
    // Modal drag dismissal bypasses PopScope, unlike back and barrier taps.
    enableDrag: false,
    body: VideoEditorVoiceEffectSheet(track: track),
  );

  /// The sound as it is on the timeline.
  final AudioEvent track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocProvider(
      create: (_) => VoiceEffectBloc(
        track: track,
        service: ref.read(voiceEffectServiceProvider),
        player: ref.read(voiceEffectAuditionPlayerFactoryProvider)(),
      )..add(const VoiceEffectSettingsChanged()),
      child: const VideoEditorVoiceEffectView(),
    );
  }
}

/// UI of [VideoEditorVoiceEffectSheet], testable with a mock bloc.
class VideoEditorVoiceEffectView extends StatelessWidget {
  /// Creates the view.
  @visibleForTesting
  const VideoEditorVoiceEffectView({super.key});

  @override
  Widget build(BuildContext context) {
    final isApplying = context.select(
      (VoiceEffectBloc bloc) => bloc.state.isApplying,
    );
    return PopScope(
      canPop: !isApplying,
      child: MultiBlocListener(
        listeners: [
          BlocListener<VoiceEffectBloc, VoiceEffectState>(
            listenWhen: (previous, current) =>
                previous.status != current.status &&
                current.status == VoiceEffectStatus.done,
            listener: (context, state) => context.pop<AudioEvent>(state.result),
          ),
          // The failure text is red under the controls, which a screen-reader
          // user would never find; say it.
          BlocListener<VoiceEffectBloc, VoiceEffectState>(
            listenWhen: (previous, current) =>
                previous.status != current.status &&
                current.status == VoiceEffectStatus.failure,
            listener: (context, _) => SemanticsService.sendAnnouncement(
              View.of(context),
              context.l10n.videoEditorVoiceEffectFailed,
              Directionality.of(context),
            ),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Header(),
            Divider(
              height: 2,
              thickness: 2,
              color: context.vineColors.surfaceContainer,
            ),
            const SizedBox(height: 16),
            const _PresetRow(),
            const SizedBox(height: 16),
            const _EffectSliders(),
            const SizedBox(height: 8),
            const _NoiseReductionTile(),
            const _FailureMessage(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isApplying = context.select(
      (VoiceEffectBloc bloc) => bloc.state.isApplying,
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 8,
        children: [
          DivineIconButton(
            icon: DivineIconName.x,
            type: DivineIconButtonType.secondary,
            size: DivineIconButtonSize.small,
            semanticLabel: l10n.commonCancel,
            onPressed: isApplying ? null : () => context.pop<AudioEvent>(),
          ),
          Flexible(
            child: Text(
              l10n.videoEditorVoiceEffectSheetTitle,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.primaryText,
              ),
            ),
          ),
          if (isApplying)
            Semantics(
              label: l10n.videoEditorVoiceEffectApplying,
              child: const SizedBox.square(
                dimension: 40,
                child: Center(child: BrandedLoadingIndicator(size: 24)),
              ),
            )
          else
            DivineIconButton(
              icon: DivineIconName.check,
              size: DivineIconButtonSize.small,
              semanticLabel: l10n.videoEditorDoneLabel,
              onPressed: () => context.read<VoiceEffectBloc>().add(
                const VoiceEffectApplyRequested(),
              ),
            ),
        ],
      ),
    );
  }
}

/// The presets, in one row that scrolls sideways once it outgrows the sheet.
class _PresetRow extends StatelessWidget {
  const _PresetRow();

  @override
  Widget build(BuildContext context) {
    final selected = context.select(
      (VoiceEffectBloc bloc) => bloc.state.preset,
    );
    final isApplying = context.select(
      (VoiceEffectBloc bloc) => bloc.state.isApplying,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        spacing: 8,
        children: [
          for (final preset in VoiceEffectPreset.values)
            _PresetChip(
              preset: preset,
              selected: preset == selected,
              onTap: isApplying
                  ? null
                  : () => context.read<VoiceEffectBloc>().add(
                      VoiceEffectSettingsChanged(effect: preset.effect),
                    ),
            ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final VoiceEffectPreset preset;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = switch (preset) {
      VoiceEffectPreset.original => l10n.videoEditorVoiceEffectOriginal,
      VoiceEffectPreset.highPitch => l10n.videoEditorVoiceEffectHighPitch,
      VoiceEffectPreset.lowPitch => l10n.videoEditorVoiceEffectLowPitch,
      VoiceEffectPreset.robot => l10n.videoEditorVoiceEffectRobot,
      VoiceEffectPreset.echo => l10n.videoEditorVoiceEffectEcho,
    };
    final colors = context.vineColors;
    return AnimationPickerChip(
      selected: selected,
      onTap: onTap,
      semanticLabel: label,
      child: ExcludeSemantics(
        child: Text(
          label,
          maxLines: 1,
          style: VineTheme.labelMediumFont(
            color: selected ? colors.accentBrand : colors.secondaryText,
          ),
        ),
      ),
    );
  }
}

/// A slider per change the effect makes, for settings no preset covers.
class _EffectSliders extends StatelessWidget {
  const _EffectSliders();

  /// Robot and echo move in steps of this many percent.
  static const _amountStep = 5;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final effect = context.select(
      (VoiceEffectBloc bloc) => bloc.state.effect,
    );
    final pitch = effect.pitch;
    final percent = NumberFormat.percentPattern(
      Localizations.localeOf(context).toString(),
    );
    String amount(int value) => percent.format(value / VoiceEffect.maxAmount);
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        _EffectSlider(
          label: l10n.videoEditorVoiceEffectPitch,
          valueLabel: pitch > 0 ? '+$pitch' : '$pitch',
          value: pitch,
          min: VoiceEffect.minPitch,
          max: VoiceEffect.maxPitch,
          step: 1,
          toEffect: (value) => effect.copyWith(pitch: value),
        ),
        _EffectSlider(
          label: l10n.videoEditorVoiceEffectRobot,
          valueLabel: amount(effect.robot),
          value: effect.robot,
          max: VoiceEffect.maxAmount,
          step: _amountStep,
          toEffect: (value) => effect.copyWith(robot: value),
        ),
        _EffectSlider(
          label: l10n.videoEditorVoiceEffectEcho,
          valueLabel: amount(effect.echo),
          value: effect.echo,
          max: VoiceEffect.maxAmount,
          step: _amountStep,
          toEffect: (value) => effect.copyWith(echo: value),
        ),
      ],
    );
  }
}

/// One change's label, value and slider.
///
/// Dragging updates the setting as it goes; the sound is rendered and heard
/// once the finger lifts.
class _EffectSlider extends StatelessWidget {
  const _EffectSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.max,
    required this.step,
    required this.toEffect,
    this.min = 0,
  });

  final String label;
  final String valueLabel;
  final int value;
  final int min;
  final int max;
  final int step;
  final VoiceEffect Function(int value) toEffect;

  void _change(BuildContext context, double value, {required bool audition}) {
    context.read<VoiceEffectBloc>().add(
      VoiceEffectSettingsChanged(
        effect: toEffect((value / step).round() * step),
        audition: audition,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isApplying = context.select(
      (VoiceEffectBloc bloc) => bloc.state.isApplying,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.primaryText,
                ),
              ),
              Text(
                valueLabel,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.mutedText,
                ),
              ),
            ],
          ),
          DivineSlider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: (max - min) ~/ step,
            semanticLabel: label,
            onChanged: isApplying
                ? null
                : (value) => _change(context, value, audition: false),
            onChangeEnd: isApplying
                ? null
                : (value) => _change(context, value, audition: true),
          ),
        ],
      ),
    );
  }
}

class _NoiseReductionTile extends StatelessWidget {
  const _NoiseReductionTile();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = context.select(
      (VoiceEffectBloc bloc) => bloc.state.noiseReduction,
    );
    final isApplying = context.select(
      (VoiceEffectBloc bloc) => bloc.state.isApplying,
    );
    // The sheet body sits on a ColoredBox, which would hide the tile's ink;
    // a transparent Material gives it a surface of its own.
    return Material(
      type: MaterialType.transparency,
      child: DivineSwitchTile(
        title: l10n.videoEditorVoiceEffectNoiseReduction,
        subtitle: l10n.videoEditorVoiceEffectNoiseReductionSubtitle,
        value: enabled,
        onChanged: isApplying
            ? null
            : (value) => context.read<VoiceEffectBloc>().add(
                VoiceEffectSettingsChanged(noiseReduction: value),
              ),
      ),
    );
  }
}

class _FailureMessage extends StatelessWidget {
  const _FailureMessage();

  @override
  Widget build(BuildContext context) {
    final failed = context.select(
      (VoiceEffectBloc bloc) => bloc.state.status == VoiceEffectStatus.failure,
    );
    if (!failed) return const SizedBox.shrink();
    final color = context.vineColors.onErrorContainer;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          ExcludeSemantics(
            child: DivineIcon(
              icon: DivineIconName.warning,
              size: 18,
              color: color,
            ),
          ),
          Expanded(
            child: Text(
              context.l10n.videoEditorVoiceEffectFailed,
              style: VineTheme.bodySmallFont(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
