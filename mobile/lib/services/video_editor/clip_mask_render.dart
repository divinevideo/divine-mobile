// ABOUTME: Turns timeline clip shape masks into the black image layers the
// ABOUTME: export draws over the track while each masked clip plays.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:divine_ui/divine_ui.dart' show VineTheme;
import 'package:flutter/painting.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/aspect_ratio_extensions.dart';
import 'package:openvine/extensions/layer_animation_storage.dart'
    show ExportLayerMapping;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_mask_window.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show LayerMask;
import 'package:pro_video_editor/pro_video_editor.dart'
    show
        AnimationPhase,
        EditorLayerImage,
        EditorVideo,
        ImageLayer,
        LayerAnimation,
        LayerAnimationType,
        ProVideoEditor,
        VideoRenderData;

/// Renders the cover of a timeline clip's [LayerMask] at [size]: black where
/// the mask hides the clip, clear where it shows it, partly see-through across
/// a soft edge.
typedef ClipMaskCoverRenderer = Future<ui.Image> Function(
  LayerMask mask,
  Size size,
);

/// The cover [mask] draws over a frame of [size], as the preview does.
Future<ui.Image> renderClipMaskCover(LayerMask mask, Size size) async {
  final recorder = ui.PictureRecorder();
  Canvas(
    recorder,
  ).drawRect(Offset.zero & size, Paint()..color = VineTheme.backgroundColor);
  final picture = recorder.endRecording();
  final black = await picture.toImage(
    size.width.ceil().clamp(1, 1 << 14),
    size.height.ceil().clamp(1, 1 << 14),
  );
  picture.dispose();
  try {
    // The cover is what the mask hides, so it is the mask turned inside out.
    return await mask.copyWith(invert: !mask.invert).applyTo(black);
  } finally {
    black.dispose();
  }
}

/// Reads the resolution of a segment's [video].
typedef VideoResolutionReader = Future<Size> Function(EditorVideo video);

Future<Size> _readResolution(EditorVideo video) async =>
    (await ProVideoEditor.instance.getMetadata(video)).resolution;

/// [task], the single-track render of [clips], with the covers of their shape
/// masks laid under its image layers; see [clipMaskCoverLayers].
///
/// Under every overlay: a clip's mask belongs to the clip, so text and
/// stickers stay on top of what it covers, as on the canvas. The covers are
/// laid out in the frame the renderer composites the segments into
/// ([VideoEditorRenderService.layerFrameSize]), like every other image layer.
///
/// Returns [task] itself when no clip has a mask.
Future<VideoRenderData> withClipMaskCovers(
  VideoRenderData task,
  List<DivineVideoClip> clips,
  model.AspectRatio aspectRatio, {
  ClipMaskCoverRenderer render = renderClipMaskCover,
  VideoResolutionReader readResolution = _readResolution,
}) async {
  if (!clips.any((clip) => clip.mask != null)) return task;
  final segments = task.videoSegments ?? const [];
  final videoSize = segments.isEmpty
      ? VideoEditorConstants.quality.resolutionForAspectRatio(aspectRatio)
      : VideoEditorRenderService.layerFrameSize([
          for (final segment in segments) await readResolution(segment.video),
        ]);
  final covers = await clipMaskCoverLayers(
    clips: clips,
    videoSize: videoSize,
    targetAspectRatio: aspectRatio.value,
    timelineMap: TransitionTimelineMap.fromClips(clips),
    render: render,
  );
  return task.copyWith(imageLayers: [...covers, ...?task.imageLayers]);
}

/// The image layers that cover what every masked clip in [clips] hides.
///
/// A timeline clip is one segment of a single-track render, which has nothing
/// underneath it to show through, so its mask is drawn over it instead: one
/// black layer per masked clip, with the shape cut out, laid over the part of
/// [videoSize] an export cropped to [targetAspectRatio] keeps. Each shows
/// while its clip does, fading in and out across an overlap transition as
/// [ClipMaskWindow.weightAt] does in the preview; its times are mapped onto
/// the output through [timelineMap], like every other overlay window.
///
/// The layers go first in the export's image layers, so that every overlay
/// stays on top of the cover. Clips that share a mask share one image.
Future<List<ImageLayer>> clipMaskCoverLayers({
  required List<DivineVideoClip> clips,
  required Size videoSize,
  required double targetAspectRatio,
  required TransitionTimelineMap timelineMap,
  ClipMaskCoverRenderer render = renderClipMaskCover,
}) async {
  final windows = clipMaskWindows(clips);
  if (windows.isEmpty) return const [];

  final frame = ExportLayerMapping.keptRect(videoSize, targetAspectRatio);
  final images = <LayerMask, EditorLayerImage>{};
  final layers = <ImageLayer>[];
  for (final window in windows) {
    final image = images[window.mask] ??= EditorLayerImage.memory(
      await _encodePng(await render(window.mask, frame.size)),
    );

    final start = timelineMap.editorToOutput(
      window.start < Duration.zero ? Duration.zero : window.start,
    );
    final end = timelineMap.editorToOutput(window.end);
    if (end <= start) continue;
    final fadeIn =
        timelineMap.editorToOutput(window.start + window.fadeIn) - start;
    final fadeOut =
        end - timelineMap.editorToOutput(window.end - window.fadeOut);

    layers.add(
      ImageLayer(
        image: image,
        startTime: start,
        endTime: end,
        offset: frame.topLeft,
        size: frame.size,
        animations: [
          if (fadeIn > Duration.zero)
            LayerAnimation(
              type: LayerAnimationType.fade,
              phase: AnimationPhase.animateIn,
              duration: fadeIn,
            ),
          if (fadeOut > Duration.zero)
            LayerAnimation(
              type: LayerAnimationType.fade,
              phase: AnimationPhase.animateOut,
              duration: fadeOut,
            ),
        ],
      ),
    );
  }
  return layers;
}

Future<Uint8List> _encodePng(ui.Image image) async {
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('The clip mask cover could not be encoded');
    }
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
