// ABOUTME: Manages pool of Nostr relay connections for subscribing and querying events.
// ABOUTME: Handles relay lifecycle, message routing, authentication, and event filtering.

import 'dart:async';
import 'dart:collection';
import 'dart:developer';

import 'package:meta/meta.dart';
import 'package:nostr_sdk/utils/relay_addr_util.dart';

import '../count_response.dart';
import '../event.dart';
import '../event_kind.dart';
import '../filter.dart';
import '../nostr.dart';
import '../src/relay/query_outcome_tracker.dart';
import '../subscription.dart';
import '../utils/string_util.dart';
import 'client_connected.dart';
import 'event_filter.dart';
import 'event_verify_isolate.dart';
import 'publish_outcome.dart';
import 'query_outcome.dart';
import 'relay.dart';
import 'relay_base.dart';
import 'relay_diagnostics.dart';
import 'relay_type.dart';
import 'signature_verification_policy.dart';

class _AuthRequiredPublishRetry {
  _AuthRequiredPublishRetry({
    required this.message,
    required this.tracker,
    required this.reason,
    required this.deadline,
  });

  final List<dynamic> message;
  final PublishTracker tracker;
  final String reason;
  final DateTime deadline;

  /// Set once the EVENT has been re-sent after AUTH. A single tracked entry
  /// lingers as the dedup marker until the relay answers OK, so later
  /// AUTH/OK triggers must not push the same frame again.
  bool resent = false;
}

class RelayPool {
  // avoid to send these events to cache relay
  static List<int> cacheAvoidEvents = [
    EventKind.nostrRemoteSigning,
    EventKind.groupMetadata,
    EventKind.groupAdmins,
    EventKind.groupMembers,
    EventKind.groupChatMessage,
    EventKind.groupNote,
    EventKind.comment,
  ];

  /// Per-relay cap inside [_sendCollect]'s sequential fan-out.
  ///
  /// Exposed as part of the public API so callers that wrap publish calls
  /// in their own outer guard can size that guard against the worst-case
  /// fan-out duration (`perRelaySendTimeout * configuredRelays.length`)
  /// rather than duplicating the literal. See
  /// `mobile/lib/services/video_event_publisher.dart` for the canonical
  /// caller-side derivation.
  static const Duration perRelaySendTimeout = Duration(seconds: 5);

  Nostr localNostr;

  final Map<String, Relay> _tempRelays = {};

  final Map<String, Relay> _relays = {};

  final Map<String, Relay> _cacheRelays = {};

  /// Optional off-main signature-verify worker (#5863). When set, the fresh
  /// Schnorr verify for a not-yet-trusted inbound event runs on a background
  /// isolate instead of the main/UI isolate. When null, verify runs inline on
  /// the main isolate exactly as before (the default, and every existing test).
  /// Wired by the app to an [EventVerifyIsolate]; injectable for tests.
  EventVerifyWorker? _verifyWorker;

  set eventVerifyWorker(EventVerifyWorker? worker) => _verifyWorker = worker;

  /// Per-relay serial tail used to keep EVENT/EOSE frames in order once verify
  /// becomes asynchronous (an EOSE must not complete a query before its
  /// preceding events finish verifying). One entry per relay url; only used
  /// when [_verifyWorker] is set.
  final Map<String, Future<void>> _orderedFrameTails = {};

  // subscription
  final Map<String, Subscription> _subscriptions = {};

  // init query
  final Map<String, Subscription> _initQuery = {};

  final Map<String, Function> _queryCompleteCallbacks = {};

  /// How each one-shot query is being answered, relay by relay, keyed by
  /// subscription id, for every query that asked to hear when it completes.
  /// Dropped with the rest of the query's state, in [_completeQuery] and
  /// [unsubscribe].
  final Map<String, QueryOutcomeTracker> _queryOutcomes = {};

  final Set<String> _queryFanoutInProgress = {};

  /// Tracks which relays have sent EOSE for each subscription.
  /// Used to determine when all relays have finished sending stored events.
  final Map<String, Set<String>> _subscriptionEoseRelays = {};

  List<EventFilter> eventFilters;

  Function(String, String)? onNotice;

  // Track pending AUTH events to match with OK responses
  final Map<String, String> _pendingAuthEvents = {};

  /// When each relay's outstanding NIP-42 handshake started.
  ///
  /// Entered when the relay's AUTH challenge starts being answered and left
  /// when the relay resolves it (`OK`) or answering it fails. A one-shot query
  /// parked behind an auth gate is only worth waiting for while this holds —
  /// see [_canStillSettleQuery].
  ///
  /// Distinct from [_pendingAuthEvents], which is keyed by event id and only
  /// populated once signing has finished; this is set first so the async
  /// signing gap does not read as "no handshake".
  ///
  /// Cleared on every connection-state transition: a handshake belongs to the
  /// socket it started on, and a relay that takes our AUTH event and never
  /// answers it would otherwise stay marked outstanding forever.
  final Map<String, DateTime> _authHandshakeStartedAt = {};

  /// How long an outstanding NIP-42 handshake may hold a one-shot query open
  /// past [querySettleWindow].
  ///
  /// A relay mid-handshake is not silent — it challenged us, and its `OK` is
  /// the thing that runs the post-AUTH replay — so the silence bound does not
  /// apply to it. But the handshake still has to be bounded on its own: a
  /// relay that takes our AUTH event and never answers it looks identical to
  /// one that is about to. Wide enough for a NIP-46 remote signer round trip,
  /// which is a network call rather than a local signature.
  static const authHandshakeWindow = Duration(seconds: 3);

  /// Relays whose NIP-42 gate is demonstrably shut on the current connection.
  ///
  /// Entered only on evidence the relay produced: it refused a REQ with
  /// `auth-required`, rejected our AUTH event, or we could not answer its
  /// challenge at all. Absence is not evidence — a freshly connected relay
  /// that has not sent its challenge yet still has a handshake coming, so it
  /// keeps holding the query. Cleared on a new challenge and on every
  /// connection-state transition.
  final Set<String> _authGateClosed = {};

  /// Relays whose status callback this pool has already chained onto. Weak, so
  /// a removed or replaced relay is not retained by the bookkeeping.
  final Expando<bool> _statusObserved = Expando<bool>('relayStatusObserved');

  /// Grace period granted to the remaining relays after the first terminal
  /// frame for a one-shot query.
  ///
  /// Mirrors [PublishTracker.settleWindow] and exists for the same reason: a
  /// healthy relay answers a REQ within a few hundred milliseconds, so making
  /// every caller wait the full query timeout for one silent sibling stalls
  /// the whole app behind the slowest connection. Unlike a dropped socket or a
  /// closed auth gate, a relay that stays connected and simply never sends
  /// `EOSE` gives off no signal at all — the only bound available is time.
  static const querySettleWindow = Duration(seconds: 1);

  /// Armed settle windows, keyed by subscription id.
  final Map<String, Timer> _querySettleTimers = {};

  /// One-shot queries that opted out of [querySettleWindow].
  ///
  /// The window trades completeness for latency: it releases the caller on the
  /// relays that answered and reports the result as if every relay had. That
  /// is the right default for reads that only display what they find, but it
  /// is unusable for a caller that is about to *replace* what it read — a
  /// replaceable event republished from a partial answer deletes whatever only
  /// the silent relay held. Those callers ask for full settlement instead and
  /// take a timeout as the answer when a relay will not give one.
  ///
  /// The same reasoning bounds the other end: a query these callers made must
  /// have been answered by at least one relay before it can complete, so a
  /// fan-out no relay even accepted is a timeout rather than an empty answer.
  final Set<String> _queriesRequiringFullSettlement = {};

  /// When each one-shot query's REQ fan-out started, so an abandoned query can
  /// ask [Relay.isSilentSince] whether a relay that never answered had gone
  /// quiet altogether. Dropped when the query settles or is unsubscribed.
  final Map<String, DateTime> _querySentAt = {};

  /// The [_querySentAt] equivalent for live subscriptions, so a subscription
  /// its caller tore down without ever being served can ask the same question.
  /// Dropped when the subscription is unsubscribed.
  final Map<String, DateTime> _subscriptionSentAt = {};

  /// Armed silence probes, keyed by subscription id.
  final Map<String, Timer> _subscriptionSilenceProbes = {};

  /// Whether teardown has begun. See [beginClose].
  bool _closed = false;

  /// One-shot queries at least one relay has already answered.
  ///
  /// Sticky for the query's lifetime rather than a property of the call that
  /// observed the frame: a terminal frame that lands while the REQ fan-out is
  /// still running is swallowed by the fan-out guard in
  /// [_fireQueryCompleteIfSettled], and the post-fan-out sweep would otherwise
  /// have no way to know the fan-out is being served — leaving the caller to
  /// pay its full timeout, which is the stall this whole path exists to stop.
  final Set<String> _queryAnswered = {};

  /// One-shot queries where a relay refused or abandoned the REQ with `CLOSED`.
  ///
  /// A `CLOSED` frame is useful evidence for default display reads: the relay is
  /// alive and the caller should not burn its full timeout once every relay has
  /// either answered or refused. But for [requireAllRelaysSettled], a refusal is
  /// not evidence that the relay had no events. A caller about to replace a
  /// replaceable event must treat that as inconclusive, the same as silence.
  final Set<String> _queryClosedWithoutAnswer = {};

  /// One-shot queries no relay took at all, so nothing can ever answer them.
  ///
  /// No relay ran `saveQuery`, so there is no terminal frame still owed and no
  /// post-AUTH replay. A failed send does leave the raw `REQ` in the relay's
  /// `pendingMessages` for the next `onConnected` to replay — `_isReqNaming`
  /// only skips REQs naming a *saved* subscription — but a query that was
  /// never saved has no [Subscription] to admit the results, so anything it
  /// draws back drops at the subscription lookup. Waiting is therefore
  /// pointless: the caller's answer cannot change between here and its
  /// deadline. [requireAllRelaysSettled] used to wait anyway because
  /// completing looked identical to "every relay says there is nothing";
  /// `sentTo` from [query] is what tells those apart now.
  ///
  /// Recorded only while the query still has a live completion callback, so a
  /// fan-out that resolves after its caller gave up cannot strand an entry
  /// here — which would both grow unbounded and, if the id were ever reused,
  /// let a later full-settlement query skip its hold.
  final Set<String> _queryReachedNoRelay = {};

  /// Track publishes awaiting OK confirmations (per event id).
  final Map<String, PublishTracker> _pendingPublishes = {};

  /// Awaited publishes that were rejected before the relay completed NIP-42.
  ///
  /// Keyed by event id, then relay url. These are retried once after the
  /// corresponding relay confirms AUTH, bounded by the publish's original
  /// deadline.
  final Map<String, Map<String, _AuthRequiredPublishRetry>>
  _authRequiredPublishRetries = {};

  Relay Function(String) tempRelayGener;

  RelayPool(
    this.localNostr,
    this.eventFilters,
    this.tempRelayGener, {
    this.onNotice,
    this.diagnosticsSink,
    this.signatureVerificationPolicy = SignatureVerificationPolicy.all,
    this.silentRepairCooldown = const Duration(seconds: 60),
    this.minSubscriptionAgeBeforeRepair = const Duration(seconds: 10),
    this.subscriptionSilenceProbe = const Duration(seconds: 8),
    this.tempRelayIdleTimeout = const Duration(seconds: 120),
    this.tempRelaySweepInterval = const Duration(seconds: 60),
  });

  final RelayDiagnosticsSink? diagnosticsSink;

