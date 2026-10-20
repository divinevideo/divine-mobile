// ABOUTME: Account deletion service implementing NIP-62 Request to Vanish
// ABOUTME: Handles network-wide account deletion by publishing kind 5 events for all user content
// ABOUTME: then publishing kind 62 event to all relays

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/relay_url_utils.dart';
import 'package:unified_logger/unified_logger.dart';

/// User-facing class of an account deletion failure.
enum DeleteAccountFailureReason {
  notAuthenticated,
  noPubkey,
  signingFailed,
  vanishNotConfirmed,
  accountRestricted,
  accountChanged,
  accountChangedAfterDeletion,
  unexpected,
}

/// Result of account deletion operation
class DeleteAccountResult {
  const DeleteAccountResult({
    required this.success,
    this.failureReason,
    this.diagnosticError,
    this.deleteEventId,
    this.deletedEventsCount = 0,
    this.contentQueryFailed = false,
    this.contentDeletionIncomplete = false,
  });

  final bool success;
  final DeleteAccountFailureReason? failureReason;

  /// Diagnostic detail for logs/tests only. UI must localize [failureReason].
  final String? diagnosticError;

  final String? deleteEventId;

  /// Number of events a relay actually confirmed (`OK true`) a kind-5 deletion
  /// request for — not merely the number we managed to write to a socket.
  final int deletedEventsCount;

  /// True when the relay query that enumerates the user's existing content
  /// failed or timed out, so the kind-5 sweep may have covered only cached or
  /// partial results.
  ///
  /// The vanish request may still have been published, so the caller must tell
  /// the user their existing content may not all have been individually
  /// requested for deletion rather than reporting an unqualified success.
  final bool contentQueryFailed;

  /// True when enumeration reached its cap or at least one event that required
  /// a kind-5 compatibility request did not get an OK confirmation.
  final bool contentDeletionIncomplete;

  factory DeleteAccountResult.createSuccess(
    String deleteEventId, {
    int deletedEventsCount = 0,
    bool contentQueryFailed = false,
    bool contentDeletionIncomplete = false,
  }) => DeleteAccountResult(
    success: true,
    deleteEventId: deleteEventId,
    deletedEventsCount: deletedEventsCount,
    contentQueryFailed: contentQueryFailed,
    contentDeletionIncomplete: contentDeletionIncomplete,
  );

  factory DeleteAccountResult.failure(
    DeleteAccountFailureReason reason, {
    String? diagnosticError,
  }) => DeleteAccountResult(
    success: false,
    failureReason: reason,
    diagnosticError: diagnosticError,
  );
}

/// Thrown when the signed-in account changes before the vanish request is
/// confirmed, so cleanup must not continue for a different account.
class AccountChangedDuringDeletion implements Exception {
  const AccountChangedDuringDeletion();

  @override
  String toString() => 'AccountChangedDuringDeletion';
}

/// Thrown when the signed-in account changes after a relay confirms any
/// deletion request. Network deletion has begun, but account-bound cleanup must
/// stop before it can target the newly signed-in account.
class AccountChangedAfterDeletion implements Exception {
  const AccountChangedAfterDeletion();

  @override
  String toString() => 'AccountChangedAfterDeletion';
}

class _VanishPublishConfig {
  const _VanishPublishConfig({
    required this.maxAttempts,
    required this.timeout,
    required this.retryDelays,
  }) : assert(maxAttempts > 0, 'maxAttempts must be at least 1');

  final int maxAttempts;
  final Duration timeout;
  final List<Duration> retryDelays;
}

class _PreparedDeletionBatch {
  const _PreparedDeletionBatch({
    required this.event,
    required this.deletedKind,
    required this.deletedEventCount,
  });

  final Event event;
  final int deletedKind;
  final int deletedEventCount;
}

class _PreparedDeletionSweep {
  const _PreparedDeletionSweep({
    required this.batches,
    required this.targetRelays,
    required this.totalEventCount,
    required this.incompleteWithoutPublishing,
  });

  final List<_PreparedDeletionBatch> batches;
  final List<String> targetRelays;
  final int totalEventCount;
  final bool incompleteWithoutPublishing;
}

