// ABOUTME: Navigation helper to open the metadata edit screen for a video.
// ABOUTME: Preserves edit navigation after deleting the legacy share menu.

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/screens/video_metadata/video_metadata_edit_screen.dart';
import 'package:openvine/utils/detached_future.dart';

/// Public helper to show the edit screen for a video from anywhere.
void showEditDialogForVideo(BuildContext context, VideoEvent video) {
  runDetached(
    context.push<void>(VideoMetadataEditScreen.pathFor(video.id), extra: video),
    'open video metadata editor for video ${video.id}',
    logName: 'showEditDialogForVideo',
    category: LogCategory.ui,
  );
}
