// ABOUTME: State for ShareSheetBloc
// ABOUTME: Tracks contacts, selected recipient, sending status, and action results

part of 'share_sheet_bloc.dart';

/// Status of the share sheet.
enum ShareSheetStatus {
  /// Initial state before contacts are loaded.
  initial,

  /// Contacts are being loaded.
  loading,

  /// Contacts loaded, ready for interaction.
  ready,
}

/// One-shot action result communicated via [ShareSheetState.actionResult].
///
/// Consumed by BlocListener to show snackbars or dismiss the sheet.
/// Constructors are intentionally **non-const** so that each instance has
/// a unique identity.  Since this hierarchy does not extend [Equatable],
/// identity equality ensures that consecutive identical-looking results
/// are always treated as distinct by [BlocListener.listenWhen] and by
/// [Bloc.emit]'s state-deduplication check inside [ShareSheetState].
sealed class ShareSheetActionResult {
  ShareSheetActionResult();
}

class ShareSheetSendSuccess extends ShareSheetActionResult {
  ShareSheetSendSuccess({
    required this.recipientNames,
    this.recipientPubkey,
    this.conversationId,
  });

  /// Display names of everyone the video was sent to, in selection order.
  final List<String> recipientNames;

  /// Recipient pubkey, passed as the conversation participant when the
  /// success snackbar's "View chat" action navigates to the DM thread.
  /// Set only for a single-recipient send.
  final String? recipientPubkey;

  /// NIP-17 conversation ID for "View chat" navigation. Set only for a
  /// single-recipient NIP-17 send — multi-recipient sends and legacy
  /// NIP-04 sends have no single thread to open, so no action is shown.
  final String? conversationId;
}

/// A send where at least one recipient did not get the video now.
///
/// Every recipient lands in exactly one list, in selection order, so the sheet
/// can say who got it, who the retry sweep is still sending to, and who will
/// never get it (#8672). A share to one recipient that did not go out lands
/// here too — whether a retry is coming is exactly what it has to say.
class ShareSheetSendIncomplete extends ShareSheetActionResult {
  ShareSheetSendIncomplete({
    required this.sentNames,
    required this.retryingNames,
    required this.notSentNames,
  }) : assert(
         retryingNames.isNotEmpty || notSentNames.isNotEmpty,
         'A send with every recipient sent is a ShareSheetSendSuccess',
       );

  /// Recipients the video was sent to.
  final List<String> sentNames;

  /// Recipients whose send is queued; the retry sweep keeps sending it.
  final List<String> retryingNames;

  /// Recipients nothing will send it to: refused by the send policy, or failed
  /// before the send was queued.
  final List<String> notSentNames;
}

/// The whole send threw before any recipient's outcome was known.
class ShareSheetSendFailure extends ShareSheetActionResult {
  ShareSheetSendFailure();
}

