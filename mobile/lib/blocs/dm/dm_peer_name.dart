// ABOUTME: The one naming precedence every DM surface resolves a peer through.
// ABOUTME: Pure and Flutter-free, so the inbox search index in
// ABOUTME: ConversationListBloc matches the string the row actually renders.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';

/// The conversation participants other than the signed-in viewer.
///
/// Nostr hex keys are case-insensitive. Keeping this comparison here prevents
/// inbox rows, navigation, actions, and search from disagreeing about which
/// participant is the viewer when stored keys use different casing.
List<String> dmConversationPeerPubkeys({
  required List<String> participantPubkeys,
  required String currentUserPubkey,
}) => participantPubkeys
    .where((pubkey) => !pubkeysEqual(pubkey, currentUserPubkey))
    .toList();

/// The first non-viewer participant, with the historical first-participant
/// fallback for malformed rows.
String dmConversationFirstPeer({
  required List<String> participantPubkeys,
  required String currentUserPubkey,
}) =>
    dmConversationPeerPubkeys(
      participantPubkeys: participantPubkeys,
      currentUserPubkey: currentUserPubkey,
    ).firstOrNull ??
    participantPubkeys.first;

/// The localized strings [dmPeerName] substitutes for a peer whose own name
/// must not be shown.
///
/// Injected rather than read from `context.l10n`, because the search index
/// that matches on them lives in a BLoC. Both values are already-translated
/// ARB keys: [deletedAccount] is `profileDeletedAccountName`, [moderation] is
/// `inboxSupportRowTitle`, and [retiredConversationClosed] is
/// `dmRetiredThreadClosedTitle`.
class DmPeerLabels extends Equatable {
  const DmPeerLabels({
    required this.deletedAccount,
    required this.moderation,
    required this.retiredConversationClosed,
  });

  /// Shown instead of the name of an account that published a NIP-62 vanish.
  final String deletedAccount;

  /// Shown instead of the kind-0 name of a Divine Moderation key.
  final String moderation;

  /// Shown instead of message content for a retired moderation thread.
  final String retiredConversationClosed;

  @override
  List<Object?> get props => [
    deletedAccount,
    moderation,
    retiredConversationClosed,
  ];
}

/// Participants a group's fallback name must account for beyond the one it
/// names.
///
/// Counts peers only — the viewer is always in `participantPubkeys` and naming
/// a room "Alice and 2 others" to the third member would count them among the
/// strangers. Returns 0 rather than -1 for a degenerate row with no peer at
/// all, so the plural never renders a negative.
int dmGroupOtherCount({
  required List<String> participantPubkeys,
  required String currentUserPubkey,
}) {
  final peers = dmConversationPeerPubkeys(
    participantPubkeys: participantPubkeys,
    currentUserPubkey: currentUserPubkey,
  ).length;
  return peers <= 1 ? 0 : peers - 1;
}

/// The title a conversation row and the sheet it opens must agree on.
///
/// A 1:1 thread is named for its peer, so [peerName] answers directly. A group
/// has no single peer to name it after — naming it for `participants.first`
/// picks an arbitrary member and hides that anyone else is in the room. NIP-17
/// gives the room a name of its own instead: "An optional `subject` tag defines
/// the current name/topic of the conversation … The newest `subject` in the
/// chat room is the subject of the conversation" (NIP-17). Divine has parsed
/// and stored that tag since the DM repository landed, so a titled room can be
/// named correctly with what is already on the row.
///
/// [groupFallbackName] answers for a room carrying no subject, and is passed in
/// already formatted for the same reason [dmPeerName] takes `profileName`: the
/// precedence is shared, the localized string lookup is not — the widget chain
/// reads it from `context.l10n` and the search index from its injected labels.
///
/// An empty or whitespace-only subject is treated as absent. A peer can set one
/// to any string, and a room titled `"   "` would otherwise render as a blank
/// row with no way to tell which thread it is.
String dmConversationTitle({
  required bool isGroup,
  required String peerName,
  required String groupFallbackName,
  String? subject,
}) {
  if (!isGroup) return peerName;
  final titled = subject?.trim();
  if (titled != null && titled.isNotEmpty) return titled;
  // An empty [peerName] is #8394's "still resolving" signal. A titled room is
  // named above without a profile, but an untitled one is named FOR its peer,
  // so falling through would render "and 2 others" beside a name that has not
  // arrived. Propagate the empty instead and let the caller skeleton it.
  if (peerName.isEmpty) return '';
  return groupFallbackName;
}

/// Resolves the profile-independent prefix shared by the row and action sheet.
String? dmPeerSubstituteName({
  required bool isVanished,
  required bool isModeration,
  required DmPeerLabels labels,
  String? displayNameOverride,
}) {
  if (isVanished) return labels.deletedAccount;
  if (displayNameOverride != null) return displayNameOverride;
  if (isModeration) return labels.moderation;
  return null;
}

/// The peer's name, in the precedence every DM surface has to agree on:
/// vanished, override, moderation, profile, generated.
///
/// This function exists because that precedence used to be written twice — the
/// widget chain rendered all five steps while `ConversationListBloc` matched on
/// the last two, so a vanished peer's row read "Deleted account" while inbox
/// search indexed a generated "Adjective Animal N" the viewer had never seen
/// (#8204). Keeping it in one pure place is what stops the next branch
/// diverging the same way.
///
/// A vanish comes first because it is the only branch that contradicts the ones
/// below it: applying one evicts the cached profile and short-circuits every
/// later fetch, so a caller that skips this check does not fall back to the
/// peer's last known name — it falls all the way through to
/// [UserProfile.defaultDisplayNameFor].
///
/// [profileName] is the caller's already-resolved step-4 value: the widget
/// chain passes `profile?.bestDisplayName`, and the BLoC passes its cached
/// entry. Both may be null, and the generated fallback answers for them.
///
/// While [isResolving] is true, the generated fallback is withheld so a
/// deterministic placeholder is not presented as the peer's real identity.
String dmPeerName({
  required String pubkeyHex,
  required bool isVanished,
  required bool isModeration,
  required DmPeerLabels labels,
  String? profileName,
  String? displayNameOverride,
  bool isResolving = false,
}) {
  final substitute = dmPeerSubstituteName(
    isVanished: isVanished,
    isModeration: isModeration,
    labels: labels,
    displayNameOverride: displayNameOverride,
  );
  if (substitute != null) return substitute;
  if (profileName != null) return profileName;
  if (isResolving) return '';
  return UserProfile.defaultDisplayNameFor(pubkeyHex);
}
