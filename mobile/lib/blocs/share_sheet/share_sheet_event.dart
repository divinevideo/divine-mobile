// ABOUTME: Events for ShareSheetBloc
// ABOUTME: Handles contact loading, recipient selection, and share actions

part of 'share_sheet_bloc.dart';

/// Base class for share sheet events.
sealed class ShareSheetEvent extends Equatable {
  const ShareSheetEvent();

  @override
  List<Object?> get props => [];
}

/// Request to load contacts (recent + followed users).
///
/// Dispatched on BLoC creation to populate the contact list.
class ShareSheetContactsLoadRequested extends ShareSheetEvent {
  const ShareSheetContactsLoadRequested();
}

/// A recipient was toggled in the composer selection.
///
/// Adds the user to the selection, or removes them when already
/// selected. Selection never sends — it reveals the message composer;
/// the send happens only on an explicit [ShareSheetSendRequested].
class ShareSheetRecipientToggled extends ShareSheetEvent {
  const ShareSheetRecipientToggled(this.recipient);

  final ShareableUser recipient;

  @override
  List<Object?> get props => [recipient.pubkey];
}

/// Send a video to one contact or to all selected recipients with an optional
/// message.
class ShareSheetSendRequested extends ShareSheetEvent {
  const ShareSheetSendRequested({this.message, this.only});

  /// The direct-send contact. A direct send requires an empty selection and
  /// no message.
  final ShareableUser? only;

  /// The optional note sent with the video; blank is sent as none.
  final String? message;

  @override
  List<Object?> get props => [message, only];
}

/// Copy share link to clipboard.
class ShareSheetCopyLinkRequested extends ShareSheetEvent {
  const ShareSheetCopyLinkRequested();
}

/// Share externally via platform share sheet.
class ShareSheetShareViaRequested extends ShareSheetEvent {
  const ShareSheetShareViaRequested();
}

/// The local thumbnail lookup that starts with the sheet found a file.
class ShareSheetThumbnailPrepared extends ShareSheetEvent {
  const ShareSheetThumbnailPrepared(this.path);

  /// Path of the image-cache file holding the video's thumbnail.
  final String path;

  @override
  List<Object?> get props => [path];
}

/// Local block or mute policy changed while the sheet was visible.
class ShareSheetEligibilityChanged extends ShareSheetEvent {
  const ShareSheetEligibilityChanged();
}

/// The signed-in account changed or its session is being torn down.
///
/// Clears every contact and selection and closes the sheet; the bloc then
/// refuses all further work for the old account.
class ShareSheetOwnerChanged extends ShareSheetEvent {
  const ShareSheetOwnerChanged();
}
