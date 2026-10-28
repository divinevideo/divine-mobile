// MPL-2.0
import 'dart:async';
import 'dart:convert';

import 'package:concord_repository/src/concord_repository.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Web and native Nostr transport for the explicitly configured POC relay.
/// A publication succeeds only after the relay accepts its event ID.
class WebSocketRelayGateway implements RelayGateway, RelayHistoryStatus {
  WebSocketRelayGateway(
    this.url, {
    this.connectionTimeout = const Duration(seconds: 10),
    this.publishTimeout = const Duration(seconds: 10),
    this.historyTimeout = const Duration(seconds: 15),
    this.reconnectDelay = const Duration(seconds: 1),
    this.maxReconnectAttempts = 3,
  });

  final String url;
  final Duration connectionTimeout;
  final Duration publishTimeout;
  final Duration historyTimeout;
  final Duration reconnectDelay;
  final int maxReconnectAttempts;
  WebSocketChannel? _channel;
  // Cancelled in _release after disconnect or close.
  // ignore: cancel_subscriptions
  StreamSubscription<dynamic>? _socketSubscription;
  Future<void>? _connecting;
  Completer<void>? _cancelConnect;
  final _subs = <String, _RelaySubscription>{};
  final _publishes = <String, _PendingPublish>{};
  Timer? _reconnectTimer;
  var _counter = 0;
  var _reconnectAttempts = 0;
  var _connected = false;
  var _closed = false;

  @override
  Future<void> get historyReady {
    if (_closed) return Future.error(StateError('Relay gateway is closed'));
    return Future.wait<void>([
      for (final subscription in _subs.values) subscription.history.future,
    ]);
  }

  @override
  bool get historyLimited =>
      _subs.values.any((subscription) => subscription.historyLimited);

  Future<void> connect() {
    if (_closed) return Future.error(StateError('Relay gateway is closed'));
    if (_connected) return Future.value();
    return _connecting ??= _open().whenComplete(() {
      _connecting = null;
      if (!_connected) _scheduleReconnect();
    });
  }

