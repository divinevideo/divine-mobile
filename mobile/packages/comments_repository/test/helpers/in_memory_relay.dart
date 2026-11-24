// ABOUTME: An in-memory Nostr relay a real NostrClient reaches through its
// ABOUTME: WebSocketChannelFactory, so tests can read every REQ and CLOSE.

import 'dart:async';
import 'dart:convert';

import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A relay held in memory.
///
/// It answers each REQ with the matching stored events followed by EOSE, and
/// delivers each event published afterwards to every live subscription it
/// matches. Pass it as the `webSocketChannelFactory` of both the
/// `NostrClientConfig` and the `RelayManagerConfig`.
class InMemoryRelay implements WebSocketChannelFactory {
  bool Function(List<Map<String, dynamic>> filters)? refuse;
  final List<Map<String, dynamic>> _events = [];
  final List<_RelayConnection> _connections = [];

  /// The subscription id of every REQ a client sent, in order.
  final List<String> requests = [];

  /// The subscription id of every CLOSE a client sent, in order.
  final List<String> closes = [];

  /// The id of every event the relay has sent a client, in order.
  final List<String> sentEventIds = [];

  /// The subscription ids clients hold open, across every connection.
  Set<String> get openSubscriptions => {
    for (final connection in _connections) ...connection.subscriptionIds,
  };

  @override
  WebSocketChannel create(Uri uri) {
    final connection = _RelayConnection(this);
    _connections.add(connection);
    return connection.channel;
  }

  /// Stores [event] as if another client had published it, and delivers it
  /// to every live subscription it matches.
  void publish(Event event) => _store(event.toJson());

  void _store(Map<String, dynamic> event) {
    _events.add(event);
    for (final connection in _connections) {
      connection.deliver(event);
    }
  }

  List<Map<String, dynamic>> _stored(List<Map<String, dynamic>> filters) {
    final byId = <String, Map<String, dynamic>>{};
    for (final filter in filters) {
      final matching =
          _events.where((event) => _matches(filter, event)).toList()..sort(
            (a, b) =>
                (b['created_at'] as int).compareTo(a['created_at'] as int),
          );
      final limit = filter['limit'] as int?;
      for (final event in limit == null ? matching : matching.take(limit)) {
        byId[event['id'] as String] = event;
      }
    }
    return byId.values.toList();
  }
}

bool _matches(Map<String, dynamic> filter, Map<String, dynamic> event) {
  bool listed(String key, Object? value) {
    final values = filter[key] as List<dynamic>?;
    return values == null || values.contains(value);
  }

  if (!listed('ids', event['id']) ||
      !listed('authors', event['pubkey']) ||
      !listed('kinds', event['kind'])) {
    return false;
  }
  final createdAt = event['created_at'] as int;
  final since = filter['since'] as int?;
  final until = filter['until'] as int?;
  if ((since != null && createdAt < since) ||
      (until != null && createdAt > until)) {
    return false;
  }
  final tags = (event['tags'] as List<dynamic>).cast<List<dynamic>>();
  for (final MapEntry(:key, :value) in filter.entries) {
    if (!key.startsWith('#')) continue;
    final name = key.substring(1);
    final wanted = (value as List<dynamic>).cast<String>();
    final hasTag = tags.any(
      (tag) => tag.length > 1 && tag[0] == name && wanted.contains(tag[1]),
    );
    if (!hasTag) return false;
  }
  return true;
}

class _RelayConnection {
  _RelayConnection(this._relay) {
    channel = _InMemoryChannel(onClientFrame: _onClientFrame);
  }

  final InMemoryRelay _relay;
  late final _InMemoryChannel channel;
  final Map<String, List<Map<String, dynamic>>> _subscriptions = {};

  Iterable<String> get subscriptionIds => _subscriptions.keys;

  void deliver(Map<String, dynamic> event) {
    for (final MapEntry(key: id, value: filters) in _subscriptions.entries) {
      if (filters.any((filter) => _matches(filter, event))) {
        _relay.sentEventIds.add(event['id'] as String);
        channel.send(['EVENT', id, event]);
      }
    }
  }

  void _onClientFrame(Object? data) {
    final frame = jsonDecode(data! as String) as List<dynamic>;
    switch (frame.first) {
      case 'REQ':
        final id = frame[1] as String;
        final filters = frame.skip(2).cast<Map<String, dynamic>>().toList();
        _relay.requests.add(id);
        if (_relay.refuse?.call(filters) ?? false) {
          channel.send(['CLOSED', id, 'restricted: filter refused']);
          return;
        }
        _subscriptions[id] = filters;
        for (final event in _relay._stored(filters)) {
          _relay.sentEventIds.add(event['id'] as String);
          channel.send(['EVENT', id, event]);
        }
        channel.send(['EOSE', id]);
      case 'CLOSE':
        final id = frame[1] as String;
        _relay.closes.add(id);
        _subscriptions.remove(id);
      case 'EVENT':
        final event = frame[1] as Map<String, dynamic>;
        channel.send(['OK', event['id'], true, '']);
        _relay._store(event);
    }
  }
}

class _InMemoryChannel implements WebSocketChannel {
  _InMemoryChannel({required void Function(Object? data) onClientFrame}) {
    _sink = _InMemorySink(onClientFrame, onClose: _toClient.close);
  }

  final StreamController<dynamic> _toClient = StreamController.broadcast();
  late final _InMemorySink _sink;

  /// Sends [frame] to the client on a later microtask, as a socket would.
  void send(List<Object?> frame) {
    final message = jsonEncode(frame);
    scheduleMicrotask(() {
      if (!_toClient.isClosed) _toClient.add(message);
    });
  }

  @override
  WebSocketSink get sink => _sink;

  @override
  Stream<dynamic> get stream => _toClient.stream;

  @override
  Future<void> get ready => Future.value();

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

class _InMemorySink implements WebSocketSink {
  _InMemorySink(this._onClientFrame, {required Future<void> Function() onClose})
    : _onClose = onClose;

  final void Function(Object? data) _onClientFrame;
  final Future<void> Function() _onClose;
  final Completer<void> _done = Completer<void>();
  bool _closed = false;

  @override
  void add(dynamic data) {
    if (_closed) throw StateError('Sink is closed');
    scheduleMicrotask(() => _onClientFrame(data));
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    // The relay ignores client errors, as a socket that dropped them would.
  }

  @override
  Future<void> addStream(Stream<dynamic> stream) => stream.forEach(add);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (_closed) return _done.future;
    _closed = true;
    await _onClose();
    _done.complete();
  }

  @override
  Future<void> get done => _done.future;
}
