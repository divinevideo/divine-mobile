// ABOUTME: Result of DmRepository.enqueueSend — the enqueue-only DM seam.
// ABOUTME: Reports the parked rumor id, or why nothing was enqueued.

import 'package:meta/meta.dart';

/// Outcome of enqueuing a NIP-17 DM without publishing it (#8053).
///
/// `enqueueSend` runs the same guards and durable enqueue as `sendMessage` but
/// stops before the network publish, so a caller can await only the fast local
/// write and drive delivery later (via `recoverFullSend` or the retry sweep).
///
/// Exactly one of these holds:
/// - [accepted] (`queuedRumorId != null`): a row is parked and ready to drive.
/// - [refused]: a self-addressed send (#8352) — a silent no-op, never queued.
/// - [blocked]: refused by send policy (#176) — not retryable.
/// - [tooLong]: the rumor exceeds the NIP-44 size ceiling (#7331) — not
///   retryable, nothing queued.
@immutable
class EnqueueSendResult {
  const EnqueueSendResult({
    this.queuedRumorId,
    this.refused = false,
    this.blocked = false,
    this.tooLong = false,
    this.error,
  });

  /// A row was enqueued; drive it with `recoverFullSend(rumorId:)`.
  const EnqueueSendResult.enqueued(String rumorId)
    : queuedRumorId = rumorId,
      refused = false,
      blocked = false,
      tooLong = false,
      error = null;

  const EnqueueSendResult.refused(String this.error)
    : queuedRumorId = null,
      refused = true,
      blocked = false,
      tooLong = false;

  const EnqueueSendResult.blocked(String this.error)
    : queuedRumorId = null,
      refused = false,
      blocked = true,
      tooLong = false;

  const EnqueueSendResult.tooLong(String this.error)
    : queuedRumorId = null,
      refused = false,
      blocked = false,
      tooLong = true;

  /// The durable `outgoing_dms` row id (the rumor id) when enqueued, else null.
  final String? queuedRumorId;

  final bool refused;
  final bool blocked;
  final bool tooLong;
  final String? error;

  /// Whether a durable row was parked and is ready to drive.
  bool get accepted => queuedRumorId != null;
}
