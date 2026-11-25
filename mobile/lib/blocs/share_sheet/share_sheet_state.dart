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

class ShareSheetEnqueueResult extends ShareSheetActionResult {
  ShareSheetEnqueueResult(this.ownerPubkey, this.recipients);
  final String ownerPubkey;
  final List<ShareDeliveryRecipient> recipients;
}

class ShareSheetAccountChanged extends ShareSheetActionResult {}

/// The whole send threw before any recipient's outcome was known.
class ShareSheetSendFailure extends ShareSheetActionResult {
  ShareSheetSendFailure();
}

/// Generic failure for utility actions (copy link, share via).
/// Error details are logged by the BLoC; the UI shows a generic message.
class ShareSheetActionFailure extends ShareSheetActionResult {
  ShareSheetActionFailure();
}

/// What content was copied, so the UI can pick the localized message.
enum ShareSheetCopiedKind { postLink }

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

/// State for the share sheet.
class ShareSheetState extends Equatable {
  const ShareSheetState({
    this.status = ShareSheetStatus.initial,
    this.contacts = const [],
    this.selectedRecipients = const [],
    this.isSending = false,
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
    ShareSheetActionResult? actionResult,
    bool clearActionResult = false,
  }) {
    return ShareSheetState(
      status: status ?? this.status,
      contacts: contacts ?? this.contacts,
      selectedRecipients: selectedRecipients ?? this.selectedRecipients,
      isSending: isSending ?? this.isSending,
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
    actionResult,
  ];
}
