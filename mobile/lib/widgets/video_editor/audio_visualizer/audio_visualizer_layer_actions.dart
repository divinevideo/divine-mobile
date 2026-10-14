// ABOUTME: Builds audio visualizer layers for the canvas and applies a new
// ABOUTME: look picked for one already there.

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/audio_visualizer/video_editor_audio_visualizer_cubit.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/audio_visualizer_layer.dart';
import 'package:openvine/widgets/video_editor/audio_visualizer/audio_visualizer_layer_view.dart';
import 'package:openvine/widgets/video_editor/audio_visualizer/audio_visualizer_sheet.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// A widget layer that draws [data], [width] canvas pixels wide, at [offset]
/// from the middle of the canvas.
///
/// The visualizer is kept in both meta slots, like every widget layer the
/// editor makes, so it comes back from undo and from a draft.
WidgetLayer audioVisualizerWidgetLayer(
  AudioVisualizerLayerData data, {
  required double width,
  Offset offset = Offset.zero,
}) {
  final meta = data.toMeta();
  return WidgetLayer(
    width: width,
    offset: offset,
    widget: AudioVisualizerLayerView(data: data),
    meta: meta,
    exportConfigs: WidgetLayerExportConfigs(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      meta: meta,
    ),
  );
}

/// Opens the visualizer sheet for [layer] and applies the look picked there.
///
/// A new style keeps the layer where it is. Its width changes by as much as
/// the new style's default width differs from the old one's, so a row of bars
/// turned into a ring does not grow to the full width of the video.
Future<void> editAudioVisualizerLayer(BuildContext context, Layer layer) async {
  final data = AudioVisualizerLayerData.of(layer);
  if (data == null) return;
  // Captured before the await: the timeline bar that opened the sheet can
  // unmount while the sheet is up, and the edit would be lost with it.
  final scope = VideoEditorScope.of(context);
  final picked = await showAudioVisualizerSheet(
    context,
    initial: data,
    soundLevels: context.read<VideoEditorAudioVisualizerCubit>(),
  );
  if (picked == null || picked == data) return;

  final editor = scope.editor;
  if (editor == null) return;
  final index = editor.activeLayers.indexWhere((l) => l.id == layer.id);
  if (index < 0) return;
  final current = editor.activeLayers[index];
  if (current is! WidgetLayer) return;

  final width = current.width;
  final meta = picked.toMeta();
  editor.replaceLayer(
    index: index,
    layer: current.copyWith(
      widget: AudioVisualizerLayerView(data: picked),
      meta: meta,
      exportConfigs: current.exportConfigs.copyWith(meta: meta),
      width: width == null
          ? null
          : width *
                VideoEditorConstants.audioVisualizerWidthFactor(picked.style) /
                VideoEditorConstants.audioVisualizerWidthFactor(data.style),
    ),
  );
}