  Future<void> _open() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final cancellation = Completer<void>();
    _cancelConnect = cancellation;
    final channel = WebSocketChannel.connect(Uri.parse(url));
    _channel = channel;
    _socketSubscription = channel.stream.listen(
      _onFrame,
      onError: (Object error) => _disconnected(channel, error),
      onDone: () => _disconnected(
        channel,
        StateError('Relay disconnected before acknowledgement'),
      ),
      cancelOnError: true,
    );
    try {
      await Future.any<void>([
        channel.ready,
        cancellation.future.then<void>(
          (_) => throw StateError('Relay gateway is closed'),
        ),
      ]).timeout(connectionTimeout);
      if (_closed || !identical(_channel, channel)) {
        throw StateError('Relay disconnected while connecting');
      }
      _connected = true;
      for (final entry in _subs.entries) {
        entry.value.beginHistoryRequest();
        _send(['REQ', entry.key, entry.value.filter]);
      }
    } on Object catch (error) {
      _disconnected(channel, error);
      rethrow;
    } finally {
      if (identical(_cancelConnect, cancellation)) _cancelConnect = null;
    }
  }

  void _send(List<dynamic> frame) {
    final channel = _channel;
    if (!_connected || channel == null) {
      throw StateError('Relay is disconnected');
    }
    channel.sink.add(jsonEncode(frame));
  }

  void _disconnected(WebSocketChannel channel, Object error) {
    if (!identical(_channel, channel)) return;
    _channel = null;
    _connected = false;
    final listener = _socketSubscription;
    _socketSubscription = null;
    unawaited(_release(channel, listener));
    _failPublishes(error);
    _scheduleReconnect();
  }

  Future<void> _release(
    WebSocketChannel channel,
    StreamSubscription<dynamic>? listener,
  ) async {
    try {
      await listener?.cancel();
      await channel.sink.close().timeout(connectionTimeout);
    } on Object {
      // The peer may already be gone, or never finish its close handshake.
    }
  }

  void _scheduleReconnect() {
    if (_closed ||
        _connected ||
        _subs.isEmpty ||
        _connecting != null ||
        _reconnectTimer != null) {
      return;
    }
    if (_reconnectAttempts >= maxReconnectAttempts) {
      final subscriptions = _subs.values.toList();
      _subs.clear();
      for (final subscription in subscriptions) {
        subscription.failHistory(StateError('Relay reconnect exhausted'));
        subscription.controller.addError(
          StateError('Relay reconnect exhausted'),
        );
        unawaited(subscription.controller.close());
      }
      return;
    }
    _reconnectAttempts++;
    _reconnectTimer = Timer(reconnectDelay * _reconnectAttempts, () {
      _reconnectTimer = null;
      if (!_closed && _subs.isNotEmpty) _connectInBackground();
    });
  }

  void _connectInBackground() {
    // Listeners receive a terminal error after bounded reconnect attempts.
    unawaited(connect().catchError((Object _) {}));
  }

  @override
  Stream<Map<String, dynamic>> subscribe(Map<String, dynamic> filter) {
    if (_closed) return Stream.error(StateError('Relay gateway is closed'));
    final id = 'concord-${_counter++}';
    late final StreamController<Map<String, dynamic>> controller;
    controller = StreamController<Map<String, dynamic>>(
      onListen: () {
        if (_closed) {
          unawaited(controller.close());
          return;
        }
        if (_subs.isEmpty) _reconnectAttempts = 0;
        final subscription = _RelaySubscription(Map.of(filter), controller);
        _subs[id] = subscription;
        subscription.historyTimer = Timer(historyTimeout, () {
          subscription.failHistory(
            TimeoutException('Relay history boundary not received'),
          );
        });
        if (_connected) {
          subscription.beginHistoryRequest();
          _send(['REQ', id, filter]);
        } else {
          _connectInBackground();
        }
      },
      onCancel: () {
        final subscription = _subs.remove(id);
        subscription?.failHistory(
          StateError('Relay subscription is cancelled'),
        );
        if (subscription != null && _connected) {
          _send(['CLOSE', id]);
        }
        if (_subs.isEmpty) {
          _reconnectTimer?.cancel();
          _reconnectTimer = null;
        }
      },
    );
    return controller.stream;
  }

  @override
  Future<void> publish(Map<String, dynamic> event) async {
    final id = event['id'];
    if (id is! String || id.isEmpty) {
      throw ArgumentError('A published event must have an ID');
    }
    await connect();
    final existing = _publishes[id];
    if (existing != null) return existing.completer.future;
    final pending = _PendingPublish();
    _publishes[id] = pending;
    pending.timer = Timer(publishTimeout, () {
      if (_publishes.remove(id) == pending) {
        final error = TimeoutException('Relay acknowledgement not received');
        pending.fail(error);
        // A silent peer may leave the socket open after losing connectivity.
        // Reconnect on the next attempt; never automatically resend an event.
        final channel = _channel;
        if (channel != null) _disconnected(channel, error);
      }
    });
    try {
      _send(['EVENT', event]);
    } on Object catch (error) {
      _publishes.remove(id);
      pending.fail(error);
    }
    return pending.completer.future;
  }

  void _onFrame(dynamic data) {
    if (data is! String) return;
    dynamic message;
    try {
      message = jsonDecode(data);
    } on FormatException {
      return;
    }
    if (message is! List || message.isEmpty) return;
    switch (message) {
      case ['EVENT', final String id, final Map<String, dynamic> event]:
        final subscription = _subs[id];
        if (subscription != null) {
          _reconnectAttempts = 0;
          subscription.receivedHistoryEvent();
          subscription.controller.add(event);
        }
      case ['EOSE', final String id]:
        // EOSE is a historical boundary; subscriptions remain live.
        if (_subs.containsKey(id)) _reconnectAttempts = 0;
        _subs[id]?.completeHistory();
      case ['OK', final String id, final bool accepted, final String reason]:
        final pending = _publishes.remove(id);
        if (pending == null) return;
        if (accepted) {
          pending.succeed();
        } else {
          pending.fail(StateError('Relay rejected event: $reason'));
        }
      case ['NOTICE', final String reason]:
        _failPublishes(StateError('Relay notice: $reason'));
      case ['CLOSED', final String id, final String reason]:
        final subscription = _subs.remove(id);
        subscription?.failHistory(
          StateError('Relay closed subscription: $reason'),
        );
        subscription?.controller.addError(
          StateError('Relay closed subscription: $reason'),
        );
        if (subscription != null) unawaited(subscription.controller.close());
      default:
        // Unknown, malformed and binary frames cannot affect transport state.
        break;
    }
  }

  void _failPublishes(Object error) {
    final pending = _publishes.values.toList();
    _publishes.clear();
    for (final publish in pending) {
      publish.fail(error);
    }
  }

  /// Permanently disposes the gateway, including pending work and live streams.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _cancelConnect?.complete();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    for (final id in _subs.keys) {
      if (_connected) _send(['CLOSE', id]);
    }
    final subscriptions = _subs.values.toList();
    _subs.clear();
    for (final subscription in subscriptions) {
      subscription.failHistory(StateError('Relay gateway is closed'));
      // Do not wait for paused consumers before releasing the transport.
      unawaited(subscription.controller.close());
    }
    _failPublishes(StateError('Relay gateway is closed'));
    final channel = _channel;
    final listener = _socketSubscription;
    _channel = null;
    _socketSubscription = null;
    _connected = false;
    if (channel != null) await _release(channel, listener);
  }
}

class _RelaySubscription {
  _RelaySubscription(this.filter, this.controller) {
    // Readiness is optional; retain errors for waiters without leaking an
    // unhandled future error when a normal live-only consumer cancels.
    unawaited(history.future.catchError((Object _) {}));
  }
  final Map<String, dynamic> filter;
  final StreamController<Map<String, dynamic>> controller;
  final history = Completer<void>();
  Timer? historyTimer;
  int _historyEvents = 0;
  bool _historyEnded = false;
  bool _historyLimited = false;

  bool get historyLimited => _historyLimited;

  void beginHistoryRequest() {
    _historyEvents = 0;
    _historyEnded = false;
  }

  void receivedHistoryEvent() {
    if (_historyEnded) return;
    _historyEvents++;
    final limit = filter['limit'];
    if (limit is int && limit > 0 && _historyEvents >= limit) {
      _historyLimited = true;
    }
  }

  void completeHistory() {
    _historyEnded = true;
    historyTimer?.cancel();
    if (!history.isCompleted) history.complete();
  }

  void failHistory(Object error) {
    historyTimer?.cancel();
    if (!history.isCompleted) history.completeError(error);
  }
}

class _PendingPublish {
  final completer = Completer<void>();
  Timer? timer;
  void succeed() {
    timer?.cancel();
    completer.complete();
  }

  void fail(Object error) {
    timer?.cancel();
    completer.completeError(error);
  }
}
