// ABOUTME: The split-screen layout screen's controls: what to put in the
// ABOUTME: selected cell, which layout, the gap and the border colour

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/split_screen_layout/split_screen_layout_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_row.dart';
import 'package:openvine/widgets/whole_word_button_text_scale.dart';

/// The actions for the selected cell: fill it from the library or the camera,
/// or empty it again.
///
/// Library and Camera split one row while both fit there on one line;
/// otherwise each gets a full-width row, the remove button beside Camera.
/// Halved, German "Mediathek" was already cut at the normal text size once
/// the remove button took its share of a 360-wide row.
class SplitScreenCellActions extends StatelessWidget {
  const SplitScreenCellActions({
    required this.onPickFromLibrary,
    required this.onRecordWithCamera,
    super.key,
  });

  /// Lines a label may wrap onto once it has a row of its own.
  static const int _maxLabelLines = 2;

  final VoidCallback onPickFromLibrary;
  final VoidCallback onRecordWithCamera;

  @override
  Widget build(BuildContext context) {
    final isFilled = context.select(
      (SplitScreenLayoutCubit cubit) => cubit.state.selectedCell != null,
    );
    final libraryLabel = context.l10n.videoEditorLibraryLabel;
    final cameraLabel = context.l10n.videoEditorCameraLabel;
    return Padding(
      padding: const .symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Camera's row also holds the remove button when they stack.
          final cameraWidth = isFilled
              ? constraints.maxWidth -
                    DivineIcon.scaleSize(context, kMinInteractiveDimension) -
                    _CellActionsLayout.spacing
              : constraints.maxWidth;
          return _CellActionsLayout(
            children: [
              WholeWordButtonTextScale(
                label: libraryLabel,
                width: constraints.maxWidth,
                hasLeadingIcon: true,
                child: DivineButton(
                  label: libraryLabel,
                  leadingIcon: .images,
                  type: .secondary,
                  size: .small,
                  expanded: true,
                  maxLines: _maxLabelLines,
                  onPressed: onPickFromLibrary,
                ),
              ),
              WholeWordButtonTextScale(
                label: cameraLabel,
                width: cameraWidth,
                hasLeadingIcon: true,
                child: DivineButton(
                  label: cameraLabel,
                  leadingIcon: .camera,
                  type: .secondary,
                  size: .small,
                  expanded: true,
                  maxLines: _maxLabelLines,
                  onPressed: onRecordWithCamera,
                ),
              ),
              if (isFilled)
                DivineIconButton(
                  icon: .trash,
                  type: .ghostSecondary,
                  size: .small,
                  semanticLabel: context.l10n.videoEditorLayoutRemoveClipLabel,
                  onPressed: () => context
                      .read<SplitScreenLayoutCubit>()
                      .selectedCellCleared(),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Lays out Library, Camera and the optional remove button as described on
/// [SplitScreenCellActions].
///
/// A render object because the choice turns on the buttons' natural widths,
/// which a widget cannot read.
class _CellActionsLayout extends MultiChildRenderObjectWidget {
  const _CellActionsLayout({required super.children})
    : assert(
        children.length == 2 || children.length == 3,
        'Library, Camera and the optional remove button',
      );

  /// Gap between the buttons, across a row and between rows.
  static const double spacing = 8;

  @override
  _RenderCellActions createRenderObject(BuildContext context) {
    return _RenderCellActions(textDirection: Directionality.of(context));
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCellActions renderObject,
  ) {
    renderObject.textDirection = Directionality.of(context);
  }
}

class _CellActionsParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderCellActions extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CellActionsParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CellActionsParentData> {
  _RenderCellActions({required TextDirection textDirection})
    : _textDirection = textDirection;

  static const double _spacing = _CellActionsLayout.spacing;

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CellActionsParentData) {
      child.parentData = _CellActionsParentData();
    }
  }

  /// Sizes and, unless [dry], positions the children.
  Size _layout(BoxConstraints constraints, {required bool dry}) {
    final [library, camera, ...rest] = getChildrenAsList();
    final remove = rest.firstOrNull;
    final libraryWidth = library.getMaxIntrinsicWidth(double.infinity);
    final cameraWidth = camera.getMaxIntrinsicWidth(double.infinity);
    final removeWidth = remove?.getMaxIntrinsicWidth(double.infinity) ?? 0;
    final removeSlot = remove == null ? 0.0 : removeWidth + _spacing;
    final maxWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : math.max(libraryWidth, cameraWidth) * 2 + _spacing + removeSlot;

    Size place(RenderBox child, BoxConstraints childConstraints) {
      if (dry) return child.getDryLayout(childConstraints);
      child.layout(childConstraints, parentUsesSize: true);
      return child.size;
    }

    BoxConstraints tight(double width) =>
        BoxConstraints.tightFor(width: math.max(0, width));

    // Left-to-right, mirrored for right-to-left once the width is known.
    final rects = <Rect>[];
    final double height;
    final half = (maxWidth - _spacing - removeSlot) / 2;
    final removeSize = remove == null
        ? Size.zero
        : place(remove, BoxConstraints(maxWidth: maxWidth));
    if (libraryWidth <= half && cameraWidth <= half) {
      final sizes = [
        place(library, tight(half)),
        place(camera, tight(half)),
        if (remove != null) removeSize,
      ];
      height = sizes.map((size) => size.height).reduce(math.max);
      var x = 0.0;
      for (final size in sizes) {
        rects.add(Offset(x, (height - size.height) / 2) & size);
        x += size.width + _spacing;
      }
    } else {
      final librarySize = place(library, tight(maxWidth));
      final cameraSize = place(camera, tight(maxWidth - removeSlot));
      final top = librarySize.height + _spacing;
      final rowHeight = math.max(cameraSize.height, removeSize.height);
      rects.addAll([
        Offset.zero & librarySize,
        Offset(0, top + (rowHeight - cameraSize.height) / 2) & cameraSize,
        if (remove != null)
          Offset(
                maxWidth - removeSize.width,
                top + (rowHeight - removeSize.height) / 2,
              ) &
              removeSize,
      ]);
      height = top + rowHeight;
    }

    final size = constraints.constrain(Size(maxWidth, height));
    if (!dry) {
      for (final (index, child) in getChildrenAsList().indexed) {
        final rect = rects[index];
        (child.parentData! as _CellActionsParentData).offset =
            switch (textDirection) {
              TextDirection.ltr => rect.topLeft,
              TextDirection.rtl => Offset(size.width - rect.right, rect.top),
            };
      }
    }
    return size;
  }

  @override
  void performLayout() {
    size = _layout(constraints, dry: false);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _layout(constraints, dry: true);

  /// Narrowest when stacked, widest when the buttons share a row.
  @override
  double computeMinIntrinsicWidth(double height) {
    final [library, camera, ...rest] = getChildrenAsList();
    final removeSlot = rest.isEmpty
        ? 0.0
        : rest.first.getMinIntrinsicWidth(double.infinity) + _spacing;
    return math.max(
      library.getMinIntrinsicWidth(double.infinity),
      camera.getMinIntrinsicWidth(double.infinity) + removeSlot,
    );
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final [library, camera, ...rest] = getChildrenAsList();
    final removeSlot = rest.isEmpty
        ? 0.0
        : rest.first.getMaxIntrinsicWidth(double.infinity) + _spacing;
    return math.max(
              library.getMaxIntrinsicWidth(double.infinity),
              camera.getMaxIntrinsicWidth(double.infinity),
            ) *
            2 +
        _spacing +
        removeSlot;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _layout(BoxConstraints(maxWidth: width), dry: true).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
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
      oldDelegate.color != color || !listEquals(oldDelegate.cells, cells);
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
