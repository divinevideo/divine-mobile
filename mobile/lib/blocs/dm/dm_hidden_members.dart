// ABOUTME: Which group messages a conversation collapses by default because
// ABOUTME: their sender is on the viewer's own block or mute list (#10150).

import 'package:nostr_sdk/nip19/pubkeys_equal.dart';

/// Whether a message renders collapsed until the viewer asks to see it.
///
/// Only a group collapses: blocking one member hides that member, not the
/// room. A one-to-one with a hidden peer stays readable in full, and the
/// viewer's own messages never collapse. [isHidden] must answer from the
/// viewer's own lists only (#7345). Collapsing keeps the message on the
/// device, so unblocking shows it again (#7025).
bool dmMessageHiddenByDefault({
  required bool isGroup,
  required String senderPubkey,
  required String currentUserPubkey,
  required bool Function(String pubkey) isHidden,
}) =>
    isGroup &&
    senderPubkey.isNotEmpty &&
    !pubkeysEqual(senderPubkey, currentUserPubkey) &&
    isHidden(senderPubkey);
