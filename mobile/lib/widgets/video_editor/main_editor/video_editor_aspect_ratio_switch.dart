// ABOUTME: Switches the video between square and 9:16 from the selected clip's
// ABOUTME: action bar as one history edit, and announces the new shape.

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/aspect_ratio_switch.dart';
import 'package:openvine/utils/semantics_announcement.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/features/main_editor/services/layer_copy_manager.dart';

/// Switches the video between square and 9:16.
///
/// Every clip is cropped to the new shape and the layers the new frame would
/// cut off are moved onto it ([placeLayerForAspectRatioSwitch]), in one
/// history entry, so one undo puts the shape and the layers back. The canvas
/// then mirrors the clips to the clip manager and the clip editor bloc, as it
/// does for every history change.
///
/// Does nothing once [context] has unmounted, and while the clips cannot be
/// changed: while a clip is being rendered, a trim dragged, a sub-editor open
/// or the clips reordered.
void switchEditorAspectRatio(BuildContext context) {
  if (!context.mounted) return;
  final clipState = context.read<ClipEditorBloc>().state;
  final main = context.read<VideoEditorMainBloc>().state;
  final editor = VideoEditorScope.of(context).editor;
  final clips = clipState.clips;
  if (editor == null ||
      !editor.mounted ||
      clips.isEmpty ||
      clipState.hasPendingClipOperation ||
      clipState.isTrimDragging ||
      main.isSubEditorOpen ||
      main.isReordering) {
    return;
  }

  final from = clips.first.targetAspectRatio;
  final to = switchedAspectRatio(from);
  final bodySize = editor.sizesManager.bodySize;
  final drawn = editor.activeLayers;
  // Copied, as the editor copies its own layers into every entry, so the
  // entry before keeps the layers where they were.
  final layers = LayerCopyManager().copyLayerList(drawn);
  for (var i = 0; i < layers.length; i++) {
    placeLayerForAspectRatioSwitch(
      layers[i],
      size: drawn[i].renderSize,
      bodySize: bodySize,
      from: from.value,
      to: to.value,
    );
  }
  editor.setClipStateWithLayers(
    clips: clipsWithAspectRatio(clips, to),
    layers: layers,
  );

  announceDetached(
    context,
    switch (to) {
      model.AspectRatio.square =>
        context.l10n.videoEditorMadeSquareAnnouncement,
      model.AspectRatio.vertical =>
        context.l10n.videoEditorMadeVerticalAnnouncement,
    },
    description: 'announce the new video shape',
    logName: 'VideoEditorAspectRatioSwitch',
  );
}