  void _diagnose(
    RelayDiagnosticSite site,
    RelayDiagnosticLevel level,
    String relayUrl,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => emitRelayDiagnostic(
    diagnosticsSink,
    RelayDiagnostic(
      site: site,
      level: level,
      relayUrl: relayUrl,
      message: message,
      error: error,
      stackTrace: stackTrace,
    ),
  );

  /// NIP-01's machine-readable `OK` / `CLOSED` prefixes, plus NIP-42's
  /// `auth-required` and the `unsupported` prefix NIP-01 uses in its own
  /// `CLOSED` examples.
  static const Set<String> _closedReasonPrefixes = {
    'auth-required',
    'blocked',
    'duplicate',
    'error',
    'invalid',
    'mute',
    'pow',
    'rate-limited',
    'restricted',
    'unsupported',
  };

  /// Reduces a `CLOSED` reason to its NIP-01 prefix, or `other`.
  ///
  /// Matches the prefix rather than searching the whole reason, like
  /// [_isExplicitAuthRequiredReason] and [_isRestrictedReason] already do.
  /// Searching mislabels the human-readable half: `blocked: too many failed
  /// auth attempts` is not an auth problem, and sends triage after NIP-42
  /// when the account is blocked. Only the fixed prefixes above are ever
  /// emitted, so relay-supplied text still cannot reach a support export.
  String _closedReasonCategory(String reason) {
    final normalized = reason.trim().toLowerCase();
    for (final prefix in _closedReasonPrefixes) {
      if (!normalized.startsWith(prefix)) continue;
      final rest = normalized.substring(prefix.length);
      if (rest.isEmpty || rest.startsWith(':')) return prefix;
    }
    return 'other';
  }

  /// Records that [relay] refused one-shot query [subId] with `CLOSED`,
  /// keeping only the reason's NIP-01 prefix.
  void _recordQueryClosed(Relay relay, String subId, String reason) =>
      _queryOutcomes[subId]?.recordClosed(relay, _closedReasonCategory(reason));

  /// How long a temp relay may sit with no inbound traffic before the sweep
  /// closes it. Injectable so tests need no wall-clock wait.
  ///
  /// A temp relay is created per entry in a caller's `tempRelays` list, and
  /// before #6585 nothing ever closed one: [_sendCollect] only tore a temp
  /// relay down when the publish deadline had *already* expired, so any
  /// address that answered in time kept its socket for the life of the
  /// process. That matters most where the addresses are not ours to choose —
  /// a NIP-17 gift wrap goes to the relays the *recipient* advertised, so an
  /// unbounded, immortal set of connections was reachable from a counterparty
  /// simply by listing hosts in their kind-10050.
  ///
  /// NIP-17's kind-10050 description says as much directly: "After sending,
  /// disconnect from these relays unless further messages are expected."
  final Duration tempRelayIdleTimeout;

  /// How often the idle sweep runs while any temp relay exists.
  final Duration tempRelaySweepInterval;

  /// Periodic idle sweep over [_tempRelays]; null while none exist.
  Timer? _tempRelaySweepTimer;

  /// Minimum gap between two silent-socket repairs of the *same* relay.
  ///
  /// A brownout relay — alive but answering slower than the OK window — lands
  /// in [PublishOutcome.noResponseFrom] on every timed-out publish and reads
  /// as silent each time (a fresh forced socket has no inbound since the next
  /// publish). Without this floor it would be force-cycled on every send,
  /// tearing down subscriptions and re-AUTHing on a connection that is merely
  /// slow. The default is well above the largest OK window so two consecutive
  /// timed-out publishes on one relay cannot double-cycle it. Injectable for
  /// tests that need to exercise the post-cooldown re-repair without a
  /// wall-clock wait.
  Duration silentRepairCooldown;

  /// How long a live subscription must have gone unanswered before its
  /// teardown is treated as evidence against the socket.
  ///
  /// Unlike a one-shot query, which is only released once its caller gave up
  /// waiting, [unsubscribe] is the ordinary teardown every screen runs — so
  /// without a floor, a feed the user left inside the relay's round-trip time
  /// would force-cycle a perfectly healthy connection and make it replay its
  /// stored window for every other subscription it carries. The default sits
  /// far above navigation-speed teardowns and well below the app's own feed
  /// deadline, so a caller that actually waited still gets the repair.
  /// Injectable so tests need no wall-clock wait.
  Duration minSubscriptionAgeBeforeRepair;

  /// How long after a subscription's REQ fan-out the pool checks whether any
  /// relay has answered, and repairs the ones that have not.
  ///
  /// Until #7301 the same check only ran from [unsubscribe], which meant a
  /// relay that swallowed the REQ was found *after* the caller had already
  /// given up. Nothing else could catch it inside that window either: the REQ
  /// is sent with `skipReconnect`, so a dropped socket queues it silently; a
  /// half-open socket accepts it into a dead connection and answers nothing;
  /// and the idle heartbeat needs 90s of silence. A feed load that started on
  /// a bad socket was therefore guaranteed to burn its caller's full deadline
  /// and show an empty screen, which is what made Android — where radio
  /// transitions produce those sockets far more often — time out ~8x more than
  /// iOS on the same code.
  ///
  /// The default sits far above a healthy relay's round-trip (a few hundred ms)
  /// and well below the app's 30s feed deadline, so a repair still leaves the
  /// re-issued REQ most of the window to be answered. Injectable so tests need
  /// no wall-clock wait.
  ///
  /// [minSubscriptionAgeBeforeRepair] has no counterpart here: teardown cancels
  /// the probe, so a feed the user left inside the relay's round-trip time is
  /// never judged at all rather than being judged and then excused.
  Duration subscriptionSilenceProbe;

  /// Controls whether [_dispatchTypedFrame] performs expensive Schnorr
  /// verification. The event id is always recomputed first; policy skips only
  /// bypass the signature check for relay origins the app is configured to
  /// trust.
  SignatureVerificationPolicy signatureVerificationPolicy;

  List<Subscription> _subscriptionsSnapshot() =>
      _subscriptions.values.toList(growable: false);

  List<Subscription> _initQueriesSnapshot() =>
      _initQuery.values.toList(growable: false);

  List<Relay> _relaysSnapshot() => _relays.values.toList(growable: false);

  List<Relay> _tempRelaysSnapshot() =>
      _tempRelays.values.toList(growable: false);

  List<Relay> _cacheRelaysSnapshot() =>
      _cacheRelays.values.toList(growable: false);

  List<String> _relayKeysSnapshot() => _relays.keys.toList(growable: false);

  List<MapEntry<String, Relay>> _relayEntriesSnapshot() =>
      _relays.entries.toList(growable: false);

  List<MapEntry<String, Relay>> _tempRelayEntriesSnapshot() =>
      _tempRelays.entries.toList(growable: false);

  List<MapEntry<String, Relay>> _cacheRelayEntriesSnapshot() =>
      _cacheRelays.entries.toList(growable: false);

  /// RelayManager stores pooled URLs without a trailing slash, while
  /// [RelayAddrUtil.handle] adds one for temporary relay addresses. Keep the
  /// wire address unchanged, but use one identity for pool/temp comparisons.
  String _relayIdentity(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  Relay? _pooledRelayForTempAddr(String addr) =>
      _relays[addr] ?? _relays[_relayIdentity(addr)];

  /// Whether [addrs] names [url], comparing on [_relayIdentity] rather than
  /// raw strings. `subscribe`/`query` run their `targetRelays` through
  /// [handleAddrList] (which ADDS a trailing slash) but compare against pool
  /// keys from `normalizeRelayUrl` (which STRIPS one), so a raw `contains`
  /// matched no pooled relay and turned the filter into a universal
  /// exclusion. #8377.
  ///
  /// The publish path reaches the same trap by a different route. [_sendCollect]
  /// does NOT run its `targetRelays` through [handleAddrList], so the strings it
  /// compares are whatever the caller passed — for a DM those are `relay` tag
  /// values lifted verbatim off a kind-10050 event, written by another client and
  /// carrying a trailing slash or not at its author's whim. A raw `contains` there
  /// silently drops the pooled socket for a relay the caller explicitly named, and
  /// the event reaches it only if the temp-relay arm happens to redial it. Both the
  /// fan-out and [_intendedPublishTargets] — which must agree, or the reachable
  /// denominator diverges from what was actually written — compare through here.
  bool _namesRelay(List<String> addrs, String url) {
    final wanted = _relayIdentity(url);
    for (final addr in addrs) {
      if (_relayIdentity(addr) == wanted) return true;
    }
    return false;
  }

  bool _isExplicitAuthRequiredReason(String message) {
    final lower = message.trim().toLowerCase();
    return lower.startsWith('auth-required');
  }

  bool _isRestrictedReason(String message) {
    return message.trim().toLowerCase().startsWith('restricted');
  }

  bool _shouldRetryPublishAfterAuth({
    required Relay relay,
    required String eventId,
    required String message,
  }) {
    final retriesForEvent = _authRequiredPublishRetries[eventId];
    if (retriesForEvent != null && retriesForEvent.containsKey(relay.url)) {
      return false;
    }
    if (_isExplicitAuthRequiredReason(message)) return true;
    // A bare "restricted" reason is NIP-01's generic members-only rejection
    // and is only auth-retryable when the relay actually speaks NIP-42 (it
    // sent an AUTH challenge, so alwaysAuth is set) and has not authed yet.
    // Without that guard a permanent allow-list rejection would be tracked
    // and hang until the publish deadline instead of failing fast.
    return _isRestrictedReason(message) &&
        relay.relayStatus.alwaysAuth &&
        !relay.relayStatus.authed;
  }

  bool _shouldReplayQueryAfterAuth(Relay relay, String reason) {
    if (_isExplicitAuthRequiredReason(reason)) return true;
    return _isRestrictedReason(reason) &&
        relay.relayStatus.alwaysAuth &&
        !relay.relayStatus.authed;
  }

  void _trackAuthRequiredPublish({
    required Relay relay,
    required List<dynamic> message,
    required PublishTracker tracker,
    required String reason,
    required DateTime deadline,
  }) {
    relay.relayStatus.alwaysAuth = true;
    tracker.deferRejection(relay.url, reason);
    final retry = _AuthRequiredPublishRetry(
      message: message,
      tracker: tracker,
      reason: reason,
      deadline: deadline,
    );
    _authRequiredPublishRetries.putIfAbsent(
      tracker.eventId,
      () => <String, _AuthRequiredPublishRetry>{},
    )[relay.url] = retry;
  }

  void _removeAuthRequiredPublish(String eventId, String relayUrl) {
    final retriesForEvent = _authRequiredPublishRetries[eventId];
    if (retriesForEvent == null) return;
    retriesForEvent.remove(relayUrl);
    if (retriesForEvent.isEmpty) {
      _authRequiredPublishRetries.remove(eventId);
    }
  }

  List<MapEntry<String, _AuthRequiredPublishRetry>> _retryEntriesForRelay(
    Relay relay,
  ) {
    final retryEntries = <MapEntry<String, _AuthRequiredPublishRetry>>[];
    for (final entry in _authRequiredPublishRetries.entries) {
      final retry = entry.value[relay.url];
      if (retry != null) {
        retryEntries.add(MapEntry(entry.key, retry));
      }
    }
    return retryEntries;
  }

  Future<void> _retryAuthRequiredPublishesForRelay(Relay relay) async {
    for (final entry in _retryEntriesForRelay(relay)) {
      final eventId = entry.key;
      final retry = entry.value;
      // A resent entry lingers only as the dedup marker; do not push it again
      // on a later AUTH/OK trigger for this relay.
      if (retry.resent) continue;

      final timeout = retry.deadline.difference(DateTime.now());
      if (timeout <= Duration.zero) {
        retry.tracker.onRejected(relay.url, retry.reason);
        _removeAuthRequiredPublish(eventId, relay.url);
        continue;
      }

      // Mark before the await: onMessage delivery is fire-and-forget, so a
      // re-entrant OK/AUTH frame must not resend this in-flight EVENT.
      retry.resent = true;
      log(
        '🔐 Re-publishing auth-required EVENT after AUTH '
        'eventId=$eventId relay=${relay.url}',
      );
      retry.tracker.clearDeferredRejection(relay.url);
      final sent = await relay
          .send(
            retry.message,
            skipReconnect: true,
            queueIfFailed: false,
            deadline: retry.deadline,
          )
          .timeout(timeout, onTimeout: () => false);
      if (!sent) {
        // The relay answered — `auth-required` is why we are here — so it is
        // not an unreachable target, whatever happened to the resend. Report
        // what it said, the same as the expired-deadline branch above; a
        // caller told "could not reach this relay" would retry the network
        // instead of the authentication.
        retry.tracker.onRejected(relay.url, retry.reason);
        _removeAuthRequiredPublish(eventId, relay.url);
      }
    }
  }

  /// Fails everything that was waiting on [relay]'s NIP-42 handshake, after
  /// that handshake has definitively concluded without authenticating.
  ///
  /// Fire-and-forget publishes are dropped rather than held. Nothing will flush
  /// them now, and a temp relay is reaped only once
  /// [Relay.pendingAuthedMessages] is empty (see [_isTempRelayReapable]) — so
  /// holding them would pin the socket open for the life of the pool and grow
  /// the queue on every later publish. A fresh challenge on this connection
  /// reopens the gate and re-parks whatever is published after it, so the loss
  /// is bounded to frames no caller is awaiting.
  void _rejectAuthRequiredPublishesForRelay(Relay relay, String authMessage) {
    for (final entry in _retryEntriesForRelay(relay)) {
      entry.value.tracker.onRejected(
        relay.url,
        authMessage.isEmpty ? entry.value.reason : authMessage,
      );
      _removeAuthRequiredPublish(entry.key, relay.url);
    }
    if (relay.pendingAuthedMessages.isNotEmpty) {
      log(
        '🔐 Dropping ${relay.pendingAuthedMessages.length} message(s) parked '
        'behind the failed auth handshake for ${relay.url}',
      );
      relay.pendingAuthedMessages.clear();
    }
    relay.drainSentFramesForAuthRetry();
  }

  /// Keeps a copy of a just-written fire-and-forget EVENT in case [relay]
  /// answers it with a NIP-42 challenge.
  ///
  /// Only the first publish on a connection needs this. Once a challenge has
  /// landed, [RelayStatus.alwaysAuth] is set and [_sendCollect] parks
  /// subsequent frames in [Relay.pendingAuthedMessages] instead — and once the
  /// handshake succeeds, `authed` is set and nothing needs replaying at all.
  /// Deadline-bound publishes are excluded because [PublishTracker] already
  /// carries their message through [_trackAuthRequiredPublish]; retaining them
  /// here as well would republish the same event twice after AUTH.
  void _retainForAuthRetry(
    Relay relay,
    List<dynamic> message,
    DateTime? deadline,
  ) {
    if (deadline != null || relay.relayStatus.authed) return;
    relay.recordSentFrame(message);
  }

  Future<bool> add(
    Relay relay, {
    bool autoSubscribe = false,
    bool init = false,
    int relayType = RelayType.normal,
  }) async {
    if (_closed) return false;
    if (relayType == RelayType.normal) {
      if (_relays.containsKey(relay.url)) {
        return true;
      } else {
        _relays[relay.url] = relay;
      }
    } else if (relayType == RelayType.cache) {
      if (_cacheRelays.containsKey(relay.url)) {
        return true;
      } else {
        _cacheRelays[relay.url] = relay;
      }
    }

    relay.onMessage = _onEvent;
    _observeRelayStatus(relay);

    if (await relay.connect()) {
      log('Relay connection succeeded: ${relay.url}');
      _diagnose(
        RelayDiagnosticSite.connectionLifecycle,
        RelayDiagnosticLevel.info,
        relay.url,
        'Relay connection succeeded',
      );
      if (autoSubscribe) {
        var replayFailed = false;
        final msg =
            '🔄 autoSubscribe: re-sending ${_subscriptions.length} '
            'subscriptions to ${relay.url}';
        log(msg);
        _diagnose(
          RelayDiagnosticSite.subscriptionReplay,
          RelayDiagnosticLevel.info,
          relay.url,
          'Re-sending ${_subscriptions.length} saved subscriptions',
        );
        for (final subscription in _subscriptionsSnapshot()) {
          // Save the subscription to the relay so that after AUTH completes
          // the relay can re-send it. Without this, autoSubscribe sends the
          // subscription once but it dies if the relay requires AUTH —
          // relay.getSubscriptions() would return empty after AUTH success.
          relay.saveSubscription(subscription);
          log('🔄 autoSubscribe: sending ${subscription.id} to ${relay.url}');
          final sent = await relay.send(
            subscription.toJson(),
            skipReconnect: true,
          );
          replayFailed = replayFailed || !sent;
        }
        if (replayFailed) {
          _diagnose(
            RelayDiagnosticSite.subscriptionReplay,
            RelayDiagnosticLevel.warning,
            relay.url,
            'Saved-subscription replay failed; reconnecting once',
          );
          relay.relayStatus.onError();
          log(
            'autoSubscribe replay failed for ${relay.url}; '
            'reconnecting once for saved-request replay',
          );
          if (!await relay.connect()) return false;
        }
      }
      if (init) {
        for (final subscription in _initQueriesSnapshot()) {
          relayDoQuery(relay, subscription, false);
        }
      }

      return true;
    } else {
      log("relay connect fail! ${relay.url}");
      _diagnose(
        RelayDiagnosticSite.connectionLifecycle,
        RelayDiagnosticLevel.warning,
        relay.url,
        'Relay connection failed',
      );
    }

    relay.relayStatus.onError();
    return false;
  }

  List<Relay> activeRelays() {
    List<Relay> list = [];
    final it = _relaysSnapshot();
    for (var relay in it) {
      if (relay.relayStatus.connected == ClientConnected.connected) {
        list.add(relay);
      }
    }
    return list;
  }

  /// Whether the pool is closing or closed, and therefore must not open any
  /// further sockets.
  @visibleForTesting
  bool get isClosed => _closed;

  /// Marks the pool as closing without tearing anything down yet.
  ///
  /// [removeAll] is what actually disposes the relays, but an owner reaches it
  /// only after a sequence of awaits (see `NostrClient.dispose`). Every one of
  /// those awaits is a window in which an armed repair can fire and call
  /// `connect()`; the socket and heartbeat timer it opens then outlive the
  /// [removeAll] that was supposed to close them, because the relay holding
  /// them is disposed a moment later and nothing can reach them again (#7367).
  /// Calling this first closes that window: the probes are disarmed and every
  /// path that could start a connection turns into a no-op.
  void beginClose() {
    if (_closed) return;
    _closed = true;
    _cancelSilenceProbes();
  }

  void _cancelSilenceProbes() {
    for (final probe in _subscriptionSilenceProbes.values) {
      probe.cancel();
    }
    _subscriptionSilenceProbes.clear();
  }

  /// Removes every relay from the pool.
  ///
  /// This on its own does not mark the pool closed, so a direct caller can
  /// use it to start over with a different relay set. Reaching it through
  /// [Nostr.close] is terminal instead, because that calls [beginClose]
  /// first and nothing reopens a closed pool.
  void removeAll() {
    final keys = _relayKeysSnapshot();
    for (var url in keys) {
      _relays[url]?.disconnect();
      _relays[url]?.dispose();
      _forgetRelayBookkeeping(url);
    }
    _relays.clear();
    for (final url in _tempRelays.keys.toList(growable: false)) {
      removeTempRelay(url);
    }
    _tempRelaySweepTimer?.cancel();
    _tempRelaySweepTimer = null;
    // Nothing left to repair, and a probe outliving the pool would fire into
    // an empty relay set on every armed subscription.
    _cancelSilenceProbes();
  }

  /// Drops the pool-side state keyed by [url] so a relay that comes back is
  /// not judged on the previous instance's connection.
  void _forgetRelayBookkeeping(String url) {
    _lastSilentRepairAt.remove(url);
    _authHandshakeStartedAt.remove(url);
    _authGateClosed.remove(url);
  }

  void remove(String url, {int relayType = RelayType.normal}) {
    log('Removing $url');
    if (relayType == RelayType.normal) {
      _relays[url]?.disconnect();
      _relays[url]?.dispose();
      _relays.remove(url);
    } else if (relayType == RelayType.cache) {
      _cacheRelays[url]?.disconnect();
      _cacheRelays[url]?.dispose();
      _cacheRelays.remove(url);
    }
    _forgetRelayBookkeeping(url);
  }

  Relay? getRelay(String url) {
    return _relays[url];
  }

  Future<bool> relayDoQuery(
    Relay relay,
    Subscription subscription,
    bool sendAfterAuth, {
    bool runBeforeConnected = false,
  }) async {
    if (!relay.relayStatus.readAccess) {
      return false;
    }

    relay.relayStatus.onQuery();

    try {
      var message = subscription.toJson();
      log(
        'Dispatching one-shot query ${subscription.id} to ${relay.url} '
        '(filters=${subscription.filters.length})',
      );
      _diagnose(
        RelayDiagnosticSite.queryDispatch,
        RelayDiagnosticLevel.info,
        relay.url,
        'Dispatching one-shot query ${subscription.id} '
        '(filters=${subscription.filters.length})',
      );
      if ((sendAfterAuth || relay.relayStatus.alwaysAuth) &&
          !relay.relayStatus.authed) {
        log('🔐 Auth-required query - sending to trigger AUTH challenge');
        relay.saveQuery(subscription);
        final deadline = DateTime.now().add(perRelaySendTimeout);
        final result = await relay
            .send(message, queueIfFailed: false, deadline: deadline)
            .timeout(perRelaySendTimeout, onTimeout: () => false);
        if (!result) {
          log(
            '🔐 Auth-required query trigger send failed; query remains saved '
            'for replay after reconnect/auth: ${subscription.id} ${relay.url}',
          );
        }
        _diagnose(
          RelayDiagnosticSite.queryDispatch,
          result ? RelayDiagnosticLevel.info : RelayDiagnosticLevel.warning,
          relay.url,
          'One-shot query ${subscription.id} trigger sent=$result',
        );
        if (result) {
          log('One-shot query ${subscription.id} trigger sent to ${relay.url}');
        }
        return true;
      } else {
        // Skip reconnect during query fan-out to avoid blocking
        // other relays while one dead relay tries exponential backoff.
        final result = await relay
            .send(message, skipReconnect: true)
            .timeout(perRelaySendTimeout, onTimeout: () => false);
        if (result) {
          relay.saveQuery(subscription);
        }
        log(
          'One-shot query ${subscription.id} dispatch to ${relay.url} '
          'succeeded=$result',
        );
        _diagnose(
          RelayDiagnosticSite.queryDispatch,
          result ? RelayDiagnosticLevel.info : RelayDiagnosticLevel.warning,
          relay.url,
          'One-shot query ${subscription.id} dispatch succeeded=$result',
        );
        return result;
      }
    } catch (err, stackTrace) {
      _diagnose(
        RelayDiagnosticSite.queryDispatch,
        RelayDiagnosticLevel.error,
        relay.url,
        'One-shot query ${subscription.id} dispatch threw',
        error: err,
        stackTrace: stackTrace,
      );
      log(err.toString());
      relay.relayStatus.onError();
    }

    return false;
  }

  void _broadcaseToCache(Map<String, dynamic> event) {
    for (final relay in _cacheRelaysSnapshot()) {
      relay.send(["EVENT", event]);
    }
  }

  String? _stringAt(Relay relay, List<dynamic> frame, int index, String field) {
    if (frame.length <= index || frame[index] is! String) {
      log(
        'Malformed relay frame from ${relay.url}: expected $field '
        'as String at index $index: $frame',
      );
      return null;
    }
    return frame[index] as String;
  }

  String? _optionalStringAt(
    Relay relay,
    List<dynamic> frame,
    int index,
    String field, {
    required String defaultValue,
  }) {
    if (frame.length <= index) {
      return defaultValue;
    }
    return _stringAt(relay, frame, index, field);
  }

  bool? _boolAt(Relay relay, List<dynamic> frame, int index, String field) {
    if (frame.length <= index || frame[index] is! bool) {
      log(
        'Malformed relay frame from ${relay.url}: expected $field '
        'as bool at index $index: $frame',
      );
      return null;
    }
    return frame[index] as bool;
  }

  Map<String, dynamic>? _mapAt(
    Relay relay,
    List<dynamic> frame,
    int index,
    String field,
  ) {
    if (frame.length <= index) {
      log(
        'Malformed relay frame from ${relay.url}: missing $field '
        'at index $index: $frame',
      );
      return null;
    }

    final value = frame[index];
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (_) {
        // Fall through to the malformed-frame log below.
      }
    }

    log(
      'Malformed relay frame from ${relay.url}: expected $field '
      'as object at index $index: $frame',
    );
    return null;
  }

  int? _intPayloadField(
    Relay relay,
    List<dynamic> frame,
    Map<String, dynamic> payload,
    String field,
  ) {
    final value = payload[field];
    if (value is int) {
      return value;
    }

    log(
      'Malformed relay frame from ${relay.url}: expected payload.$field '
      'as int: $frame',
    );
    return null;
  }

  bool? _optionalBoolPayloadField(
    Relay relay,
    List<dynamic> frame,
    Map<String, dynamic> payload,
    String field, {
    required bool defaultValue,
  }) {
    final value = payload[field];
    if (value == null) {
      return defaultValue;
    }
    if (value is bool) {
      return value;
    }

    log(
      'Malformed relay frame from ${relay.url}: expected payload.$field '
      'as bool: $frame',
    );
    return null;
  }

  /// Session-scoped, insertion-ordered set of `"id:sig"` keys whose Schnorr
  /// signature has already been verified on this isolate. The same event
  /// arriving again from another relay skips the ~0.3ms secp256k1 verify that
  /// otherwise dominates cold start (signature verification was ~42% of
  /// startup CPU in profiling). Eviction is oldest-inserted-first (FIFO); a
  /// duplicate hit is not moved to most-recent, so it is not a true LRU — for
  /// a bounded seen-set that distinction is immaterial.
  ///
  /// The signature is part of the key because a Nostr event id commits to
  /// the event body only, *not* to `sig` — a relay can replay a known id
  /// carrying a different, invalid signature. Keying by id alone would let
  /// that copy skip verification; keying by `(id, sig)` forces a re-verify
  /// whenever the signature differs. Only fresh network verifications are
  /// recorded here, so a known/duplicate hit never masks an unverified copy.
  static const int _verifiedEventKeysCap = 20000;
  final LinkedHashSet<String> _verifiedEventKeys = LinkedHashSet<String>();

  /// Optional lookup for `(event id, signature)` pairs already verified in a
  /// *previous* session.
  ///
  /// Relays re-send events the app already downloaded and persisted, so on
  /// every cold start those events arrive again and would be re-verified. The
  /// app injects a lookup backed by its local event store (every persisted
  /// event was verified before being written), letting [_onEvent] skip the
  /// expensive Schnorr verify for a known id **only when the incoming
  /// signature matches the one that was persisted** — the id alone does not
  /// commit to `sig`. Must be a cheap, synchronous, side-effect-free test.
  bool Function(String eventId, String signature)? isKnownVerifiedEvent;

  /// Diagnostic counters for how [_onEvent] treated each incoming event's
  /// signature. Read-only; read by the dedup tests to assert that the skip
  /// branches actually fire. There is no production reader by design — the
  /// periodic verify-stats log was removed to keep the hot path quiet; wire
  /// these into a diagnostics surface if on-device skip-rate visibility is
  /// ever needed.
  int get verifiesPerformed => _verifiesPerformed;
  int get verifiesSkippedKnown => _verifiesSkippedKnown;
  int get verifiesSkippedSessionDup => _verifiesSkippedSessionDup;
  int get verifiesSkippedByPolicy => _verifiesSkippedByPolicy;
  int _verifiesPerformed = 0;
  int _verifiesSkippedKnown = 0;
  int _verifiesSkippedSessionDup = 0;
  int _verifiesSkippedByPolicy = 0;

  /// Records [key] (an `"id:sig"` pair) as verified, evicting the oldest once
  /// the cap is hit.
  void _markEventVerified(String key) {
    _verifiedEventKeys
      ..remove(key)
      ..add(key);
    if (_verifiedEventKeys.length > _verifiedEventKeysCap) {
      _verifiedEventKeys.remove(_verifiedEventKeys.first);
    }
  }

  /// Verifies [event]'s Schnorr signature, off the main isolate when a verify
  /// worker is wired (#5863), else inline via [Event.isSigned]. The caller has
  /// already run [Event.isValid] (id recompute), so only the signature is
  /// checked here. On any worker failure (isolate closed / died) it degrades
  /// to the inline check so a verify never hangs and correctness is preserved.
  Future<bool> _verifySignatureOffMain(
    Event event,
    Map<String, dynamic> eventJson,
  ) async {
    final worker = _verifyWorker;
    if (worker == null) return event.isSigned;
    try {
      return await worker.verify(eventJson);
    } catch (_) {
      return event.isSigned;
    }
  }

  /// Runs [work] after the previous EVENT/EOSE frame from the same relay,
  /// preserving per-relay in-order delivery once verify is asynchronous. Errors
  /// are swallowed on the retained tail so one bad frame can't wedge the chain;
  /// the returned future still surfaces them to the immediate caller.
  Future<void> _enqueueOrdered(Relay relay, Future<void> Function() work) {
    final key = relay.url;
    final prev = _orderedFrameTails[key] ?? Future<void>.value();
    final next = prev.then((_) => work());
    _orderedFrameTails[key] = next.catchError((Object _) {});
    return next;
  }

  /// Fires the one-shot query callback for [subId] once no relay still has it
  /// pending, then forgets the callback.
  ///
  /// Both terminal frames route here: `EOSE` (the relay finished sending
  /// stored events) and `CLOSED` (the relay ended the subscription without
  /// finishing). Either way a default caller must be released rather than left
  /// to burn its whole timeout budget.
  /// Set [afterTerminalFrame] when the call is driven by a relay's own `EOSE`
  /// or `CLOSED`. That is the proof at least one relay is answering, and it is
  /// what arms [querySettleWindow] for whichever relays are still silent.
  /// Set [afterClosedWithoutAnswer] for `CLOSED` frames that cannot prove
  /// absence for callers that require full settlement.
  /// Set [afterFanoutReachedNoRelay] when the REQ fan-out ended with no relay
  /// having taken the query.
  ///
  /// A fourth fact takes no flag because it is read from the relays
  /// themselves: whether any relay still holds this query while being unable
  /// to answer it. That one is recomputed on every call rather than recorded,
  /// because it can both appear without a status change and disappear again on
  /// a reconnect.
  ///
  /// Every set this records into is written *after* the `callback == null`
  /// return, so a query the caller already abandoned cannot re-enter the
  /// bookkeeping that [_completeQuery] and [unsubscribe] have swept.
  void _fireQueryCompleteIfSettled(
    String subId, {
    bool afterTerminalFrame = false,
    bool afterClosedWithoutAnswer = false,
    bool afterFanoutReachedNoRelay = false,
  }) {
    final callback = _queryCompleteCallbacks[subId];
    if (callback == null) return;
    if (afterTerminalFrame) _queryAnswered.add(subId);
    if (afterClosedWithoutAnswer) _queryClosedWithoutAnswer.add(subId);
    if (afterFanoutReachedNoRelay) _queryReachedNoRelay.add(subId);
    if (_queryFanoutInProgress.contains(subId)) return;

    final list = [
      ..._relaysSnapshot(),
      ..._tempRelaysSnapshot(),
      ..._cacheRelaysSnapshot(),
    ];
    // Split what the old single condition collapsed. A relay that owes nothing
    // and a relay that took the REQ and can no longer answer it are very
    // different facts, and only the first means "settled".
    //
    // The second is the hole: a dropped socket, a zombie repair mid-cycle, or
    // a NIP-42 gate the relay has shown is shut. Such a relay is deliberately
    // not waited on — that is what [_canStillSettleQuery] exists to stop — but
    // it leaves exactly the gap a silent relay leaves, and a caller that
    // demanded full settlement must not read the relays that did answer as
    // "every relay says there is nothing".
    //
    // Derived here rather than recorded when the relay goes dark, for two
    // reasons. A silent-relay repair marks the relay unable to settle *before*
    // it fires any status change, so a recorded flag would still be empty in
    // that window. And the state is not permanent: a reconnect re-issues the
    // saved REQ under the same subscription id and its events reach the
    // original caller, so a relay that comes back and answers must stop
    // counting — a sticky flag would report a repaired flap as an inconclusive
    // read and roll back a write that had in fact succeeded.
    var strandedOnBlockedRelay = false;
    for (final r in list) {
      if (!r.checkQuery(subId)) continue;
      // Some relay still owes us a terminal frame for this query.
      if (_canStillSettleQuery(r)) {
        if (_queryAnswered.contains(subId) &&
            !_queriesRequiringFullSettlement.contains(subId)) {
          _armQuerySettleWindow(subId);
        }
        return;
      }
      strandedOnBlockedRelay = true;
    }

    // Nothing is pending — but for a full-settlement caller that only means
    // the query is complete if some relay actually answered it and no relay
    // became stranded. A relay that `CLOSED` the REQ has made no data claim,
    // but it has terminated its copy of the request: waiting cannot turn that
    // refusal into an answer. Complete the transport promptly and let the
    // query outcome report `relayClosed`, which strict compatibility callers
    // map back to an inconclusive result.
    //
    // A fan-out no relay took is the one shape that cannot improve by waiting
    // — see [_queryReachedNoRelay] — and `sentTo` already tells the caller the
    // answer is not authoritative, so it completes now instead of costing the
    // caller its whole deadline.
    // [strandedOnBlockedRelay] joins the two existing reasons to keep waiting.
    // It cannot coincide with [_queryReachedNoRelay]: a fan-out no relay took
    // leaves no relay holding the query, so nothing can be stranded on one.
    if (_queriesRequiringFullSettlement.contains(subId) &&
        !_queryReachedNoRelay.contains(subId) &&
        (!_queryAnswered.contains(subId) || strandedOnBlockedRelay)) {
      return;
    }

    _completeQuery(subId, callback);
  }

  /// Bounds how long the relays that have not answered [subId] can hold the
  /// caller, once some other relay has proven the fan-out is being served.
  ///
  /// Only a timer can bound this: a connected relay that never sends `EOSE`
  /// looks identical to one that is about to.
  void _armQuerySettleWindow(String subId) {
    if (_querySettleTimers.containsKey(subId)) return;
    _querySettleTimers[subId] = Timer(querySettleWindow, () {
      _querySettleTimers.remove(subId);
      final callback = _queryCompleteCallbacks[subId];
      if (callback == null) return;
      // A relay mid-NIP-42 is not silent, so the silence bound does not apply
      // to it: it challenged us, and its `OK` is what runs the post-AUTH
      // replay that this query is parked for. Completing here would send
      // `CLOSE` and drop the parked query, and the replay would find nothing.
      // [authHandshakeWindow] is what keeps the re-arming finite.
      if (_queryHasRelayMidHandshake(subId)) {
        _armQuerySettleWindow(subId);
        return;
      }
      log(
        'Query $subId settled without ${_queryStragglers(subId)} — '
        'completing on the relays that answered',
      );
      _completeQuery(subId, callback);
    });
  }

  /// Whether any relay still holding [subId] is inside its NIP-42 handshake.
  bool _queryHasRelayMidHandshake(String subId) => [
    ..._relaysSnapshot(),
    ..._tempRelaysSnapshot(),
    ..._cacheRelaysSnapshot(),
  ].any((r) => r.checkQuery(subId) && _hasLiveAuthHandshake(r));

  /// Restarts an armed settle window for [subId] because a relay is still
  /// streaming its result set.
  ///
  /// The window bounds *silence* — a relay that never terminates a REQ gives
  /// off no other signal. A relay part-way through answering is not that: it
  /// is being served, just not finished. Expiring the window under it closes
  /// the REQ mid-stream, and the caller is told the query completed normally,
  /// so a truncated result set is indistinguishable from a complete one.
  ///
  /// No-op unless a window is already armed, so a query nobody has answered
  /// yet still gets the caller's full timeout.
  void _restartQuerySettleWindow(String subId) {
    final armed = _querySettleTimers.remove(subId);
    if (armed == null) return;
    armed.cancel();
    _armQuerySettleWindow(subId);
  }

  /// Relay urls that never answered [subId]; diagnostic only.
  List<String> _queryStragglers(String subId) => [
    for (final r in [
      ..._relaysSnapshot(),
      ..._tempRelaysSnapshot(),
      ..._cacheRelaysSnapshot(),
    ])
      if (r.checkQuery(subId)) r.url,
  ];

  void _completeQuery(String subId, Function callback) {
    _diagnoseInconclusiveFullSettlementQuery(subId);
    // Judged before [_releaseQuery] takes the query off every relay, which
    // would erase which of them never answered.
    final tracker = _queryOutcomes.remove(subId);
    final outcome = tracker == null
        ? null
        : _concludeQueryOutcome(subId, tracker, atDeadline: false);
    _queryCompleteCallbacks.remove(subId);
    _queryAnswered.remove(subId);
    _queryClosedWithoutAnswer.remove(subId);
    _queryReachedNoRelay.remove(subId);
    _queriesRequiringFullSettlement.remove(subId);
    _querySettleTimers.remove(subId)?.cancel();
    _releaseQuery(subId);
    callback();
    if (outcome != null) tracker?.onOutcome?.call(outcome);
  }

  /// Tears down [subId] on every relay that still has it saved.
  ///
  /// The caller is done, so a relay that never produced its terminal frame is
  /// holding a REQ nobody is listening to. Left alone it stays open for the
  /// life of the socket — relays cap concurrent subscriptions, the saved
  /// [Subscription] pins the caller's event box, and both the post-AUTH replay
  /// and the zombie reconnect re-issue it on every future cycle. That matters
  /// most for exactly the relay this path exists for: one that never sends a
  /// terminal frame leaks a subscription per query for the whole session.
  ///
  /// A relay that never answered is also the zombie-socket candidate, so it is
  /// offered to [_repairSilentRelays] first — while [_querySentAt] still holds
  /// the fan-out timestamp that check needs.
  void _releaseQuery(String subId) {
    _repairRelaysThatNeverAnswered(subId);
    for (final relay in [
      ..._relaysSnapshot(),
      ..._tempRelaysSnapshot(),
      ..._cacheRelaysSnapshot(),
    ]) {
      if (!relay.checkQuery(subId)) continue;
      if (relay.relayStatus.connected == ClientConnected.connected) {
        unawaited(relay.checkAndCompleteQuery(subId));
      } else {
        // No socket to send `CLOSE` on; queueing it would only replay a
        // subscription the caller has already abandoned.
        relay.discardQuery(subId);
      }
    }
  }

  /// Tears down the live subscription [subId] on every relay holding it.
  ///
  /// The subscription half of [_releaseQuery], and it makes the same
  /// connected-state decision for the same reason. `CLOSE` is a statement
  /// about the current socket: sending it on a disconnected relay drives a
  /// reconnect purely to deliver a teardown frame, and when that fails the
  /// frame is queued into `pendingMessages` — where it names a subscription
  /// that only ever existed on the connection that already died.
  void _releaseSubscription(String subId) {
    for (final relay in [
      ..._relaysSnapshot(),
      ..._tempRelaysSnapshot(),
      ..._cacheRelaysSnapshot(),
    ]) {
      if (relay.relayStatus.connected == ClientConnected.connected) {
        relay.checkAndCompleteSubscription(subId);
      } else {
        relay.discardSubscription(subId);
      }
    }
  }

  /// Whether a query saved on [relay] can still produce a terminal frame, and
  /// therefore deserves to hold [_fireQueryCompleteIfSettled] back.
  ///
  /// A saved query means one of two different things, and only the first is
  /// worth waiting for:
  ///
  /// * the REQ is live on the current socket and its `EOSE`/`CLOSED` is still
  ///   coming, or
  /// * the REQ is parked for replay — the relay refused it with
  ///   `auth-required`, or the socket died under it.
  ///
  /// A parked query is replayed after NIP-42 succeeds or after a reconnect,
  /// both of which land far outside the caller's timeout. Counting it as
  /// outstanding makes *every* query in the app pay its full timeout for as
  /// long as one relay sits behind a closed auth gate, even when the healthy
  /// relays already answered.
  bool _canStillSettleQuery(Relay relay) {
    // A dropped socket cannot deliver the terminal frame for a REQ that was
    // written to it; the reconnect path re-issues the REQ on a fresh socket.
    if (relay.relayStatus.connected != ClientConnected.connected) return false;

    // A connection being force-cycled as a zombie reports `connected`
    // throughout, so it would otherwise keep charging concurrent queries the
    // full timeout for the whole repair.
    if (_silentRelayRepairsInFlight.contains(relay.url)) return false;

    // Behind an auth gate the replay only happens if NIP-42 completes. Wait
    // while a handshake is outstanding, and stop waiting once the relay has
    // shown the gate is shut — it refused the REQ with auth-required, refused
    // our AUTH event, or we could never answer its challenge.
    //
    // "No handshake" on its own is not that evidence: `alwaysAuth` latches for
    // the session, so a relay that has just reconnected sits in exactly that
    // state for the round trip before its challenge arrives. Treating that as
    // settled would silently drop the results of every read-gated relay on
    // cold start.
    if (relay.relayStatus.alwaysAuth && !relay.relayStatus.authed) {
      if (_hasLiveAuthHandshake(relay)) return true;
      return !_authGateClosed.contains(relay.url);
    }

    return true;
  }

  /// Whether [relay]'s NIP-42 handshake is outstanding and still inside
  /// [authHandshakeWindow].
  ///
  /// The age check is what stops a relay that accepts our AUTH event and never
  /// answers it from holding queries open for the life of the connection —
  /// nothing else about that relay distinguishes it from one still working.
  bool _hasLiveAuthHandshake(Relay relay) {
    final startedAt = _authHandshakeStartedAt[relay.url];
    if (startedAt == null) return false;
    return DateTime.now().difference(startedAt) < authHandshakeWindow;
  }

  /// Records that [relay]'s NIP-42 gate is shut and releases whatever was
  /// parked behind it.
  void _closeAuthGate(Relay relay) {
    _authHandshakeStartedAt.remove(relay.url);
    _authGateClosed.add(relay.url);
    _settleQueriesBlockedBy(relay);
  }

  /// Watches [relay]'s connection state so a dropped socket releases the
  /// one-shot queries that were still riding on it.
  ///
  /// [Relay.relayStatusCallback] is a single slot that NIP-46 also uses on its
  /// own (non-pool) relays, so any existing callback is chained rather than
  /// replaced. Wiring is idempotent: `add` is public and re-entrant for relay
  /// types it does not de-duplicate, and a chain that grew per call would
  /// re-run the settle sweep once per `add`.
  void _observeRelayStatus(Relay relay) {
    if (_statusObserved[relay] ?? false) return;
    _statusObserved[relay] = true;
    final previous = relay.relayStatusCallback;
    relay.relayStatusCallback = () {
      previous?.call();
      // NIP-42 state belongs to one socket: `authed` is reset on connect and a
      // fresh connection re-challenges from scratch. Carrying either marker
      // across a transition would let a relay that swallowed our AUTH event
      // read as "handshake outstanding" for the rest of the session.
      _authHandshakeStartedAt.remove(relay.url);
      _authGateClosed.remove(relay.url);
      _settleQueriesBlockedBy(relay);
    };
  }

  /// Force-cycles the relays that never produced a terminal frame for the
  /// abandoned query [subId].
  ///
  /// A caller only abandons a query by timing out, so any relay still holding
  /// it demonstrably did not answer. When that same connection also received no
  /// inbound frame of any kind since the REQ was written, it is the half-open
  /// zombie [_repairSilentRelays] already remediates on the publish side — a
  /// socket that still reports `connected` to every health gate while silently
  /// swallowing everything written to it. Without this, queries never trigger
  /// that repair, so a zombie keeps charging every subsequent query the full
  /// timeout until something else happens to cycle the connection.
  void _repairRelaysThatNeverAnswered(String subId) {
    final sentAt = _querySentAt.remove(subId);
    if (sentAt == null) return;
    final silent = [
      for (final relay in [
        ..._relaysSnapshot(),
        ..._tempRelaysSnapshot(),
        ..._cacheRelaysSnapshot(),
      ])
        if (relay.checkQuery(subId)) relay.url,
    ];
    if (silent.isEmpty) return;
    _repairSilentRelays(silent, sentAt);
  }

  /// [_repairRelaysThatNeverAnswered] for live subscriptions.
  ///
  /// A live subscription has no terminal frame, so "the relay still holds it"
  /// is true right up to the CLOSE — silence since the REQ is the whole signal,
  /// and [_repairSilentRelays] is what applies it. A relay that streamed events
  /// or EOSE'd stamped its activity clock and is therefore left alone; one that
  /// swallowed the REQ into a half-open socket is not, which is the case the
  /// feed loads hit. Without this a zombie charges every subsequent feed load
  /// the caller's full timeout until something else happens to cycle it.
  ///
  /// A subscription torn down before [minSubscriptionAgeBeforeRepair] proves
  /// nothing about the socket — the relay may simply not have answered yet —
  /// so it is ignored rather than charged against the connection.
  void _repairRelaysThatNeverServedSubscription(String subId) {
    final sentAt = _subscriptionSentAt.remove(subId);
    if (sentAt == null) return;
    if (DateTime.now().difference(sentAt) < minSubscriptionAgeBeforeRepair) {
      return;
    }
    final silent = [
      for (final relay in [
        ..._relaysSnapshot(),
        ..._tempRelaysSnapshot(),
        ..._cacheRelaysSnapshot(),
      ])
        if (relay.hasSubscriptionById(subId)) relay.url,
    ];
    if (silent.isEmpty) return;
    _repairSilentRelays(silent, sentAt);
  }

  /// [_repairRelaysThatNeverServedSubscription], run *while* the subscription
  /// is still live instead of at its teardown.
  ///
  /// Teardown-time repair only helps the next load; the one the user is
  /// watching has already failed by then. Probing at
  /// [subscriptionSilenceProbe] applies the same evidence — this relay was
  /// sent the REQ and has sent nothing back since — early enough that the
  /// re-issued REQ can still land inside the caller's deadline.
  ///
  /// Two shapes of "sent nothing back" are repaired, because from the caller's
  /// side they are the same failure:
  ///
  /// - **Connected but silent**: the half-open zombie [_repairSilentRelays]
  ///   already handles. Its own filters apply here unchanged, so a relay that
  ///   streamed events or EOSE'd is left alone and [silentRepairCooldown]
  ///   still rate-limits per relay.
  /// - **Not connected**: the REQ was queued rather than written, because
  ///   [relayDoSubscribe] sends with `skipReconnect`. Nothing periodic
  ///   reconnects relays, so without this the frame sits in `pendingMessages`
  ///   until some unrelated event happens to reconnect the socket. This branch
  ///   is not gated by [silentRepairCooldown]; it is bounded instead by the
  ///   probe being one-shot per subscription and by [Relay.connect] no-opping a
  ///   relay that is already connected or connecting.
  void _probeSubscriptionSilence(String subId) {
    _subscriptionSilenceProbes.remove(subId);
    if (_closed) return;
    if (!_subscriptions.containsKey(subId)) return;
    final sentAt = _subscriptionSentAt[subId];
    if (sentAt == null) return;

    final silent = <String>[];
    final dropped = <Relay>[];
    for (final relay in [
      ..._relaysSnapshot(),
      ..._tempRelaysSnapshot(),
      ..._cacheRelaysSnapshot(),
    ]) {
      if (!relay.hasSubscriptionById(subId)) continue;
      if (relay.relayStatus.connected == ClientConnected.connected) {
        silent.add(relay.url);
      } else {
        dropped.add(relay);
      }
    }

    if (silent.isNotEmpty) _repairSilentRelays(silent, sentAt);
    for (final relay in dropped) {
      log(
        '📡 ${relay.url} was sent subscription $subId while disconnected and '
        'has not reconnected; connecting so the queued REQ is written',
      );
      unawaited(_reconnectDroppedRelay(relay));
    }
  }

  /// Connects [relay] so a REQ queued while it was down is actually written.
  ///
  /// As with [_reconnectSilentRelay], the closed-check cannot be reached on
  /// its own — [_probeSubscriptionSilence] is the only caller and it already
  /// refuses on a closed pool — and is kept for a future caller's benefit.
  Future<void> _reconnectDroppedRelay(Relay relay) async {
    if (_closed) return;
    try {
      log('Reconnecting dropped relay ${relay.url}');
      _diagnose(
        RelayDiagnosticSite.connectionLifecycle,
        RelayDiagnosticLevel.info,
        relay.url,
        'Reconnecting dropped relay',
      );
      await relay.connect();
    } catch (e, stackTrace) {
      _diagnose(
        RelayDiagnosticSite.connectionLifecycle,
        RelayDiagnosticLevel.warning,
        relay.url,
        'Dropped-relay reconnect failed',
        error: e,
        stackTrace: stackTrace,
      );
      log('dropped-relay reconnect failed for ${relay.url}: $e');
    }
  }

  /// Subscription ids that still have a silence probe armed. Tests assert on
  /// this to prove [unsubscribe] disarms the probe, rather than leaning on the
  /// [_probeSubscriptionSilence] no-op guard — which would leave a dropped
  /// `.cancel()` invisible behind a leaked one-shot timer.
  @visibleForTesting
  List<String> get armedSilenceProbeSubscriptionIds =>
      _subscriptionSilenceProbes.keys.toList(growable: false);

  /// Releases the one-shot queries [relay] is parked on once it can no longer
  /// answer them.
  ///
  /// [_fireQueryCompleteIfSettled] only runs off a terminal frame or the end of
  /// fan-out. When a relay goes quiet instead — socket dropped, AUTH refused —
  /// nothing re-runs the check, so the callers blocked behind it have to be
  /// released here.
  void _settleQueriesBlockedBy(Relay relay) {
    if (_canStillSettleQuery(relay)) return;
    for (final query in relay.getQueries()) {
      _fireQueryCompleteIfSettled(query.id);
    }
  }

  Future<void> _onEvent(Relay relay, List<dynamic> json) async {
    final messageType = _stringAt(relay, json, 0, 'message type');
    if (messageType == null) return;

    // Log message type + sub ID (full json is too verbose for data frames)
    if (json.length >= 2) {
      final msgSubId = json[1];
      if (messageType == 'CLOSED' || messageType == 'NOTICE') {
        log('📡 Raw message from ${relay.url}: $json');
      } else if (messageType != 'EVENT') {
        // EVENT is excluded: it is the highest-volume frame, and a reconnect
        // replays a whole subscription window at once. OK and COUNT log
        // themselves below, so this mainly covers EOSE and unknown types.
        // Debug-only — the assert closure never runs in profile/release, and
        // logging here unconditionally cost ~6% of main-isolate CPU in
        // on-device profiling (#5957).
        assert(() {
          log('📡 ${relay.url}: $messageType $msgSubId');
          return true;
        }());
      }
    } else {
      log('📡 Raw message from ${relay.url}: $json');
    }

    // #5863: when an off-main verify worker is wired, serialize the frames
    // that carry or terminate a query per relay so the asynchronous verify
    // preserves in-order delivery — a terminal frame must not complete a query
    // before its preceding events finish verifying. CLOSED is terminal too: a
    // relay may stream part of a stored replay and then abandon it, so
    // completing on CLOSED out of order would drop the events already in
    // flight. With no worker the original synchronous path runs unchanged.
    if (_verifyWorker != null &&
        (messageType == 'EVENT' ||
            messageType == 'EOSE' ||
            messageType == 'CLOSED')) {
      return _enqueueOrdered(
        relay,
        () => _dispatchTypedFrame(relay, json, messageType),
      );
    }
    return _dispatchTypedFrame(relay, json, messageType);
  }

  /// Records that [relay] sent one-shot query [subId] an `EVENT` frame the
  /// pool rejected. The frame may have taken a slot of the relay's `limit`,
  /// so the query's outcome treats the relay as possibly capped, as it does
  /// one that answered outside the filter.
  void _recordRejectedQueryEvent(Relay relay, String subId) {
    if (_subscriptions[subId] != null) return;
    if (relay.getRequestSubscription(subId) == null) return;
    _queryOutcomes[subId]?.recordRejectedEvent(relay);
  }

  Future<void> _dispatchTypedFrame(
    Relay relay,
    List<dynamic> json,
    String messageType,
  ) async {
    if (messageType == 'EVENT') {
      try {
        final subId = _stringAt(relay, json, 1, 'EVENT subscription id');
        if (subId == null) return;

        final eventJson = _mapAt(relay, json, 2, 'EVENT payload');
        if (eventJson == null) {
          _recordRejectedQueryEvent(relay, subId);
          return;
        }

        final Event event;
        try {
          event = Event.fromJson(eventJson);
        } catch (err) {
          log('Dropping malformed relay event from ${relay.url}: $err');
          _recordRejectedQueryEvent(relay, subId);
          return;
        }

        // Cheap integrity check first: [Event.isValid] recomputes the
        // sha256 id from the event's own content, so a tampered payload is
        // rejected here without touching the expensive EC verifier.
        if (!event.isValid) {
          log(
            'Dropping relay event with invalid id '
            'from ${relay.url}: eventId=${event.id}',
          );
          _recordRejectedQueryEvent(relay, subId);
          return;
        }

        // Skip the expensive Schnorr verify when this exact `(id, sig)` pair
        // is already trusted. The event id commits to the body but not to
        // `sig`, so trust is keyed by both — a replayed id carrying a
        // different signature falls through to a full verify below.
        //  - Pairs verified in a previous session (known to the injected
        //    [isKnownVerifiedEvent] store) skip re-verify on cold start.
        //  - Pairs verified earlier this session (a duplicate delivery of the
        //    same event from another relay) skip re-verify.
        // Only fresh network verifications are recorded in [_verifiedEventKeys]
        // so a known/duplicate hit never masks an unverified network copy.
        if (event.sig.isEmpty) {
          log(
            'Dropping relay event with empty signature '
            'from ${relay.url}: eventId=${event.id}',
          );
          _recordRejectedQueryEvent(relay, subId);
          return;
        }

        final verifyKey = '${event.id}:${event.sig}';
        if (_verifiedEventKeys.contains(verifyKey)) {
          _verifiesSkippedSessionDup++;
        } else if (isKnownVerifiedEvent?.call(event.id, event.sig) ?? false) {
          _verifiesSkippedKnown++;
        } else if (_shouldVerifySignature(relay)) {
          if (await _verifySignatureOffMain(event, eventJson)) {
            _markEventVerified(verifyKey);
            _verifiesPerformed++;
          } else {
            log(
              'Dropping relay event with invalid signature '
              'from ${relay.url}: eventId=${event.id}',
            );
            // Decided after an await, off the main isolate when a verify
            // worker is wired; the query may have ended meanwhile, and then
            // there is no outcome left to record on.
            _recordRejectedQueryEvent(relay, subId);
            return;
          }
        } else {
          _verifiesSkippedByPolicy++;
        }

        final poolSubscription = _subscriptions[subId];
        final querySubscription = poolSubscription == null
            ? relay.getRequestSubscription(subId)
            : null;
        final subscription = poolSubscription ?? querySubscription;

        if (subscription == null) {
          return;
        }

        // Liveness before admission: a frame arriving is progress whether or
        // not we wanted its contents. Both of these say "this relay is still
        // working", which is a property of the socket, not of the payload.
        relay.relayStatus.noteReceive();
        if (querySubscription != null) {
          // The relay is mid-answer for this one-shot query, so it has not
          // gone silent. Restart the grace period rather than cutting its
          // result set off part-way through.
          _restartQuerySettleWindow(subId);
        }

        if (!subscription.matchesEvent(event)) {
          log(
            'Dropping relay event that does not match subscription filter '
            'from ${relay.url}: eventId=${event.id}, subId=$subId',
          );
          if (querySubscription != null) {
            // A relay that does not honour the filter may have spent its
            // limit on events the query never asked for.
            _queryOutcomes[subId]?.recordOffFilterEvent(relay);
          }
          return;
        }

        if (querySubscription != null) {
          // Counted before the block list below: an event hidden from the
          // caller still took a slot in the relay's `limit`.
          _queryOutcomes[subId]?.recordEvent(relay, event);
        }

        if ((relay.relayStatus.relayType != RelayType.cache)) {
          var event = Map<String, dynamic>.from(eventJson);
          var kind = event["kind"];
          if (!cacheAvoidEvents.contains(kind)) {
            event["sources"] = [relay.url];
            _broadcaseToCache(event);
          }
        }

        // check block pubkey
        for (var eventFilter in eventFilters) {
          if (eventFilter.check(event)) {
            return;
          }
        }

        if (relay.relayStatus.relayType == RelayType.cache) {
          // local message read source from json
          var sources = eventJson["sources"];
          if (sources != null && sources is List) {
            for (var source in sources) {
              event.sources.add(source);
            }
          }
          // mark this event is from local relay.
          event.cacheEvent = true;
        } else {
          event.sources.add(relay.url);
        }
        subscription.onEvent(event);
      } catch (err) {
        log(err.toString());
      }
    } else if (messageType == 'EOSE') {
      final subId = _stringAt(relay, json, 1, 'EOSE subscription id');
      if (subId == null) return;
      // Debug-only: EOSE is a per-settlement frame, and logging it
      // unconditionally cost ~6% of main-isolate CPU in on-device profiling
      // (#5957). The assert closure never runs in profile/release; the
      // structured diagnostic below carries the settlement to injected sinks.
      assert(() {
        log('Relay ${relay.url} settled request $subId with EOSE');
        return true;
      }());
      _diagnose(
        RelayDiagnosticSite.requestSettlement,
        RelayDiagnosticLevel.info,
        relay.url,
        'Relay settled request $subId with EOSE',
      );
      // Recorded before the await: `checkAndCompleteQuery` forgets the query
      // at once, and a completion that runs while its CLOSE is in flight
      // would otherwise find this relay gone without an answer.
      if (relay.checkQuery(subId)) {
        _queryOutcomes[subId]?.recordEose(relay, json);
      }
      var isQuery = await relay.checkAndCompleteQuery(subId);
      if (isQuery) {
        _fireQueryCompleteIfSettled(subId, afterTerminalFrame: true);
      } else {
        // Handle EOSE for long-running subscriptions
        final subscription = _subscriptions[subId];
        if (subscription != null && subscription.onEose != null) {
          // Track which relays have sent EOSE for this subscription
          _subscriptionEoseRelays.putIfAbsent(subId, () => <String>{});
          _subscriptionEoseRelays[subId]!.add(relay.url);

          // Check if all relays that have this subscription have sent EOSE
          final activeRelays = _getRelaysWithSubscription(subId);
          if (_subscriptionEoseRelays[subId]!.length >= activeRelays.length) {
            subscription.onEose!();
            _subscriptionEoseRelays.remove(subId);
          }
        }
      }
    } else if (messageType == "OK") {
      log('📡 OK response from ${relay.url}: $json');

      // Check if this OK is for an AUTH event
      final eventId = _stringAt(relay, json, 1, 'OK event id');
      if (eventId == null) return;
      final success = _boolAt(relay, json, 2, 'OK success');
      if (success == null) return;
      final message = _optionalStringAt(
        relay,
        json,
        3,
        'OK message',
        defaultValue: '',
      );
      if (message == null) return;
      _diagnose(
        RelayDiagnosticSite.requestSettlement,
        success ? RelayDiagnosticLevel.info : RelayDiagnosticLevel.warning,
        relay.url,
        'Relay settled event $eventId with OK accepted=$success',
      );

      // The relay has spoken for this event. Unless it refused for a reason
      // NIP-42 can fix, a frame retained by [_retainForAuthRetry] has served
      // its purpose and must not be replayed after a later, unrelated AUTH.
      if (success ||
          !_shouldRetryPublishAfterAuth(
            relay: relay,
            eventId: eventId,
            message: message,
          )) {
        relay.takeSentFrame(eventId);
      }

      // Check if this OK is for a publish we are awaiting.
      //
      // Trackers are keyed on event id alone, so without the membership check
      // any connected relay could accept or reject a publish it was never
      // sent — deciding the outcome of, say, a narrowly targeted direct
      // message it has no part in.
      final pendingPublish = _pendingPublishes[eventId];
      final publishTracker =
          pendingPublish != null && pendingPublish.isTarget(relay.url)
          ? pendingPublish
          : null;
      if (pendingPublish != null && publishTracker == null) {
        log(
          '📡 Ignoring OK for $eventId from ${relay.url}: not a publish target',
        );
      }
      if (publishTracker != null) {
        if (success) {
          _removeAuthRequiredPublish(eventId, relay.url);
          publishTracker.onAccepted(relay.url);
        } else if (_shouldRetryPublishAfterAuth(
          relay: relay,
          eventId: eventId,
          message: message,
        )) {
          final originalMessage = publishTracker.message;
          final deadline = publishTracker.deadline;
          if (originalMessage == null || deadline == null) {
            publishTracker.onRejected(relay.url, message);
          } else {
            _trackAuthRequiredPublish(
              relay: relay,
              message: originalMessage,
              tracker: publishTracker,
              reason: message,
              deadline: deadline,
            );
            if (relay.relayStatus.authed) {
              await _retryAuthRequiredPublishesForRelay(relay);
            }
          }
        } else {
          _removeAuthRequiredPublish(eventId, relay.url);
          publishTracker.onRejected(relay.url, message);
        }
      }

      // Check if this is responding to our AUTH event
      if (_pendingAuthEvents.containsKey(eventId)) {
        _pendingAuthEvents.remove(eventId);
        _authHandshakeStartedAt.remove(relay.url);

        if (success) {
          relay.relayStatus.authed = true;
          log('🔐 AUTH succeeded for ${relay.url}');
          _diagnose(
            RelayDiagnosticSite.authentication,
            RelayDiagnosticLevel.info,
            relay.url,
            'Relay authentication succeeded',
          );

          // Send pending messages
          for (var message in relay.pendingAuthedMessages) {
            relay.send(message);
          }
          relay.pendingAuthedMessages.clear();

          // Flush and re-send frames that were retained while waiting for auth
          for (final frame in relay.drainSentFramesForAuthRetry()) {
            relay.send(frame);
          }

          // Send subscriptions
          if (relay.hasSubscription()) {
            var subs = relay.getSubscriptions();
            log(
              '🔐 AUTH post-auth: re-sending ${subs.length} '
              'subscriptions to ${relay.url}',
            );
            for (var subscription in subs) {
              log(
                '🔐 AUTH post-auth: sending ${subscription.id} '
                '${relay.url}',
              );
              relay.send(subscription.toJson());
            }
          } else {
            log(
              '🔐 AUTH post-auth: NO subscriptions saved for '
              '${relay.url}',
            );
          }

          // Re-issue one-shot queries. Their pre-auth REQ was sent to trigger
          // the challenge and may have been CLOSED with auth-required, so the
          // saved query still needs to run once the relay accepts us.
          for (final query in relay.getQueries()) {
            log('🔐 AUTH post-auth: re-sending query ${query.id} ${relay.url}');
            relay.send(query.toJson());
          }
          await _retryAuthRequiredPublishesForRelay(relay);
        } else {
          relay.relayStatus.authed = false;
          log('🔐 AUTH failed for ${relay.url}: $message');
          _diagnose(
            RelayDiagnosticSite.authentication,
            RelayDiagnosticLevel.warning,
            relay.url,
            'Relay authentication failed',
          );
          _rejectAuthRequiredPublishesForRelay(relay, message);
          // The gate stayed shut, so the queries parked for the post-AUTH
          // replay will never be replayed.
          _closeAuthGate(relay);
        }
      }
    } else if (messageType == "NOTICE") {
      log('📡 NOTICE from ${relay.url}: $json');
      final message = _stringAt(relay, json, 1, 'NOTICE message');
      if (message == null) return;
      _diagnose(
        RelayDiagnosticSite.notice,
        RelayDiagnosticLevel.warning,
        relay.url,
        'Relay sent a NOTICE frame',
      );

      // notice save, TODO maybe should change code
      if (onNotice != null) {
        onNotice!(relay.url, message);
      }
    } else if (messageType == "AUTH") {
      try {
        // auth needed
        log('🔐 AUTH challenge received from ${relay.url}');
        _diagnose(
          RelayDiagnosticSite.authentication,
          RelayDiagnosticLevel.info,
          relay.url,
          'Relay requested authentication',
        );
        final challenge = _stringAt(relay, json, 1, 'AUTH challenge');
        if (challenge == null) return;
        relay.relayStatus.alwaysAuth = true;
        // Marks the handshake outstanding before the async signing below, so
        // queries parked behind this gate keep waiting instead of reading the
        // signing gap as "nothing is coming". See [_canStillSettleQuery].
        _authHandshakeStartedAt[relay.url] = DateTime.now();
        // A new challenge supersedes whatever the last one concluded.
        _authGateClosed.remove(relay.url);
        log('🔐 Challenge: $challenge');
        var tags = [
          ["relay", relay.url],
          ["challenge", challenge],
        ];
        // Guard against empty cached pubkey: this path is triggered by
        // the relay, not a user action, and can race with sign-out,
        // initial signer load, and account-switch. Refresh from the
        // signer on demand; StateError falls through to the catch below
        // and the AUTH response is skipped.
        final pk = await localNostr.ensurePublicKey();
        Event? event = Event(pk, EventKind.authentication, tags, "");
        event = await localNostr.nostrSigner.signEvent(event);
        if (event != null) {
          log('🔐 Sending AUTH response for challenge: $challenge');

          // Track this AUTH event to match with OK response
          _pendingAuthEvents[event.id] = relay.url;

          relay.send(["AUTH", event.toJson()]);
          log('🔐 AUTH response sent, waiting for relay confirmation...');

          if (relay.pendingAuthedMessages.isNotEmpty) {
            log(
              '🔐 Pending ${relay.pendingAuthedMessages.length} messages for after auth confirmation',
            );
          }
        } else {
          log('🔐 AUTH signing returned null for ${relay.url}');
          _rejectAuthRequiredPublishesForRelay(relay, '');
          _closeAuthGate(relay);
        }
      } catch (err, stackTrace) {
        _diagnose(
          RelayDiagnosticSite.authentication,
          RelayDiagnosticLevel.error,
          relay.url,
          'Relay authentication handling failed',
          error: err,
          stackTrace: stackTrace,
        );
        log('🔐 AUTH handling failed for ${relay.url}: $err\n$stackTrace');
        _rejectAuthRequiredPublishesForRelay(relay, '');
        _closeAuthGate(relay);
      }
    } else if (messageType == 'COUNT') {
      // NIP-45 COUNT response
      final subscriptionId = _stringAt(relay, json, 1, 'COUNT subscription id');
      if (subscriptionId == null) return;
      final payload = _mapAt(relay, json, 2, 'COUNT payload');
      if (payload == null) return;
      final count = _intPayloadField(relay, json, payload, 'count');
      if (count == null) return;
      final approximate = _optionalBoolPayloadField(
        relay,
        json,
        payload,
        'approximate',
        defaultValue: false,
      );
      if (approximate == null) return;

      log('📊 COUNT response: $count (approximate: $approximate)');

      final response = CountResponse(count: count, approximate: approximate);

      relay.completeCountQuery(subscriptionId, response);
    } else if (messageType == 'CLOSED') {
      // Handle CLOSED messages - check if it's for a COUNT query
      final subscriptionId = _stringAt(
        relay,
        json,
        1,
        'CLOSED subscription id',
      );
      if (subscriptionId == null) return;
      final reason = _optionalStringAt(
        relay,
        json,
        2,
        'CLOSED reason',
        defaultValue: 'Unknown reason',
      );
      if (reason == null) return;

      log('📡 CLOSED from ${relay.url}: $subscriptionId - $reason');
      _diagnose(
        RelayDiagnosticSite.requestSettlement,
        RelayDiagnosticLevel.warning,
        relay.url,
        'Relay closed request $subscriptionId '
        '(reason=${_closedReasonCategory(reason)})',
      );
      // Check if this is a COUNT query being refused
      if (relay.hasCountQuery(subscriptionId)) {
        relay.failCountQuery(subscriptionId, reason);
      }

      // CLOSED terminates this relay's copy of a live REQ. Forget it locally
      // immediately so reconnect cannot replay a subscription the relay has
      // already refused. Other relays may still be serving the same logical
      // subscription; only fail that subscription once none remain.
      if (!_shouldReplayQueryAfterAuth(relay, reason) &&
          relay.discardSubscription(subscriptionId)) {
        final subscription = _subscriptions[subscriptionId];
        final activeRelays = _getRelaysWithSubscription(subscriptionId);
        if (subscription != null && activeRelays.isEmpty) {
          _subscriptionSilenceProbes.remove(subscriptionId)?.cancel();
          _subscriptions.remove(subscriptionId);
          _subscriptionEoseRelays.remove(subscriptionId);
          _subscriptionSentAt.remove(subscriptionId);
          subscription.onClosed?.call(reason);
        } else if (subscription != null && subscription.onEose != null) {
          final eoseRelays = _subscriptionEoseRelays[subscriptionId];
          // A relay that reported EOSE and then refused the REQ leaves the
          // tally with it. Left in, its EOSE would stand in for a relay that
          // is still streaming stored events, and a bounded read would close
          // on a partial result.
          eoseRelays?.remove(relay.url);
          if (eoseRelays != null && eoseRelays.length >= activeRelays.length) {
            subscription.onEose!();
            _subscriptionEoseRelays.remove(subscriptionId);
          }
        }
        return;
      }

      // A refused/abandoned REQ is terminal unless it is the pre-AUTH probe
      // that must stay saved for replay after NIP-42 succeeds.
      if (_shouldReplayQueryAfterAuth(relay, reason)) {
        // A refusal the post-AUTH replay may still overturn; an EOSE the
        // replay draws replaces it.
        if (relay.checkQuery(subscriptionId)) {
          _recordQueryClosed(relay, subscriptionId, reason);
        }
        // The relay named the gate itself. With no live handshake nothing is
        // going to run that replay, and this refusal is the evidence
        // [_canStillSettleQuery] waits for before giving up on it. Judged on
        // the same bound as everywhere else: a handshake the relay swallowed
        // must stop suppressing its own refusal once it goes stale, or every
        // later query on that socket pays its full budget.
        if (!_hasLiveAuthHandshake(relay)) _closeAuthGate(relay);
      } else if (relay.discardQuery(subscriptionId)) {
        _recordQueryClosed(relay, subscriptionId, reason);
        _fireQueryCompleteIfSettled(
          subscriptionId,
          afterTerminalFrame: true,
          afterClosedWithoutAnswer: true,
        );
      }
    }
  }

  void addInitQuery(
    List<Map<String, dynamic>> filters,
    Function(Event) onEvent, {
    String? id,
    Function? onComplete,
  }) {
    if (filters.isEmpty) {
      throw ArgumentError("No filters given", "filters");
    }

    final Subscription subscription = Subscription(filters, onEvent, id: id);
    _initQuery[subscription.id] = subscription;
    if (onComplete != null) {
      _queryCompleteCallbacks[subscription.id] = onComplete;
    }
  }

  /// subscribe shoud be a long time filter search.
  /// like: subscribe the newest event、notice.
  /// subscribe info will hold in reply pool and close in reply pool.
  /// subscribe can be subscribe when new relay put into pool.
  String subscribe(
    List<Map<String, dynamic>> filters,
    Function(Event) onEvent, {
    String? id,
    List<String>? tempRelays,
    List<String>? targetRelays,
    List<int> relayTypes = RelayType.all,
    bool sendAfterAuth =
        false, // if relay not connected, it will send after auth
    void Function()? onEose,
    void Function(String reason)? onClosed,
  }) {
    if (filters.isEmpty) {
      throw ArgumentError("No filters given", "filters");
    }

    tempRelays = handleAddrList(tempRelays);
    targetRelays = handleAddrList(targetRelays);

    final Subscription subscription = Subscription(
      filters,
      onEvent,
      id: id,
      onEose: onEose,
      onClosed: onClosed,
    );
    _subscriptions[subscription.id] = subscription;
    _subscriptionSentAt[subscription.id] = DateTime.now();
    final subscribedRelayIdentities = <String>{};
    log(
      '📋 subscribe: id=${subscription.id}, '
      'relays=${_relays.length}, filters=$filters',
    );
    // tempRelay, only query those relay which has bean provide
    if (tempRelays != null &&
        tempRelays.isNotEmpty &&
        relayTypes.contains(RelayType.temp)) {
      for (var tempRelayAddr in tempRelays) {
        // check if normal relays has this temp relay, try to get relay from normal relays
        Relay? relay = _pooledRelayForTempAddr(tempRelayAddr);
        relay ??= checkAndGenTempRelay(tempRelayAddr);
        if (!subscribedRelayIdentities.add(_relayIdentity(relay.url))) {
          continue;
        }

        relayDoSubscribe(
          relay,
          subscription,
          sendAfterAuth,
          runBeforeConnected: true,
        );
      }
    }

    // normal relay, usually will query all the normal relays, but if targetRelays has provide, it only query from the provided querys.
    if (relayTypes.contains(RelayType.normal)) {
      for (final entry in _relayEntriesSnapshot()) {
        var relayAddr = entry.key;
        var relay = entry.value;

        if (targetRelays != null && !_namesRelay(targetRelays, relayAddr)) {
          continue;
        }
        if (!subscribedRelayIdentities.add(_relayIdentity(relay.url))) {
          continue;
        }

        relayDoSubscribe(relay, subscription, sendAfterAuth);
      }
    }

    // cache relay
    if (relayTypes.contains(RelayType.cache)) {
      for (final relay in _cacheRelaysSnapshot()) {
        relayDoSubscribe(relay, subscription, sendAfterAuth);
      }
    }

    _subscriptionSilenceProbes.remove(subscription.id)?.cancel();
    if (!_closed) {
      _subscriptionSilenceProbes[subscription.id] = Timer(
        subscriptionSilenceProbe,
        () => _probeSubscriptionSilence(subscription.id),
      );
    }

    return subscription.id;
  }

  Future<bool> relayDoSubscribe(
    Relay relay,
    Subscription subscription,
    bool sendAfterAuth, {
    bool runBeforeConnected = false,
  }) async {
    if (!relay.relayStatus.readAccess) {
      return false;
    }

    relay.relayStatus.onQuery();

    try {
      relay.saveSubscription(subscription);

      var message = subscription.toJson();
      final subscribeMsg =
          '📤 relayDoSubscribe: ${subscription.id} → ${relay.url} '
          '(authed=${relay.relayStatus.authed}, '
          'readAccess=${relay.relayStatus.readAccess}, '
          'connected=${relay.relayStatus.connected})';
      log(subscribeMsg);
      _diagnose(
        RelayDiagnosticSite.queryDispatch,
        RelayDiagnosticLevel.info,
        relay.url,
        'Dispatching request ${subscription.id} '
        '(filters=${subscription.filters.length})',
      );
      if ((sendAfterAuth || relay.relayStatus.alwaysAuth) &&
          !relay.relayStatus.authed) {
        log(
          '🔐 Auth-required subscription - sending to trigger AUTH challenge',
        );
        final deadline = DateTime.now().add(perRelaySendTimeout);
        final result = await relay
            .send(message, queueIfFailed: false, deadline: deadline)
            .timeout(perRelaySendTimeout, onTimeout: () => false);
        if (result) {
          log('Request ${subscription.id} dispatch to ${relay.url} succeeded');
          _diagnose(
            RelayDiagnosticSite.queryDispatch,
            RelayDiagnosticLevel.info,
            relay.url,
            'Request ${subscription.id} dispatch succeeded',
          );
          return true;
        }
      } else {
        var result = await relay.send(message, skipReconnect: true);
        log('📤 relayDoSubscribe: ${subscription.id} send result=$result');
        _diagnose(
          RelayDiagnosticSite.queryDispatch,
          result ? RelayDiagnosticLevel.info : RelayDiagnosticLevel.warning,
          relay.url,
          'Request ${subscription.id} dispatch succeeded=$result',
        );
        return result;
      }
    } catch (err, stackTrace) {
      _diagnose(
        RelayDiagnosticSite.queryDispatch,
        RelayDiagnosticLevel.error,
        relay.url,
        'Request ${subscription.id} dispatch threw',
        error: err,
        stackTrace: stackTrace,
      );
      log(err.toString());
      relay.relayStatus.onError();
    }

    return false;
  }

  bool tempRelayHasSubscription(String relayAddr) {
    var relay = _tempRelays[relayAddr];
    if (relay != null) {
      return relay.hasSubscription();
    }

    return false;
  }

  void unsubscribe(String id) {
    _subscriptionSilenceProbes.remove(id)?.cancel();
    final subscription = _subscriptions.remove(id);
    // Clean up EOSE tracking for this subscription
    _subscriptionEoseRelays.remove(id);
    if (subscription != null) {
      // A relay that still holds this REQ never served it, so offer it to the
      // zombie repair before the teardown sweep below drops that evidence.
      _repairRelaysThatNeverServedSubscription(id);
      _releaseSubscription(id);
    } else {
      _diagnoseInconclusiveFullSettlementQuery(id);
      // No matching subscription — treat [id] as a one-shot query. Drop its
      // completion callback so a query cancelled before EOSE doesn't leak a
      // never-fired callback in [_queryCompleteCallbacks].
      _queryCompleteCallbacks.remove(id);
      _queryOutcomes.remove(id);
      _queryFanoutInProgress.remove(id);
      _queryAnswered.remove(id);
      _queryClosedWithoutAnswer.remove(id);
      _queryReachedNoRelay.remove(id);
      _queriesRequiringFullSettlement.remove(id);
      _querySettleTimers.remove(id)?.cancel();
      _releaseQuery(id);
    }
  }

  /// Reports settlement evidence before query teardown destroys it.
  ///
  /// Full-settlement queries reach this path when their caller's deadline
  /// expires. Socket repair and observability deliberately have different
  /// gates: a relay can remain connected and receive unrelated frames while
  /// still never settling this request, which makes it ineligible for zombie
  /// repair but no less important in a support export. See #9030.
  void _diagnoseInconclusiveFullSettlementQuery(String subId) {
    if (!_queriesRequiringFullSettlement.contains(subId)) return;

    final relays = [
      ..._relaysSnapshot(),
      ..._tempRelaysSnapshot(),
      ..._cacheRelaysSnapshot(),
    ];
    final unsettled = <Relay>[];
    for (final relay in relays) {
      if (relay.checkQuery(subId)) unsettled.add(relay);
    }
    for (final relay in unsettled) {
      _diagnose(
        RelayDiagnosticSite.requestSettlement,
        RelayDiagnosticLevel.warning,
        relay.url,
        'Relay did not settle request $subId within the caller window',
      );
    }

    final answered = _queryAnswered.contains(subId);
    final closedWithoutAnswer = _queryClosedWithoutAnswer.contains(subId);
    final noRelayTookRequest = _queryReachedNoRelay.contains(subId);
    final strandedOnBlockedRelay = unsettled.any(
      (relay) => !_canStillSettleQuery(relay),
    );
    if (answered &&
        !closedWithoutAnswer &&
        !noRelayTookRequest &&
        !strandedOnBlockedRelay &&
        unsettled.isEmpty) {
      return;
    }
    _diagnose(
      RelayDiagnosticSite.requestSettlement,
      RelayDiagnosticLevel.warning,
      RelayDiagnostic.poolScope,
      'Full-settlement request $subId ended inconclusively '
      '(answered=$answered, closedWithoutAnswer=$closedWithoutAnswer, '
      'noRelayTookRequest=$noRelayTookRequest, '
      'strandedOnBlockedRelay=$strandedOnBlockedRelay, '
      'unsettledRelays=${unsettled.length})',
    );
  }

  // different relay use different filter
  String queryByFilters(
    Map<String, List<Map<String, dynamic>>> filtersMap,
    Function(Event) onEvent, {
    String? id,
    Function? onComplete,
  }) {
    if (filtersMap.isEmpty ||
        filtersMap.values.any((filters) => filters.isEmpty)) {
      // A per-relay entry with no filters would build a Subscription that
      // matches nothing, so every event it received would be dropped by the
      // admission gate. The sibling entry points reject this the same way.
      throw ArgumentError("No filters given", "filters");
    }
    id ??= StringUtil.rndSecureNameStr(16);
    if (onComplete != null) {
      _queryCompleteCallbacks[id] = onComplete;
    }
    var entries = filtersMap.entries;
    for (var entry in entries) {
      var url = entry.key;
      var filters = entry.value;

      var relay = _relays[url];
      if (relay != null) {
        Subscription subscription = Subscription(filters, onEvent, id: id);
        relayDoQuery(relay, subscription, false);
      }
    }
    return id;
  }

  List<String>? handleAddrList(List<String>? addrList) {
    if (addrList == null) return null;
    return addrList.map(RelayAddrUtil.handle).toList();
  }

  /// query should be a one time filter search.
  /// like: query metadata, query old event.
  /// query info will hold in relay and close in relay when EOSE message be received.
  /// if onlyTempRelays is true and tempRelays is not empty, it will only query throw tempRelays.
  /// if onlyTempRelays is false and tempRelays is not empty, it will query bath myRelays and tempRelays.
  /// Set [requireAllRelaysSettled] when a partial answer is worse for the
  /// caller than no answer — see [_queriesRequiringFullSettlement]. The query
  /// then completes only once every relay that can still answer has, so a relay
  /// that stays connected and never sends a terminal frame runs the caller out
  /// to its own timeout instead of being skipped past.
  ///
  /// The returned `sentTo` names the relays that took the REQ: the frame
  /// reached the socket, or the relay is behind an auth gate and the query is
  /// parked for post-NIP-42 replay. Only those relays can ever answer, so an
  /// empty `sentTo` means nothing was asked — which is not the same as every
  /// relay having nothing, and is the distinction a caller about to replace a
  /// replaceable event has to make. Cache relays count toward it, so it
  /// answers "did anything take this REQ", not "did a network relay take it".
  ///
  /// The future resolves once the fan-out is done. `onComplete` may already
  /// have fired by then — a fan-out that settles the query calls it inline.
  ///
  /// [onOutcome] receives how the query ended, as a [QueryOutcome], when the
  /// pool completes it: at the same moment and under the same conditions as
  /// `onComplete`, which it may replace. Its `endedBy` is never
  /// `QueryEnd.deadline`, because the pool does not own the caller's
  /// deadline; a caller whose deadline fires first calls
  /// [reportQueryDeadline], then [unsubscribe], instead.
  Future<({String id, List<String> sentTo})> query(
    List<Map<String, dynamic>> filters,
    Function(Event) onEvent, {
    String? id,
    Function? onComplete,
    void Function(QueryOutcome outcome)? onOutcome,
    List<String>? tempRelays,
    List<String>? targetRelays,
    List<int> relayTypes = RelayType.all,
    bool sendAfterAuth =
        false, // if relay not connected, it will send after auth
    bool requireAllRelaysSettled = false,
  }) async {
    if (filters.isEmpty) {
      throw ArgumentError("No filters given", "filters");
    }

    tempRelays = handleAddrList(tempRelays);
    targetRelays = handleAddrList(targetRelays);

    Subscription subscription = Subscription(filters, onEvent, id: id);
    // Either callback asks the pool to settle the query and say so.
    final completionRequested = onComplete != null || onOutcome != null;
    QueryOutcomeTracker? outcomeTracker;
    if (completionRequested) {
      _queryCompleteCallbacks[subscription.id] =
          onComplete ?? _ignoreQueryComplete;
      _queryFanoutInProgress.add(subscription.id);
      _querySentAt[subscription.id] = DateTime.now();
      if (requireAllRelaysSettled) {
        _queriesRequiringFullSettlement.add(subscription.id);
      }
      outcomeTracker = QueryOutcomeTracker(
        subscription.id,
        subscription.parsedFilters,
        onOutcome: onOutcome,
      );
      _queryOutcomes[subscription.id] = outcomeTracker;
    }

    // Collect futures so we can await them before the early-completion
    // check. Each relayDoQuery call only resolves after relay.send()
    // and saveQuery(), which is fast with skipReconnect: true. Each resolves
    // to the relay's url when it took the REQ, so the fan-out can report who
    // is actually able to answer.
    final queryFutures = <Future<String?>>[];
    final queriedRelayIdentities = <String>{};

    // Recorded on this call's own outcome record, never a newer one under
    // the same id, so a deadline that beats the fan-out can still name the
    // relays being asked.
    Future<String?> sendQueryTo(
      Relay relay, {
      bool runBeforeConnected = false,
    }) {
      outcomeTracker?.recordDispatch(relay);
      return relayDoQuery(
        relay,
        subscription,
        sendAfterAuth,
        runBeforeConnected: runBeforeConnected,
      ).then((accepted) {
        outcomeTracker?.recordReqTaken(relay, taken: accepted);
        return accepted ? relay.url : null;
      });
    }

    // tempRelay, only query those relay which has bean provide
    if (tempRelays != null &&
        tempRelays.isNotEmpty &&
        relayTypes.contains(RelayType.temp)) {
      for (var tempRelayAddr in tempRelays) {
        // check if normal relays has this temp relay, try to get relay from normal relays
        Relay? relay = _pooledRelayForTempAddr(tempRelayAddr);
        relay ??= checkAndGenTempRelay(tempRelayAddr);
        if (!queriedRelayIdentities.add(_relayIdentity(relay.url))) {
          continue;
        }

        queryFutures.add(sendQueryTo(relay, runBeforeConnected: true));
      }
    }

    // normal relay, usually will query all the normal relays, but if targetRelays has provide, it only query from the provided querys.
    if (relayTypes.contains(RelayType.normal)) {
      for (final entry in _relayEntriesSnapshot()) {
        var relayAddr = entry.key;
        var relay = entry.value;

        if (targetRelays != null && !_namesRelay(targetRelays, relayAddr)) {
          continue;
        }
        if (!queriedRelayIdentities.add(_relayIdentity(relay.url))) {
          continue;
        }

        queryFutures.add(sendQueryTo(relay));
      }
    }

    // cache relay
    if (relayTypes.contains(RelayType.cache)) {
      for (final relay in _cacheRelaysSnapshot()) {
        queryFutures.add(sendQueryTo(relay));
      }
    }

    final List<String?> fanout;
    try {
      // Wait for all sends to complete (and saveQuery to run) before allowing
      // terminal frames to decide whether every relay has settled.
      fanout = await Future.wait(queryFutures);
    } finally {
      if (completionRequested) {
        _queryFanoutInProgress.remove(subscription.id);
      }
    }
    final sentTo = fanout.nonNulls.toList();
    outcomeTracker?.recordFanoutFinished();

    if (completionRequested) {
      _fireQueryCompleteIfSettled(
        subscription.id,
        afterFanoutReachedNoRelay: sentTo.isEmpty,
      );
    }

    return (id: subscription.id, sentTo: sentTo);
  }

  /// Reports that the caller's own deadline ended one-shot query [id] before
  /// the pool completed it, and returns how the query stood at that moment.
  ///
  /// Call it when that deadline fires, just before [unsubscribe]. The
  /// outcome's `endedBy` is `QueryEnd.deadline`, or `QueryEnd.noRelay` when
  /// the fan-out had already finished without any relay taking the REQ; its
  /// `possiblyCapped` and `confirmedExhaustive` are judged on what had
  /// arrived. It emits the query's one [RelayDiagnosticSite.queryCompletion]
  /// line, at warning level, and marks the query reported, so the pool emits
  /// no second line for it, even if a relay completes it before [unsubscribe]
  /// runs.
  ///
  /// Returns null when the pool holds no record of [id]: it has completed or
  /// been unsubscribed, or it was started with neither `onComplete` nor
  /// `onOutcome`.
  QueryOutcome? reportQueryDeadline(String id) {
    final tracker = _queryOutcomes[id];
    if (tracker == null) return null;
    return _concludeQueryOutcome(id, tracker, atDeadline: true);
  }

  /// Judges how query [subId] ended and emits its completion line when due.
  QueryOutcome _concludeQueryOutcome(
    String subId,
    QueryOutcomeTracker tracker, {
    required bool atDeadline,
  }) {
    final concluded = tracker.conclude(
      atDeadline: atDeadline,
      pendingStateOf: (relay) => _pendingRelayState(relay, subId),
    );
    final diagnostic = concluded.diagnostic;
    if (diagnostic != null) emitRelayDiagnostic(diagnosticsSink, diagnostic);
    return concluded.outcome;
  }

  /// What [relay], which has sent no terminal frame for [subId], can still
  /// be expected to do about it, by the reasons [_canStillSettleQuery] gives
  /// for no longer waiting on a relay.
  PendingRelayState _pendingRelayState(Relay relay, String subId) {
    if (!relay.checkQuery(subId) ||
        relay.relayStatus.connected != ClientConnected.connected ||
        _silentRelayRepairsInFlight.contains(relay.url)) {
      return PendingRelayState.connectionLost;
    }
    // Past the connection checks, a shut NIP-42 gate is the one reason left
    // for [_canStillSettleQuery] to stop waiting on the relay.
    return _canStillSettleQuery(relay)
        ? PendingRelayState.serving
        : PendingRelayState.authGateShut;
  }

  /// Stands in for `onComplete` when a query asked only for its outcome.
  static void _ignoreQueryComplete() {}

  /// send message to relay
  /// there are tempRelays, it also send to tempRelays too.
  Future<bool> send(
    List<dynamic> message, {
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    final result = await _sendCollect(
      message,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
    );
    return result.sentTo.isNotEmpty;
  }

  /// Same as [send] but returns the list of relay URLs the message reached.
  ///
  /// An entry in the returned list means the relay's WebSocket accepted the
  /// frame (or it was queued for pending-auth delivery). It does NOT mean the
  /// relay accepted the event at the protocol level — use
  /// [sendEventAwaitOk] for that guarantee.
  ///
  /// Sends use `skipReconnect: true` so that a single disconnected relay
  /// cannot block the sequential fan-out by triggering a multi-minute
  /// exponential-backoff reconnect (mirrors the query fan-out paths above).
  /// Reconnection is driven by the relay manager's heartbeat, not by
  /// outbound publishes.
  ///
  /// Each individual `relay.send` is also wrapped in [perRelaySendTimeout]
  /// as a belt-and-suspenders backstop. `skipReconnect: true` already short-
  /// circuits the disconnected-state path inside `WebSocketConnectionManager`,
  /// but it does not bypass the `connecting`-state wait nor protect against
  /// a relay whose underlying socket is wedged after a successful handshake
  /// (TCP backpressure, slow peer). The per-relay timeout caps any single
  /// relay's contribution to the sequential fan-out, so the outer publish
  /// flow stays responsive even on degraded networks. Callers that wrap
  /// the publish call in their own outer guard should size that guard
  /// against `perRelaySendTimeout * configuredRelays.length` plus a small
  /// scheduling buffer.
  Future<({List<String> sentTo, Set<String> attemptedRelayUrls})> _sendCollect(
    List<dynamic> message, {
    List<String>? tempRelays,
    List<String>? targetRelays,
    DateTime? deadline,
  }) async {
    final sentTo = <String>[];
    final attemptedRelayUrls = <String>{};

    Duration sendTimeout() {
      final remaining = deadline?.difference(DateTime.now());
      if (remaining == null || remaining > perRelaySendTimeout) {
        return perRelaySendTimeout;
      }
      if (remaining.isNegative || remaining == Duration.zero) {
        return Duration.zero;
      }
      return remaining;
    }

    bool deadlineExpired() {
      return deadline != null && !DateTime.now().isBefore(deadline);
    }

    // Only tears down a temp relay once the publish deadline has passed —
    // before that the relay may still be carrying a concurrent publish or
    // query, since temp relays are keyed by URL and therefore shared. The
    // sockets this deliberately leaves behind are reclaimed by
    // [sweepIdleTempRelays] once they go quiet, which is safe precisely
    // because it judges idleness rather than guessing at ownership.
    void removeExpiredTempRelay(Relay relay) {
      if (!deadlineExpired()) return;
      unawaited(relay.disconnect());
      removeTempRelay(relay.url);
    }

    for (final relay in _relaysSnapshot()) {
      final timeout = sendTimeout();
      if (timeout == Duration.zero) break;

      if (message[0] == "EVENT") {
        if (!relay.relayStatus.writeAccess) {
          continue;
        }
      }

      if (targetRelays != null && targetRelays.isNotEmpty) {
        if (!_namesRelay(targetRelays, relay.url)) {
          // not contain this relay
          continue;
        }
      }

      // Ask the socket as well as the status mirror. The mirror is written from
      // the connection layer's state stream, so it can still read `disconnect`
      // while a handshake is in flight — and then the only thing left to notice
      // that this relay was attempted is `deadlineExpired()` after the write
      // gives up. That check loses a race it cannot win: the wait ends on a
      // `Timer`, whose duration the VM truncates to whole milliseconds, so it
      // can return up to a millisecond before the deadline it was measured
      // against and drop a relay the fan-out spent its whole budget on.
      final sendStartedWhileConnecting =
          relay.relayStatus.connected == ClientConnected.connecting ||
          relay.isSocketConnecting;
      try {
        // Check if relay requires authentication
        if (relay.relayStatus.alwaysAuth && !relay.relayStatus.authed) {
          log(
            '🔐 Relay ${relay.url} requires auth (alwaysAuth=${relay.relayStatus.alwaysAuth}, authed=${relay.relayStatus.authed})',
          );

          // Many relays only send AUTH challenges after a frame that needs
          // auth. Deadline-bound publishes cannot sit in the auth queue, so
          // send once inside the deadline and let the OK/AUTH handlers retry
          // the EVENT if the relay accepts after NIP-42 completes.
          if (deadline != null) {
            log(
              '🔐 Deadline-bound auth publish - sending to trigger AUTH challenge',
            );
            var timedOut = false;
            var result = await relay
                .send(message, queueIfFailed: false, deadline: deadline)
                .timeout(
                  timeout,
                  onTimeout: () {
                    timedOut = true;
                    log(
                      '⏱️ Per-relay auth-trigger send timeout for ${relay.url} '
                      '(connected=${relay.relayStatus.connected}, '
                      'authed=${relay.relayStatus.authed})',
                    );
                    return false;
                  },
                );
            if (result ||
                timedOut ||
                sendStartedWhileConnecting ||
                deadlineExpired()) {
              attemptedRelayUrls.add(relay.url);
            }
            if (result) {
              sentTo.add(relay.url);
            }
          } else {
            log('🔐 Queueing message for authentication: ${message[0]}');
            relay.pendingAuthedMessages.add(message);
            sentTo.add(relay.url);
            attemptedRelayUrls.add(relay.url);
          }
          log(
            '🔐 Pending authed messages count: ${relay.pendingAuthedMessages.length}',
          );
        } else {
          log(
            '🔐 Relay ${relay.url} sending immediately (alwaysAuth=${relay.relayStatus.alwaysAuth}, authed=${relay.relayStatus.authed})',
          );
          // Skip reconnect during fan-out to avoid blocking other relays
          // while one dead relay tries exponential backoff (can hang the
          // publish for many minutes). Same convention as relayDoQuery /
          // relayDoSubscribe above.
          var timedOut = false;
          var result = await relay
              .send(
                message,
                skipReconnect: true,
                queueIfFailed: deadline == null,
                deadline: deadline,
              )
              .timeout(
                timeout,
                onTimeout: () {
                  timedOut = true;
                  log(
                    '⏱️ Per-relay send timeout for ${relay.url} '
                    '(connected=${relay.relayStatus.connected}, '
                    'authed=${relay.relayStatus.authed})',
                  );
                  return false;
                },
              );
          if (result) {
            _retainForAuthRetry(relay, message, deadline);
          }
          if (result ||
              timedOut ||
              sendStartedWhileConnecting ||
              deadlineExpired()) {
            attemptedRelayUrls.add(relay.url);
          }
          if (result) {
            sentTo.add(relay.url);
          }
        }
      } catch (err) {
        if (sendStartedWhileConnecting) {
          attemptedRelayUrls.add(relay.url);
        }
        log(err.toString());
        relay.relayStatus.onError();
      }
    }

    if (tempRelays != null) {
      for (var tempRelayAddr in tempRelays) {
        if (attemptedRelayUrls.any(
          (url) => _relayIdentity(url) == _relayIdentity(tempRelayAddr),
        )) {
          continue;
        }
        attemptedRelayUrls.add(tempRelayAddr);
        final timeout = sendTimeout();
        if (timeout == Duration.zero) break;

        var tempRelay = checkAndGenTempRelay(tempRelayAddr);
        // Same skipReconnect rationale as the main loop above: a fresh
        // tempRelay whose initial connection is still in-flight must not
        // block the publish.

        // A known-auth relay that has not authed yet would answer this frame
        // with `auth-required`, and a fire-and-forget publish has no tracker to
        // notice. Park it behind the handshake instead, exactly as the main
        // loop above does; `_onEvent` flushes the queue once AUTH lands.
        if (tempRelay.relayStatus.alwaysAuth &&
            !tempRelay.relayStatus.authed &&
            deadline == null) {
          tempRelay.pendingAuthedMessages.add(message);
          sentTo.add(tempRelay.url);
          continue;
        }

        var result = await tempRelay
            .send(
              message,
              skipReconnect: true,
              queueIfFailed: false,
              deadline: deadline,
            )
            .timeout(
              timeout,
              onTimeout: () {
                log(
                  '⏱️ Per-relay send timeout for tempRelay ${tempRelay.url} '
                  '(connected=${tempRelay.relayStatus.connected})',
                );
                removeExpiredTempRelay(tempRelay);
                return false;
              },
            );
        if (!result) {
          removeExpiredTempRelay(tempRelay);
        }
        if (result) {
          _retainForAuthRetry(tempRelay, message, deadline);
          sentTo.add(tempRelay.url);
        }
      }
    }

    return (sentTo: sentTo, attemptedRelayUrls: attemptedRelayUrls);
  }

  /// Record how broadly a publish was accepted.
  ///
  /// Counts only — never relay URLs or event ids, so the line is safe to keep
  /// on in any build and carries nothing that identifies a user. Until this
  /// existed there was no signal at all about how often a publish is accepted
  /// by some relays and refused by others.
  void _recordPublishBreadth(PublishOutcome outcome) {
    if (outcome.acceptedByAll) return;
    log(
      '📡 Publish accepted by ${outcome.acceptedBy.length}/'
      '${outcome.targetCount} relays '
      '(rejected=${outcome.rejectedBy.length} '
      'silent=${outcome.noResponseFrom.length} '
      'unreachable=${outcome.unreachableTargets.length})',
    );
  }

  /// Every relay a publish with these parameters intends to reach, split into
  /// who may answer it and who counts towards its denominator.
  ///
  /// Mirrors the iteration [_sendCollect] performs, but resolves it *before*
  /// the fan-out starts so the set is complete even for relays the fan-out
  /// later fails to write to. Deriving the target set from send results
  /// instead would silently shrink the denominator: a relay that could not be
  /// written to would be absent from the outcome entirely, and a publish could
  /// settle while later relays had not been attempted yet.
  ///
  /// `expected` is every write-enabled relay the fan-out may write to, and is
  /// what [PublishTracker.isTarget] admits. It deliberately ignores connection
  /// state: `relayStatus.connected` lags the socket it describes — it starts
  /// at [ClientConnected.disconnect] and only advances when the state stream
  /// delivers, and a relay retrying a dead host is [ClientConnected.connecting]
  /// exactly like one whose first handshake is still in flight. Gating who may
  /// answer on it would discard a real `OK true` from a healthy relay that
  /// replied before the fan-out reported, since `send` waits out the
  /// `connecting` state and writes anyway.
  ///
  /// `counted` starts as the relays a failed write should be reported against,
  /// dropping configured relays that were plainly offline before the fan-out.
  /// The fan-out then adds back relays it actually attempted, including ones
  /// whose in-flight connection waited until the publish deadline. `writeAccess`
  /// is a config flag that defaults to true, so counting on it alone made every
  /// offline relay a target that could only ever land in
  /// [PublishOutcome.unreachableTargets] — which on mobile, where some relay
  /// is nearly always down, left [PublishOutcome.acceptedByAll] permanently
  /// false and reported every successful publish as partial. Nothing the
  /// fan-out actually reached or exhausted drops out: [PublishTracker.setReachable]
  /// receives both the written relays and the attempted denominator.
  ///
  /// [targetRelays] and [tempRelays] are exempt from the narrowing. Naming a
  /// relay is the caller asserting intent for that specific relay, and "we
  /// never reached the one you asked for" is the answer it wants — the
  /// kind:10002 bootstrap publish names its indexers precisely so it can tell
  /// an unreached indexer from a refusing one.
  ({Set<String> expected, Set<String> counted}) _intendedPublishTargets(
    List<dynamic> message, {
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) {
    final expected = <String>{};
    final counted = <String>{};
    final isEvent = message.isNotEmpty && message[0] == "EVENT";
    final hasFilter = targetRelays != null && targetRelays.isNotEmpty;
    for (final relay in _relaysSnapshot()) {
      if (isEvent && !relay.relayStatus.writeAccess) continue;
      if (hasFilter && !_namesRelay(targetRelays, relay.url)) continue;
      expected.add(relay.url);
      if (isEvent &&
          !hasFilter &&
          relay.relayStatus.connected != ClientConnected.connected) {
        continue;
      }
      counted.add(relay.url);
    }
    if (tempRelays != null) {
      expected.addAll(tempRelays);
      counted.addAll(tempRelays);
    }
    return (expected: expected, counted: counted);
  }

  /// Send an `EVENT` message and wait for `OK` confirmations from relays.
  ///
  /// Registers a [PublishTracker] keyed on the event id. The returned future
  /// completes when either:
  ///  * every relay the fan-out reached has responded (accept or reject), OR
  ///  * [PublishTracker.settleWindow] elapses after the first response, OR
  ///  * [timeout] elapses.
  ///
  /// It does **not** complete on the first acceptance. A publish that one
  /// relay accepts and another rejects must report both, and nothing in this
  /// client republishes to the relays that did not accept.
  ///
  /// Relays that were targeted but could not be written to are reported in
  /// [PublishOutcome.unreachableTargets]. Callers should inspect
  /// [PublishOutcome.acceptedByAll] or [PublishOutcome.acceptedByAny]
  /// depending on the breadth of acceptance they require — note that relay
  /// acceptance is not a durability guarantee.
  Future<PublishOutcome> sendEventAwaitOk(
    List<dynamic> message, {
    required String eventId,
    List<String>? tempRelays,
    List<String>? targetRelays,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    // Register tracker BEFORE sending so a fast relay can't respond with OK
    // before we start listening.
    final existing = _pendingPublishes[eventId];
    if (existing != null) {
      return existing.future;
    }
    final sentAt = DateTime.now();
    final deadline = sentAt.add(timeout);
    final targets = _intendedPublishTargets(
      message,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
    );
    final tracker = PublishTracker(
      eventId: eventId,
      message: message,
      deadline: deadline,
      expectedRelays: targets.expected,
      countedTargets: targets.counted,
      timeout: timeout,
    );
    _pendingPublishes[eventId] = tracker;

    // Narrow the awaited set to the relays the fan-out actually wrote to. The
    // rest become unreachable targets rather than blocking the publish until
    // the timeout. When nothing was written this settles the tracker at once.
    //
    // Reported in a `finally` because the tracker defers its hard timeout
    // until this call arrives: a fan-out that threw would otherwise leave the
    // publish hanging.
    var sentTo = const <String>[];
    var countedTargets = targets.counted;
    try {
      final result = await _sendCollect(
        message,
        tempRelays: tempRelays,
        targetRelays: targetRelays,
        deadline: deadline,
      );
      sentTo = result.sentTo;
      countedTargets = {...targets.counted, ...result.attemptedRelayUrls};
    } finally {
      tracker.setReachable(sentTo, countedTargets: countedTargets);
    }

    unawaited(
      tracker.future
          .then((outcome) {
            _recordPublishBreadth(outcome);
            // Repair every relay that stayed silent, whether or not a sibling
            // accepted. `noResponseFrom` now means "reached this relay and it
            // never answered", not "lost the OK race", so a confirmed publish
            // can still be hiding a zombie socket. The existing filters keep
            // this from churning healthy connections: `isSilentSince` requires
            // no inbound frame of ANY kind since the publish (so a relay
            // serving subscriptions is excluded), `silentRepairCooldown`
            // rate-limits per relay, and `_silentRelayRepairsInFlight`
            // collapses concurrent repairs of the same URL.
            if (outcome.noResponseFrom.isNotEmpty) {
              _repairSilentRelays(outcome.noResponseFrom, sentAt);
            }
          })
          .whenComplete(() {
            _pendingPublishes.remove(eventId);
            _authRequiredPublishRetries.remove(eventId);
          }),
    );
    return tracker.future;
  }

  /// Relays with an OK-timeout repair cycle already in flight, so concurrent
  /// publish timeouts don't stack reconnects on the same connection.
  final Set<String> _silentRelayRepairsInFlight = {};

  /// When each relay was last silent-repaired, enforcing [silentRepairCooldown]
  /// so a brownout relay isn't force-cycled on every timed-out publish.
  final Map<String, DateTime> _lastSilentRepairAt = {};

  /// Repair pass for frames that were written and answered with silence.
  ///
  /// A relay lands in [PublishOutcome.noResponseFrom] when its WebSocket sink
  /// accepted the EVENT frame but no OK of either polarity came back within
  /// the confirm window; the query and subscription paths feed the same check
  /// with the relays still holding an abandoned REQ. When the same connection
  /// ALSO received no inbound frame of any kind since that frame was written,
  /// the socket is a half-open zombie (typically left behind by a connectivity
  /// flap). Nothing else repairs it: publish and REQ sends pass
  /// `skipReconnect`, the idle heartbeat needs 90s+ of silence, and a zombie
  /// still reports `connected` to every health gate — so every retry inside
  /// that window would deterministically time out again. Force-cycle the
  /// connection so the next attempt runs on a live socket; the reconnect
  /// re-issues the relay's saved REQs (see [Relay.onConnected]).
  void _repairSilentRelays(List<String> silentRelayUrls, DateTime sentAt) {
    if (_closed) return;
    final now = DateTime.now();
    for (final url in silentRelayUrls) {
      final relay = _relays[url] ?? _cacheRelays[url] ?? _tempRelays[url];
      if (relay is! RelayBase) continue;
      if (!relay.isSilentSince(sentAt)) continue;
      final lastRepair = _lastSilentRepairAt[url];
      if (lastRepair != null &&
          now.difference(lastRepair) < silentRepairCooldown) {
        continue;
      }
      if (!_silentRelayRepairsInFlight.add(url)) continue;
      _lastSilentRepairAt[url] = now;
      log(
        '📡 $url accepted a frame but sent nothing back for the whole window '
        'the caller waited; reconnecting the stale connection',
      );
      _diagnose(
        RelayDiagnosticSite.connectionLifecycle,
        RelayDiagnosticLevel.warning,
        url,
        'Relay sent no response during the settlement window; reconnecting',
      );
      unawaited(
        _reconnectSilentRelay(
          relay,
        ).whenComplete(() => _silentRelayRepairsInFlight.remove(url)),
      );
    }
  }

  /// Force-cycles [relay]'s socket. [Relay.onConnected] re-issues the saved
  /// subscriptions and pending one-shot queries on the fresh connection, so an
  /// in-flight REQ that the closed socket swallowed still runs.
  ///
  /// The closed-check is belt and braces, not a second line of defence that
  /// can be reached on its own: [_repairSilentRelays] is the only caller and
  /// it checks the same flag with no suspension point in between. It is kept
  /// so a future second caller inherits the refusal rather than having to
  /// remember it.
  Future<void> _reconnectSilentRelay(RelayBase relay) async {
    if (_closed) return;
    try {
      await relay.forceReconnect();
      log('Silent-relay reconnect completed for ${relay.url}');
      _diagnose(
        RelayDiagnosticSite.connectionLifecycle,
        RelayDiagnosticLevel.info,
        relay.url,
        'Silent-relay reconnect completed',
      );
    } catch (e, stackTrace) {
      _diagnose(
        RelayDiagnosticSite.connectionLifecycle,
        RelayDiagnosticLevel.warning,
        relay.url,
        'Silent-relay reconnect failed',
        error: e,
        stackTrace: stackTrace,
      );
      log('silent-relay reconnect failed for ${relay.url}: $e');
    }
  }

  void reconnect() {
    if (_closed) return;
    for (final relay in _relaysSnapshot()) {
      relay.connect();
    }
  }

  Relay checkAndGenTempRelay(String addr) {
    var tempRelay = _tempRelays[addr];
    if (tempRelay != null && _shouldReplaceTempRelay(tempRelay)) {
      _tempRelays.remove(addr);
      unawaited(tempRelay.disconnect());
      tempRelay.dispose();
      // The replacement is a different socket, so nothing the pool concluded
      // about the old one carries over.
      _forgetRelayBookkeeping(addr);
      tempRelay = null;
    }
    if (tempRelay == null) {
      tempRelay = tempRelayGener(addr);
      tempRelay.onMessage = _onEvent;
      // Temp relays serve one-shot queries like any other relay, so they need
      // the same drop-releases-the-query sweep [add] wires up.
      _observeRelayStatus(tempRelay);
      if (!_closed) tempRelay.connect();
      _tempRelays[addr] = tempRelay;
      _ensureTempRelaySweepScheduled();
    }

    return tempRelay;
  }

  /// Whether the idle-temp-relay sweep is armed. Tests assert on this to
  /// prove teardown leaves no `Timer.periodic` behind, which is the shape
  /// that strands into an unrelated later suite under a merged isolate.
  @visibleForTesting
  bool get hasTempRelaySweepScheduled => _tempRelaySweepTimer != null;

  void _ensureTempRelaySweepScheduled() {
    if (_closed) return;
    if (_tempRelaySweepTimer != null) return;
    _tempRelaySweepTimer = Timer.periodic(
      tempRelaySweepInterval,
      (_) => sweepIdleTempRelays(),
    );
  }

  /// Closes temp relays that have gone quiet and are not serving anything.
  ///
  /// A temp relay exists to carry one publish or one targeted query. Once that
  /// is done the socket is pure liability: it holds a connection open to an
  /// address the caller may not control, and it keeps the pool paying for a
  /// peer nothing is waiting on. This is the teardown NIP-17 asks for on the
  /// DM path, applied uniformly so every `tempRelays` caller inherits it.
  ///
  /// A relay is closed only when it is **both** silent for
  /// [tempRelayIdleTimeout] **and** holds no live subscription or unanswered
  /// query. Temp relays are keyed by URL and therefore shared — a second
  /// publish, or a query naming the same address, reuses the same entry — so
  /// closing on "this publish finished" would cut a socket out from under a
  /// concurrent caller. Idleness is the only condition that is safe to judge
  /// without tracking ownership.
  @visibleForTesting
  void sweepIdleTempRelays() {
    final idleSince = DateTime.now().subtract(tempRelayIdleTimeout);
    for (final entry in _tempRelayEntriesSnapshot()) {
      if (!_isTempRelayReapable(entry.value, idleSince)) continue;
      log('Closing idle temp relay ${entry.key}');
      removeTempRelay(entry.key);
    }
  }

  bool _isTempRelayReapable(Relay relay, DateTime idleSince) {
    // Still carrying work for somebody — never reap.
    if (relay.hasSubscription() || relay.getQueries().isNotEmpty) return false;

    // Queued frames are work too. A disconnected relay replays these the
    // moment it reconnects (`Relay.onConnected`), and `pendingAuthedMessages`
    // is specifically a publish parked behind a NIP-42 handshake. Reaping
    // disconnects and disposes, which clears `_shouldReconnect` — so without
    // this the sweep would cancel the very reconnect the caller is waiting on
    // and the publish would be reported unanswered instead of being resent.
    if (relay.pendingMessages.isNotEmpty ||
        relay.pendingAuthedMessages.isNotEmpty) {
      return false;
    }

    // A relay that failed to connect, or has since dropped, is doing nothing
    // for anyone. [RelayBase.isSilentSince] deliberately answers false for a
    // socket that is not connected — it exists to spot *live* zombie sockets —
    // so the disconnected case has to be caught separately or those entries
    // would accumulate forever, which is the half of the leak that a failed
    // send used to produce.
    //
    // Give it one idle window first. `connect()` is async, so an entry is in
    // the map before its socket opens; `RelayStatus.connectTime` is stamped
    // when the status is built and never reset, which for a temp relay is its
    // creation time. Without this the branch depends on every `Relay`
    // implementation advancing to `connecting` before the first sweep can
    // observe it — true for the ones here, but by scheduler accident rather
    // than by contract, and not true of a manually driven sweep.
    if (relay.relayStatus.connected == ClientConnected.disconnect) {
      return relay.relayStatus.connectTime.isBefore(idleSince);
    }

    // Connected: reap only once genuinely quiet. The connection stamps its
    // activity clock on connect, so a freshly opened socket is never silent.
    return relay is RelayBase && relay.isSilentSince(idleSince);
  }

  bool _shouldReplaceTempRelay(Relay relay) {
    if (relay.relayStatus.connected == ClientConnected.disconnect) {
      return true;
    }
    return relay.relayStatus.connected == ClientConnected.connected &&
        relay is RelayBase &&
        !relay.checkHealth();
  }

  List<String> getExtralReadableRelays(
    List<String> extralRelays,
    int maxRelayNum,
  ) {
    List<String> list = [];

    int sameNum = 0;
    for (var extralRelay in extralRelays) {
      extralRelay = RelayAddrUtil.handle(extralRelay);

      var relay = _relays[extralRelay];
      if (relay == null || !relay.relayStatus.readAccess) {
        // not contains or can't readable
        list.add(extralRelay);
      } else {
        sameNum++;
      }
    }

    var needExtralNum = maxRelayNum - sameNum;
    if (needExtralNum <= 0) {
      return [];
    }

    if (list.length < needExtralNum) {
      return list;
    }

    return list.sublist(0, needExtralNum);
  }

  void removeTempRelay(String addr) {
    var relay = _tempRelays.remove(addr);
    if (relay != null) {
      relay.disconnect();
      relay.dispose();
    }
    _forgetRelayBookkeeping(addr);
    // Pairs with the arm in [checkAndGenTempRelay]: the sweep exists only to
    // serve entries in [_tempRelays], so it stops with the last one rather
    // than waiting for a tick to notice the map is empty.
    if (_tempRelays.isEmpty) {
      _tempRelaySweepTimer?.cancel();
      _tempRelaySweepTimer = null;
    }
  }

  Relay? getTempRelay(String url) {
    return _tempRelays[url];
  }

  /// Addresses currently holding a temp-relay connection.
  ///
  /// Keys are normalised by [RelayAddrUtil.handle], so tests assert on this
  /// rather than on the raw URL they passed in — a raw-URL lookup misses and
  /// would make an "it was cleaned up" assertion pass vacuously.
  @visibleForTesting
  List<String> get tempRelayUrls => _tempRelays.keys.toList(growable: false);

  bool readable() {
    for (final relay in _relaysSnapshot()) {
      if (relay.relayStatus.connected == ClientConnected.connected &&
          relay.relayStatus.readAccess) {
        return true;
      }
    }

    return false;
  }

  /// Configure a relay to always require authentication
  void setRelayAlwaysAuth(String relayUrl, bool alwaysAuth) {
    var relay = _relays[relayUrl];
    if (relay != null) {
      relay.relayStatus.alwaysAuth = alwaysAuth;
    }
  }

  /// Configure multiple relays with authentication requirements
  void configureRelayAuth(Map<String, bool> relayAuthConfig) {
    relayAuthConfig.forEach((url, alwaysAuth) {
      setRelayAlwaysAuth(url, alwaysAuth);
    });
  }

  /// Get current authentication configuration for all relays
  Map<String, bool> getRelayAuthConfig() {
    Map<String, bool> config = {};
    for (final entry in _relayEntriesSnapshot()) {
      final url = entry.key;
      final relay = entry.value;
      config[url] = relay.relayStatus.alwaysAuth;
    }
    return config;
  }

  bool writable() {
    for (final relay in _relaysSnapshot()) {
      if (relay.relayStatus.connected == ClientConnected.connected &&
          relay.relayStatus.writeAccess) {
        return true;
      }
    }

    return false;
  }

  /// Convenience method for searching events using NIP-50.
  ///
  /// Performs a full-text search across event content on NIP-50 compatible relays.
  ///
  /// Parameters:
  /// - [query]: The search query string
  /// - [kinds]: Optional list of event kinds to filter
  /// - [authors]: Optional list of author public keys
  /// - [since]: Optional start time for the search range
  /// - [until]: Optional end time for the search range
  /// - [limit]: Maximum number of results to return (default: 100)
  /// - [timeout]: How long to wait for results (default: 5 seconds)
  /// - [relayUrls]: Optional specific relays to query (uses all connected relays if not specified)
  ///
  /// Returns a list of [Event] objects matching the search criteria.
  /// Results are automatically deduplicated by event ID.
  Future<List<Event>> searchEvents(
    String query, {
    List<int>? kinds,
    List<String>? authors,
    DateTime? since,
    DateTime? until,
    int? limit,
    Duration? timeout,
    List<String>? relayUrls,
  }) async {
    // Create filter with search parameter
    final filter = Filter(
      search: query,
      kinds: kinds,
      authors: authors,
      since: since != null ? since.millisecondsSinceEpoch ~/ 1000 : null,
      until: until != null ? until.millisecondsSinceEpoch ~/ 1000 : null,
      limit: limit ?? 100,
    );

    // Collect events
    final eventMap = <String, Event>{};

    // Set up timeout and EOSE-based early completion
    final timeoutDuration = timeout ?? const Duration(seconds: 5);
    final completer = Completer<List<Event>>();
    String? subscriptionId;
    Timer? timeoutTimer;

    void completeSearch() {
      if (completer.isCompleted) return;
      timeoutTimer?.cancel();
      if (subscriptionId != null) {
        unsubscribe(subscriptionId);
      }
      completer.complete(eventMap.values.toList());
    }

    // Subscribe with EOSE callback for early completion
    subscriptionId = subscribe(
      [filter.toJson()],
      (event) {
        // Deduplicate by event ID
        eventMap[event.id] = event;
      },
      targetRelays: relayUrls,
      onEose: completeSearch,
    );

    // Timeout fallback in case not all relays send EOSE
    if (!completer.isCompleted) {
      timeoutTimer = Timer(timeoutDuration, completeSearch);
    }

    return completer.future;
  }

  /// Sends a COUNT query (NIP-45) to relays and returns the largest count.
  ///
  /// Unlike [query], this returns a count rather than events.
  ///
  /// [timeout] bounds the whole request, the send included, so a relay that
  /// is still connecting cannot hold it past the deadline. A COUNT that could
  /// not be written is dropped, not queued: replayed on the next connection,
  /// its answer would reach nobody.
  ///
  /// Throws [CountNotSentException] when no relay accepted the COUNT, and
  /// [CountNotSupportedException] when relays accepted it but none answered
  /// in time, whether by timing out or refusing with CLOSED.
  ///
  /// Parameters:
  /// - [filters]: The filters to count events for (same format as REQ)
  /// - [id]: Optional subscription ID
  /// - [tempRelays]: Optional list of temporary relays to query
  /// - [relayTypes]: Types of relays to query (default: all)
  /// - [timeout]: How long the whole request may take (default: 5 seconds)
  Future<CountResponse> count(
    List<Map<String, dynamic>> filters, {
    String? id,
    List<String>? tempRelays,
    List<int> relayTypes = RelayType.all,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (filters.isEmpty) {
      throw ArgumentError('No filters given', 'filters');
    }

    final deadline = DateTime.now().add(timeout);
    Duration remaining() {
      final left = deadline.difference(DateTime.now());
      return left.isNegative ? Duration.zero : left;
    }

    tempRelays = handleAddrList(tempRelays);

    final subscriptionId = id ?? StringUtil.rndSecureNameStr(16);

    // Collect all relays to try
    final relaysToTry = <Relay>[];

    // Add temp relays first
    if (tempRelays != null &&
        tempRelays.isNotEmpty &&
        relayTypes.contains(RelayType.temp)) {
      for (var tempRelayAddr in tempRelays) {
        Relay? relay = _pooledRelayForTempAddr(tempRelayAddr);
        relay ??= checkAndGenTempRelay(tempRelayAddr);
        relaysToTry.add(relay);
      }
    }

    // Add normal relays
    if (relayTypes.contains(RelayType.normal)) {
      for (final relay in _relaysSnapshot()) {
        if (!relaysToTry.contains(relay)) {
          relaysToTry.add(relay);
        }
      }
    }

    // Add cache relays
    if (relayTypes.contains(RelayType.cache)) {
      for (final relay in _cacheRelaysSnapshot()) {
        if (!relaysToTry.contains(relay)) {
          relaysToTry.add(relay);
        }
      }
    }

    // Send COUNT to all relays in parallel, return the largest count.
    // Different relays may have different subsets of data, so the highest
    // count is the most accurate.
    final eligibleRelays = relaysToTry
        .where((r) => r.relayStatus.readAccess)
        .toList();

    if (eligibleRelays.isEmpty) {
      throw CountNotSentException('No relay can take COUNT');
    }

    var acceptedByAny = false;
    final futures = <Future<CountResponse?>>[];
    for (var i = 0; i < eligibleRelays.length; i++) {
      final relay = eligibleRelays[i];
      // Use index as suffix to avoid hashCode collisions between URLs
      final relaySubId = '${subscriptionId}_$i';
      final relayMessage = ['COUNT', relaySubId, ...filters];

      futures.add(() async {
        // What is left of the budget once the send is done, so the timeout
        // diagnostic reports the wait the relay actually had rather than the
        // whole request budget.
        var answerBudget = timeout;
        try {
          final sent = await relay.send(
            relayMessage,
            queueIfFailed: false,
            skipReconnect: true,
            deadline: deadline,
          );
          if (!sent) {
            log('📊 COUNT not sent to ${relay.url}');
            _diagnose(
              RelayDiagnosticSite.queryDispatch,
              RelayDiagnosticLevel.info,
              relay.url,
              'COUNT $relaySubId not sent',
            );
            return null;
          }
          acceptedByAny = true;

          // Only register after successful send to avoid orphaned completers
          final responseFuture = relay.registerCountQuery(relaySubId);
          log('📊 COUNT request sent to ${relay.url}');
          answerBudget = remaining();
          return await responseFuture.timeout(answerBudget);
        } on TimeoutException {
          log('📊 COUNT timed out on ${relay.url}');
          relay.failCountQuery(relaySubId, 'Timeout');
          _diagnose(
            RelayDiagnosticSite.requestSettlement,
            RelayDiagnosticLevel.warning,
            relay.url,
            'Relay did not answer COUNT $relaySubId within '
            '${answerBudget.inMilliseconds} ms',
          );
          return null;
        } on CountNotSupportedException catch (e) {
          // A CLOSED refusal, which the CLOSED handler has already reported.
          log('📊 COUNT refused by ${relay.url}: $e');
          return null;
        } catch (e) {
          log('📊 COUNT failed on ${relay.url}: $e');
          // Clean up if the completer is still pending
          if (relay.hasCountQuery(relaySubId)) {
            relay.failCountQuery(relaySubId, e.toString());
          }
          _diagnose(
            RelayDiagnosticSite.requestSettlement,
            RelayDiagnosticLevel.warning,
            relay.url,
            'COUNT $relaySubId failed (${e.runtimeType})',
          );
          return null;
        }
      }());
    }

    final responses = await Future.wait(futures);
    final best = responses.whereType<CountResponse>().fold<CountResponse?>(
      null,
      (a, b) => a == null || b.count > a.count ? b : a,
    );

    if (best == null) {
      if (!acceptedByAny) {
        throw CountNotSentException('No relay accepted COUNT');
      }
      throw CountNotSupportedException('No relay responded to COUNT');
    }

    return best;
  }

  /// Returns the set of relay URLs that have the given subscription active.
  ///
  /// This is used to determine when all relays have sent EOSE for a subscription.
  /// Only counts relays that actually received the subscription, not relays with
  /// unrelated subscriptions.
  Set<String> _getRelaysWithSubscription(String subscriptionId) {
    final relays = <String>{};

    // Check normal relays
    for (final entry in _relayEntriesSnapshot()) {
      if (entry.value.hasSubscriptionById(subscriptionId)) {
        relays.add(entry.key);
      }
    }

    // Check temp relays
    for (final entry in _tempRelayEntriesSnapshot()) {
      if (entry.value.hasSubscriptionById(subscriptionId)) {
        relays.add(entry.key);
      }
    }

    // Check cache relays
    for (final entry in _cacheRelayEntriesSnapshot()) {
      if (entry.value.hasSubscriptionById(subscriptionId)) {
        relays.add(entry.key);
      }
    }

    return relays;
  }

  bool _shouldVerifySignature(Relay relay) {
    switch (signatureVerificationPolicy) {
      case SignatureVerificationPolicy.all:
        return true;
      case SignatureVerificationPolicy.untrustedRelays:
        return !_relays.containsKey(relay.url);
      case SignatureVerificationPolicy.nonDivineRelays:
        return !_isDivineRelayHost(relay.url);
    }
  }

  bool _isDivineRelayHost(String relayUrl) {
    final uri = Uri.tryParse(relayUrl);
    final host = uri?.host.toLowerCase();
    if (host == null || host.isEmpty) return false;
    return host == 'divine.video' || host.endsWith('.divine.video');
  }
}
