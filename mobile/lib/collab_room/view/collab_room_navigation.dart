// ABOUTME: The camera flows a collaborative room starts: filming your part,
// ABOUTME: and posting the finished video with everyone as collaborators

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/collab_room/collab_room_layout.dart';
import 'package:openvine/collab_room/collab_room_providers.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/router/routes/video_routes.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Opens the camera to film the account's part of [room], cut to the shape
/// of its cell. Returns once the part flow ends: the part was handed in, or
/// the camera was closed.
Future<void> openCollabRoomPartRecorder(
  BuildContext context,
  WidgetRef ref,
  CollabRoom room,
) async {
  final cellAspectRatio = room.cellAspectRatioOf(room.ownerPubkey);
  if (cellAspectRatio == null) return;
  // A part is a session of its own: start from an empty camera.
  await ref
      .read(videoPublishProvider.notifier)
      .clearAll(keepAutosavedDraft: true);
  if (!context.mounted) return;
  final part = CollabRoomPartContext(
    roomId: room.id,
    cellAspectRatio: cellAspectRatio,
    cellShape:
        room.cellShapeOf(room.ownerPubkey) ?? SplitScreenCellShape.rectangle,
    me: room.ownerPubkey,
    callKey: room.callKey,
    inviteRevision: room.me?.inviteRevision ?? 0,
  );
  final partSession = ref.read(collabRoomPartProvider.notifier)..set(part);
  try {
    await VideoRecorderRouteData(
      collabRoom: room.id,
      entryPoint: CreationEntryPoint.collabRoom,
    ).push<void>(context);
  } finally {
    partSession.finish(expected: part);
  }
}

/// Opens the post screen for [clip], the finished video of [room], with
/// everyone who filmed a part as a collaborator.
Future<void> openCollabRoomPost(
  BuildContext context,
  WidgetRef ref,
  CollabRoom room,
  DivineVideoClip clip,
) async {
  await ref
      .read(videoPublishProvider.notifier)
      .clearAll(keepAutosavedDraft: true);
  if (!context.mounted) return;
  ref.read(collabRoomPostProvider.notifier).set(room.id);
  ref.read(clipManagerProvider.notifier).replaceClips([clip]);
  final editor = ref.read(videoEditorProvider.notifier);
  for (final member in room.participants) {
    if (member.pubkey != room.authorPubkey) {
      editor.addCollaborator(member.pubkey);
    }
  }
  // Rendered while the post screen is up, which shows the progress, as a
  // Classic take is.
  runDetached(
    editor.startRenderVideo(),
    'render the collaborative video',
    logName: 'CollabRoomNavigation',
    category: LogCategory.video,
  );
  await context.push(VideoMetadataScreen.pathForDraft(isStopMotion: false));
  if (context.mounted && ref.read(collabRoomPostProvider) == room.id) {
    await ref
        .read(videoPublishProvider.notifier)
        .clearAll(keepAutosavedDraft: true);
  }
}
