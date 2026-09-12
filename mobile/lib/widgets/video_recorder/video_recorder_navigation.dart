// ABOUTME: View-layer navigation helpers for the video recorder. Navigation is
// ABOUTME: a UI concern, so it lives here rather than on VideoRecorderBloc; the
// ABOUTME: bloc only exposes VideoRecorderCameraPausedForNavigation so the
// ABOUTME: camera can be released cleanly during a push transition.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';
import 'package:openvine/utils/await_push_transition.dart';
import 'package:unified_logger/unified_logger.dart';

/// Closes the video recorder.
///
/// Pops if there is a route to pop to, otherwise navigates home (the recorder
/// was reached via `go`, so there is nothing on the stack).
void closeVideoRecorder(BuildContext context, WidgetRef ref) {
  if (context.canPop()) {
    // The recorder's `PopScope` discards the session on the way out; a `go`
    // never reaches it, so that branch has to do it here.
    context.pop();
    return;
  }
  discardRecorderSession(ref);
  context.go(VideoFeedPage.pathForIndex(0));
}

/// Ends the recording session the user is walking away from.
///
/// Every recorded clip is already saved to the persistent clip library, so
/// this only drops the session — which is what keeps the camera from
/// reopening on the previous session's settings. The aspect ratio is derived
/// from the clips in the session and its toggle is disabled while any exist
/// (mixing ratios in one video isn't supported), so a surviving 1:1 clip
/// pinned the next camera open to 1:1 until the selection was cleared in the
/// library.
///
/// An autosaved session's recovery point *is* the autosave draft, so
/// discarding the session takes that draft with it. A named draft holds its
/// own file and the autosave draft then belongs to some other session — leave
/// it alone.
///
/// Deleting it here loses nothing the user could miss: at the camera the
/// autosave draft only ever holds the selected clips, and those are already in
/// the persistent clip library. Editor state cannot be in it, because the
/// editor refuses to close on an autosaved session without a decision
/// (`canPop: !isAutosavedDraft`) — save turns it into a named draft, discard
/// ends the session, and an unedited close has nothing to keep. Keeping the
/// draft would instead have the next camera open offer a "continue?" prompt
/// whose only payload is the clip selection that pinned the aspect ratio in
/// the first place. An OS kill still leaves the draft intact, which is the
/// case recovery is for.
void discardRecorderSession(WidgetRef ref) {
  final isAutosavedDraft = ref.read(videoEditorProvider).isAutosavedDraft;
  unawaited(
    ref
        .read(videoPublishProvider.notifier)
        .clearAll(keepAutosavedDraft: !isAutosavedDraft),
  );
}

