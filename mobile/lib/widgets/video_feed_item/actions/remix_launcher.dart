// ABOUTME: Opens the editor with a remix clip from a video sheet, keeping any
// ABOUTME: autosaved session as a draft before the remix replaces it.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/video_content_actions/video_content_actions_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/router/routes/video_routes.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/video_feed_item/actions/sheet_dismissal.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_content_action_feedback.dart';
import 'package:unified_logger/unified_logger.dart';

/// Starts a new editor session holding only [clip], then closes the sheet
/// owning [sheetContext] and opens the editor. Completes once the editor is
/// pushed, or when the launch gives up, not when the editor closes.
///
/// A session the viewer left unfinished lives in the autosave, which the new
/// session replaces. When it holds clips it is first saved as a new regular
/// draft, so it stays in the Drafts tab. If that save fails nothing is
/// cleared: the sheet closes with a failure message and the session is kept.
///
/// Backing out of the editor is its usual save-or-discard prompt: a timeline
/// with a credited clip counts as edited.
Future<void> openRemixInEditor(
  BuildContext sheetContext,
  WidgetRef ref,
  DivineVideoClip clip,
) async {
  // Read up front: the sheet, and with it [ref], may be gone after an await.
  final draftStorage = ref.read(draftStorageServiceProvider);
  final videoPublish = ref.read(videoPublishProvider.notifier);
  final clipManager = ref.read(clipManagerProvider.notifier);

  try {
    if (await draftStorage.draftExists(VideoEditorConstants.autoSaveId)) {
      final autosave = await draftStorage.getDraftById(
        VideoEditorConstants.autoSaveId,
      );
      if (autosave != null && autosave.clips.isNotEmpty) {
        // A fresh id, sharing the autosave's files; deleting the autosave
        // below leaves files another draft still names. duplicate() retires
        // the challenge and the post time, as copying a project should; this
        // is the same session moving to the Drafts tab, so both come along.
        await draftStorage.saveDraft(
          autosave.duplicate().copyWith(
            challengeContext: autosave.challengeContext,
            scheduledAt: autosave.scheduledAt,
            skipUpdateLastModified: true,
          ),
        );
      }
    }
  } catch (e, stackTrace) {
    Log.error(
      'Could not keep the autosaved session before a remix: $e',
      name: 'RemixLauncher',
      category: LogCategory.video,
      error: e,
      stackTrace: stackTrace,
    );
    if (sheetContext.mounted) {
      showVideoContentActionFeedback(sheetContext, VideoContentActionFailure());
    }
    return;
  }
  if (!sheetContext.mounted) return;

  await videoPublish.clearAll();
  if (!sheetContext.mounted) return;
  clipManager.insertClip(0, clip);

  await presentAfterSheetDismiss<void>(sheetContext, (hostContext) async {
    // Not awaited: the push completes only when the editor closes.
    runDetached(
      const VideoEditorRouteData(
        from: VideoEditorScreen.libraryOrigin,
      ).push<void>(hostContext),
      'open the editor with a remix',
      logName: 'RemixLauncher',
      category: LogCategory.video,
    );
  });
}