/// Service for deleting user's entire Nostr account via NIP-62
class AccountDeletionService {
  AccountDeletionService({
    required NostrClient nostrService,
    required AuthService authService,
    Future<void> Function(Duration duration)? retryDelay,
  }) : _nostrService = nostrService,
       _authService = authService,
       _retryDelay = retryDelay ?? Future<void>.delayed;

  final NostrClient _nostrService;
  final AuthService _authService;
  final Future<void> Function(Duration duration) _retryDelay;

  static const _vanishPublish = _VanishPublishConfig(
    maxAttempts: 3,
    timeout: Duration(seconds: 30),
    retryDelays: [Duration(seconds: 2), Duration(seconds: 5)],
  );
  static const _interBatchDelay = Duration(milliseconds: 500);
  static const _rateLimitRetryDelay = Duration(minutes: 1);
  static const _sweepQueryLimit = 10000;
  static const _sweepQueryTimeout = Duration(seconds: 30);

  /// Kinds this flow's own deletion machinery produces, excluded from the sweep.
  ///
  /// NIP-09: "Publishing a deletion request event against a deletion request has
  /// no effect." NIP-62 states the same for a request to vanish. Sweeping them
  /// asks relays to delete this flow's own kind-5 requests and the vanish
  /// request itself, which grows the `e`-tag list on every retry for no
  /// protocol effect — and asks the network to retract a legally-framed vanish.
  static const _kindsExcludedFromSweep = {5, 62};

  /// Inclusive lower bound of the NIP-01 addressable (parameterized replaceable)
  /// range. Deletions for these kinds need an `a` tag, not just `e`.
  static const _addressableKindMin = 30000;
  static const _addressableKindMax = 39999;

  /// Aborts (via [AccountChangedDuringDeletion]) if [expectedPubkey] is set and
  /// no longer matches the live signer. Called immediately before every
  /// destructive sign/publish and after each awaited deletion outcome so a
  /// mid-flight account switch can't continue cleanup for a different account.
  void _assertSignerMatches(String? expectedPubkey) {
    if (expectedPubkey != null &&
        _authService.currentPublicKeyHex != expectedPubkey) {
      throw const AccountChangedDuringDeletion();
    }
  }

  void _assertSignerStillMatches(
    String? expectedPubkey, {
    required bool anyConfirmed,
  }) {
    try {
      _assertSignerMatches(expectedPubkey);
    } on AccountChangedDuringDeletion {
      if (anyConfirmed) {
        throw const AccountChangedAfterDeletion();
      }
      rethrow;
    }
  }

