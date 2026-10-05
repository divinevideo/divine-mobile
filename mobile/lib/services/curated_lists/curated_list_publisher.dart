// ABOUTME: Coordinates durable curated-list publication and privacy recovery.
// ABOUTME: Keeps unconfirmed intents out of retry and retains NIP-09 requests.

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/curated_list_relay_gateway.dart';
import 'package:unified_logger/unified_logger.dart';

/// Persists a replacement only while [current] is still the captured row.
typedef PersistCuratedList = Future<bool> Function(
  CuratedList current,
  CuratedList replacement,
);

/// The app's publication adapter; the cache owner supplies its storage edge.
///
/// Privacy and permissions stay at their last accepted values during a send.
/// Only a relay-acknowledged target enters the durable recovery journal.
class CuratedListPublisher {
  CuratedListPublisher({
    required NostrClient client,
    required CuratedListRelayGateway gateway,
    required CuratedListPublishClock publishClock,
    required CuratedList? Function(String) findList,
    required PersistCuratedList persistList,
  }) : _client = client,
       _gateway = gateway,
       _clock = publishClock,
       _findList = findList,
       _persistList = persistList;

  final NostrClient _client;
  final CuratedListRelayGateway _gateway;
  final CuratedListPublishClock _clock;
  final CuratedList? Function(String) _findList;
  final PersistCuratedList _persistList;

  bool _owns(String owner) => _gateway.currentAuthenticatedPubkey() == owner;

