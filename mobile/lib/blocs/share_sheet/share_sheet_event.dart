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

/// A recipient was toggled (contact-row tap or Find People pick).
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

/// Send video with an optional message to all selected recipients.
class ShareSheetSendRequested extends ShareSheetEvent {
  const ShareSheetSendRequested({this.message});

  final String? message;

  @override
  List<Object?> get props => [message];
}

/// Copy share link to clipboard.
class ShareSheetCopyLinkRequested extends ShareSheetEvent {
  const ShareSheetCopyLinkRequested();
}

/// Share externally via platform share sheet.
class ShareSheetShareViaRequested extends ShareSheetEvent {
  const ShareSheetShareViaRequested();
}
