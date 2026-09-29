// ABOUTME: "Back to timeline" action for a clip detached onto the canvas
// ABOUTME: Reads the layer and asks the clip editor to put the clip back

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show Layer;

/// Puts the detached clip on [layer] back onto the timeline.
///
/// Everything the bloc needs is read off the layer here, because the bloc
/// cannot reach the editor: the clip, the stretch of it the layer shows, and
/// the placeholder that holds its slot. The bloc changes the clip list and the
/// scaffold removes the layer once that lands, as one history entry.
///
/// The stretch is the length of the bar [item], not of the layer: the timeline
/// clamps the bar to the composition, so after the composition has shrunk the
/// bar is what the user sees and what plays, while the layer still carries the
/// end it was placed with.
///
/// The layer's action bar is closed straight away, so a second tap cannot
/// send the same clip back twice.
Future<void> reattachDetachedClip(
  BuildContext context,
  Layer layer, {
  required TimelineOverlayItem item,
}) async {
  final meta = DetachedClipLayerData.metaOf(layer);
  if (meta == null) return;

  final bloc = context.read<ClipEditorBloc>();
  final playhead = context.read<VideoEditorMainBloc>().state.currentPosition;
  context.read<TimelineOverlayBloc>().add(
    const TimelineOverlayItemSelected(null),
  );

  final documentsPath = await getDocumentsPath();
  if (bloc.isClosed) return;

  final data = DetachedClipLayerData.fromMeta(meta, documentsPath);
  if (data == null || data.clip.video == null) return;

  bloc.add(
    ClipEditorDetachedClipReattachRequested(
      layerId: layer.id,
      clip: data.clip,
      playhead: playhead,
      sourceOffset: data.sourceOffset,
      window: item.endTime - item.startTime,
      placeholderClipId: data.placeholderClipId,
    ),
  );
}
