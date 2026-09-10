// ABOUTME: Shared fake WebSocket channel primitives for nostr_sdk tests.
// ABOUTME: Keeps relay and connection-manager tests from duplicating sockets.

import 'dart:async';

import 'package:nostr_sdk/relay/web_socket_connection_manager.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class FakeWebSocketSink implements WebSocketSink {
  final List<dynamic> messages = [];
  bool closed = false;
  final Completer<void> _doneCompleter = Completer<void>();

  @override
  void add(dynamic data) {
    if (closed) throw StateError('Sink is closed');
    messages.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<dynamic> addStream(Stream<dynamic> stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future<dynamic> close([int? closeCode, String? closeReason]) async {
    closed = true;
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }

  @override
  Future<dynamic> get done => _doneCompleter.future;
}

class FakeWebSocketChannel implements WebSocketChannel {
  FakeWebSocketChannel({Future<void>? readyFuture})
    : _readyFuture = readyFuture ?? Future.value();

  final FakeWebSocketSink _sink = FakeWebSocketSink();
  final StreamController<dynamic> _streamController =
      StreamController<dynamic>.broadcast();
  final Future<void> _readyFuture;

  @override
  WebSocketSink get sink => _sink;

  @override
  Stream<dynamic> get stream => _streamController.stream;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => _readyFuture;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('${invocation.memberName} not used in this test');
  }

  void simulateMessage(dynamic message) => _streamController.add(message);

  /// Ends the stream as a relay dropping the socket would. The connection
  /// manager handles this through the same `_handleDisconnect()` its idle
  /// heartbeat uses, so it also stands in for an idle drop.
  Future<void> closeFromRemote() => _streamController.close();

  List<dynamic> get sentMessages => _sink.messages;

  /// Whether the sink was closed — i.e. whether the socket this channel
  /// stands for was actually shut down rather than left open.
  bool get isClosed => _sink.closed;
}

class FakeWebSocketChannelFactory implements WebSocketChannelFactory {
  FakeWebSocketChannelFactory({
    this.readyDelay,
    this.readyError,
    this.readyFutureFactory,
  });

  Duration? readyDelay;
  Object? readyError;
  Future<void> Function()? readyFutureFactory;
  final List<FakeWebSocketChannel> createdChannels = [];

  @override
  WebSocketChannel create(Uri uri) {
    final channel = FakeWebSocketChannel(readyFuture: _readyFuture());
    createdChannels.add(channel);
    return channel;
  }

  FakeWebSocketChannel? get lastChannel =>
      createdChannels.isEmpty ? null : createdChannels.last;

  Future<void> _readyFuture() {
    final factory = readyFutureFactory;
    if (factory != null) return factory();
    final error = readyError;
    if (error != null) return Future<void>.error(error);
    final delay = readyDelay;
    return delay == null ? Future.value() : Future<void>.delayed(delay);
  }
}
