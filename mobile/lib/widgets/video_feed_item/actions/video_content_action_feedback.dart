// ABOUTME: Per-video action feedback in sheet banners and after dismissal.
// ABOUTME: Also hosts the clip-title prompt that starts an Add to clips.

import 'package:bookmarks_repository/bookmarks_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_content_actions/video_content_actions_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/repositories/remix_consent_repository.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/video_feed_item/actions/clip_title_sheet.dart';
import 'package:openvine/widgets/video_feed_item/actions/sheet_dismissal.dart';
import 'package:unified_logger/unified_logger.dart';

/// Reports [result] for the sheet owning [sheetContext].
///
/// The sheet is dismissed first: a snackbar raised while it is open lands on
/// the opener's scaffold, underneath the sheet. A [VideoContentRemixReady] is
/// not feedback — the info sheet opens the editor with it — so it leaves the
/// sheet alone.
void showVideoContentActionFeedback(
  BuildContext sheetContext,
  VideoContentActionResult result,
) {
  final l10n = sheetContext.l10n;
  final messenger = ScaffoldMessenger.of(sheetContext);

  final (snackText, isError) = switch (result) {
    // "Failed to add bookmark" names no recovery for the state the user is
    // almost certainly in, and after a long blocking wait that matters more,
    // not less. Both network-shaped failures are worded that way: the read
    // runs with requireAllRelaysSettled, so a single slow relay reports
    // timedOut while the device is merely degraded, not offline. An unreadable
    // private list names neither add nor remove: the repository refused
    // because it cannot tell which one Save would be. Everything else keeps
    // the add- or remove-specific copy.
    VideoContentSaveResult() => _saveFeedbackMessage(l10n, result),
    VideoContentClipImportResult(:final succeeded, :final libraryTitle) => (
      succeeded
          ? l10n.shareSheetSavedClipToClips(
              libraryTitle ?? l10n.shareSheetUntitledClip,
            )
          : l10n.shareSheetAddToClipsFailed,
      !succeeded,
    ),
    VideoContentRemixFailed() => (l10n.remixStartFailed, true),
    VideoContentRemixRefused(:final consent) => (
      consent == RemixConsent.blocked
          ? l10n.remixBlockedByCreator
          : l10n.remixConsentCheckFailed,
      true,
    ),
    VideoContentCopiedToClipboard(:final kind) => (
      switch (kind) {
        VideoContentCopiedKind.eventJson => l10n.shareCopiedEventJson,
        VideoContentCopiedKind.eventId => l10n.shareCopiedEventId,
      },
      false,
    ),
    VideoContentActionFailure() => (l10n.shareActionFailed, true),
    VideoContentRemixReady() => (null, false),
  };
  if (snackText == null) return;

  dismissSheet(sheetContext);
  if (result case VideoContentCopiedToClipboard(:final text)) {
    runDetached(
      _copyThenReport(
        messenger,
        text,
        copiedText: snackText,
        failedText: l10n.shareActionFailed,
      ),
      'copy video content value to clipboard',
      logName: 'VideoContentActionFeedback',
      category: LogCategory.ui,
    );
    return;
  }
  messenger.showSnackBar(
    DivineSnackbarContainer.snackBar(snackText, error: isError),
  );
}

/// Localized bookmark feedback shared by the sheet banner and snackbar.
(String, bool) _saveFeedbackMessage(
  AppLocalizations l10n,
  VideoContentSaveResult result,
) => (
  result.succeeded
      ? (result.removed
            ? l10n.shareRemovedFromBookmarks
            : l10n.shareAddedToBookmarks)
      : switch (result.failure) {
          BookmarkToggleFailure.couldNotReachRelays ||
          BookmarkToggleFailure.timedOut => l10n.profileSetupNoRelaysConnected,
          BookmarkToggleFailure.privateItemsUnreadable =>
            l10n.shareBookmarkPrivateItemsLocked,
          _ =>
            result.wasBookmarkedBeforeToggle
                ? l10n.shareFailedToRemoveBookmark
                : l10n.shareFailedToAddBookmark,
        },
  !result.succeeded,
);

/// Bookmark feedback inside an info sheet that stays open after a toggle.
/// The next action clears the result, including a retry after a failure.
class VideoContentSaveFeedback extends StatelessWidget {
  const VideoContentSaveFeedback({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      VideoContentActionsBloc,
      VideoContentActionsState,
      VideoContentSaveResult?
    >(
      selector: (state) => switch (state.actionResult) {
        final VideoContentSaveResult result => result,
        _ => null,
      },
      builder: (context, result) {
        if (result == null) return const SizedBox.shrink();
        final (message, isError) = _saveFeedbackMessage(context.l10n, result);
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Semantics(
            liveRegion: true,
            child: DivineSnackbarContainer(label: message, error: isError),
          ),
        );
      },
    );
  }
}

/// Copies [text], then confirms it only once the platform has taken it.
Future<void> _copyThenReport(
  ScaffoldMessengerState messenger,
  String text, {
  required String copiedText,
  required String failedText,
}) async {
  var copied = true;
  try {
    await Clipboard.setData(ClipboardData(text: text));
  } on PlatformException catch (error) {
    copied = false;
    Log.warning(
      'Could not copy to the clipboard: $error',
      name: 'VideoContentActionFeedback',
      category: LogCategory.ui,
    );
  }
  if (!messenger.mounted) return;
  messenger.showSnackBar(
    DivineSnackbarContainer.snackBar(
      copied ? copiedText : failedText,
      error: !copied,
    ),
  );
}

/// Reports [VideoContentActionsBloc] results through snackbar feedback,
/// except bookmark results shown inline when [keepBookmarkResultsOpen].
///
/// Results that arrive while another route covers this one are dropped, so a
/// late result never closes a route that was pushed on top of the sheet.
class VideoContentActionsFeedbackListener extends StatelessWidget {
  const VideoContentActionsFeedbackListener({
    required this.child,
    this.keepBookmarkResultsOpen = false,
    super.key,
  });

  final Widget child;

  /// The info sheet reports bookmark results beside its actions instead.
  /// Other actions and the share sheet retain their dismissal behavior.
  final bool keepBookmarkResultsOpen;

  @override
  Widget build(BuildContext context) {
    return BlocListener<VideoContentActionsBloc, VideoContentActionsState>(
      listenWhen: (previous, current) =>
          current.actionResult != null &&
          previous.actionResult != current.actionResult,
      listener: (context, state) {
        final result = state.actionResult;
        if (result == null) return;
        if (!context.mounted || ModalRoute.of(context)?.isCurrent == false) {
          Log.info(
            'Dropped a ${result.runtimeType}: a route covers the sheet',
            name: 'VideoContentActionsFeedbackListener',
            category: LogCategory.ui,
          );
          return;
        }
        if (keepBookmarkResultsOpen && result is VideoContentSaveResult) return;
        showVideoContentActionFeedback(context, result);
      },
      child: child,
    );
  }
}

/// Asks for a clip title, then adds the video to the clip library.
///
/// [sheetContext] must sit below a [VideoContentActionsBloc] provider.
/// Cancelling the prompt, or closing the sheet while it is open, adds nothing.
Future<void> requestAddToClips(BuildContext sheetContext) async {
  final bloc = sheetContext.read<VideoContentActionsBloc>();
  final libraryTitle = await ClipTitleSheet.show(
    context: sheetContext,
    initialTitle: bloc.defaultClipTitle,
  );
  if (libraryTitle == null || !sheetContext.mounted) return;
  bloc.add(VideoContentAddToClipsRequested(libraryTitle: libraryTitle));
}
