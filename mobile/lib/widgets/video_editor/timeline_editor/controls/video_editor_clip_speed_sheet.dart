// ABOUTME: Bottom sheet for adjusting the playback speed of the selected clip,
// ABOUTME: via one-tap presets or a slider; pops the chosen speed as a double.

import 'package:divine_ui/divine_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';

/// The slider computes its discrete values in floating point, so a preset
/// counts as selected when the speed is within this distance of it.
const double _presetTolerance = 1e-6;

const double _minTapTarget = 48;

const double _chipGap = 8;

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
          ValueListenableBuilder<double>(
            valueListenable: speed,
            builder: (_, value, _) => _SpeedPresetRow(
              value: value,
              onSelected: (preset) => speed.value = preset,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedPresetRow extends StatelessWidget {
  const _SpeedPresetRow({required this.value, required this.onSelected});

  final double value;
  final ValueChanged<double> onSelected;

  static int _columnsFor(double width, int count) {
    if (count <= 1 || width <= 0) return 1;
    var columns = count;
    while (columns > 1) {
      final slot = (width - _chipGap * (columns - 1)) / columns;
      if (slot >= _minTapTarget) return columns;
      columns--;
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    const presets = VideoEditorConstants.clipSpeedPresets;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.maxWidth, presets.length);
        final slot =
            (constraints.maxWidth - _chipGap * (columns - 1)) / columns;
        return Wrap(
          spacing: _chipGap,
          runSpacing: _chipGap,
          children: [
            for (final preset in presets)
              SizedBox(
                width: slot,
                child: _SpeedPresetChip(
                  preset: preset,
                  selected: (value - preset).abs() < _presetTolerance,
                  onTap: () => onSelected(preset),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SpeedPresetChip extends StatelessWidget {
  const _SpeedPresetChip({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final double preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 0.50 -> "0.5", 1.00 -> "1": presets read as short, familiar speeds.
    final label = preset.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
    final colors = context.vineColors;
    return Semantics(
      button: true,
      selected: selected,
      label: context.l10n.videoEditorSpeedPresetSemanticLabel(label),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _minTapTarget,
            minHeight: _minTapTarget,
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: selected
                      ? colors.controlSelectedFill
                      : colors.controlFill,
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: selected
                          ? colors.accentBrand
                          : colors.controlOutline,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      '$label×',
                      maxLines: 1,
                      style: VineTheme.labelMediumFont(
                        color: selected
                            ? colors.accentBrand
                            : colors.secondaryText,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
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
