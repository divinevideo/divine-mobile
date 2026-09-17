// ABOUTME: Broadcasts already-signed Nostr events: REST-first with an OK-aware WebSocket fallback
// ABOUTME: Owns the retry ladder, relay-presence recovery, and the derived outer publish timeout

import 'dart:async';
import 'dart:convert';

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/relay/relay_pool.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/services/event_api_client.dart';
import 'package:openvine/utils/async_utils.dart';
import 'package:openvine/utils/log_tag_sanitizer.dart';
import 'package:unified_logger/unified_logger.dart';

/// Floor for the derived outer publish timeout. Covers empty-config /
/// pre-init races where `configuredRelayCount` reads as `0` but the
/// publish would still queue against a tempRelay or wait on
/// initialisation. Also keeps the timeout from collapsing to the buffer
/// alone for `relayCount == 1`, which would leave no slack for normal
/// network latency.
const Duration _outerPublishTimeoutFloor = Duration(seconds: 10);

/// Ceiling for the derived outer publish timeout. Bounds worst-case
/// user-visible publish latency on misconfigured huge relay lists so a
/// user with 50 wedged relays does not wait several minutes for the
/// publish to give up.
///
/// **Trade-off**: clamping to the ceiling means the strict invariant
/// `outer >= inner_worst_case + buffer` only holds while
/// `derived <= ceiling`. Beyond that boundary (currently
/// `relayCount >= 12` with `perRelaySendTimeout = 5s` and `buffer = 5s`)
/// the buffer evaporates; from `relayCount == 13` upward the outer
/// guard can fire before the inner sequential fan-out completes,
/// re-introducing the original false-negative-publish failure mode for
/// that edge case. We accept this because the field worst case is
/// driven by `connecting`-state waits and post-handshake socket
/// wedges — not all configured relays — so practical fan-out times for
/// any reasonable config stay well under the ceiling. The retry loop in
/// [SignedEventRelayPublisher.publish] absorbs the rare false-negative
/// when it does happen.
const Duration _outerPublishTimeoutCeiling = Duration(seconds: 60);

/// Buffer added on top of the per-relay × count derivation. Covers the
/// microtask queue drains between sequential `relay.send` calls inside
/// [RelayPool._sendCollect], plus a small allowance for log formatting
/// and other in-process scheduling jitter. Picked at one
/// `perRelaySendTimeout` worth of slack — small relative to the total
/// `perRelay × N` budget at default-config sizes (≈14% of the 35s outer
/// at N=6) but large enough to absorb realistic dispatch overhead on
/// cold-start without erosion as the relay count grows.
const Duration _outerPublishTimeoutBuffer = RelayPool.perRelaySendTimeout;

/// Attempts made by [SignedEventRelayPublisher.publish] before giving up.
const int _maxPublishAttempts = 3;

/// Computes the outer timeout that bounds the call into
/// [NostrClient.publishEventAwaitOk] inside
/// [SignedEventRelayPublisher.publishViaWebSocket].
///
/// Derivation: `RelayPool.perRelaySendTimeout * relayCount + buffer`,
/// clamped to `[floor, ceiling]`. Encoding the relationship in code
/// keeps the outer guard from silently firing before the inner
/// sequential fan-out inside [RelayPool._sendCollect] can complete on
/// degraded networks, regardless of how many relays the user has
/// configured — up to the ceiling boundary documented on
/// [_outerPublishTimeoutCeiling].
///
/// **Caveats on `relayCount`**: the value passed in is treated as an
/// upper bound on the actual sequential fan-out width. Two factors
/// make the real fan-out narrower:
///   * `_sendCollect` skips relays without `writeAccess` for `EVENT`
///     messages, so read-only relays in the configured set don't
///     consume a per-relay slot.
///   * Callers passing `tempRelays` to `RelayPool.send` add fan-out
///     width that this helper cannot see; the canonical
///     [SignedEventRelayPublisher] path does not, but a future caller
///     might.
/// Both factors err on the conservative side — the derived bound is
/// never tighter than the real worst case.
///
/// Exposed at file scope so unit tests can assert the math directly
/// without spinning up a [NostrClient].
Duration outerPublishTimeoutFor(int relayCount) {
  final derived =
      RelayPool.perRelaySendTimeout * relayCount + _outerPublishTimeoutBuffer;
  if (derived < _outerPublishTimeoutFloor) return _outerPublishTimeoutFloor;
  if (derived > _outerPublishTimeoutCeiling) return _outerPublishTimeoutCeiling;
  return derived;
}

