// ABOUTME: Domain model for a NIP-25 emoji reaction on a NIP-17 DM.
// ABOUTME: Carries the local publish state for outgoing rows so the UI
// ABOUTME: can render pending/failed chips without a separate map.

import 'package:equatable/equatable.dart';

/// Local publish state for outgoing reaction rows.
///
/// - [sent]: real reaction event id; published and ack'd.
/// - [pending]: optimistic placeholder id, publish in flight.
/// - [failed]: publish attempt threw; chip shows retry affordance.
/// - [unconfirmed]: the automatic retries ran out while no relay confirmed
///   the reaction, though one may have received it (#8516). Shows like
///   [failed], with a retry, and a later launch tries it again on its own.
/// - [blocked]: send policy (#176 protected-minor DM restriction) rejected the
///   recipient. Terminal and NOT retryable — retrying only re-hits the same
///   policy — so the retry sweep and a chip re-tap must leave it alone. Renders
///   as a settled own chip, never a red retry chip.
/// - [removalRefused]: a kind-5 removal was not delivered: send policy
///   refused it, or its automatic retries ran out. The local reaction stays
///   soft-deleted, but its warning chip offers an explicit retry.
/// - [received]: row originated from an incoming relay event (peer's
///   reaction or self-wrap copy of our own).
enum DmReactionPublishStatus {
  sent,
  pending,
  failed,
  unconfirmed,
  blocked,
  removalRefused,
  received,
}

/// A NIP-25 (kind 7) emoji reaction on a NIP-17 direct message.
///
/// The reaction was carried inside the same seal+gift-wrap envelope as the
/// underlying DM, so no public metadata leaks. The model is account-scoped
/// — [ownerPubkey] is the account viewing it, not the reactor.
class DmReaction extends Equatable {
  const DmReaction({
    required this.id,
    required this.conversationId,
    required this.targetMessageId,
    required this.targetMessageAuthor,
    required this.reactorPubkey,
    required this.emoji,
    required this.createdAt,
    required this.ownerPubkey,
    required this.publishStatus,
    this.giftWrapId,
  });

  /// The reaction rumor event id (kind 7). For outgoing pending rows
  /// this is a placeholder token until publish resolves.
  final String id;

  /// Conversation the target message belongs to.
  final String conversationId;

  /// Rumor id of the message being reacted to.
  final String targetMessageId;

  /// Pubkey of the target message's author.
  final String targetMessageAuthor;

  /// Pubkey of the user who created this reaction.
  final String reactorPubkey;

  /// Reaction content — emoji codepoint or NIP-30 `:shortcode:`.
  final String emoji;

  /// Unix timestamp from the rumor's `created_at`.
  final int createdAt;

  /// Account viewing this row (multi-account isolation).
  final String ownerPubkey;

  /// Local publish state. See [DmReactionPublishStatus].
  final DmReactionPublishStatus publishStatus;

  /// First gift-wrap id observed carrying this reaction. Null for
  /// outgoing rows that have not yet been published.
  final String? giftWrapId;

  /// Is this reaction by the current account?
  bool get isOwn => reactorPubkey == ownerPubkey;

  /// Is this row still in flight or failed (UI shows retry affordance)?
  bool get isUnsettled =>
      publishStatus == DmReactionPublishStatus.pending ||
      publishStatus == DmReactionPublishStatus.failed ||
      publishStatus == DmReactionPublishStatus.unconfirmed;

  @override
  List<Object?> get props => [
    id,
    conversationId,
    targetMessageId,
    targetMessageAuthor,
    reactorPubkey,
    emoji,
    createdAt,
    ownerPubkey,
    publishStatus,
    giftWrapId,
  ];
}
