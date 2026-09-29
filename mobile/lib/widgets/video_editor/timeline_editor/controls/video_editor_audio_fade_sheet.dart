// ABOUTME: Bottom sheet for setting how long the selected sound fades in and out.
// ABOUTME: Returns the chosen AudioFadeSelection via context.pop.

import 'package:divine_ui/divine_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';

/// A sound's fade in and fade out, as picked in [VideoEditorAudioFadeSheet].
typedef AudioFadeSelection = ({Duration fadeIn, Duration fadeOut});

/// Lets the creator pick how long a sound fades in and out.
///
/// Each fade can run the whole [soundLength] in
/// [VideoEditorConstants.audioFadeStep] steps, and the two together never
/// outlast it: lengthening one shortens the other where they would meet.
class VideoEditorAudioFadeSheet extends StatefulWidget {
  const VideoEditorAudioFadeSheet({
    required this.soundLength,
    this.initialFadeIn = Duration.zero,
    this.initialFadeOut = Duration.zero,
    super.key,
  });

  /// How long the sound plays on the timeline.
  final Duration soundLength;

  final Duration initialFadeIn;
  final Duration initialFadeOut;

  @override
  State<VideoEditorAudioFadeSheet> createState() =>
      _VideoEditorAudioFadeSheetState();
}

class _VideoEditorAudioFadeSheetState extends State<VideoEditorAudioFadeSheet> {
  late final Duration _maxFade;
  late final ValueNotifier<AudioFadeSelection> _fade;

  @override
  void initState() {
    super.initState();
    _maxFade = _snap(widget.soundLength);
    final fadeIn = _clampToMax(_snap(widget.initialFadeIn));
    _fade = ValueNotifier((
      fadeIn: fadeIn,
      fadeOut: _fitBeside(fadeIn, _clampToMax(_snap(widget.initialFadeOut))),
    ));
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  /// Rounds [value] down to a whole slider step.
  Duration _snap(Duration value) {
    final step = VideoEditorConstants.audioFadeStep.inMilliseconds;
    return Duration(milliseconds: value.inMilliseconds ~/ step * step);
  }

  Duration _clampToMax(Duration value) => value > _maxFade ? _maxFade : value;

  /// [fade] shortened so it and [other] fit into the sound together.
  Duration _fitBeside(Duration other, Duration fade) {
    final room = _snap(widget.soundLength - other);
    return fade > room ? room : fade;
  }

  void _setFadeIn(Duration fadeIn) {
    _fade.value = (
      fadeIn: fadeIn,
      fadeOut: _fitBeside(fadeIn, _fade.value.fadeOut),
    );
  }

  void _setFadeOut(Duration fadeOut) {
    _fade.value = (
      fadeIn: _fitBeside(fadeOut, _fade.value.fadeIn),
      fadeOut: fadeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
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
                onPressed: () => context.pop<AudioFadeSelection>(),
              ),
              Flexible(
                child: Text(
                  l10n.videoEditorFadeSheetTitle,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ),
              DivineIconButton(
                icon: DivineIconName.check,
                size: DivineIconButtonSize.small,
                semanticLabel: l10n.videoEditorDoneLabel,
                onPressed: () => context.pop<AudioFadeSelection>(_fade.value),
              ),
            ],
          ),
        ),
        Divider(
          height: 2,
          thickness: 2,
          color: context.vineColors.surfaceContainer,
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<AudioFadeSelection>(
          valueListenable: _fade,
          builder: (_, fade, _) => Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 24,
            children: [
              _FadeControl(
                label: l10n.videoEditorFadeInLabel,
                value: fade.fadeIn,
                max: _maxFade,
                onChanged: _setFadeIn,
              ),
              _FadeControl(
                label: l10n.videoEditorFadeOutLabel,
                value: fade.fadeOut,
                max: _maxFade,
                onChanged: _setFadeOut,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// One fade's label, value and slider.
class _FadeControl extends StatelessWidget {
  const _FadeControl({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final Duration value;
  final Duration max;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    final stepMs = VideoEditorConstants.audioFadeStep.inMilliseconds;
    final steps = max.inMilliseconds ~/ stepMs;
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
                '${(value.inMilliseconds / 1000).toStringAsFixed(1)}s',
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.mutedText,
                ),
              ),
            ],
          ),
          DivineSlider(
            value: value.inMilliseconds / 1000,
            max: max.inMilliseconds / 1000,
            divisions: steps > 0 ? steps : null,
            semanticLabel: label,
            onChanged: steps > 0
                ? (seconds) => onChanged(
                    Duration(
                      milliseconds: (seconds * 1000 / stepMs).round() * stepMs,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