  Future<bool> publish(
    CuratedList source, {
    bool confirmed = false,
    void Function()? onPublicationUnconfirmed,
  }) async {
    var attemptedConfirmedSend = false;
    var relayAccepted = false;
    var reportedUnconfirmed = false;
    void reportUnconfirmed() {
      if (reportedUnconfirmed) return;
      reportedUnconfirmed = true;
      onPublicationUnconfirmed?.call();
    }

    try {
      final target = source.publicationTarget;
      final owner = _gateway.currentAuthenticatedPubkey();
      if (owner == null || target.pubkey != owner) return false;
      final event = await _gateway.signList(
        target,
        ownerPubkey: owner,
        createdAt: () => _clock.next(ownerPubkey: owner, listId: target.id),
      );
      if (event == null || event.pubkey != owner || !_owns(owner)) return false;

      var current = _findList(target.authorScopedId);
      if (current == null || current.pubkey != owner) return false;
      final acknowledged = current.pendingVisibility?.relayAccepted == true
          ? current.pendingVisibility
          : null;
      final signedAt = event.createdAtDateTime;
      final sending = target
          .stageVisibilityFrom(current)
          .copyWith(
            nostrEventId: current.nostrEventId,
            updatedAt: signedAt.isAfter(current.updatedAt)
                ? signedAt
                : current.updatedAt,
            pendingRepublish: true,
            pendingVisibility: acknowledged,
            clearPendingVisibility: acknowledged == null,
            pendingPlaintextEventIds: current.pendingPlaintextEventIds,
          );
      // Persist the attempted revision, but never a new unconfirmed proposal.
      // If this write fails, the cache callback restores only this candidate.
      if (!await _persistList(current, sending) || !_owns(owner)) return false;

      final changesPermissions =
          CuratedListVisibility.fromList(current) !=
          CuratedListVisibility.fromList(target);
      if (confirmed || changesPermissions) {
        attemptedConfirmedSend = true;
        final outcome = await _client.publishEventAwaitOk(event);
        relayAccepted = outcome.acceptedByAny;
        if (!relayAccepted) {
          if (outcome.noResponseFrom.isNotEmpty || outcome.rejectedBy.isEmpty) {
            reportUnconfirmed();
          }
          if (outcome.rejectedBy.values.any(
            (reason) => reason.toLowerCase().contains('future'),
          )) {
            _clock.rejectedFuture(
              ownerPubkey: owner,
              listId: target.id,
              createdAt: event.createdAt,
            );
          }
          // The only remaining proposal can be an earlier acknowledged
          // recovery. A failed new request was never persisted as an intent.
          return false;
        }
      } else {
        final result = await _client.publishEvent(event);
        if (result.failureReason != null) return false;
      }
      // Recording an already acknowledged event still belongs to its
      // captured author's unchanged row after an account switch. Further
      // signing/redaction remains gated to the active owner.
      current = _findList(target.authorScopedId);
      if (current == null || current.pubkey != owner || current != sending) {
        return false;
      }
      final commitsPermissions =
          CuratedListVisibility.fromList(current) !=
          CuratedListVisibility.fromList(target);
      if (commitsPermissions) {
        // An acknowledged target must survive a rejected final acceptance
        // write. Unlike the old pre-send proposal, this journal is safe to
        // recover through later metadata edits and restart backfill.
        final journal = target
            .stageVisibilityFrom(
              current,
              stageProposal: true,
              relayAccepted: true,
            )
            .copyWith(
              nostrEventId: current.nostrEventId,
              updatedAt: current.updatedAt,
              pendingRepublish: true,
              pendingPlaintextEventIds: current.pendingPlaintextEventIds,
            );
        if (!await _persistList(current, journal)) {
          return false;
        }
        current = _findList(target.authorScopedId);
        if (current == null || current != journal) return false;
      }

      // Capture old plaintext IDs before replacing the event identity. The
      // outbox is durable in the same commit as the private accepted state.
      final plaintextIds = <String>{...current.pendingPlaintextEventIds};
      if (current.isPublic &&
          !target.isPublic &&
          current.nostrEventId != null) {
        plaintextIds.add(current.nostrEventId!);
      }
      final committed = current.copyWith(
        nostrEventId: event.id,
        updatedAt: signedAt.isAfter(current.updatedAt)
            ? signedAt
            : current.updatedAt,
        isPublic: target.isPublic,
        isCollaborative: target.isCollaborative,
        allowedCollaborators: target.allowedCollaborators,
        pendingRepublish: false,
        clearPendingVisibility: true,
        pendingPlaintextEventIds: plaintextIds.toList(growable: false),
      );
      if (!await _persistList(current, committed)) return false;
      // Failure of advisory redaction does not undo an accepted replacement.
      // Its IDs remain stored for a later sync, without claiming erasure.
      await retryPlaintextRedactions(target.authorScopedId);
      return true;
    } catch (error) {
      if (attemptedConfirmedSend && !relayAccepted) reportUnconfirmed();
      Log.warning(
        'Curated list publication deferred (${error.runtimeType})',
        name: 'CuratedListPublisher',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Retries event-specific requests without republishing an accepted list.
  Future<bool> retryPlaintextRedactions(String authorScopedId) async {
    var current = _findList(authorScopedId);
    final owner = current?.pubkey;
    if (current == null || owner == null || !_owns(owner)) return false;
    for (final eventId in List<String>.of(current.pendingPlaintextEventIds)) {
      try {
        current = _findList(authorScopedId);
        if (current == null || !_owns(owner)) return false;
        // A pending private acceptance journal is not yet a durable private
        // commit. Publish/recover it before requesting plaintext deletion.
        if (current.pendingVisibility != null && current.isPublic) return false;
        final createdAt = _clock.next(ownerPubkey: owner, listId: current.id);
        final reservedAt = DateTime.fromMillisecondsSinceEpoch(
          createdAt * 1000,
        );
        final reserved = current.copyWith(
          updatedAt: reservedAt.isAfter(current.updatedAt)
              ? reservedAt
              : current.updatedAt,
        );
        if (!await _persistList(current, reserved) || !_owns(owner)) {
          return false;
        }
        final accepted = await _gateway.redactPlaintextListEvent(
          eventId,
          ownerPubkey: owner,
          createdAt: createdAt,
        );
        if (!accepted || !_owns(owner)) return false;
        current = _findList(authorScopedId);
        if (current == null) return false;
        final completed = current.copyWith(
          pendingPlaintextEventIds: current.pendingPlaintextEventIds
              .where((id) => id != eventId)
              .toList(growable: false),
        );
        if (!await _persistList(current, completed)) return false;
      } catch (error) {
        Log.warning(
          'Plaintext redaction deferred (${error.runtimeType})',
          name: 'CuratedListPublisher',
          category: LogCategory.system,
        );
        return false;
      }
    }
    return true;
  }
}