/// Result categories for a signed-event publish attempt.
///
/// Separates publish success from retryable transport failures. Account
/// restrictions are not an outcome: they surface as
/// [AccountRestrictedPublishException] so callers cannot retry past them.
enum EventPublishOutcome { published, transientFailure }

enum _RelayPresence { found, notFound, unknown }

/// Broadcasts already-signed Nostr events to the configured relays.
///
/// Two entry points:
///
/// * [publishViaWebSocket] — one OK-aware attempt over the relay pool. The
///   single-shot path for audio and subtitle events, whose callers keep
///   their own null/false handling.
/// * [publish] — the video-event strategy: up to three attempts with a 2s/4s
///   backoff, all sending the same signed event. With an [EventApiClient]
///   wired, as the app always does, each attempt is REST first with an
///   OK-aware WebSocket fallback, and a relay-presence check before each
///   retry skips the re-send when a relay already serves the event. Without
///   one, the attempts are WebSocket only and check no presence.
///
/// The backoff waits are owned by an [AsyncScope], so [dispose] stops a
/// retry ladder rather than letting it resume into a torn-down owner. Nothing
/// in the app disposes the video publisher today: a provider rebuild drops
/// the old instance undisposed, and a ladder it started runs to completion.
class SignedEventRelayPublisher {
  SignedEventRelayPublisher({
    required NostrClient nostrClient,
    EventApiClient? eventApiClient,
    String trustedRelayUrl = AppConstants.defaultRelayUrl,
  }) : _nostrClient = nostrClient,
       _eventApiClient = eventApiClient,
       _trustedRelayUrl = trustedRelayUrl;

  static const String _logName = 'SignedEventRelayPublisher';

  final NostrClient _nostrClient;

  /// REST-first publish client. When non-null, video events are published
  /// via `POST /api/events` first and fall back to the WebSocket relay pool
  /// on every REST failure except an account restriction, 4xx rejections
  /// included. When null (legacy / test wiring), the publisher uses the
  /// WebSocket-only retry path.
  final EventApiClient? _eventApiClient;
  final String _trustedRelayUrl;
  final AsyncScope _async = AsyncScope(debugName: _logName);

  /// Configured authoritative relay used to classify account restrictions.
  String get trustedRelayUrl => _trustedRelayUrl;

  /// The outer timeout that will bound the next call into
  /// [NostrClient.publishEventAwaitOk] inside [publishViaWebSocket],
  /// computed live from [outerPublishTimeoutFor] and the current
  /// [NostrClient.configuredRelayCount].
  ///
  /// Exposed so tests can pin the production wiring between the helper
  /// and the call site without instrumenting `Future.timeout`. Reading
  /// this getter has no side effects.
  Duration get currentOuterPublishTimeout =>
      outerPublishTimeoutFor(_nostrClient.configuredRelayCount);

  /// Publishes an already-signed [event] using the REST-first strategy with
  /// an OK-aware WebSocket fallback.
  ///
  /// Behaviour when an [EventApiClient] is configured:
  /// 1. If [isRetry], first query configured relays by event id and by
  ///    `author+kind+d-tag`; if the event is already on a relay, report it
  ///    published and stop (avoids re-publishing a previously accepted
  ///    event whose `OK` was lost).
  /// 2. Up to 3 attempts of `POST /api/events`. A 200 acceptance is
  ///    published; any other REST result except an account restriction
  ///    falls back to a WebSocket publish that waits for relay `OK` frames.
  /// 3. Before each retry, re-check relay presence so a false-negative
  ///    WebSocket `OK` does not produce a duplicate publish.
  ///
  /// When no [EventApiClient] is configured, the legacy WebSocket-only
  /// retry path is used unchanged.
  ///
  /// The same signed [event] is reused across all attempts — no event is
  /// re-signed per retry, so relays deduplicate by id.
  ///
  /// Throws:
  ///
  /// * [AccountRestrictedPublishException] when the authoritative REST
  ///   endpoint or configured Divine relay reports that the account is
  ///   suspended or banned.
  /// * [AsyncCancelledException] when [dispose] runs before the ladder
  ///   finishes: a pending backoff ends and no further attempt starts.
  Future<EventPublishOutcome> publish(
    Event event, {
    bool isRetry = false,
  }) async {
    final apiClient = _eventApiClient;
    if (apiClient == null) {
      return _publishWithWebSocketRetries(event);
    }

    if (isRetry && await _relayPresence(event) == _RelayPresence.found) {
      Log.info(
        '♻️ Recovered already-published video event ${event.id} from relays; '
        'skipping re-publish',
        name: _logName,
        category: LogCategory.video,
      );
      return EventPublishOutcome.published;
    }

    for (var attempt = 1; attempt <= _maxPublishAttempts; attempt++) {
      // A lost OK on a prior attempt can leave the event already stored on
      // a relay; re-check before re-broadcasting to avoid duplicates.
      if (attempt > 1 && await _relayPresence(event) == _RelayPresence.found) {
        Log.info(
          '♻️ Event ${event.id} found on relay before retry $attempt; '
          'marking published',
          name: _logName,
          category: LogCategory.video,
        );
        return EventPublishOutcome.published;
      }

      _throwIfDisposed(attempt);
      final outcome = await _publishViaRestThenWebSocket(apiClient, event);
      switch (outcome) {
        case EventPublishOutcome.published:
          return EventPublishOutcome.published;
        case EventPublishOutcome.transientFailure:
          await _backoffAfterFailedAttempt(attempt);
      }
    }
    if (await _relayPresence(event) == _RelayPresence.found) {
      return EventPublishOutcome.published;
    }
    return EventPublishOutcome.transientFailure;
  }

