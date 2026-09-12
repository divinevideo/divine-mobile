// ABOUTME: Bottom sheet for adjusting the playback speed of the selected clip.
// ABOUTME: Returns the chosen speed multiplier as a double via context.pop.

import 'package:divine_ui/divine_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';

class VideoEditorClipSpeedSheet extends StatefulWidget {
  const VideoEditorClipSpeedSheet({super.key, this.initialSpeed = 1.0});

  final double initialSpeed;

  @override
  State<VideoEditorClipSpeedSheet> createState() =>
      _VideoEditorClipSpeedSheetState();
}

class _VideoEditorClipSpeedSheetState extends State<VideoEditorClipSpeedSheet> {
  late final ValueNotifier<double> _speed;

  @override
  void initState() {
    super.initState();
    _speed = ValueNotifier(
      widget.initialSpeed.clamp(
        VideoEditorConstants.clipSpeedMin,
        VideoEditorConstants.clipSpeedMax,
      ),
    );
  }

  @override
  void dispose() {
    _speed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                onPressed: () => context.pop<double>(),
              ),
              Flexible(
                child: Text(
                  context.l10n.videoEditorSpeedSheetTitle,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ),
              DivineIconButton(
                icon: DivineIconName.check,
                size: DivineIconButtonSize.small,
                onPressed: () => context.pop<double>(_speed.value),
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
        _SpeedControlBar(speed: _speed),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SpeedControlBar extends StatelessWidget {
  const _SpeedControlBar({required this.speed});

  final ValueNotifier<double> speed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          ValueListenableBuilder<double>(
            valueListenable: speed,
            builder: (_, value, _) => _SpeedLabelRow(value: value),
          ),
          ValueListenableBuilder<double>(
            valueListenable: speed,
            builder: (_, value, _) => DivineSlider(
              value: value,
              min: VideoEditorConstants.clipSpeedMin,
              max: VideoEditorConstants.clipSpeedMax,
              divisions:
                  ((VideoEditorConstants.clipSpeedMax -
                              VideoEditorConstants.clipSpeedMin) /
                          VideoEditorConstants.clipSpeedStep)
                      .round(),
              onChanged: (v) => speed.value = v,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedLabelRow extends StatelessWidget {
  const _SpeedLabelRow({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          context.l10n.videoEditorSpeedLabel,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        Text(
          '${value.toStringAsFixed(2)}×',
          style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
        ),
      ],
    );
  }
}
