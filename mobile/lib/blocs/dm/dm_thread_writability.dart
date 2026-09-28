// ABOUTME: Shared policy for whether a DM thread may expose write affordances.
// ABOUTME: Keeps conversation and detached player surfaces on the same gate.

import 'package:openvine/config/official_accounts.dart';

/// Why a DM thread is writable or read-only for the current account.
enum DmThreadWritability {
  writable,
  closedRetired,
  blockedByUs,

  /// No counterparty could be resolved — the conversation row is missing, or
  /// the read failed — so there is nobody to address. Never writable.
  unresolved,
}

/// Resolves the write state shared by every DM surface.
///
/// An empty [participantPubkeys] means the counterparties could not be
/// resolved, so [DmThreadWritability.unresolved] is checked first and wins
/// over every other rule: there is no first participant to test for a block,
/// and no peer to compare against a retired moderation account.
///
/// Retired moderation threads are one-to-one today, but checking every peer
/// keeps a rotated key read-only if an old route reconstructs it as a group.
/// Blocking deliberately follows the conversation's existing rule: the route
/// identifies its target with the first participant. Changing group semantics
/// is a separate product decision.
DmThreadWritability resolveDmThreadWritability({
  required List<String> participantPubkeys,
  required bool Function(String pubkey) isBlockedByUs,
}) {
  if (participantPubkeys.isEmpty) return DmThreadWritability.unresolved;
  if (participantPubkeys.any(isRetiredModerationAccount)) {
    return DmThreadWritability.closedRetired;
  }
  if (isBlockedByUs(participantPubkeys.first)) {
    return DmThreadWritability.blockedByUs;
  }
  return DmThreadWritability.writable;
}
