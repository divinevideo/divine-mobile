// ABOUTME: The split-screen layout screen's controls: what to put in the
// ABOUTME: selected cell, which layout, the gap and the border colour

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/split_screen_layout/split_screen_layout_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_row.dart';

/// The actions for the selected cell: fill it from the library or the camera,
/// or empty it again.
class SplitScreenCellActions extends StatelessWidget {
  const SplitScreenCellActions({
    required this.onPickFromLibrary,
    required this.onRecordWithCamera,
    super.key,
  });

  final VoidCallback onPickFromLibrary;
  final VoidCallback onRecordWithCamera;

  @override
  Widget build(BuildContext context) {
    final isFilled = context.select(
      (SplitScreenLayoutCubit cubit) => cubit.state.selectedCell != null,
    );
    return Padding(
      padding: const .symmetric(horizontal: 16),
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: DivineButton(
              label: context.l10n.videoEditorLibraryLabel,
              leadingIcon: .images,
              type: .secondary,
              size: .small,
              expanded: true,
              onPressed: onPickFromLibrary,
            ),
          ),
          Expanded(
            child: DivineButton(
              label: context.l10n.videoEditorCameraLabel,
              leadingIcon: .camera,
              type: .secondary,
              size: .small,
              expanded: true,
              onPressed: onRecordWithCamera,
            ),
          ),
          if (isFilled)
            DivineIconButton(
              icon: .trash,
              type: .ghostSecondary,
              size: .small,
              semanticLabel: context.l10n.videoEditorLayoutRemoveClipLabel,
              onPressed: () =>
                  context.read<SplitScreenLayoutCubit>().selectedCellCleared(),
            ),
        ],
      ),
    );
  }
}

/// One tile per layout, each a small drawing of its cells.
class SplitScreenPresetPicker extends StatelessWidget {
  const SplitScreenPresetPicker({super.key});

  /// Height of a tile, and so of the row.
  static const double tileHeight = 56;

  @override
  Widget build(BuildContext context) {
    final (:selected, :frameAspectRatio) = context.select(
      (SplitScreenLayoutCubit cubit) => (
        selected: cubit.state.preset,
        frameAspectRatio: cubit.state.frameAspectRatio,
      ),
    );
    return SizedBox(
      height: tileHeight,
      child: ListView(
        scrollDirection: .horizontal,
        padding: const .symmetric(horizontal: 16),
        children: [
          for (final preset in SplitScreenLayoutPreset.values) ...[
            if (preset.index > 0) const SizedBox(width: 12),
            _PresetTile(
              preset: preset,
              frameAspectRatio: frameAspectRatio,
              isSelected: preset == selected,
            ),
          ],
        ],
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.frameAspectRatio,
    required this.isSelected,
  });

  final SplitScreenLayoutPreset preset;
  final double frameAspectRatio;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Semantics(
      button: true,
      selected: isSelected,
      label: _label(context),
      child: GestureDetector(
        onTap: () =>
            context.read<SplitScreenLayoutCubit>().presetSelected(preset),
        child: Container(
          width: SplitScreenPresetPicker.tileHeight,
          padding: const .all(8),
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: .circular(16),
            border: .all(
              width: 2,
              color: isSelected ? colors.accentBrand : colors.outlineMuted,
            ),
          ),
          child: Center(
            child: AspectRatio(
              aspectRatio: frameAspectRatio,
              child: CustomPaint(
                painter: _PresetPainter(
                  cells: preset.cellRects(
                    aspectRatio: frameAspectRatio,
                    gap: _iconGap,
                  ),
                  color: isSelected
                      ? colors.accentBrand
                      : colors.onSurfaceMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Wide enough that the cells read as separate at icon size.
  static const double _iconGap = 0.08;

  String _label(BuildContext context) => switch (preset) {
    .sideBySide => context.l10n.videoEditorLayoutPresetSideBySide,
    .stacked => context.l10n.videoEditorLayoutPresetStacked,
    .threeColumns => context.l10n.videoEditorLayoutPresetThreeColumns,
    .threeStacked => context.l10n.videoEditorLayoutPresetThreeStacked,
    .oneOverTwo => context.l10n.videoEditorLayoutPresetOneOverTwo,
    .twoOverOne => context.l10n.videoEditorLayoutPresetTwoOverOne,
    .oneBesideTwo => context.l10n.videoEditorLayoutPresetOneBesideTwo,
    .twoBesideOne => context.l10n.videoEditorLayoutPresetTwoBesideOne,
    .grid => context.l10n.videoEditorLayoutPresetGrid,
    .oneOverThree => context.l10n.videoEditorLayoutPresetOneOverThree,
    .pictureInPictureTopLeft =>
      context.l10n.videoEditorLayoutPresetPictureInPictureTopLeft,
    .pictureInPictureTopRight =>
      context.l10n.videoEditorLayoutPresetPictureInPictureTopRight,
    .pictureInPictureBottomLeft =>
      context.l10n.videoEditorLayoutPresetPictureInPictureBottomLeft,
    .pictureInPictureBottomRight =>
      context.l10n.videoEditorLayoutPresetPictureInPictureBottomRight,
  };
}

class _PresetPainter extends CustomPainter {
  const _PresetPainter({required this.cells, required this.color});

  final List<Rect> cells;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    // The picture-in-picture window sits on its big cell, so it is cut out of
    // it to stay visible at icon size.
    final outline = Paint()
      ..color = VineTheme.transparent
      ..blendMode = BlendMode.clear;
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final (index, cell) in cells.indexed) {
      final rect = Rect.fromLTWH(
        cell.left * size.width,
        cell.top * size.height,
        cell.width * size.width,
        cell.height * size.height,
      );
      if (index > 0 && cells.first.overlaps(cell)) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(1.5), const .circular(3)),
          outline,
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const .circular(2)),
        fill,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PresetPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.cells != cells;
}

/// The gap slider and the border colour row.
class SplitScreenBorderControls extends StatelessWidget {
  const SplitScreenBorderControls({super.key});

  @override
  Widget build(BuildContext context) {
    final (:gap, :borderColor) = context.select(
      (SplitScreenLayoutCubit cubit) => (
        gap: cubit.state.gap,
        borderColor: cubit.state.borderColor,
      ),
    );
    final cubit = context.read<SplitScreenLayoutCubit>();
    final labelStyle = VineTheme.bodySmallFont(
      color: context.vineColors.secondaryText,
    );
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: 8,
      children: [
        Padding(
          padding: const .symmetric(horizontal: 16),
          child: Row(
            spacing: 12,
            children: [
              ExcludeSemantics(
                child: Text(
                  context.l10n.videoEditorLayoutGapLabel,
                  style: labelStyle,
                ),
              ),
              Expanded(
                child: DivineSlider(
                  value: gap,
                  max: SplitScreenLayoutGeometry.maxGap,
                  semanticLabel: context.l10n.videoEditorLayoutGapLabel,
                  onChanged: cubit.gapChanged,
                ),
              ),
            ],
          ),
        ),
        VideoEditorColorRow(
          selected: borderColor,
          padding: const .symmetric(horizontal: 16),
          semanticLabel: context.l10n.videoEditorLayoutBorderColorLabel,
          onSelected: cubit.borderColorChanged,
          onCustom: () async {
            final picked = await showFullColorPicker(
              context,
              initialColor: borderColor,
            );
            if (picked != null) cubit.borderColorChanged(picked);
          },
        ),
      ],
    );
  }
}
