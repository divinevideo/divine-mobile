// ABOUTME: Abstract relay class defining the Nostr relay interface.
// ABOUTME: Manages subscriptions, queries, COUNT queries, and pending messages.

import 'dart:async';
import 'dart:developer';

import 'package:meta/meta.dart';

import '../count_response.dart';
import '../subscription.dart';
import 'client_connected.dart';
import 'relay_diagnostics.dart';
import 'relay_info.dart';
import 'relay_info_util.dart';
import 'relay_status.dart';

/// An awaited publish a relay holds until it answers: the EVENT frame as it
/// was sent, and the publish's deadline. See [Relay.savePublish].
typedef SavedPublish = ({List<dynamic> message, DateTime deadline});

/// Publishes a relay holds, by event id; see [Relay.takeSavedPublishes].
typedef SavedPublishes = Map<String, SavedPublish>;

enum WriteAccess { readOnly, writeOnly, readWrite, nothing }

abstract class Relay {
  final String url;

  RelayStatus relayStatus;

  RelayInfo? info;

  // to hold the message when the ws haven't connected and should be send after connected.
  List<List<dynamic>> pendingMessages = [];

  // to hold the message when the ws haven't authed and should be send after auth.
  List<List<dynamic>> pendingAuthedMessages = [];

  /// Cap on [_sentFramesForAuthRetry]. Sized for the burst a single user action
  /// can fan out (a gift-wrapped DM writes one frame per recipient relay), not
  /// for a backlog: anything still held past that is a relay that never
  /// answered, and replaying it is no longer useful.
  static const int _maxSentFramesForAuthRetry = 32;

  /// Written EVENT frames held for a possible post-NIP-42 replay, keyed by
  /// event id. Insertion-ordered, so eviction drops the oldest first.
  final Map<String, List<dynamic>> _sentFramesForAuthRetry = {};

  Function(Relay, List<dynamic>)? onMessage;

  /// Reports an unanswered publish discarded because the relay is read-only.
  void Function(String eventId)? onPublishReplayDisabled;

  // subscriptions
  final Map<String, Subscription> _subscriptions = {};

  // queries
  final Map<String, Subscription> _queries = {};

  // NIP-45 COUNT queries
  final Map<String, Completer<CountResponse>> _countQueries = {};

  /// The `COUNT` frame each entry of [_countQueries] was sent as, when its
  /// sender gave one, so a replacement relay object can send it again.
  final Map<String, List<dynamic>> _countRequests = {};

  // Observed COUNT support on the current socket.
  bool? _supportsCount;

  Relay(this.url, this.relayStatus, {this.diagnosticsSink});

  final RelayDiagnosticsSink? diagnosticsSink;

