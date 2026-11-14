// ABOUTME: State and one-shot action results for VideoContentActionsBloc
// ABOUTME: Carries save progress, bookmark status, and the last action result

part of 'video_content_actions_bloc.dart';

/// One-shot result of a content action, consumed by a BlocListener.
sealed class VideoContentActionResult {
  VideoContentActionResult();
}

/// Consolidates save success and failure into a single class, using
/// [succeeded] to distinguish the outcome.
///
/// When [succeeded] is true, [removed] tells the UI whether the video was
/// removed from global bookmarks (toggle off) vs added (toggle on).
///
/// [wasBookmarkedBeforeToggle] is set for every attempt. When [succeeded]
/// is false, the UI uses it to show an add-specific vs remove-specific error.
class VideoContentSaveResult extends VideoContentActionResult {
  VideoContentSaveResult({
    required this.succeeded,
    this.removed = false,
    this.wasBookmarkedBeforeToggle = false,
    this.failure,
  });

  final bool succeeded;

  /// Meaningful only when [succeeded] is true: user turned the bookmark off.
  final bool removed;

  /// Whether the video was already globally bookmarked before this toggle.
  final bool wasBookmarkedBeforeToggle;

  /// Why the toggle failed, so the UI can say "couldn't reach the network"
  /// instead of a generic error. `null` when [succeeded] is true.
  final BookmarkToggleFailure? failure;
}

class VideoContentClipImportResult extends VideoContentActionResult {
  VideoContentClipImportResult({required this.succeeded, this.libraryTitle});

  final bool succeeded;
  final String? libraryTitle;
}

/// What content was copied, so the UI can pick the localized message.
enum VideoContentCopiedKind { eventJson, eventId }

class VideoContentCopiedToClipboard extends VideoContentActionResult {
  VideoContentCopiedToClipboard({required this.kind, required this.text});

  /// Which content was copied; the UI maps this to a localized message.
  final VideoContentCopiedKind kind;

  /// Text to copy to clipboard.
  final String text;
}

/// Generic failure for utility actions (copy JSON, copy event ID).
/// Error details are logged by the BLoC; the UI shows a generic message.
class VideoContentActionFailure extends VideoContentActionResult {
  VideoContentActionFailure();
}

/// Whether the video is already in the user's global (kind 10003) bookmarks.
///
/// Starts [unknown] and stays there until a relay-reconciled read resolves it.
/// [unknown] must render as the plain "Save" affordance rather than as
/// [notSaved]: the two are indistinguishable to a reader, but conflating them
/// would let an unresolved read claim the video is not bookmarked — which is
/// exactly the mislabel this state exists to prevent.
enum VideoBookmarkStatus { unknown, saved, notSaved }

/// State for per-video content actions.
class VideoContentActionsState extends Equatable {
  const VideoContentActionsState({
    this.isSaving = false,
    this.isImportingClip = false,
    this.bookmarkStatus = VideoBookmarkStatus.unknown,
    this.actionResult,
  });

  /// Whether a bookmark save/remove is in progress.
  ///
  /// The toggle reconciles kind 10003 with the relay, signs, and waits for the
  /// publish to be accepted before it can report anything, so the UI has to
  /// show that it is working rather than sitting inert (#7073).
  final bool isSaving;

  /// Whether the video is being added to the viewer's clips.
  ///
  /// The import downloads the video before it can report anything, so the
  /// action shows that it is working instead of sitting inert.
  final bool isImportingClip;

  /// Whether this video is already globally bookmarked, per a reconciled read.
  final VideoBookmarkStatus bookmarkStatus;

  /// One-shot action result for BlocListener consumption.
  /// Cleared on next state emission.
  final VideoContentActionResult? actionResult;

  VideoContentActionsState copyWith({
    bool? isSaving,
    bool? isImportingClip,
    VideoBookmarkStatus? bookmarkStatus,
    VideoContentActionResult? actionResult,
    bool clearActionResult = false,
  }) {
    return VideoContentActionsState(
      isSaving: isSaving ?? this.isSaving,
      isImportingClip: isImportingClip ?? this.isImportingClip,
      bookmarkStatus: bookmarkStatus ?? this.bookmarkStatus,
      actionResult: clearActionResult
          ? null
          : (actionResult ?? this.actionResult),
    );
  }

  @override
  List<Object?> get props => [
    isSaving,
    isImportingClip,
    bookmarkStatus,
    actionResult,
  ];
}
