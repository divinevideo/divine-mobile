// ABOUTME: Blend action for a timeline layer: a row of blend modes that mixes
// ABOUTME: the layer with the video beneath it live and writes the chosen one.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/extensions/layer_blend_mode.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/animation_picker_components.dart';
import 'package:pro_image_editor/features/main_editor/services/layer_copy_manager.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show Layer;
import 'package:pro_video_editor/pro_video_editor.dart' show LayerBlendMode;

/// Opens the blend modes for [layer], selected in the timeline as [item], and
/// writes the mode the sheet closes on as one history step.
///
/// The mode is judged against the video beneath the layer, so the sheet
/// leaves the canvas unscrimmed and every mode tapped shows on the layer
/// right away, without a history step of its own; the layer is put back
/// before the chosen mode is written, so the edit is one undo however many
/// modes were tried. Closing the sheet keeps what the canvas shows, however it
/// is closed; only its cancel button puts the layer back.
///
/// A layer is not drawn outside its time range, so a playhead outside it is
/// moved to the layer's start first — otherwise there would be nothing to
/// judge the mode on.
Future<void> editLayerBlendMode(
  BuildContext context,
  Layer layer, {
  required TimelineOverlayItem item,
}) async {
  final scope = VideoEditorScope.of(context);
  final editor = scope.editor;
  if (editor == null) return;
  final mainBloc = context.read<VideoEditorMainBloc>();

  final time = scope.playTimeNotifier.value;
  if (time < item.startTime || time > item.endTime) {
    mainBloc.add(VideoEditorSeekRequested(item.startTime));
  }

  void show(Layer shown) {
    if (!editor.mounted) return;
    final index = editor.activeLayers.indexWhere((l) => l.id == layer.id);
    if (index < 0) return;
    editor.replaceLayer(index: index, layer: shown, skipUpdateHistory: true);
  }

  final initial = layer.exportBlendMode;
  LayerBlendMode? chosen;
  final confirmed = await VineBottomSheet.show<bool>(
    context: context,
    expanded: false,
    scrollable: false,
    isScrollControlled: true,
    barrierColor: VineTheme.transparent,
    body: LayerBlendModeSheet(
      initialMode: initial,
      onChanged: (mode) {
        chosen = mode;
        show(layerWithBlendMode(layer, mode));
      },
    ),
  );

  final value = chosen;
  if (value == null) return;
  show(layer);
  if (confirmed == false || value == initial || !editor.mounted) return;
  final index = editor.activeLayers.indexWhere((l) => l.id == layer.id);
  if (index < 0) return;
  editor.replaceLayer(
    index: index,
    layer: layerWithBlendMode(editor.activeLayers[index], value),
  );
}

/// A copy of [layer], drawn onto the video in [mode], that keeps its widget
/// key so the canvas updates the layer it shows instead of building a new one.
Layer layerWithBlendMode(Layer layer, LayerBlendMode mode) =>
    LayerCopyManager().copyLayer(layer)..blendMode = mode.blendMode;

/// The blend sheet: a chip per mode the editor offers, the current one
/// selected.
///
/// Reports every mode tapped through [onChanged] so the canvas can follow it,
/// and pops `false` from its cancel button and `true` from its done button.
class LayerBlendModeSheet extends StatefulWidget {
  const LayerBlendModeSheet({
    required this.initialMode,
    required this.onChanged,
    super.key,
  });

  /// The layer's mode when the sheet opens.
  final LayerBlendMode initialMode;

  /// Called with each mode tapped.
  final ValueChanged<LayerBlendMode> onChanged;

  @override
  State<LayerBlendModeSheet> createState() => _LayerBlendModeSheetState();
}

class _LayerBlendModeSheetState extends State<LayerBlendModeSheet> {
  late LayerBlendMode _mode = widget.initialMode;

  void _select(LayerBlendMode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    widget.onChanged(mode);
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
                onPressed: () => context.pop<bool>(false),
              ),
              Flexible(
                child: Text(
                  l10n.videoEditorBlendLabel,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ),
              DivineIconButton(
                icon: DivineIconName.check,
                size: DivineIconButtonSize.small,
                semanticLabel: l10n.videoEditorDoneLabel,
                onPressed: () => context.pop<bool>(true),
              ),
            ],
          ),
        ),
        Divider(
          height: 2,
          thickness: 2,
          color: context.vineColors.surfaceContainer,
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16),
          child: Row(
            spacing: 8,
            children: [
              for (final mode in editorBlendModes)
                _BlendModeChip(
                  mode: mode,
                  selected: mode == _mode,
                  onTap: () => _select(mode),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BlendModeChip extends StatelessWidget {
  const _BlendModeChip({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final LayerBlendMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = blendModeLabel(context, mode);
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

/// The name of [mode], as the sheet shows it.
String blendModeLabel(BuildContext context, LayerBlendMode mode) {
  final l10n = context.l10n;
  return switch (mode) {
    LayerBlendMode.normal => l10n.videoEditorBlendModeNormal,
    LayerBlendMode.multiply => l10n.videoEditorBlendModeMultiply,
    LayerBlendMode.screen => l10n.videoEditorBlendModeScreen,
    LayerBlendMode.overlay => l10n.videoEditorBlendModeOverlay,
    LayerBlendMode.softLight => l10n.videoEditorBlendModeSoftLight,
    LayerBlendMode.darken => l10n.videoEditorBlendModeDarken,
    LayerBlendMode.lighten => l10n.videoEditorBlendModeLighten,
    LayerBlendMode.add => l10n.videoEditorBlendModeAdd,
    LayerBlendMode.difference => l10n.videoEditorBlendModeDifference,
  };
}
