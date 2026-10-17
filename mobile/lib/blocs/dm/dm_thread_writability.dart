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
/// over every other rule: there is no participant to test for a block, and no
/// peer to compare against a retired moderation account.
///
/// Retired moderation threads are one-to-one today, but checking every peer
/// keeps a rotated key read-only if an old route reconstructs it as a group.
///
/// Blocking one member of a group keeps the thread writable, and the view
/// discloses the block (#10150). A group with every member blocked is
/// read-only, like a blocked one-to-one, which stays readable (#7025).
DmThreadWritability resolveDmThreadWritability({
  required List<String> participantPubkeys,
  required bool Function(String pubkey) isBlockedByUs,
}) {
  if (participantPubkeys.isEmpty) return DmThreadWritability.unresolved;
  if (participantPubkeys.any(isRetiredModerationAccount)) {
    return DmThreadWritability.closedRetired;
  }
  if (participantPubkeys.every(isBlockedByUs)) {
    return DmThreadWritability.blockedByUs;
  }
  return DmThreadWritability.writable;
}

/// The participants the viewer blocked, in route order.
///
/// The thread is [DmThreadWritability.blockedByUs] only when this holds every
/// participant; a group's read-only notice is built from this list.
List<String> dmThreadBlockedParticipants({
  required List<String> participantPubkeys,
  required bool Function(String pubkey) isBlockedByUs,
}) => participantPubkeys.where(isBlockedByUs).toList();