/// Consolidates the former ShareSheetSaveSuccess and ShareSheetSaveFailure
/// into a single class, using [succeeded] to distinguish the outcome.
///
/// When [succeeded] is true, [removed] tells the UI whether the video was
/// removed from global bookmarks (toggle off) vs added (toggle on).
///
/// [wasBookmarkedBeforeToggle] is set for every attempt. When [succeeded]
/// is false, the UI uses it to show an add-specific vs remove-specific error.
class ShareSheetSaveResult extends ShareSheetActionResult {
  ShareSheetSaveResult({
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

  /// Why the toggle failed, so the sheet can say "couldn't reach the network"
  /// instead of a generic error. `null` when [succeeded] is true.
  final BookmarkToggleFailure? failure;
}

class ShareSheetVideoClipImportResult extends ShareSheetActionResult {
  ShareSheetVideoClipImportResult({required this.succeeded, this.libraryTitle});

  final bool succeeded;
  final String? libraryTitle;
}

/// Generic failure for utility actions (copy link, share via, etc.).
/// Error details are logged by the BLoC; the UI shows a generic message.
class ShareSheetActionFailure extends ShareSheetActionResult {
  ShareSheetActionFailure();
}

/// What content was copied, so the UI can pick the localized message.
enum ShareSheetCopiedKind { postLink, eventJson, eventId }

class ShareSheetCopiedToClipboard extends ShareSheetActionResult {
  ShareSheetCopiedToClipboard({required this.kind, required this.text});

  /// Which content was copied; the UI maps this to a localized message.
  final ShareSheetCopiedKind kind;

  /// Text to copy to clipboard.
  final String text;
}

class ShareSheetShareViaTriggered extends ShareSheetActionResult {
  ShareSheetShareViaTriggered({
    required this.shareUrl,
    this.thumbnailPath,
    this.title,
    this.subject,
  });

  /// The share URL to pass as text to the platform share sheet.
  final String shareUrl;

  /// Local file path of the downloaded thumbnail image, or `null` if
  /// the download failed or no thumbnail was available.
  final String? thumbnailPath;

  /// Video title used as the share sheet title / Android `EXTRA_TITLE`.
  final String? title;

  /// Video title used as email subject where supported.
  final String? subject;
}

/// Whether the video is already in the user's global (kind 10003) bookmarks.
///
/// Starts [unknown] and stays there until a relay-reconciled read resolves it.
/// [unknown] must render as the plain "Save" affordance rather than as
/// [notSaved]: the two are indistinguishable to a reader, but conflating them
/// would let an unresolved read claim the video is not bookmarked — which is
/// exactly the mislabel this state exists to prevent.
enum ShareSheetBookmarkStatus { unknown, saved, notSaved }

/// State for the share sheet.
class ShareSheetState extends Equatable {
  const ShareSheetState({
    this.status = ShareSheetStatus.initial,
    this.contacts = const [],
    this.selectedRecipients = const [],
    this.isSending = false,
    this.isSaving = false,
    this.bookmarkStatus = ShareSheetBookmarkStatus.unknown,
    this.actionResult,
  });

  /// Current loading status.
  final ShareSheetStatus status;

  /// Loaded contacts (recent + followed users).
  final List<ShareableUser> contacts;

  /// Recipients selected for the message-send flow, in selection order.
  final List<ShareableUser> selectedRecipients;

  /// Whether a send operation is in progress.
  final bool isSending;

  /// Whether a bookmark save/remove is in progress.
  ///
  /// The toggle reconciles kind 10003 with the relay, signs, and waits for the
  /// publish to be accepted before it can report anything, so the sheet has to
  /// show that it is working rather than sitting inert (#7073).
  final bool isSaving;

  /// Whether this video is already globally bookmarked, per a reconciled read.
  final ShareSheetBookmarkStatus bookmarkStatus;

  /// One-shot action result for BlocListener consumption.
  /// Cleared on next state emission.
  final ShareSheetActionResult? actionResult;

  /// Whether contacts have finished loading.
  bool get contactsLoaded => status == ShareSheetStatus.ready;

  /// Whether [user] is currently selected.
  bool isSelected(ShareableUser user) =>
      selectedRecipients.any((r) => r.pubkey == user.pubkey);

  ShareSheetState copyWith({
    ShareSheetStatus? status,
    List<ShareableUser>? contacts,
    List<ShareableUser>? selectedRecipients,
    bool? isSending,
    bool? isSaving,
    ShareSheetBookmarkStatus? bookmarkStatus,
    ShareSheetActionResult? actionResult,
    bool clearActionResult = false,
  }) {
    return ShareSheetState(
      status: status ?? this.status,
      contacts: contacts ?? this.contacts,
      selectedRecipients: selectedRecipients ?? this.selectedRecipients,
      isSending: isSending ?? this.isSending,
      isSaving: isSaving ?? this.isSaving,
      bookmarkStatus: bookmarkStatus ?? this.bookmarkStatus,
      actionResult: clearActionResult
          ? null
          : (actionResult ?? this.actionResult),
    );
  }

  @override
  List<Object?> get props => [
    status,
    contacts,
    selectedRecipients,
    isSending,
    isSaving,
    bookmarkStatus,
    actionResult,
  ];
}
