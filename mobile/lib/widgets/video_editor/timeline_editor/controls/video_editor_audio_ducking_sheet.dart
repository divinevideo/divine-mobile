// ABOUTME: Bottom sheet for letting the selected sound get quieter while a
// ABOUTME: voice-over talks. Returns the chosen AudioDuckingSelection via pop.

import 'package:divine_ui/divine_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Whether a sound ducks under the voice-over and how loud it stays while it
/// does, as picked in [VideoEditorAudioDuckingSheet].
typedef AudioDuckingSelection = ({bool enabled, double volume});

/// Lets the creator have a sound get quieter whenever a voice-over talks.
///
/// The slider sets how much quieter, from [minStrength] to 100 % in
/// [strengthStep]s; the sound then plays at the rest of its volume, which is
/// what [AudioDuckingSelection.volume] holds.
class VideoEditorAudioDuckingSheet extends StatefulWidget {
  const VideoEditorAudioDuckingSheet({
    required this.initialEnabled,
    required this.initialVolume,
    required this.hasVoiceOver,
    super.key,
  });

  /// Whether the sound ducks when the sheet opens.
  final bool initialEnabled;

  /// How loud the sound stays while ducked when the sheet opens, from 0 to 1.
  final double initialVolume;

  /// Whether the video has a voice-over the sound can duck under yet.
  final bool hasVoiceOver;

  /// The least a ducking sound goes down.
  static const double minStrength = 0.1;

  /// How far one slider step moves the strength.
  static const double strengthStep = 0.05;

  @override
  State<VideoEditorAudioDuckingSheet> createState() =>
      _VideoEditorAudioDuckingSheetState();
}

class _VideoEditorAudioDuckingSheetState
    extends State<VideoEditorAudioDuckingSheet> {
  late final ValueNotifier<AudioDuckingSelection> _selection;

  @override
  void initState() {
    super.initState();
    _selection = ValueNotifier((
      enabled: widget.initialEnabled,
      volume: _snapVolume(widget.initialVolume),
    ));
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  /// [volume] on a whole slider step and within the slider's range.
  static double _snapVolume(double volume) {
    const step = VideoEditorAudioDuckingSheet.strengthStep;
    final strength = ((1 - volume) / step).round() * step;
    return 1 - strength.clamp(VideoEditorAudioDuckingSheet.minStrength, 1.0);
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
                onPressed: () => context.pop<AudioDuckingSelection>(),
              ),
              Flexible(
                child: Text(
                  l10n.videoEditorDuckingSheetTitle,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ),
              DivineIconButton(
                icon: DivineIconName.check,
                size: DivineIconButtonSize.small,
                semanticLabel: l10n.videoEditorDoneLabel,
                onPressed: () =>
                    context.pop<AudioDuckingSelection>(_selection.value),
              ),
            ],
          ),
        ),
        Divider(
          height: 2,
          thickness: 2,
          color: context.vineColors.surfaceContainer,
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<AudioDuckingSelection>(
          valueListenable: _selection,
          builder: (_, selection, _) => Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              // The sheet body sits on a ColoredBox, which would hide the
              // tile's ink; a transparent Material gives it a surface of its
              // own.
              Material(
                type: MaterialType.transparency,
                child: DivineSwitchTile(
                  title: l10n.videoEditorDuckingSwitchLabel,
                  subtitle: widget.hasVoiceOver
                      ? l10n.videoEditorDuckingDescription
                      : l10n.videoEditorDuckingNoVoiceOverHint,
                  value: selection.enabled,
                  onChanged: (enabled) => _selection.value = (
                    enabled: enabled,
                    volume: selection.volume,
                  ),
                ),
              ),
              _StrengthControl(
                strength: 1 - selection.volume,
                onChanged: selection.enabled
                    ? (strength) => _selection.value = (
                        enabled: true,
                        volume: 1 - strength,
                      )
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// How much quieter the sound gets, as a label, a percentage and a slider.
class _StrengthControl extends StatelessWidget {
  const _StrengthControl({required this.strength, required this.onChanged});

  final double strength;

  /// Null while ducking is off.
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const min = VideoEditorAudioDuckingSheet.minStrength;
    const step = VideoEditorAudioDuckingSheet.strengthStep;
    final percentFormat = NumberFormat.percentPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final percent = percentFormat.format(strength);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Opacity(
        opacity: onChanged == null ? DivineSwitchTile.disabledOpacity : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              spacing: 8,
              children: [
                // Wraps under large text sizes and long translations, so the
                // percentage stays on the sheet.
                Expanded(
                  child: Text(
                    l10n.videoEditorDuckingStrengthLabel,
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                ),
                Text(
                  percent,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.mutedText,
                  ),
                ),
              ],
            ),
            DivineSlider(
              value: strength,
              min: min,
              divisions: ((1 - min) / step).round(),
              semanticLabel: l10n.videoEditorDuckingStrengthLabel,
              semanticValue: percentFormat.format,
              onChanged: onChanged == null
                  ? null
                  : (value) => onChanged!((value / step).round() * step),
            ),
          ],
        ),
      ),
    );
  }
}
