import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_layer_view.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/features/main_editor/services/layer_copy_manager.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show Layer, ProImageEditorState, WidgetLayer;

/// Toggles mute on every video clip, every clip detached onto the canvas and
/// every independently-controllable audio track at once.
///
/// If anything is currently audible (any clip or custom track with
/// `volume > 0`), this mutes everything to `0.0`. Otherwise it restores all
/// to `1.0`. Triggers `HapticFeedback.mediumImpact()` to acknowledge the
/// gesture — call sites should not add their own haptic on top.
///
/// Both the timeline header's volume button (long-press) and the per-arc
/// volume controls in [VideoEditorTimelineVolume] route through this so
/// behaviour stays in lockstep.
void toggleAllTimelineVolumeMuted(BuildContext context) {
  final clipBloc = context.read<ClipEditorBloc>();
  final overlayBloc = context.read<TimelineOverlayBloc>();
  final editor = VideoEditorScope.maybeOf(context)?.editor;

  final clips = clipBloc.state.clips;
  final customAudioTracks = overlayBloc.state.audioTracks
      .where((t) => !t.isClipAnchoredOriginalSound)
      .toList(growable: false);
  final detachedClipVolumes = [
    for (final layer in editor?.activeLayers ?? const <Layer>[])
      if (DetachedClipLayerData.isDetachedClipLayer(layer))
        DetachedClipLayerData.volumeOf(DetachedClipLayerData.metaOf(layer)),
  ];

  final allMuted =
      clips.every((c) => c.volume == 0.0) &&
      customAudioTracks.every((t) => t.volume == 0.0) &&
      detachedClipVolumes.every((volume) => volume == 0.0);
  final targetVolume = allMuted ? 1.0 : 0.0;

  unawaited(HapticFeedback.mediumImpact());
  if (editor != null &&
      detachedClipVolumes.any((volume) => volume != targetVolume)) {
    _writeAllVolumes(editor, targetVolume, clipBloc, overlayBloc);
  }
  clipBloc.add(ClipEditorAllClipsVolumeChanged(volume: targetVolume));
  overlayBloc.add(
    TimelineOverlayAllAudioVolumeChanged(volume: targetVolume),
  );
}

/// Writes [volume] onto every clip, custom sound and detached clip as one
/// history entry.
///
/// A detached clip lives in the editor's layers rather than in a bloc, so the
/// blocs' own volume write cannot reach it. Writing everything here keeps the
/// toggle one undo step: the clips and sounds the blocs then set are the ones
/// this entry already holds, and [ProImageEditorState.setVolumeState] skips
/// writing them a second time.
void _writeAllVolumes(
  ProImageEditorState editor,
  double volume,
  ClipEditorBloc clipBloc,
  TimelineOverlayBloc overlayBloc,
) {
  // The bloc handlers set the same values; the guard in setVolumeState only
  // recognises its own entry when both sides agree on every field.
  final clips = clipBloc.state.clips
      .map((c) => c.copyWith(volume: volume))
      .toList(growable: false);
  final audioTracks = overlayBloc.state.audioTracks
      .map(
        (t) => t.isClipAnchoredOriginalSound ? t : t.copyWith(volume: volume),
      )
      .toList(growable: false);
  // Copied, as the editor copies its own layers into every entry, so the new
  // entry shares no layer object with the one before it.
  final layers = LayerCopyManager().copyLayerList(editor.activeLayers);
  for (var i = 0; i < layers.length; i++) {
    final layer = layers[i];
    if (layer is! WidgetLayer) continue;
    final meta = DetachedClipLayerData.withVolume(
      DetachedClipLayerData.metaOf(layer),
      volume,
    );
    if (meta != null) layers[i] = detachedClipLayerWithMeta(layer, meta);
  }

  editor.setVolumeState(
    clips: clips,
    audioTracks: audioTracks,
    layers: layers,
  );
}
