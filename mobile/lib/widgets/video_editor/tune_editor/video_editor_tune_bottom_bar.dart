// ABOUTME: Bottom bar for the video editor tune adjustments.
// ABOUTME: Shows a slider for the selected adjustment and selectable chips.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';

/// Localized display name for a tune adjustment [id].
String tuneAdjustmentLabel(BuildContext context, String id) {
  final l10n = context.l10n;
  return switch (id) {
    'brightness' => l10n.videoEditorTuneBrightness,
    'contrast' => l10n.videoEditorTuneContrast,
    'saturation' => l10n.videoEditorTuneSaturation,
    'exposure' => l10n.videoEditorTuneExposure,
    'hue' => l10n.videoEditorTuneHue,
    'temperature' => l10n.videoEditorTuneTemperature,
    'tint' => l10n.videoEditorTuneTint,
    'fade' => l10n.videoEditorTuneFade,
    _ => id,
  };
}

/// Formats a tune adjustment [value] for display using its [labelMultiplier].
String tuneAdjustmentValueLabel(double value, double labelMultiplier) =>
    (value * labelMultiplier).round().toString();

/// Bottom bar for the tune editor.
///
/// Displays a horizontal slider that drives the currently selected adjustment
/// and a scrollable row of chips (one per adjustment) showing each adjustment's
/// name and current value.
class VideoEditorTuneBottomBar extends StatelessWidget {
  const VideoEditorTuneBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.25);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: const Column(
        mainAxisSize: .min,
        mainAxisAlignment: .center,
        children: [
          SizedBox(height: 34, child: _TuneSlider()),
          SizedBox(height: 52, child: _TuneChips()),
        ],
      ),
    );
  }
}

class _TuneSlider extends StatelessWidget {
  const _TuneSlider();

  @override
  Widget build(BuildContext context) {
    final adjustment = context.select(
      (VideoEditorTuneBloc b) => b.state.selectedAdjustment,
    );
    final value = context.select(
      (VideoEditorTuneBloc b) => b.state.selectedValue,
    );
    final scope = VideoEditorScope.of(context);
    final label = tuneAdjustmentLabel(context, adjustment.id);

    return Padding(
      padding: const .symmetric(horizontal: 16),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3,
          activeTrackColor: context.vineColors.accentPositive,
          inactiveTrackColor: context.vineColors.outlineMuted,
          thumbColor: context.vineColors.accentPositive,
          overlayColor: context.vineColors.accentPositive.withValues(
            alpha: 0.12,
          ),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          valueIndicatorColor: context.vineColors.surfaceContainer,
          valueIndicatorTextStyle: VineTheme.bodySmallFont(
            color: context.vineColors.primaryText,
          ),
        ),
        child: Slider(
          min: adjustment.min,
          max: adjustment.max,
          divisions: adjustment.divisions,
          value: value.clamp(adjustment.min, adjustment.max),
          label: tuneAdjustmentValueLabel(value, adjustment.labelMultiplier),
          semanticFormatterCallback: (v) =>
              '$label ${tuneAdjustmentValueLabel(v, adjustment.labelMultiplier)}',
          onChangeStart: (v) {
            scope.tuneEditor
              ?..selectedIndex = context
                  .read<VideoEditorTuneBloc>()
                  .state
                  .selectedIndex
              ..onChangedStart(v);
          },
          onChanged: (v) {
            context.read<VideoEditorTuneBloc>().add(
              VideoEditorTuneValueChanged(v),
            );
            scope.tuneEditor?.onChanged(v);
          },
          onChangeEnd: (v) => scope.tuneEditor?.onChangedEnd(v),
        ),
      ),
    );
  }
}

class _TuneChips extends StatelessWidget {
  const _TuneChips();

  @override
  Widget build(BuildContext context) {
    final (adjustments, selectedIndex, values) = context.select(
      (VideoEditorTuneBloc b) => (
        b.state.adjustments,
        b.state.selectedIndex,
        b.state.values,
      ),
    );

    return ListView.separated(
      scrollDirection: .horizontal,
      padding: const .fromLTRB(16, 0, 16, 4),
      itemCount: adjustments.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final adjustment = adjustments[index];
        return _TuneChip(
          label: tuneAdjustmentLabel(context, adjustment.id),
          value: values[adjustment.id] ?? 0,
          labelMultiplier: adjustment.labelMultiplier,
          isSelected: index == selectedIndex,
          onTap: () {
            context.read<VideoEditorTuneBloc>().add(
              VideoEditorTuneAdjustmentSelected(index),
            );
            VideoEditorScope.of(context).tuneEditor?.selectedIndex = index;
          },
        );
      },
    );
  }
}

class _TuneChip extends StatelessWidget {
  const _TuneChip({
    required this.label,
    required this.value,
    required this.labelMultiplier,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final double value;
  final double labelMultiplier;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isAdjusted = value != 0;
    final valueLabel = isAdjusted
        ? tuneAdjustmentValueLabel(value, labelMultiplier)
        : '—';
    return Semantics(
      // Fold the current value into the label so it's announced alongside the
      // adjustment name; the child Text nodes are excluded to avoid a double
      // announcement.
      label: isAdjusted ? '$label, $valueLabel' : label,
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const .symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: context.vineColors.surfaceContainer,
            borderRadius: .circular(16),
            border: .all(
              color: isSelected
                  ? context.vineColors.accentPositive
                  : context.vineColors.outlineMuted,
              width: 2,
            ),
          ),
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: .min,
              mainAxisAlignment: .center,
              spacing: 2,
              children: [
                Text(
                  label,
                  style: VineTheme.bodySmallFont(
                    color: isSelected
                        ? context.vineColors.accentPositive
                        : context.vineColors.onSurface,
                  ),
                ),
                Text(
                  valueLabel,
                  style: VineTheme.labelSmallFont(
                    color: isAdjusted
                        ? context.vineColors.onSurface
                        : context.vineColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
