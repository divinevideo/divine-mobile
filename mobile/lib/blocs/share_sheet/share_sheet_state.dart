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

/// A send finished, with the local outcome of every attempted recipient.
///
/// When at least one recipient is queued the sheet hands [recipients] to the
/// delivery banner and closes; when none is, it stays open on the draft.
class ShareSheetEnqueueResult extends ShareSheetActionResult {
  ShareSheetEnqueueResult(this.ownerPubkey, this.recipients);

  /// The account that sent the share.
  final String ownerPubkey;

  /// Every attempted recipient in selection order, refused ones included.
  final List<ShareDeliveryRecipient> recipients;

  /// Whether no recipient reached the outgoing queue.
  bool get noneQueued =>
      recipients.every((r) => r.outcome.delivery == ShareDelivery.notSent);
}

/// The account that opened the sheet is no longer the signed-in one.
///
/// The sheet closes; nothing it held may be sent as the new account.
class ShareSheetAccountChanged extends ShareSheetActionResult {}

/// The whole send threw before committing, so nothing was queued and a resend
/// cannot duplicate a message.
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

  /// A ready local thumbnail, if the cache found one before the tap.
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
    List<ShareableUser> selectedRecipients = const [],
    this.disabledPubkeys = const {},
    this.unavailablePubkeys = const {},
    this.isSending = false,
    this.refusedRecipients = const [],
    this.sendFailed = false,
    this.ownerExpired = false,
    this.actionResult,
  }) : attemptedRecipients = selectedRecipients;

  /// Current loading status.
  final ShareSheetStatus status;

  /// Loaded contacts (recent + followed users).
  final List<ShareableUser> contacts;

  /// Recipients selected for the message-send flow, in selection order.
  final List<ShareableUser> attemptedRecipients;

  List<ShareableUser> get selectedRecipients => disabledPubkeys.isEmpty
      ? attemptedRecipients
      : attemptedRecipients
            .where((r) => !disabledPubkeys.contains(r.pubkey))
            .toList(growable: false);

  /// Contacts shown but not selectable or sendable: ineligible under the
  /// local block and mute policy, or in [unavailablePubkeys].
  ///
  /// A selected recipient that becomes disabled stays in
  /// [attemptedRecipients] but leaves [selectedRecipients].
  final Set<String> disabledPubkeys;

  /// The part of [disabledPubkeys] that eligibility does not decide: contacts
  /// the ranking snapshot excluded, and rows hydration left without an
  /// identity. Kept so an eligibility change cannot re-enable them.
  final Set<String> unavailablePubkeys;

  /// Whether a send operation is in progress.
  final bool isSending;

  /// Every recipient of the latest send when none of them was queued, so the
  /// sheet keeps naming them until the selection changes or a send starts.
  final List<ShareDeliveryRecipient> refusedRecipients;

  /// Whether the latest send threw before committing, kept until the
  /// selection changes or a send starts.
  final bool sendFailed;

  /// Whether the account that opened the sheet has gone. Once set it stays
  /// set, and the sheet refuses every further load, selection and send.
  final bool ownerExpired;

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
    Set<String>? disabledPubkeys,
    Set<String>? unavailablePubkeys,
    bool? isSending,
    List<ShareDeliveryRecipient>? refusedRecipients,
    bool? sendFailed,
    ShareSheetActionResult? actionResult,
    bool clearActionResult = false,
  }) {
    return ShareSheetState(
      status: status ?? this.status,
      contacts: contacts ?? this.contacts,
      selectedRecipients: selectedRecipients ?? attemptedRecipients,
      disabledPubkeys: disabledPubkeys ?? this.disabledPubkeys,
      unavailablePubkeys: unavailablePubkeys ?? this.unavailablePubkeys,
      isSending: isSending ?? this.isSending,
      refusedRecipients: refusedRecipients ?? this.refusedRecipients,
      sendFailed: sendFailed ?? this.sendFailed,
      ownerExpired: ownerExpired,
      actionResult: clearActionResult
          ? null
          : (actionResult ?? this.actionResult),
    );
  }

  @override
  List<Object?> get props => [
    status,
    contacts,
    attemptedRecipients,
    disabledPubkeys,
    unavailablePubkeys,
    isSending,
    refusedRecipients,
    sendFailed,
    ownerExpired,
    actionResult,
  ];
}