  /// Publishes a signed [event] to the configured relays and returns
  /// [EventPublishOutcome.published] iff at least one relay confirmed
  /// acceptance with a NIP-20 `OK true` response
  /// ([PublishOutcome.confirmed]).
  ///
  /// A successful WebSocket send is NOT sufficient — relays can accept
  /// the frame and still reject the event at the protocol level (e.g.
  /// the divine relay's policy rejections). Treating a bare send as
  /// success used to mark rejected videos as published while they were
  /// silently dropped relay-side.
  ///
  /// **Failure contract** (returns [EventPublishOutcome.transientFailure]):
  /// timeouts, ordinary relay rejection/no response, and inner exceptions.
  /// Video publication retries those outcomes with relay-presence recovery;
  /// single-shot audio/subtitle callers retain their existing null/false
  /// handling.
  ///
  /// **Sentinel-return contract** (audits #3593 / #4592): transport and domain
  /// failures intentionally remain outcomes rather than exceptions because all
  /// internal callers already have explicit recovery behavior. The one narrow
  /// exception is [AccountRestrictedPublishException]: an exact suspended or
  /// banned response from the configured authoritative relay is not retryable,
  /// and callers must preserve it so the UI can offer Account status instead of
  /// another futile attempt. Messages from other relays cannot establish Divine
  /// account standing, and any relay acceptance still wins.
  Future<EventPublishOutcome> publishViaWebSocket(Event event) async {
    try {
      Log.debug(
        'Publishing event to Nostr relays: ${event.id}',
        name: _logName,
        category: LogCategory.video,
      );

      // Log relay diagnostics
      Log.info(
        '🔍 Relay diagnostics: isInitialized=${_nostrClient.isInitialized}, '
        'configured=${_nostrClient.configuredRelayCount}, '
        'connected=${_nostrClient.connectedRelayCount}',
        name: _logName,
        category: LogCategory.video,
      );
      Log.info(
        '🔍 Configured relays: ${_nostrClient.configuredRelays}',
        name: _logName,
        category: LogCategory.video,
      );
      Log.info(
        '🔍 Connected relays: ${_nostrClient.connectedRelays}',
        name: _logName,
        category: LogCategory.video,
      );

      // Ensure NostrClient is initialized before attempting broadcast
      if (!_nostrClient.isInitialized) {
        Log.warning(
          '⚠️ NostrClient not initialized, initializing now...',
          name: _logName,
          category: LogCategory.video,
        );
        await _nostrClient.initialize();
      }

      Log.info(
        '📡 ${_nostrClient.connectedRelayCount} relay(s) connected',
        name: _logName,
        category: LogCategory.video,
      );

      _logFullEvent(event);

      // Publish and wait for a NIP-20 `OK` from at least one relay. The
      // [outerPublishTimeoutFor]-derived bound (perRelaySendTimeout ×
      // relayCount + buffer) is passed as the OK-wait timeout — the SDK's
      // publish tracker starts that timer before the send fan-out, so it
      // covers both the sequential sends and the OK wait.
      //
      // Defense-in-depth: the outer `Future.timeout` (one extra
      // [RelayPool.perRelaySendTimeout] of slack so the inner tracker
      // normally fires first) guards the code that runs before the
      // tracker exists — e.g. `retryDisconnectedRelays` stuck in
      // reconnect backoff. The retry loop in [publish] picks up after
      // each failed attempt.
      //
      // We use try/catch on [TimeoutException] rather than `.timeout(
      // onTimeout: ...)`: `publishEventAwaitOk` returns a non-nullable
      // [PublishOutcome], so an `onTimeout` closure could not return
      // null, and the try/catch shape also avoids the mocktail
      // runtime-type mismatch on stubbed futures.
      final outerTimeout = currentOuterPublishTimeout;
      PublishOutcome? publishOutcome;
      try {
        publishOutcome = await _nostrClient
            .publishEventAwaitOk(event, timeout: outerTimeout)
            .timeout(outerTimeout + RelayPool.perRelaySendTimeout);
      } on TimeoutException {
        Log.error(
          '⏱️ publishEventAwaitOk timed out after '
          '${outerTimeout.inSeconds}s for event ${event.id} '
          '(relayCount=${_nostrClient.configuredRelayCount})',
          name: _logName,
          category: LogCategory.video,
        );
        publishOutcome = null;
      }

      if (publishOutcome != null && publishOutcome.confirmed) {
        Log.info(
          '📡 Event confirmed by relay(s): ${event.id} '
          '(${publishOutcome.summary}, '
          'configured=${_nostrClient.configuredRelayCount}, '
          'connected=${_nostrClient.connectedRelayCount})',
          name: _logName,
          category: LogCategory.video,
        );

        return EventPublishOutcome.published;
      }

      final restrictionReason = publishOutcome == null
          ? null
          : accountRestrictedReasonFromOutcome(
              publishOutcome,
              trustedRelayUrl: _trustedRelayUrl,
            );
      if (restrictionReason != null) {
        Log.error(
          'Authoritative WebSocket relay restricted event ${event.id} '
          'from ${pubkeyForLogs(event.pubkey)}: $restrictionReason',
          name: _logName,
          category: LogCategory.video,
        );
        throw AccountRestrictedPublishException(
          reason: restrictionReason,
          source: AccountRestrictionSource.webSocket,
        );
      }
      final failureReason = publishOutcome?.summary ?? 'timeout';
      Log.error(
        '❌ Event publish failed for ${event.id}: $failureReason '
        '(configured=${_nostrClient.configuredRelayCount}, '
        'connected=${_nostrClient.connectedRelayCount})',
        name: _logName,
        category: LogCategory.video,
      );
      return EventPublishOutcome.transientFailure;
    } on AccountRestrictedPublishException {
      rethrow;
    } catch (e) {
      Log.error(
        'Failed to publish event to relays: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return EventPublishOutcome.transientFailure;
    }
  }

  /// Stops any retry ladder in [publish]: a pending backoff ends and no
  /// further attempt starts, so the ladder completes with
  /// [AsyncCancelledException].
  void dispose() => _async.dispose();

  /// Refuses to start [attempt] once [dispose] has run. The backoff wait
  /// alone would miss a dispose that lands during a relay-presence check.
  void _throwIfDisposed(int attempt) {
    if (_async.isDisposed) {
      throw AsyncCancelledException('publish-attempt-$attempt');
    }
  }

  void _logFullEvent(Event event) {
    Log.info(
      '📤 FULL EVENT TO PUBLISH:',
      name: _logName,
      category: LogCategory.video,
    );
    Log.info('  ID: ${event.id}', name: _logName, category: LogCategory.video);
    Log.info(
      '  Pubkey: ${pubkeyForLogs(event.pubkey)}',
      name: _logName,
      category: LogCategory.video,
    );
    Log.info(
      '  Created At: ${event.createdAt}',
      name: _logName,
      category: LogCategory.video,
    );
    Log.info(
      '  Kind: ${event.kind}',
      name: _logName,
      category: LogCategory.video,
    );
    Log.info(
      '  Content: "${event.content}"',
      name: _logName,
      category: LogCategory.video,
    );
    Log.info(
      '  Tags (${event.tags.length} total):',
      name: _logName,
      category: LogCategory.video,
    );
    for (final tag in event.tags) {
      final sanitizedTag = sanitizeTagForLog(tag);
      Log.info(
        '    - ${sanitizedTag.join(", ")}',
        name: _logName,
        category: LogCategory.video,
      );
    }
    Log.info(
      '  Signature: ${event.sig}',
      name: _logName,
      category: LogCategory.video,
    );
    Log.info(
      '  Is Valid: ${event.isValid}',
      name: _logName,
      category: LogCategory.video,
    );
    Log.info(
      '  Is Signed: ${event.isSigned}',
      name: _logName,
      category: LogCategory.video,
    );

    // Log the raw JSON representation
    try {
      final eventMap = sanitizeEventJsonForLog(event.toJson());
      final jsonStr = jsonEncode(eventMap);
      Log.info(
        '📋 FULL EVENT JSON:',
        name: _logName,
        category: LogCategory.video,
      );
      Log.info(jsonStr, name: _logName, category: LogCategory.video);
    } catch (e) {
      Log.warning(
        'Could not serialize event to JSON: $e',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }

  /// One publish attempt: REST first, then an OK-aware WebSocket publish on a
  /// retryable REST failure.
  Future<EventPublishOutcome> _publishViaRestThenWebSocket(
    EventApiClient apiClient,
    Event event,
  ) async {
    final restResult = await apiClient.publishEvent(event);
    switch (restResult) {
      case EventApiAccepted():
        return EventPublishOutcome.published;
      case EventApiRejected(:final statusCode, :final reason):
        if (isAccountRestrictedReason(reason)) {
          Log.error(
            'Authoritative REST publish restricted event ${event.id} from '
            '${pubkeyForLogs(event.pubkey)}: $reason',
            name: _logName,
            category: LogCategory.video,
          );
          throw AccountRestrictedPublishException(
            reason: reason,
            source: AccountRestrictionSource.rest,
          );
        }
        Log.warning(
          '⚠️ REST publish rejected ($statusCode) for ${event.id}: $reason; '
          'falling back to an OK-aware WebSocket publish',
          name: _logName,
          category: LogCategory.video,
        );
        return publishViaWebSocket(event);
      case EventApiTransientFailure(:final reason):
        Log.warning(
          '⚠️ REST publish transient failure for ${event.id} ($reason); '
          'falling back to an OK-aware WebSocket publish',
          name: _logName,
          category: LogCategory.video,
        );
        return publishViaWebSocket(event);
    }
  }

  /// Legacy WebSocket-only publish with the original 3-attempt, 2s/4s backoff
  /// retry loop. Used only when no [EventApiClient] is configured.
  Future<EventPublishOutcome> _publishWithWebSocketRetries(Event event) async {
    for (var attempt = 1; attempt <= _maxPublishAttempts; attempt++) {
      _throwIfDisposed(attempt);
      final outcome = await publishViaWebSocket(event);
      if (outcome == EventPublishOutcome.published) {
        if (attempt > 1) {
          Log.info(
            '✅ Publish succeeded on attempt $attempt',
            name: _logName,
            category: LogCategory.video,
          );
        }
        return EventPublishOutcome.published;
      }

      await _backoffAfterFailedAttempt(attempt);
    }
    return EventPublishOutcome.transientFailure;
  }

  /// Waits out the 2s/4s backoff after a failed [attempt], or logs the
  /// exhausted ladder when it was the last one.
  Future<void> _backoffAfterFailedAttempt(int attempt) async {
    if (attempt < _maxPublishAttempts) {
      final delaySeconds = attempt * 2; // 2s, 4s backoff
      Log.warning(
        '⚠️ Publish attempt $attempt failed, retrying in ${delaySeconds}s...',
        name: _logName,
        category: LogCategory.video,
      );
      await _async.delay(
        Duration(seconds: delaySeconds),
        debugName: 'publish-backoff-$attempt',
      );
    } else {
      Log.error(
        '❌ All $_maxPublishAttempts publish attempts failed',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }

  /// Checks whether [event] is already retrievable from the configured relays,
  /// queried both by event id and by `author+kind+d-tag`.
  Future<_RelayPresence> _relayPresence(Event event) async {
    try {
      final dTag = _dTagOf(event);
      final filters = <Filter>[
        Filter(ids: [event.id], limit: 1),
        if (dTag.isNotEmpty)
          Filter(
            authors: [event.pubkey],
            kinds: [event.kind],
            d: [dTag],
            limit: 1,
          ),
      ];
      final found = await _nostrClient.queryEvents(filters, useCache: false);
      for (final candidate in found) {
        if (candidate.id == event.id) return _RelayPresence.found;
        if (candidate.pubkey == event.pubkey &&
            candidate.kind == event.kind &&
            _dTagOf(candidate) == dTag) {
          return _RelayPresence.found;
        }
      }
      return _RelayPresence.notFound;
    } catch (e) {
      Log.warning(
        'Recovery query failed for ${event.id}: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return _RelayPresence.unknown;
    }
  }

  static String _dTagOf(Event event) {
    for (final tag in event.tags) {
      if (tag.length >= 2 && tag[0] == 'd') return tag[1];
    }
    return '';
  }
}
