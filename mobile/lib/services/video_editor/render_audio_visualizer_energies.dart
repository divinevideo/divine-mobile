// ABOUTME: Reads the sound an export's audio visualizers draw from, downloading
// ABOUTME: network sounds through the fetcher the render's mux reuses.

import 'dart:typed_data';

import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/audio_visualizer_layer.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/services/video_editor/detached_clip_composite.dart';
import 'package:openvine/services/video_editor/render_audio_fetcher.dart';
import 'package:openvine/services/video_editor/video_editor_audio_level_resolver.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show EditorAudio, ExportedLayer;

/// [audioEnergiesOnExport] for the audio visualizers and the sound credits
/// whose equalizer follows the sound among [capturedLayers], or `null` when
/// it holds none: the [sounds] and [clips] of a render cut at
/// [maxOutputDuration], and the [detached] clips it composites over them.
/// Downloads go through [audioFetcher], which the mux reuses, into
/// [tempFilePaths], logged under the render's [logName].
Future<Float32List?> audioVisualizerEnergiesForRender({
  required List<ExportedLayer> capturedLayers,
  required List<AudioEvent> sounds,
  required List<DivineVideoClip> clips,
  required List<DetachedClipExportLayer> detached,
  required Duration? maxOutputDuration,
  required RenderAudioFetcher audioFetcher,
  required List<String> tempFilePaths,
  required String logName,
  VideoEditorAudioLevelResolver? resolver,
}) async {
  if (!capturedLayers.any(
    (item) =>
        AudioVisualizerLayerData.isAudioVisualizerLayer(item.layer) ||
        (SocialStickerData.of(item.layer)?.listensToSound ?? false),
  )) {
    return null;
  }
  final outputDuration = TransitionTimelineMap.fromClips(clips).outputDuration;
  return audioEnergiesOnExport(
    sounds: sounds,
    clips: clips,
    detachedClips: [
      for (final item in detached)
        DetachedClipSound(
          clip: item.clip,
          sourceOffset: item.sourceOffset,
          startTime: item.layer.startTime,
          endTime: item.layer.endTime,
        ),
    ],
    videoEnd: maxOutputDuration != null && maxOutputDuration < outputDuration
        ? maxOutputDuration
        : outputDuration,
    localPathFor: (url) async {
      final path = await audioFetcher.localPathFor(
        EditorAudio.network(url),
        logName: logName,
      );
      if (!tempFilePaths.contains(path)) tempFilePaths.add(path);
      return path;
    },
    resolver: resolver,
  );
}