  void diagnose(
    RelayDiagnosticSite site,
    RelayDiagnosticLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => emitRelayDiagnostic(
    diagnosticsSink,
    RelayDiagnostic(
      site: site,
      level: level,
      relayUrl: url,
      message: message,
      error: error,
      stackTrace: stackTrace,
    ),
  );

  /// The method to call connect function by framework.
  ///
  /// Supplying [onReplayFailure] waits for saved REQs to be replayed and
  /// reports the ID of each request that could not be sent.
  Future<bool> connect({void Function(String id)? onReplayFailure}) async {
    try {
      relayStatus.authed = false;
      var result = await doConnect();
      if (result) {
        if (connectionIsFresh) markSocketOpened();
        try {
          final replay = onConnected(
            source: 'connect()',
            onReplayFailure: onReplayFailure,
          );
          if (onReplayFailure == null) {
            unawaited(replay);
          } else {
            await replay;
          }
        } catch (e) {
          log("onConnected exception.");
          log('$e');
        }
      }
      return result;
    } catch (e) {
      log("connect fail");
      disconnect();
      return false;
    }
  }

  /// The method implement by different relays to do some real when it connecting.
  Future<bool> doConnect();

  /// Whether the socket this [onConnected] runs on is a new one.
  ///
  /// [connect] short-circuits when the connection is already live, so it can
  /// reach [onConnected] without anything having been cycled. Such a socket
  /// still holds every REQ it was sent, and re-issuing them would only make
  /// the relay replay its stored window again.
  bool get connectionIsFresh => true;

  /// Whether this relay's socket is mid-handshake right now.
  ///
  /// [relayStatus] mirrors the connection layer through a stream, so it trails
  /// the socket it describes. A caller deciding whether a failed write was
  /// nonetheless *attempted* must ask the socket, not the mirror: a publish
  /// that waits out an in-flight handshake and gives up reads as "never tried"
  /// from a mirror that has not caught up yet. Implementations that own a
  /// connection override this; the default falls back to the mirror.
  bool get isSocketConnecting =>
      relayStatus.connected == ClientConnected.connecting;

  /// Identifies the socket this relay is currently on.
  ///
  /// A new socket starts every subscription over: the relay replays its
  /// stored events for each saved REQ. Callers compare generations to tell
  /// an answer given on the current socket from one given on an earlier one.
  /// Unique across relay objects, because a reconnect can replace the object
  /// for a URL rather than reopen it (`RelayManager` does on app resume).
  int get connectionGeneration => _connectionGeneration;
  int _connectionGeneration = 0;
  static int _lastConnectionGeneration = 0;

  /// The medhod called after relay connect success.
  ///
  /// Flushes whatever was queued while the socket was down, then — when the
  /// connection is actually new — sends again every publish still waiting for
  /// its `OK`, and re-issues every saved subscription and pending one-shot
  /// query. The re-issue is what makes a reconnect
  /// recoverable: a REQ written to a socket that later died is gone, and the
  /// relay keeps no record of it, so without this a live subscription goes
  /// permanently silent after any reconnect and its caller can only fall back
  /// to a timeout. Mirrors the post-AUTH replay and the zombie reconnect in
  /// `RelayPool`.
  Future<void> onConnected({
    String? source,
    void Function(String id)? onReplayFailure,
  }) async {
    final isFresh = connectionIsFresh;
    if (isFresh) {
      _connectionGeneration = ++_lastConnectionGeneration;
      _supportsCount = null;
    }
    final saved = isFresh
        ? [..._subscriptions.values, ..._queries.values]
        : const <Subscription>[];
    await _flushPendingMessages(source, {
      for (final s in saved) s.id,
    }, dropQueuedCloses: isFresh);
    if (isFresh) await _resendSavedPublishes(source);
    await _reissueSavedRequests(source, saved, onReplayFailure);
  }

  /// Sends every publish this relay is still holding (see [savePublish]) on
  /// the fresh socket.
  ///
  /// The `OK` for an EVENT written to the previous socket can only arrive on
  /// that socket, so without this an awaited publish waits out its deadline
  /// after any reconnect even when the relay stored the event (#11446). The
  /// same signed event is sent: its id does not change, and a relay that
  /// already holds it answers `OK true` without keeping a second copy. A
  /// publish written to this socket while it was opening is left alone, and
  /// one whose deadline has passed is dropped.
  Future<void> _resendSavedPublishes(String? source) async {
    final now = DateTime.now();
    _publishes.removeWhere((_, saved) => !now.isBefore(saved.publish.deadline));
    final stranded = [
      for (final MapEntry(:key, :value) in _publishes.entries)
        if (value.writtenAt < _socketOpenedAt)
          (eventId: key, publish: value.publish),
    ];
    if (stranded.isEmpty) return;
    diagnose(
      RelayDiagnosticSite.requestSettlement,
      RelayDiagnosticLevel.info,
      'Re-sending ${stranded.length} publishes still waiting for OK '
      '(source=${source ?? "unknown"})',
    );
    for (final (:eventId, :publish) in stranded) {
      if (!_publishes.containsKey(eventId)) continue;
      if (!relayStatus.writeAccess) {
        forgetPublish(eventId);
        onPublishReplayDisabled?.call(eventId);
        continue;
      }
      try {
        final sent = await send(
          publish.message,
          queueIfFailed: false,
          skipReconnect: true,
          deadline: publish.deadline,
        );
        if (sent && _publishes.containsKey(eventId)) {
          savePublish(eventId, publish.message, publish.deadline);
        }
      } catch (e, stackTrace) {
        diagnose(
          RelayDiagnosticSite.requestSettlement,
          RelayDiagnosticLevel.error,
          'Publish $eventId threw while being re-sent',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Sends the frames that failed while the socket was down.
  ///
  /// REQ frames naming one of [reissuedIds] are dropped instead of sent: the
  /// saved subscription carries the same REQ and is re-issued right after, and
  /// sending both makes the relay replay its whole stored window twice.
  ///
  /// [dropQueuedCloses] drops queued `CLOSE` frames for the same class of
  /// reason, and is set exactly when this socket is a new one. A relay forgets
  /// every subscription when its socket dies, so a `CLOSE` queued against the
  /// previous connection can only name something the fresh socket has never
  /// heard of. At best that is a wasted frame. At worst it is destructive:
  /// `RelayPool` re-issues saved subscriptions from its own post-AUTH replay
  /// and zombie reconnect, off this await chain, so a caller that tore down a
  /// subscription and later re-subscribed under the same explicit id can have
  /// the replayed REQ land first — and then this stale `CLOSE` tears down the
  /// live subscription, which goes silent with no terminal frame.
  ///
  /// A reused connection is the opposite case and is left alone: nothing
  /// cycled, so a queued `CLOSE` may still name a subscription this very
  /// socket is holding.
  Future<void> _flushPendingMessages(
    String? source,
    Set<String> reissuedIds, {
    required bool dropQueuedCloses,
  }) async {
    log(
      '[Relay] onConnected[${source ?? "unknown"}]: ${relayStatus.addr} - sending ${pendingMessages.length} pending messages',
    );
    if (pendingMessages.isEmpty) {
      log(
        '[Relay] onConnected[${source ?? "unknown"}]: ${relayStatus.addr} - NO pending messages to send!',
      );
      return;
    }
    final messagesToSend = List<List<dynamic>>.from(pendingMessages);
    pendingMessages.clear();

    for (var message in messagesToSend) {
      if (_isReqNaming(message, reissuedIds)) continue;
      if (dropQueuedCloses && _isClose(message)) continue;
      try {
        final result = await send(
          message,
          queueIfFailed: false,
          skipReconnect: true,
        );
        if (!result) {
          pendingMessages.add(message);
          log("message send fail onConnected");
        } else {
          log(
            '[Relay] onConnected[${source ?? "unknown"}]: sent pending message type=${message.isNotEmpty ? message[0] : "unknown"}',
          );
        }
      } catch (e) {
        pendingMessages.add(message);
        log("message send exception onConnected");
        log('$e');
      }
    }
    log(
      '[Relay] onConnected[${source ?? "unknown"}]: ${relayStatus.addr} - replay complete, remaining pending messages=${pendingMessages.length}',
    );
  }

  bool _isReqNaming(List<dynamic> message, Set<String> ids) =>
      message.length > 1 && message[0] == 'REQ' && ids.contains(message[1]);

  bool _isClose(List<dynamic> message) =>
      message.isNotEmpty && message[0] == 'CLOSE';

  /// Re-sends every REQ this relay is still holding on the fresh socket.
  ///
  /// `skipReconnect` matches how these REQs were sent the first time
  /// (`RelayPool.relayDoSubscribe`): re-issuing onto a socket that dies again
  /// must queue the frame, not drive a nested reconnect out of the reconnect
  /// handler that is already running.
  Future<void> _reissueSavedRequests(
    String? source,
    List<Subscription> saved,
    void Function(String id)? onReplayFailure,
  ) async {
    if (saved.isEmpty) return;
    diagnose(
      RelayDiagnosticSite.subscriptionReplay,
      RelayDiagnosticLevel.info,
      'Re-issuing ${saved.length} saved relay requests '
      '(source=${source ?? "unknown"})',
    );
    log(
      '[Relay] onConnected[${source ?? "unknown"}]: ${relayStatus.addr} - re-issuing ${saved.length} saved REQs',
    );
    for (final subscription in saved) {
      try {
        final sent = await send(subscription.toJson(), skipReconnect: true);
        if (sent) continue;
        log('Saved relay request ${subscription.id} was not sent');
        diagnose(
          RelayDiagnosticSite.subscriptionReplay,
          RelayDiagnosticLevel.warning,
          'Saved relay request ${subscription.id} was not sent',
        );
      } catch (e, stackTrace) {
        diagnose(
          RelayDiagnosticSite.subscriptionReplay,
          RelayDiagnosticLevel.error,
          'Saved relay request ${subscription.id} threw while replaying',
          error: e,
          stackTrace: stackTrace,
        );
        log('subscription re-issue exception onConnected');
        log('$e');
      }
      onReplayFailure?.call(subscription.id);
    }
  }

  Future<void> getRelayInfo(String url) async {
    info ??= await RelayInfoUtil.get(url);
  }

  /// Retains an already-written EVENT frame so it can be replayed if the relay
  /// turns out to want NIP-42 first.
  ///
  /// [RelayStatus.alwaysAuth] only flips once a challenge has landed, so the
  /// very first publish on a connection cannot be parked in
  /// [pendingAuthedMessages] — it has to go out to provoke the challenge. A
  /// fire-and-forget caller keeps no handle on that frame, so without a copy
  /// here the post-AUTH flush has nothing to replay and the event is gone.
  ///
  /// Bounded by [_maxSentFramesForAuthRetry], evicting oldest-first: this holds
  /// frames the relay has not answered, and a peer that stays silent must not
  /// grow the map without limit.
  void recordSentFrame(List<dynamic> frame) {
    final eventId = _extractEventId(frame);
    if (eventId == null) return;
    // Re-insert last so the eviction order below stays newest-last.
    _sentFramesForAuthRetry
      ..remove(eventId)
      ..[eventId] = frame;
    while (_sentFramesForAuthRetry.length > _maxSentFramesForAuthRetry) {
      _sentFramesForAuthRetry.remove(_sentFramesForAuthRetry.keys.first);
    }
  }

  /// Retrieves and removes a previously recorded frame by event ID.
  ///
  /// Called once the relay has spoken for that event — accepted it, or refused
  /// it for a reason NIP-42 cannot fix — so it is never replayed.
  List<dynamic>? takeSentFrame(String eventId) {
    return _sentFramesForAuthRetry.remove(eventId);
  }

  /// Returns all retained frames and clears the map.
  List<List<dynamic>> drainSentFramesForAuthRetry() {
    final frames = _sentFramesForAuthRetry.values.toList();
    _sentFramesForAuthRetry.clear();
    return frames;
  }

  /// Extracts the event id from a client-to-relay EVENT frame.
  ///
  /// Only the publish shape `["EVENT", <event>]` is recognised. The three-element
  /// `["EVENT", <subId>, <event>]` shape is the relay-to-client direction and is
  /// never something this client sent, so it is not a retry candidate.
  String? _extractEventId(List<dynamic> frame) {
    if (frame.length != 2 || frame[0] != 'EVENT') {
      return null;
    }
    final event = frame[1];
    if (event is Map && event['id'] is String) {
      return event['id'] as String;
    }
    return null;
  }

  /// Sends [message] to this relay.
  ///
  /// [deadline] is a hard send deadline: implementations must not write or
  /// queue the message after it has expired.
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  });

  Future<void> disconnect();

  void onError(String errMsg, {bool reconnect = false}) {
    log("relay error $errMsg");
    relayStatus.onError();
    relayStatus.connected = ClientConnected.disconnect;
    if (relayStatusCallback != null) {
      relayStatusCallback!();
    }
    // Note: reconnection is now handled by WebSocketConnectionManager
  }

  List<Subscription> getSubscriptions() {
    return _subscriptions.values.toList();
  }

  void saveSubscription(Subscription subscription) {
    _subscriptions[subscription.id] = subscription;
  }

  bool checkAndCompleteSubscription(String id) {
    // all subscription should be close
    var sub = _subscriptions.remove(id);
    if (sub != null) {
      send(["CLOSE", id]);
      return true;
    }
    return false;
  }

  bool hasSubscription() {
    return _subscriptions.isNotEmpty;
  }

  bool hasSubscriptionById(String id) {
    return _subscriptions.containsKey(id);
  }

  void saveQuery(Subscription subscription) {
    _queries[subscription.id] = subscription;
  }

  /// Awaited publishes this relay has not answered, by event id, each with
  /// the [_lastSocketMark] of its last write (0: never written by this
  /// object).
  final Map<String, ({SavedPublish publish, int writtenAt})> _publishes = {};

  /// Orders socket openings and publish writes across every relay object.
  static int _lastSocketMark = 0;

  /// The [_lastSocketMark] taken when the current socket opened.
  int _socketOpenedAt = 0;

  /// Records that a new socket has just opened, before [onConnected] runs.
  ///
  /// [onConnected] sends a saved publish again only if it was written before
  /// this mark. An EVENT written while the socket was opening already went
  /// out on it, and sending it again would only make the relay answer twice.
  @protected
  void markSocketOpened() => _socketOpenedAt = ++_lastSocketMark;

  /// Keeps the EVENT [message] for [eventId], just written to this relay,
  /// until the relay answers it, so [onConnected] sends it again on a later
  /// socket before [deadline].
  void savePublish(String eventId, List<dynamic> message, DateTime deadline) {
    _publishes[eventId] = (
      publish: (message: message, deadline: deadline),
      writtenAt: ++_lastSocketMark,
    );
  }

  /// Takes over a publish another relay object for this url was holding, to
  /// be sent on this object's next socket.
  void adoptPublish(String eventId, SavedPublish publish) {
    _publishes[eventId] = (publish: publish, writtenAt: 0);
  }

  /// Stops holding the publish of [eventId]; returns whether it was held.
  bool forgetPublish(String eventId) => _publishes.remove(eventId) != null;

  /// Whether this relay holds a publish it has not answered yet.
  bool get holdsPublishes => _publishes.isNotEmpty;

  /// Removes and returns every publish this relay is holding.
  ///
  /// For a relay object leaving the pool: the object that replaces it under
  /// the same url sends them on its own socket.
  SavedPublishes takeSavedPublishes() {
    final saved = {
      for (final MapEntry(:key, :value) in _publishes.entries)
        key: value.publish,
    };
    _publishes.clear();
    return saved;
  }

  /// The one-shot queries still awaiting EOSE on this relay.
  ///
  /// Unlike [getSubscriptions], these are closed when their EOSE arrives.
  /// [onConnected] re-issues them on a fresh socket, and `RelayPool` hands
  /// them to the object that replaces this one for its url, so the query can
  /// still EOSE instead of only resolving via the caller's timeout.
  List<Subscription> getQueries() {
    return _queries.values.toList();
  }

  Future<bool> checkAndCompleteQuery(String id) async {
    // all subscription should be close
    var sub = _queries.remove(id);
    if (sub != null) {
      await send(["CLOSE", id]);
      return true;
    }
    return false;
  }

  /// Drops a pending one-shot query without sending `CLOSE`.
  ///
  /// Used when the relay itself ended the subscription (a `CLOSED` frame), so
  /// echoing a `CLOSE` back would name a subscription the relay has already
  /// forgotten. Returns whether [id] named a pending query.
  bool discardQuery(String id) {
    final discarded = _queries.remove(id) != null;
    if (discarded) _discardQueuedReq(id);
    return discarded;
  }

  /// Drops a live subscription without sending `CLOSE`.
  ///
  /// Used whenever the relay has already forgotten the subscription, so a
  /// `CLOSE` naming it would reach nothing: either the relay ended it itself
  /// (a `CLOSED` frame), or the socket it lived on is gone. Returns whether
  /// [id] named a live subscription.
  bool discardSubscription(String id) {
    final discarded = _subscriptions.remove(id) != null;
    if (discarded) _discardQueuedReq(id);
    return discarded;
  }

  /// Drops a `REQ` that failed before its saved subscription was discarded.
  ///
  /// A fresh socket would otherwise replay the abandoned request without any
  /// local subscription left to receive its events or send its eventual
  /// `CLOSE`. Only callers that actually removed a saved request invoke this,
  /// so deliberately queued, unsaved requests remain eligible for replay.
  void _discardQueuedReq(String id) {
    pendingMessages.removeWhere(
      (message) =>
          message.length > 1 && message[0] == 'REQ' && message[1] == id,
    );
  }

  bool checkQuery(String id) {
    return _queries[id] != null;
  }

  Subscription? getRequestSubscription(String id) {
    return _queries[id];
  }

  // NIP-45 COUNT query methods

  /// Register a COUNT query and return a future that completes with the response
  ///
  /// [request] is the `COUNT` frame that was sent. Only a query registered
  /// with it can be sent again by a relay object that replaces this one.
  Future<CountResponse> registerCountQuery(
    String id, {
    List<dynamic>? request,
  }) {
    final completer = Completer<CountResponse>();
    _countQueries[id] = completer;
    if (request != null) _countRequests[id] = request;
    return completer.future;
  }

  /// Removes and returns every COUNT query still waiting for its answer, with
  /// the frame each was sent as, when known.
  ///
  /// For a relay object leaving the pool: whatever it still owes can only be
  /// answered on another socket now.
  List<
    ({String id, Completer<CountResponse> completer, List<dynamic>? request})
  >
  takePendingCountQueries() {
    final pending = [
      for (final entry in _countQueries.entries)
        (
          id: entry.key,
          completer: entry.value,
          request: _countRequests[entry.key],
        ),
    ];
    _countQueries.clear();
    _countRequests.clear();
    return pending;
  }

  /// Waits for COUNT [id] on this relay's next socket, completing
  /// [completer], with [request] queued to be sent once it connects.
  ///
  /// For a COUNT another relay object for this url was waiting on when it
  /// left the pool.
  void adoptCountQuery(
    String id,
    Completer<CountResponse> completer,
    List<dynamic> request,
  ) {
    _countQueries[id] = completer;
    _countRequests[id] = request;
    pendingMessages.add(request);
  }

  /// Check if a COUNT query exists for this ID
  bool hasCountQuery(String id) {
    return _countQueries.containsKey(id);
  }

  /// Complete a COUNT query with the response
  void completeCountQuery(String id, CountResponse response) {
    final completer = _countQueries.remove(id);
    _countRequests.remove(id);
    if (completer == null) return;
    _supportsCount = true;
    completer.complete(response);
  }

  /// Complete a COUNT query with an error (e.g., CLOSED response)
  ///
  /// A frame for it still queued for the next socket is dropped: nobody is
  /// waiting for its answer any more.
  void failCountQuery(String id, String reason) {
    final completer = _countQueries.remove(id);
    if (_countRequests.remove(id) != null) {
      pendingMessages.removeWhere(
        (message) =>
            message.length > 1 && message[0] == 'COUNT' && message[1] == id,
      );
    }
    completer?.completeError(CountNotSupportedException(reason));
  }

  /// Whether the current socket has refused COUNT.
  ///
  /// Once disconnected, allow the caller to try again on a fresh socket.
  bool get countUnsupported =>
      _supportsCount == false &&
      relayStatus.connected == ClientConnected.connected;

  /// Settles pending COUNTs after a known unknown-command notice unless the
  /// socket has already answered COUNT. An ambiguous notice also needs to
  /// agree with the advertised capabilities.
  void handleCountUnknownCommandNotice(
    String reason, {
    required bool namesCount,
  }) {
    if (_countQueries.isEmpty || _supportsCount == true) return;
    if (!namesCount && (info?.nips.any((nip) => '$nip' == '45') ?? false)) {
      return;
    }

    _supportsCount = false;
    final pending = _countQueries.values.toList();
    _countQueries.clear();
    _countRequests.clear();
    for (final completer in pending) {
      completer.completeError(CountNotSupportedException(reason));
    }
  }

  Function? relayStatusCallback;

  void dispose() {}
}
