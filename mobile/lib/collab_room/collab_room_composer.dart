// ABOUTME: Puts a collaborative room's parts together into one video: side by
// ABOUTME: side in a split screen, or one after another, full frame

import 'dart:io';
import 'dart:ui';

import 'package:flutter/painting.dart' show Alignment;
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';
import 'package:openvine/services/video_editor/split_screen_layout_render_service.dart';
import 'package:openvine/services/video_editor/video_editor_merge_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// One part to put in the video: its file, where its cell sits as fractions
/// of the frame, and whether its sound is the one the video keeps.
typedef CollabRoomComposeCell = ({
  File file,
  Rect rect,
  SplitScreenCellShape shape,
  bool withSound,
});

/// Renders [cells] into one video of [aspectRatio], with [backgroundColor]
/// in the gaps, or returns `null` when the render produced no file.
typedef CollabRoomComposer = Future<DivineVideoClip?> Function({
  required List<CollabRoomComposeCell> cells,
  required model.AspectRatio aspectRatio,
  required Color backgroundColor,
  required String taskId,
});

/// The [CollabRoomComposer] the app uses: every part, centred in its cell,
/// goes into one encode with the split-screen layout renderer. Every part but
/// the one [CollabRoomComposeCell.withSound] marks is muted.
///
/// Throws when a part's file cannot be read, and whatever the renderer throws.
Future<DivineVideoClip?> composeCollabRoom({
  required List<CollabRoomComposeCell> cells,
  required model.AspectRatio aspectRatio,
  required Color backgroundColor,
  required String taskId,
}) async {
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final renderCells = <SplitScreenRenderCell>[];
  for (final (index, cell) in cells.indexed) {
    final video = EditorVideo.file(cell.file);
    final metadata = await ProVideoEditor.instance.getMetadata(video);
    final size = metadata.resolution;
    renderCells.add((
      clip: DivineVideoClip(
        id: 'collab_part_${stamp}_$index',
        video: video,
        duration: metadata.duration,
        recordedAt: DateTime.now(),
        targetAspectRatio: aspectRatio,
        originalAspectRatio: size.height > 0 ? size.width / size.height : null,
        volume: cell.withSound ? 1 : 0,
      ),
      rect: cell.rect,
      shape: cell.shape,
      alignment: Alignment.center,
      zoom: 1,
    ));
  }
  return SplitScreenLayoutRenderService.render(
    cells: renderCells,
    aspectRatio: aspectRatio,
    backgroundColor: backgroundColor,
    taskId: taskId,
  );
}

/// One part of a room filmed in series: its file and how long it plays.
typedef CollabRoomSeriesPart = ({File file, Duration length});

/// Joins [parts], in the order given, into one video of [aspectRatio], or
/// returns `null` when the render produced no file.
typedef CollabRoomSeriesComposer = Future<DivineVideoClip?> Function({
  required List<CollabRoomSeriesPart> parts,
  required model.AspectRatio aspectRatio,
  required String taskId,
});

/// The [CollabRoomSeriesComposer] the app uses: every part fills the frame,
/// cut to its [CollabRoomSeriesPart.length] if it runs longer, and keeps its
/// own sound; the parts play one after another in one encode.
///
/// Throws when a part's file cannot be read, and whatever the renderer throws.
Future<DivineVideoClip?> composeCollabRoomSeries({
  required List<CollabRoomSeriesPart> parts,
  required model.AspectRatio aspectRatio,
  required String taskId,
}) async {
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final clips = <DivineVideoClip>[];
  for (final (index, part) in parts.indexed) {
    final video = EditorVideo.file(part.file);
    final metadata = await ProVideoEditor.instance.getMetadata(video);
    final size = metadata.resolution;
    final duration = metadata.duration;
    clips.add(
      DivineVideoClip(
        id: 'collab_part_${stamp}_$index',
        video: video,
        duration: duration,
        recordedAt: DateTime.now(),
        targetAspectRatio: aspectRatio,
        originalAspectRatio: size.height > 0 ? size.width / size.height : null,
        trimEnd: duration > part.length ? duration - part.length : .zero,
      ),
    );
  }
  final merged = await VideoEditorMergeService.mergeClips(
    clips: clips,
    renderId: taskId,
  );
  // The render already cut every part to the frame, so the editor must not
  // crop the joined video again.
  return merged?.copyWith(originalAspectRatio: aspectRatio.value);
}
