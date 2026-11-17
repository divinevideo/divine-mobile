// ABOUTME: Opens the editor with a remix clip from a video sheet, keeping any
// ABOUTME: autosaved session as a draft before the remix replaces it.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/video_content_actions/video_content_actions_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
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
/// session replaces. It is first kept as a new regular draft
/// ([VideoEditorNotifier.keepAutosaveAsDraft]), so it stays in the Drafts
/// tab. If that save fails nothing is cleared: the sheet closes with a
/// failure message and the session is kept.
/// An [Error] while keeping the session is rethrown after that message, so
/// it reaches crash reporting.
///
/// Gives up without opening the editor when, once the autosave is safe, a
/// route the user opened covers the sheet or the sheet is already closing:
/// dismissing it then would close that other route instead. Giving up before
/// the autosave is cleared deletes the kept copy again, so the session stays
/// listed once.
///
/// Backing out of the editor is its usual save-or-discard prompt: a timeline
/// with a credited clip counts as edited.
Future<void> openRemixInEditor(
  BuildContext sheetContext,
  WidgetRef ref,
  DivineVideoClip clip,
) async {
  // Read up front: the sheet, and with it [ref], may be gone after an await.
  final videoEditor = ref.read(videoEditorProvider.notifier);
  final videoPublish = ref.read(videoPublishProvider.notifier);
  final clipManager = ref.read(clipManagerProvider.notifier);

  final String? keptDraftId;
  try {
    keptDraftId = await videoEditor.keepAutosaveAsDraft();
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
    // A programming fault rather than a storage failure: the caller's
    // runDetached reports it.
    if (e is Error) rethrow;
    return;
  }
  if (!sheetContext.mounted || !_isSheetOnTop(sheetContext)) {
    // The autosave still holds the session, so the copy would list it twice
    // and a retry would copy it again.
    if (keptDraftId != null) await videoEditor.discardKeptDraft(keptDraftId);
    return;
  }

  await videoPublish.clearAll();
  if (!sheetContext.mounted || !_isSheetOnTop(sheetContext)) return;
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

/// Whether the sheet owning the mounted [sheetContext] is the top route, so
/// dismissing it closes the sheet and nothing else.
bool _isSheetOnTop(BuildContext sheetContext) {
  if (ModalRoute.of(sheetContext)?.isCurrent ?? false) return true;
  Log.info(
    'Dropped a remix launch: a route covers the sheet, or it is closing',
    name: 'RemixLauncher',
    category: LogCategory.video,
  );
  return false;
}
