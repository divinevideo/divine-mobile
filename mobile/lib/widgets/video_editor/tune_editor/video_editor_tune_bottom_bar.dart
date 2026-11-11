// ABOUTME: Bottom bar for the video editor tune adjustments.
// ABOUTME: Shows the selected adjustment's controls and selectable chips.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/tune_editor/tune_labels.dart';
import 'package:openvine/widgets/video_editor/tune_editor/tune_slider_theme.dart';
import 'package:openvine/widgets/video_editor/tune_editor/video_editor_tune_color_panel.dart';
import 'package:openvine/widgets/video_editor/tune_editor/video_editor_tune_curve_panel.dart';

/// Bottom bar for the tune editor.
///
/// Above a scrollable row of chips — one per adjustment with a slider of its
/// own, showing its name and value, then one for the Color section and one
/// for the Curve section — it shows the selected chip's controls: a slider,
/// the [VideoEditorTuneColorPanel] or the [VideoEditorTuneCurvePanel].
class VideoEditorTuneBottomBar extends StatelessWidget {
  const VideoEditorTuneBottomBar({super.key});

  static const double _sliderHeight = 34;
  static const double _chipsHeight = 52;

  /// The room the bar leaves around its controls and chips.
  static const double _margin =
      VideoEditorConstants.bottomBarHeight - _sliderHeight - _chipsHeight;

  /// The bar's height, without the system navigation bar, for the section
  /// the selected chip opens; it rebuilds [context] when that changes.
  static double heightOf(BuildContext context) => heightFor(
    context.select((VideoEditorTuneBloc b) => b.state.section),
  );

  /// The bar's height, without the system navigation bar, while [section]
  /// is open.
  static double heightFor(VideoEditorTuneSection section) => switch (section) {
    .slider => VideoEditorConstants.bottomBarHeight,
    .color => VideoEditorTuneColorPanel.height + _chipsHeight + _margin,
    .curve => VideoEditorTuneCurvePanel.height + _chipsHeight + _margin,
  };

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.25);
    final section = context.select((VideoEditorTuneBloc b) => b.state.section);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: Column(
        mainAxisSize: .min,
        mainAxisAlignment: .center,
        children: [
          switch (section) {
            .slider => const SizedBox(
              height: _sliderHeight,
              child: _TuneSlider(),
            ),
            .color => const VideoEditorTuneColorPanel(),
            .curve => const VideoEditorTuneCurvePanel(),
          },
          const SizedBox(height: _chipsHeight, child: _TuneChips()),
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
        data: tuneSliderTheme(context),
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
    final state = context.select((VideoEditorTuneBloc b) => b.state);
    final adjustments = state.sliderAdjustments;
    final l10n = context.l10n;

    return ListView.separated(
      scrollDirection: .horizontal,
      padding: const .fromLTRB(16, 0, 16, 4),
      itemCount: adjustments.length + 2,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        if (index == adjustments.length) {
          return _TuneSectionChip(
            label: l10n.videoEditorTuneColor,
            isAdjusted: state.isSectionAdjusted(.color),
            isSelected: state.section == .color,
            onTap: () => context.read<VideoEditorTuneBloc>().add(
              VideoEditorTuneColorBandSelected(state.colorBand),
            ),
          );
        }
        if (index == adjustments.length + 1) {
          return _TuneSectionChip(
            label: l10n.videoEditorTuneCurve,
            isAdjusted: state.isSectionAdjusted(.curve),
            isSelected: state.section == .curve,
            onTap: () => context.read<VideoEditorTuneBloc>().add(
              VideoEditorTuneCurveChannelSelected(state.curveChannel),
            ),
          );
        }
        final adjustment = adjustments[index];
        final value = state.valueOf(adjustment.id);
        final isAdjusted = value != 0;
        return _TuneChip(
          label: tuneAdjustmentLabel(context, adjustment.id),
          valueLabel: isAdjusted
              ? tuneAdjustmentValueLabel(value, adjustment.labelMultiplier)
              : '—',
          isAdjusted: isAdjusted,
          isSelected: adjustment.id == state.selectedAdjustment.id,
          onTap: () {
            final adjustmentIndex = state.indexOf(adjustment.id);
            context.read<VideoEditorTuneBloc>().add(
              VideoEditorTuneAdjustmentSelected(adjustmentIndex),
            );
            VideoEditorScope.of(context).tuneEditor?.selectedIndex =
                adjustmentIndex;
          },
        );
      },
    );
  }
}

/// The chip of the Color or Curve section, marked with a dot while any of
/// its values is set.
class _TuneSectionChip extends StatelessWidget {
  const _TuneSectionChip({
    required this.label,
    required this.isAdjusted,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isAdjusted;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TuneChip(
      label: label,
      valueLabel: isAdjusted ? '•' : '—',
      semanticValue: isAdjusted ? context.l10n.videoEditorTuneChanged : null,
      isAdjusted: isAdjusted,
      isSelected: isSelected,
      onTap: onTap,
    );
  }
}

class _TuneChip extends StatelessWidget {
  const _TuneChip({
    required this.label,
    required this.valueLabel,
    required this.isAdjusted,
    required this.isSelected,
    required this.onTap,
    this.semanticValue,
  });

  final String label;

  /// What the chip shows under [label].
  final String valueLabel;

  /// What screen readers announce after [label] while [isAdjusted], or
  /// `null` for [valueLabel].
  final String? semanticValue;

  final bool isAdjusted;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Fold the current value into the label so it's announced alongside the
      // adjustment name; the child Text nodes are excluded to avoid a double
      // announcement.
      label: isAdjusted ? '$label, ${semanticValue ?? valueLabel}' : label,
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