/// Navigates to the video editor (or the metadata screen, depending on mode),
/// releasing the camera during the transition and re-initializing it on return.
///
/// Mirrors the legacy `VideoRecorderNotifier.openVideoEditor`: the camera is
/// disposed only after the push animation is past the visible frame (disposing
/// immediately would flash the camera-init screen behind the transition), and
/// re-initialized once the pushed route pops.
Future<void> openVideoEditorFromRecorder(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!await _ensureAuthenticatedForRecorderExit(context, ref)) return;
  if (!context.mounted) return;

  final bloc = context.read<VideoRecorderBloc>();
  final recorderMode = bloc.state.recorderMode;
  final clipManager = ref.read(clipManagerProvider.notifier);

  // Both next steps snapshot the clip list right here (classic renders it
  // below, the editor seeds its session from it on init), so a clip-delete
  // Undo honored after this point would silently diverge from that snapshot.
  // Finalize the pending deletion and drop its snackbar instead.
  if (ref.read(clipManagerProvider).pendingDeletion != null) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await ref.read(clipManagerProvider.notifier).commitPendingDeletion();
    if (!context.mounted) return;
  }

  await ref
      .read(creationAnalyticsTrackerProvider)
      .recordingCompleted(
        mode: recorderMode,
        clipCount: clipManager.clips.length,
        duration: clipManager.totalDuration,
      );
  if (!context.mounted) return;

  // Lip-sync records against a selected sound, so silence the clips before the
  // editor: only the chosen audio should be heard, with the clips muted and
  // the sound carried in as its own track (seeded on editor init).
  if (recorderMode == VideoRecorderMode.lipSync) {
    ref.read(clipManagerProvider.notifier).muteAllClips();
  }

  if (!recorderMode.hasVideoEditor) {
    ref.read(videoEditorProvider.notifier).startRenderVideo();
  }

  // Lock recording before the push so a volume / Bluetooth trigger that races
  // the navigation can't start (or leave) a recording on the camera we are
  // about to release. The camera is still live here, so the lock can reset any
  // in-flight recording cleanly — without racing the deferred dispose below.
  if (bloc.isClosed) return;
  bloc.add(const VideoRecorderRecordingLockedForNavigation());

  final navigation = recorderMode.hasVideoEditor
      ? context.push(VideoEditorScreen.path)
      : context.push(VideoMetadataScreen.path);

  await awaitPushTransition(context);
  if (bloc.isClosed) return;
  await _pauseCameraForNavigation(bloc);
  if (recorderMode.hasVideoEditor) {
    await ref.read(audioSessionServiceProvider).configureForMixedPlayback();
  } else {
    await ref.read(audioSessionServiceProvider).resetAudioSession();
  }

  await navigation;
  if (!context.mounted || bloc.isClosed) return;
  bloc.add(const VideoRecorderInitializeRequested());
}

/// Navigates to the library's drafts and clips tabs, releasing the camera
/// during the transition and re-initializing it on return.
Future<void> openRecorderLibrary(BuildContext context, WidgetRef ref) async {
  if (!await _ensureAuthenticatedForRecorderExit(context, ref)) return;
  if (!context.mounted) return;

  final bloc = context.read<VideoRecorderBloc>();

  // Scope the library to the current mode's clip type: stop-motion stills and
  // normal video clips can't share one editor timeline, so each mode only sees
  // (and can add) its own kind.
  final clipTypeFilter = bloc.state.recorderMode.capturesStills
      ? LibraryClipTypeFilter.stopMotion
      : LibraryClipTypeFilter.video;

  // Lock recording before the push so a volume / Bluetooth trigger that races
  // the navigation can't start (or leave) a recording on the camera we are
  // about to release. The camera is still live here, so the lock can reset any
  // in-flight recording cleanly — without racing the deferred dispose below.
  if (bloc.isClosed) return;
  bloc.add(const VideoRecorderRecordingLockedForNavigation());

  final navigation = context.pushNamed(
    LibraryScreen.clipsOnlyRouteName,
    queryParameters: {'type': ?clipTypeFilter.queryValue},
  );

  await awaitPushTransition(context);
  if (bloc.isClosed) return;
  await _pauseCameraForNavigation(bloc);
  await ref.read(audioSessionServiceProvider).resetAudioSession();

  await navigation;
  if (!context.mounted || bloc.isClosed) return;
  bloc.add(const VideoRecorderInitializeRequested());

  // Opening a draft from the library's Drafts tab resets the clip manager the
  // recorder shares with the editor. The session survives as its autosave, so
  // offer it back here — the recorder stays mounted throughout, so its own
  // check never re-runs and the session would otherwise only resurface on the
  // next app start.
  await offerAutosavedSession(context, ref, openEditorOnRestore: false);
}