  /// Delete user's account using NIP-62 Request to Vanish
  /// First fetches all user events and publishes kind 5 deletion requests for each
  /// Then publishes kind 62 account deletion request
  Future<DeleteAccountResult> deleteAccount({
    String? customReason,
    void Function(int current, int total)? onProgress,
    String? expectedPubkey,
  }) async {
    var deletedCount = 0;
    var kind5DeletionIncomplete = false;
    try {
      if (!_authService.isAuthenticated) {
        return DeleteAccountResult.failure(
          DeleteAccountFailureReason.notAuthenticated,
          diagnosticError: 'Not authenticated',
        );
      }

      final pubkey = _authService.currentPublicKeyHex;
      if (pubkey == null || pubkey.isEmpty) {
        return DeleteAccountResult.failure(
          DeleteAccountFailureReason.noPubkey,
          diagnosticError: 'No pubkey available',
        );
      }
      if (expectedPubkey != null && pubkey != expectedPubkey) {
        return DeleteAccountResult.failure(
          DeleteAccountFailureReason.accountChanged,
          diagnosticError: 'Signed-in account changed; deletion aborted',
        );
      }

      final reason =
          customReason ?? 'User requested account deletion via Divine app';

      Log.info(
        'Starting account deletion for pubkey: ${pubkeyForLogs(pubkey)}',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );

      final sweep = await _fetchSweepTargets(pubkey);
      final allUserEvents = sweep.events;

      Log.info(
        'Found ${allUserEvents.length} events to delete'
        '${sweep.queryFailed ? ' (relay query incomplete)' : ''}',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );

      _PreparedDeletionSweep? preparedSweep;
      if (allUserEvents.isNotEmpty) {
        preparedSweep = await _prepareDeletionEventsForAll(
          allUserEvents,
          reason,
          expectedPubkey: expectedPubkey,
        );
        if (preparedSweep == null) {
          return DeleteAccountResult.failure(
            DeleteAccountFailureReason.signingFailed,
            diagnosticError: 'Failed to prepare deletion events',
          );
        }
      }

      // Sign the network-wide vanish only after every kind-5 fallback event is
      // signed. Its created_at must cover those earlier events, while preparing
      // every signature up front ensures signing failure cannot follow an
      // irreversible publish.
      final event = await createNip62Event(
        reason: reason,
        expectedPubkey: expectedPubkey,
      );

      if (event == null) {
        return DeleteAccountResult.failure(
          DeleteAccountFailureReason.signingFailed,
          diagnosticError: 'Failed to create deletion event',
        );
      }

      if (preparedSweep != null) {
        final deletion = await _publishPreparedDeletionSweep(
          preparedSweep,
          expectedPubkey: expectedPubkey,
          onProgress: onProgress,
        );
        deletedCount = deletion.confirmedCount;
        kind5DeletionIncomplete = deletion.incomplete;

        Log.info(
          'Published $deletedCount NIP-09 deletion requests',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
      }

      // Final guard immediately before the network-wide kind-62 publish.
      _assertSignerMatches(expectedPubkey);
      // Await the relay `OK` rather than the socket write: this event is
      // irreversible and legally framed, so "a WebSocket accepted the frame" is
      // not good enough evidence to report deletion to the user.
      final outcome = await _publishVanishWithRetry(
        event,
        expectedPubkey: expectedPubkey,
      );

      if (outcome.failed && !_isAlreadyVanishedOutcome(outcome)) {
        Log.error(
          'NIP-62 deletion request not confirmed by any relay: '
          '${outcome.summary}',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
        return DeleteAccountResult.failure(
          isAccountRestrictedOutcome(
                outcome,
                trustedRelayUrl: _nostrService.defaultRelayUrl,
              )
              ? DeleteAccountFailureReason.accountRestricted
              : DeleteAccountFailureReason.vanishNotConfirmed,
          diagnosticError: outcome.summary,
        );
      }

      Log.info(
        outcome.confirmed
            ? 'NIP-62 deletion request confirmed by relay(s): '
                  '${outcome.acceptedBy}'
            : 'NIP-62 deletion already accepted by relay(s): '
                  '${outcome.rejectionCategories}',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );

      return DeleteAccountResult.createSuccess(
        event.id,
        deletedEventsCount: deletedCount,
        contentQueryFailed: sweep.queryFailed,
        contentDeletionIncomplete:
            sweep.reachedLimit || kind5DeletionIncomplete,
      );
    } on AccountChangedAfterDeletion {
      Log.warning(
        'Deletion cleanup aborted: signed-in account changed after a '
        'deletion request was confirmed',
        name: 'AccountDeletionService',
        category: LogCategory.auth,
      );
      return DeleteAccountResult.failure(
        DeleteAccountFailureReason.accountChangedAfterDeletion,
        diagnosticError:
            'Signed-in account changed after deletion confirmation; '
            'account-bound cleanup stopped',
      );
    } on AccountChangedDuringDeletion {
      Log.warning(
        'Deletion aborted: signed-in account changed mid-flight',
        name: 'AccountDeletionService',
        category: LogCategory.auth,
      );
      return DeleteAccountResult.failure(
        deletedCount > 0
            ? DeleteAccountFailureReason.accountChangedAfterDeletion
            : DeleteAccountFailureReason.accountChanged,
        diagnosticError: deletedCount > 0
            ? 'Signed-in account changed after deletion confirmation; '
                  'account-bound cleanup stopped'
            : 'Signed-in account changed; deletion aborted',
      );
    } catch (e) {
      Log.error(
        'Account deletion failed: $e',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
      return DeleteAccountResult.failure(
        DeleteAccountFailureReason.unexpected,
        diagnosticError: e.toString(),
      );
    }
  }

  Future<PublishOutcome> _publishVanishWithRetry(
    Event event, {
    String? expectedPubkey,
  }) async {
    PublishOutcome? lastOutcome;

    for (var attempt = 1; attempt <= _vanishPublish.maxAttempts; attempt++) {
      final outcome = await _nostrService.publishEventAwaitOk(
        event,
        timeout: _vanishPublish.timeout,
      );
      _assertSignerStillMatches(
        expectedPubkey,
        anyConfirmed: outcome.confirmed || _isAlreadyVanishedOutcome(outcome),
      );

      if (outcome.confirmed || _isAlreadyVanishedOutcome(outcome)) {
        return outcome;
      }

      if (isAccountRestrictedOutcome(
        outcome,
        trustedRelayUrl: _nostrService.defaultRelayUrl,
      )) {
        return outcome;
      }

      lastOutcome = outcome;
      if (attempt == _vanishPublish.maxAttempts) {
        break;
      }

      Log.warning(
        'NIP-62 deletion request not confirmed on attempt $attempt/'
        '${_vanishPublish.maxAttempts}: ${outcome.summary}',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
      await _retryDelay(_vanishPublish.retryDelays[attempt - 1]);
      _assertSignerMatches(expectedPubkey);
    }

    return lastOutcome!;
  }

  static bool _isAlreadyVanishedOutcome(PublishOutcome outcome) =>
      outcome.rejectedBy.values.any(_isAlreadyVanishedReason);

  static bool _isAlreadyVanishedReason(String reason) {
    final normalized = reason.toLowerCase();
    return normalized.startsWith('duplicate:') ||
        normalized.contains('already vanished') ||
        normalized.contains('already have this event');
  }

  /// The value of an event's first `d` tag, or `null` when it has none.
  ///
  /// An addressable event's coordinate is `kind:pubkey:d-tag`, so a missing `d`
  /// tag means the event has no addressable coordinate to delete.
  static String? _dTagOf(Event event) {
    for (final tag in event.tags) {
      if (tag.length >= 2 && tag[0] == 'd') {
        return tag[1];
      }
    }
    return null;
  }

  /// Fetch the user's events that are valid targets for the kind-5 sweep.
  ///
  /// NIP-01 filters cannot express "every kind except these", so the query stays
  /// broad and [_kindsExcludedFromSweep] is applied here.
  ///
  /// Returns `queryFailed: true` when the relay query failed or timed out. The
  /// caller must not treat cached or partial results as complete enumeration.
  Future<({List<Event> events, bool queryFailed, bool reachedLimit})>
  _fetchSweepTargets(String pubkey) async {
    if (_nostrService.isDisposed) {
      Log.error(
        'Failed to fetch user events: Nostr client is disposed',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
      return (events: const <Event>[], queryFailed: true, reachedLimit: false);
    }

    try {
      final filter = Filter(authors: [pubkey], limit: _sweepQueryLimit);
      final query = await _nostrService.queryEventsDetailed(
        [filter],
        timeout: _sweepQueryTimeout,
        requireAllRelaysSettled: true,
      );
      final events = query.events;
      final queryFailed = query.timedOut || query.noRelays;
      final reachedLimit = events.length >= _sweepQueryLimit;

      final targets = events
          .where((event) => !_kindsExcludedFromSweep.contains(event.kind))
          .toList(growable: false);

      Log.debug(
        'Fetched ${events.length} events for user ${pubkeyForLogs(pubkey)} '
        '(${targets.length} sweep targets after excluding kinds '
        '${_kindsExcludedFromSweep.join(', ')})',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );

      if (queryFailed) {
        Log.error(
          'Relay query did not complete reliably for user ${pubkeyForLogs(pubkey)} '
          '(timedOut=${query.timedOut}, noRelays=${query.noRelays})',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
      }

      if (reachedLimit) {
        Log.warning(
          'Relay query reached the $_sweepQueryLimit-event account deletion '
          'sweep limit for user ${pubkeyForLogs(pubkey)}',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
      }

      return (
        events: targets,
        queryFailed: queryFailed,
        reachedLimit: reachedLimit,
      );
    } catch (e) {
      Log.error(
        'Failed to fetch user events: $e',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
      return (events: const <Event>[], queryFailed: true, reachedLimit: false);
    }
  }

  /// Sign every NIP-09 fallback event before any irreversible publish begins.
  Future<_PreparedDeletionSweep?> _prepareDeletionEventsForAll(
    List<Event> events,
    String reason, {
    String? expectedPubkey,
  }) async {
    final total = events.length;
    final connectedRelays = _nostrService.connectedRelays;
    final kind5TargetRelays = connectedRelays
        .where(
          (relay) =>
              !isDivineHostedRelayUrl(relay) &&
              _nostrService.isRelayAllowed(relay),
        )
        .toList(growable: false);

    if (connectedRelays.isEmpty) {
      Log.warning(
        'Skipping NIP-09 sweep because no relay is connected',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
      return _PreparedDeletionSweep(
        batches: const [],
        targetRelays: const [],
        totalEventCount: total,
        incompleteWithoutPublishing: true,
      );
    }

    if (kind5TargetRelays.isEmpty) {
      Log.info(
        'Skipping NIP-09 sweep because no connected relay requires the '
        'NIP-62 compatibility fallback',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
      return _PreparedDeletionSweep(
        batches: const [],
        targetRelays: const [],
        totalEventCount: total,
        incompleteWithoutPublishing: false,
      );
    }

    final eventsByKind = <int, List<Event>>{};
    for (final event in events) {
      eventsByKind.putIfAbsent(event.kind, () => []).add(event);
    }

    final preparedBatches = <_PreparedDeletionBatch>[];
    for (final entry in eventsByKind.entries) {
      final kind = entry.key;
      final kindEvents = entry.value;
      final deleteEvent = await _createBatchDeleteEvent(
        events: kindEvents,
        kind: kind,
        reason: reason,
        expectedPubkey: expectedPubkey,
      );
      if (deleteEvent == null) {
        Log.error(
          'Failed to prepare batch deletion for kind $kind',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
        return null;
      }
      preparedBatches.add(
        _PreparedDeletionBatch(
          event: deleteEvent,
          deletedKind: kind,
          deletedEventCount: kindEvents.length,
        ),
      );
    }

    return _PreparedDeletionSweep(
      batches: preparedBatches,
      targetRelays: kind5TargetRelays,
      totalEventCount: total,
      incompleteWithoutPublishing: false,
    );
  }

  /// Publish a fully signed NIP-09 sweep.
  Future<({int confirmedCount, bool incomplete})> _publishPreparedDeletionSweep(
    _PreparedDeletionSweep sweep, {
    String? expectedPubkey,
    void Function(int current, int total)? onProgress,
  }) async {
    var successCount = 0;
    if (sweep.batches.isEmpty) {
      onProgress?.call(sweep.totalEventCount, sweep.totalEventCount);
      return (
        confirmedCount: 0,
        incomplete: sweep.incompleteWithoutPublishing,
      );
    }

    for (var batchIndex = 0; batchIndex < sweep.batches.length; batchIndex++) {
      final batch = sweep.batches[batchIndex];
      _assertSignerStillMatches(
        expectedPubkey,
        anyConfirmed: successCount > 0,
      );
      var outcome = await _nostrService.publishEventAwaitOk(
        batch.event,
        targetRelays: sweep.targetRelays,
      );
      if (isRateLimitedOutcome(outcome)) {
        await _retryDelay(_rateLimitRetryDelay);
        _assertSignerStillMatches(
          expectedPubkey,
          anyConfirmed: successCount > 0,
        );
        outcome = await _nostrService.publishEventAwaitOk(
          batch.event,
          targetRelays: sweep.targetRelays,
        );
      }
      _assertSignerStillMatches(
        expectedPubkey,
        anyConfirmed: outcome.confirmed || successCount > 0,
      );
      if (isAccountRestrictedOutcome(
        outcome,
        trustedRelayUrl: _nostrService.defaultRelayUrl,
      )) {
        Log.warning(
          'Stopping batch deletion after the configured relay reported an '
          'account restriction',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
        onProgress?.call(successCount, sweep.totalEventCount);
        return (confirmedCount: successCount, incomplete: true);
      }
      if (outcome.confirmed) {
        successCount += batch.deletedEventCount;
        Log.debug(
          'Batch deletion for ${batch.deletedEventCount} events '
          'of kind ${batch.deletedKind} '
          'confirmed by ${outcome.acceptedBy}',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
      } else {
        Log.warning(
          'Batch deletion for kind ${batch.deletedKind} not confirmed: '
          '${outcome.summary}',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
      }

      onProgress?.call(successCount, sweep.totalEventCount);
      if (batchIndex < sweep.batches.length - 1) {
        await _retryDelay(_interBatchDelay);
        _assertSignerStillMatches(
          expectedPubkey,
          anyConfirmed: successCount > 0,
        );
      }
    }

    return (
      confirmedCount: successCount,
      incomplete: successCount < sweep.totalEventCount,
    );
  }

  /// Create NIP-09 kind 5 deletion event for multiple events of the same kind
  Future<Event?> _createBatchDeleteEvent({
    required List<Event> events,
    required int kind,
    required String reason,
    String? expectedPubkey,
  }) async {
    try {
      if (!_authService.isAuthenticated) {
        return null;
      }

      final tags = <List<String>>[];

      // Addressable kinds need an `a` tag as well as `e`. NIP-09: "When an `a`
      // tag is used, relays SHOULD delete all versions of the replaceable event
      // up to the `created_at`." With `e` alone, every prior version of an
      // edited video survives on a relay that implements NIP-09 but not NIP-62
      // — which is exactly the population this sweep exists to serve.
      final isAddressable =
          kind >= _addressableKindMin && kind <= _addressableKindMax;
      final addressableIds = <String>{};

      for (final event in events) {
        tags.add(['e', event.id]);

        if (isAddressable) {
          final dTag = _dTagOf(event);
          if (dTag != null && dTag.isNotEmpty) {
            addressableIds.add('$kind:${event.pubkey}:$dTag');
          }
        }
      }

      for (final addressableId in addressableIds) {
        tags.add(['a', addressableId]);
      }

      tags.add(['k', kind.toString()]);

      // Immediately before signing the kind-5 deletion for this account.
      _assertSignerMatches(expectedPubkey);
      final signedEvent = await _authService.createAndSignEvent(
        kind: 5,
        content: reason,
        tags: tags,
      );

      return signedEvent;
    } on AccountChangedDuringDeletion {
      rethrow;
    } catch (e) {
      Log.error(
        'Failed to create batch delete event: $e',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Create NIP-62 kind 62 event with ALL_RELAYS tag
  Future<Event?> createNip62Event({
    required String reason,
    String? expectedPubkey,
  }) async {
    try {
      if (!_authService.isAuthenticated) {
        Log.error(
          'Cannot create NIP-62 event: not authenticated',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
        return null;
      }

      final pubkey = _authService.currentPublicKeyHex;
      if (pubkey == null || pubkey.isEmpty) {
        Log.error(
          'Cannot create NIP-62 event: no pubkey available',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
        return null;
      }

      // NIP-62 requires relay tag with ALL_RELAYS for network-wide deletion
      final tags = <List<String>>[
        ['relay', 'ALL_RELAYS'],
      ];

      Log.info(
        'Creating NIP-62 event with pubkey: ${pubkeyForLogs(pubkey)}, kind: 62, reason: $reason',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );

      // Immediately before signing the network-wide kind-62 vanish.
      _assertSignerMatches(expectedPubkey);
      // Create and sign event via AuthService
      final signedEvent = await _authService.createAndSignEvent(
        kind: 62, // NIP-62 account deletion kind
        content: reason,
        tags: tags,
      );

      if (signedEvent == null) {
        Log.error(
          'Failed to create and sign NIP-62 event',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
        return null;
      }

      Log.info(
        'Created NIP-62 deletion event (kind 62): ${signedEvent.id}',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );

      return signedEvent;
    } on AccountChangedDuringDeletion {
      rethrow;
    } catch (e, stackTrace) {
      Log.error(
        'Failed to create NIP-62 event: $e\nStack trace: $stackTrace',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
      return null;
    }
  }
}
