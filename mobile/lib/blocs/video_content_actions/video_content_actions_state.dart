// ABOUTME: State and one-shot action results for VideoContentActionsBloc
// ABOUTME: Carries save, clip-import and remix progress, bookmark status and results

part of 'video_content_actions_bloc.dart';

/// One-shot result of a content action, consumed by a BlocListener.
///
/// Constructors are deliberately non-const and the hierarchy is not
/// Equatable: each result is a distinct instance, so two identical-looking
/// results in a row (two failed copies, say) still both reach the listener.
sealed class VideoContentActionResult {
  VideoContentActionResult();
}

/// Outcome of a bookmark toggle; [succeeded] tells success from failure.
///
/// When [succeeded] is true, [removed] tells the UI whether the video was
/// removed from global bookmarks (toggle off) vs added (toggle on).
///
/// [wasBookmarkedBeforeToggle] is set for every attempt that reached the
/// repository. When [succeeded] is false, the UI uses it to show an
/// add-specific vs remove-specific error.
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

/// A remix or an Add to clips was refused because the creator's consent is
/// not a yes.
///
/// [consent] is [RemixConsent.blocked] when the creator blocks remixing on
/// their account or declined reuse of this video, or [RemixConsent.unknown]
/// when their profile could not be read and the user should try again.
class VideoContentRemixRefused extends VideoContentActionResult {
  VideoContentRemixRefused({required this.consent});

  final RemixConsent consent;
}

/// A remix the creator allowed could not start: the video could not be
/// brought into the viewer's clip library, so the editor did not open.
class VideoContentRemixFailed extends VideoContentActionResult {
  VideoContentRemixFailed();
}

/// The video is in the viewer's clip library as [clip], ready to open in the
/// editor. Not feedback: the info sheet opens the editor with it.
class VideoContentRemixReady extends VideoContentActionResult {
  VideoContentRemixReady({required this.clip});

  final DivineVideoClip clip;
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
    this.isPreparingRemix = false,
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

  /// Whether a remix is being prepared: the consent check, finding or
  /// importing the clip the editor opens with, then opening the editor, until
  /// [VideoContentRemixLaunchFinished].
  final bool isPreparingRemix;

  /// Whether a content action is running. While one runs, the sheet holds
  /// the others and the bloc ignores their requests.
  bool get isActionInFlight => isSaving || isImportingClip || isPreparingRemix;

  /// Whether this video is already globally bookmarked, per a reconciled read.
  final VideoBookmarkStatus bookmarkStatus;

  /// Last one-shot action result, for BlocListener consumption. Kept until
  /// the next result, or until a save, clip import or remix starts.
  final VideoContentActionResult? actionResult;

  VideoContentActionsState copyWith({
    bool? isSaving,
    bool? isImportingClip,
    bool? isPreparingRemix,
    VideoBookmarkStatus? bookmarkStatus,
    VideoContentActionResult? actionResult,
    bool clearActionResult = false,
  }) {
    return VideoContentActionsState(
      isSaving: isSaving ?? this.isSaving,
      isImportingClip: isImportingClip ?? this.isImportingClip,
      isPreparingRemix: isPreparingRemix ?? this.isPreparingRemix,
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
    isPreparingRemix,
    bookmarkStatus,
    actionResult,
  ];
}