/// Offers the autosaved session back when the recorder is holding no clips.
///
/// The autosave draft is the app's recovery point for unfinished work: the
/// editor refuses to close on one without a decision, and opening the camera
/// on a fresh start asks the same question. Any other point where the clip
/// manager empties under a mounted recorder has to ask too, or the session
/// silently waits for the next launch.
///
/// [openEditorOnRestore] continues into the editor once the clips are back,
/// which is what opening the camera wants. A caller the user reached by
/// navigating back to the recorder leaves them there instead.
Future<void> offerAutosavedSession(
  BuildContext context,
  WidgetRef ref, {
  required bool openEditorOnRestore,
}) async {
  if (!ref.read(videoEditorProvider).isAutosavedDraft) return;
  if (ref.read(clipManagerProvider).hasClips) return;

  final draft = await ref.read(draftStorageServiceProvider).getAutosaveDraft();
  if (!context.mounted) return;
  if (draft == null) {
    Log.debug(
      '📹 No valid autosaved draft found',
      name: 'VideoRecorderNavigation',
      category: LogCategory.video,
    );
    return;
  }

  Log.info(
    '📹 Found valid autosaved draft',
    name: 'VideoRecorderNavigation',
    category: LogCategory.video,
  );

  await VineBottomSheetPrompt.show(
    context: context,
    sticker: .videoClapBoard,
    title: context.l10n.videoRecorderAutosaveFoundTitle,
    subtitle: context.l10n.videoRecorderAutosaveFoundSubtitle,
    primaryButtonText: context.l10n.videoRecorderAutosaveContinueButton,
    onPrimaryPressed: () async {
      final restoreSuccessful = await ref
          .read(videoEditorProvider.notifier)
          .restoreDraft();

      if (!context.mounted) return;
      context.pop();

      if (!restoreSuccessful) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoRecorderAutosaveRestoreFailure,
            error: true,
          ),
        );
        return;
      }

      // Match the restored clips' aspect ratio so the user can't mix ratios on
      // subsequent recordings. The legacy restoreDraft set this on the recorder
      // directly; with the bloc the View owns the cross-feature dispatch.
      final clips = ref.read(clipManagerProvider).clips;
      if (clips.isNotEmpty) {
        context.read<VideoRecorderBloc>().add(
          VideoRecorderAspectRatioSet(clips.first.targetAspectRatio),
        );
      }

      if (!openEditorOnRestore) return;
      await openVideoEditorFromRecorder(context, ref);
    },
    secondaryButtonText: context.l10n.videoRecorderAutosaveDiscardButton,
    onSecondaryPressed: () {
      ref.read(videoEditorProvider.notifier).removeAutosavedDraft();
      context.pop();
    },
  );
}

Future<void> _pauseCameraForNavigation(VideoRecorderBloc bloc) {
  // A closed bloc drops the event, so the completion would never resolve and
  // the awaiting caller would hang. Skip the handoff instead.
  if (bloc.isClosed) return Future<void>.value();
  final completion = Completer<void>();
  bloc.add(VideoRecorderCameraPausedForNavigation(completion: completion));
  return completion.future;
}

Future<bool> _ensureAuthenticatedForRecorderExit(
  BuildContext context,
  WidgetRef ref,
) async {
  final authGate = ref.read(recorderExitAuthGateProvider);
  final showedRestoreSnackbar = authGate.isRestoring;
  if (showedRestoreSnackbar && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.authSigningYouIn),
        duration: authGate.restoreTimeout,
      ),
    );
  }

  final authenticated = await authGate.waitForAuthenticatedOrTerminal();
  if (showedRestoreSnackbar) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  if (authenticated) return true;

  final outcome = await ref
      .read(videoEditorProvider.notifier)
      .saveAsDraft(enforceCreateNewDraft: true);

  // A save was already in flight; don't double-report or navigate.
  if (outcome == DraftSaveOutcome.alreadyInProgress) return false;
  if (!context.mounted) return false;

  final saved = outcome == DraftSaveOutcome.saved;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        saved
            ? context.l10n.uploadFailureSheetSavedToDraftsSnackbar
            : context.l10n.videoMetadataFailedToSaveSnackbar,
      ),
    ),
  );

  if (saved) {
    context.go(WelcomeScreen.path);
  }
  return false;
}
