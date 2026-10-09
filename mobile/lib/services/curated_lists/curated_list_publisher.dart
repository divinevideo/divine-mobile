// ABOUTME: Coordinates durable curated-list publication and privacy recovery.
// ABOUTME: Keeps unconfirmed intents out of retry and retains NIP-09 requests.

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/curated_list_relay_gateway.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_journal.dart';
import 'package:unified_logger/unified_logger.dart';

/// Persists a replacement only while [current] is still the captured row.
typedef PersistCuratedList = Future<bool> Function(
  CuratedList current,
  CuratedList replacement,
);

/// Positive authority for the exact target at the point of relay dispatch.
typedef CuratedListPublicationAuthorization = bool Function(CuratedList target);

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
    required CuratedListRecoveryJournal recoveryJournal,
    required bool Function() isCurrentSession,
    required CuratedListPublicationAuthorization isPublicationAuthorized,
    void Function(CuratedList target, Event event)? onPublicationAccepted,
  }) : _client = client,
       _gateway = gateway,
       _clock = publishClock,
       _findList = findList,
       _persistList = persistList,
       _recovery = recoveryJournal,
       _isCurrentSession = isCurrentSession,
       _isPublicationAuthorized = isPublicationAuthorized,
       _onPublicationAccepted = onPublicationAccepted;

  final NostrClient _client;
  final CuratedListRelayGateway _gateway;
  final CuratedListPublishClock _clock;
  final CuratedList? Function(String) _findList;
  final PersistCuratedList _persistList;

  final CuratedListRecoveryJournal _recovery;
  final bool Function() _isCurrentSession;
  final CuratedListPublicationAuthorization _isPublicationAuthorized;
  final void Function(CuratedList target, Event event)? _onPublicationAccepted;

  bool _owns(String owner) =>
      _isCurrentSession() && _gateway.currentAuthenticatedPubkey() == owner;

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
      if (owner == null ||
          target.pubkey != owner ||
          !_owns(owner) ||
          !_isPublicationAuthorized(target) ||
          _recovery.needsRepair(owner)) {
        return false;
      }
      final event = await _gateway.signList(
        target,
        ownerPubkey: owner,
        createdAt: () => _clock.next(ownerPubkey: owner, listId: target.id),
      );
      if (event == null ||
          event.pubkey != owner ||
          !_owns(owner) ||
          !_isPublicationAuthorized(target)) {
        return false;
      }

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
      if (!await _persistList(current, sending) ||
          !_owns(owner) ||
          !_isPublicationAuthorized(target)) {
        return false;
      }

      final changesPermissions =
          CuratedListVisibility.fromList(current) !=
          CuratedListVisibility.fromList(target);
      final evidenceTicket = changesPermissions
          ? await _recovery.ticket(owner, current.id)
          : null;
      // Ticket capture crosses the shared recovery barrier. A retired lease
      // cannot dispatch, even when that capture produced a ticket before
      // the barrier reported its operation cancelled.
      if (!_owns(owner) ||
          !_isPublicationAuthorized(target) ||
          _recovery.needsRepair(owner)) {
        return false;
      }
      if (changesPermissions && evidenceTicket == null) return false;
      final priorPlaintextIds = <String>{
        ...current.pendingPlaintextEventIds,
        if (current.isPublic &&
            !target.isPublic &&
            current.nostrEventId != null)
          current.nostrEventId!,
      };
      if (!_owns(owner) || !_isPublicationAuthorized(target)) return false;
      if (confirmed || changesPermissions) {
        attemptedConfirmedSend = true;
        final outcome = await _client.publishEventAwaitOk(event);
        relayAccepted = outcome.acceptedByAny;
        if (!relayAccepted) {
          Log.warning(
            'List publish not accepted (rejected=${outcome.rejectedBy.length}, '
            'noResponse=${outcome.noResponseFrom.length})',
            name: 'CuratedListPublisher',
            category: LogCategory.system,
          );
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
        if (result.failureReason != null) {
          Log.warning(
            'List publish failed (${result.failureReason.runtimeType})',
            name: 'CuratedListPublisher',
            category: LogCategory.system,
          );
          return false;
        }
      }
      var savedAcceptance = true;
      if (changesPermissions) {
        try {
          savedAcceptance = await _recovery.accepted(
            owner: owner,
            listId: current.id,
            visibility: CuratedListVisibility.fromList(
              target,
              relayAccepted: true,
            ),
            eventId: event.id,
            acceptedAt: signedAt,
            plaintextEventIds: priorPlaintextIds,
            ticket: evidenceTicket,
          );
        } catch (error) {
          savedAcceptance = false;
          Log.warning(
            'Acknowledged list recovery storage failed (${error.runtimeType})',
            name: 'CuratedListPublisher',
            category: LogCategory.system,
          );
        }
      }
      // Only minimal captured evidence can outlive the cache's account lease.
      if (!_owns(owner) || !_isPublicationAuthorized(target)) return false;
      current = _findList(target.authorScopedId);
      if (current == null || current.pubkey != owner) return false;
      if (current != sending) {
        // A newer durable relay revision wins; retain only advisory evidence.
        await _recovery.visibilityCommitted(owner, current.id, current);
        return false;
      }
      final commitsPermissions =
          CuratedListVisibility.fromList(current) !=
          CuratedListVisibility.fromList(target);
      if (commitsPermissions) {
        if (!_owns(owner) || !_isPublicationAuthorized(target)) return false;
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
        // Even refused recovery storage projects the retained ACK into this
        // session. Only an explicit Sync may settle it; cleanup must drain it.
        if (!await _persistList(current, journal) ||
            !savedAcceptance ||
            !_owns(owner) ||
            !_isPublicationAuthorized(target)) {
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
      if (!_isPublicationAuthorized(target) ||
          !await _persistList(current, committed) ||
          !_owns(owner) ||
          !_isPublicationAuthorized(target)) {
        return false;
      }
      if (!await _recovery.visibilityCommitted(
            owner,
            committed.id,
            committed,
          ) ||
          !_owns(owner) ||
          !_isPublicationAuthorized(target)) {
        return false;
      }
      // Failure of advisory redaction does not undo an accepted replacement.
      // Its IDs remain stored for a later sync, without claiming erasure.
      if (relayAccepted) _onPublicationAccepted?.call(target, event);
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
  ///
  /// The owner journal also covers a row wiped by ordinary logout. A pending
  /// permission transition needs an owned row recovered first; an accepted
  /// private commit's deletion IDs can be delivered without its payload.
  Future<bool> retryPlaintextRedactions(String authorScopedId) async {
    final separator = authorScopedId.indexOf(':');
    if (separator < 1) return false;
    final owner = authorScopedId.substring(0, separator);
    final listId = authorScopedId.substring(separator + 1);
    if (!_owns(owner) || _recovery.needsRepair(owner)) return false;
    var current = _findList(authorScopedId);
    var saved = _recovery.record(owner, listId);
    if (current?.hasPendingPermissionRecovery == true) return false;
    if (saved?.requiresPrivateCommit == true && current?.isPublic == true) {
      return false;
    }
    if (saved?.visibility != null || saved?.requiresPrivateCommit == true) {
      if (current == null ||
          current.nostrEventId == null ||
          current.pendingRepublish ||
          _recovery.needsPermissionRecovery(current, owner)) {
        return false;
      }
      if (!await _recovery.visibilityCommitted(owner, listId, current) ||
          !_owns(owner)) {
        return false;
      }
      saved = _recovery.record(owner, listId);
    }
    if (saved?.acceptedAt != null) {
      _clock.observeRevision(
        ownerPubkey: owner,
        listId: listId,
        updatedAt: saved!.acceptedAt!,
      );
    }
    final pending = <String>{
      ...?current?.pendingPlaintextEventIds,
      ...?saved?.plaintextEventIds,
    };
    for (final eventId in pending) {
      try {
        current = _findList(authorScopedId);
        if (!_owns(owner) || current?.hasPendingPermissionRecovery == true) {
          return false;
        }
        final createdAt = _clock.next(ownerPubkey: owner, listId: listId);
        if (current != null) {
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
        }
        final accepted = await _gateway.redactPlaintextListEvent(
          eventId,
          ownerPubkey: owner,
          createdAt: createdAt,
        );
        if (!accepted || !_owns(owner)) {
          Log.warning(
            'Plaintext deletion request not accepted; recovery retained',
            name: 'CuratedListPublisher',
            category: LogCategory.system,
          );
          return false;
        }
        current = _findList(authorScopedId);
        if (current != null) {
          final completed = current.copyWith(
            pendingPlaintextEventIds: current.pendingPlaintextEventIds
                .where((id) => id != eventId)
                .toList(growable: false),
          );
          if (!await _persistList(current, completed) || !_owns(owner)) {
            return false;
          }
        }
        if (!await _recovery.redactionAccepted(owner, listId, eventId) ||
            !_owns(owner)) {
          return false;
        }
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
