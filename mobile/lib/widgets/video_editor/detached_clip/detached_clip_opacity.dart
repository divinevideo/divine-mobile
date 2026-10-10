// ABOUTME: Opacity action for a clip detached onto the canvas: a slider that
// ABOUTME: fades the layer live and writes the chosen value onto it

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_layer_view.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show Layer, WidgetLayer;

/// Opens the opacity slider for the detached clip on [layer], selected in the
/// timeline as [item], and writes the value it settles on onto that layer.
///
/// The value is judged against what is underneath, so the sheet leaves the
/// canvas unscrimmed and every step shows on the layer while it is dragged.
/// Those steps go through the editor's main bloc instead of the layer: written
/// to the layer, one drag would become dozens of undo steps. Only the value the
/// sheet closes on is written, as one history entry.
///
/// Closing the sheet keeps what the canvas shows, however it is closed; only
/// its cancel button puts the layer back.
///
/// A clip is not drawn outside its time window, so a playhead sitting outside
/// it is moved to the clip's start first — otherwise the slider would fade
/// nothing anyone can see.
Future<void> editDetachedClipOpacity(
  BuildContext context,
  Layer layer, {
  required TimelineOverlayItem item,
}) async {
  final meta = DetachedClipLayerData.metaOf(layer);
  if (meta == null) return;

  // Captured before the await, like every other detached-clip action: the
  // context may be gone by the time the sheet closes.
  final scope = VideoEditorScope.of(context);
  final mainBloc = context.read<VideoEditorMainBloc>();
  final layerId = layer.id;

  final playhead = mainBloc.state.currentPosition;
  if (playhead < item.startTime || playhead > item.endTime) {
    mainBloc.add(VideoEditorSeekRequested(item.startTime));
  }

  double? chosen;
  final confirmed = await VineBottomSheet.show<bool>(
    context: context,
    expanded: false,
    scrollable: false,
    isScrollControlled: true,
    barrierColor: VineTheme.transparent,
    body: LayerOpacitySheet(
      initialOpacity: DetachedClipLayerData.opacityOf(meta),
      onChanged: (opacity) {
        chosen = opacity;
        mainBloc.addIfOpen(
          VideoEditorDetachedClipOpacityPreviewChanged((
            layerId: layerId,
            opacity: opacity,
          )),
        );
      },
    ),
  );

  final value = chosen;
  if (confirmed != false && value != null) {
    _writeOpacity(scope, layerId, value);
  }
  // Ended after the write, so no frame shows the old value in between.
  mainBloc.addIfOpen(const VideoEditorDetachedClipOpacityPreviewChanged(null));
}

/// Writes [opacity] onto the layer [layerId] as one editor-history entry.
void _writeOpacity(VideoEditorScope scope, String layerId, double opacity) {
  final editor = scope.editor;
  if (editor == null) return;
  final index = editor.activeLayers.indexWhere((l) => l.id == layerId);
  if (index < 0) return;
  final current = editor.activeLayers[index];
  if (current is! WidgetLayer) return;

  // Edited from the layer's *current* meta, so anything that landed on it
  // while the sheet was open — a crop finishing — is kept.
  final currentMeta = DetachedClipLayerData.metaOf(current);
  // A slider dragged back to where it started changed nothing, and an undo
  // step that undoes nothing reads as a broken undo.
  if (DetachedClipLayerData.opacityOf(currentMeta) == opacity) return;
  final updated = DetachedClipLayerData.withOpacity(currentMeta, opacity);
  if (updated == null) return;

  editor.replaceLayer(
    index: index,
    layer: current.copyWith(
      widget: DetachedClipLayerView(meta: updated),
      meta: updated,
      exportConfigs: current.exportConfigs.copyWith(meta: updated),
    ),
  );
}

/// The opacity sheet: a slider from invisible to solid, in whole percent.
///
/// Shared by every layer; see also `editLayerOpacity`.
///
/// Reports every step through [onChanged] so the canvas can follow it, and
/// pops `false` from its cancel button and `true` from its done button.
class LayerOpacitySheet extends StatefulWidget {
  const LayerOpacitySheet({
    required this.initialOpacity,
    required this.onChanged,
    super.key,
  });

  /// The layer's opacity when the sheet opens, from 0 to 1.
  final double initialOpacity;

  /// Called with each new value while the slider is dragged.
  final ValueChanged<double> onChanged;

  @override
  State<LayerOpacitySheet> createState() => _LayerOpacitySheetState();
}

class _LayerOpacitySheetState extends State<LayerOpacitySheet> {
  /// One slider step: a whole percent.
  static const int _steps = 100;

  late double _opacity = widget.initialOpacity.clamp(0.0, 1.0);

  void _setOpacity(double opacity) {
    setState(() => _opacity = opacity);
    widget.onChanged(opacity);
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
                  l10n.videoEditorOpacityLabel,
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
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            spacing: 12,
            children: [
              Expanded(
                child: DivineSlider(
                  value: _opacity,
                  divisions: _steps,
                  semanticLabel: l10n.videoEditorOpacityLabel,
                  onChanged: _setOpacity,
                ),
              ),
              // The slider announces its own value, so the figure beside it
              // is for sighted users only. Kept at a fixed minimum width so
              // the track does not shift as the digits change.
              ExcludeSemantics(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 44),
                  child: Text(
                    '${(_opacity * _steps).round()}%',
                    textAlign: TextAlign.end,
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.mutedText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
