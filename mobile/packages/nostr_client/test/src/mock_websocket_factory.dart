import 'dart:async';
import 'package:nostr_sdk/relay/web_socket_connection_manager.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Mock WebSocket sink for testing
class MockWebSocketSink implements WebSocketSink {
  final List<dynamic> messages = [];
  bool closed = false;
  int? closeCode;
  String? closeReason;
  final Completer<void> _doneCompleter = Completer<void>();

  @override
  void add(dynamic data) {
    if (closed) throw StateError('Sink is closed');
    messages.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    this.closeCode = closeCode;
    this.closeReason = closeReason;
    closed = true;
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }

  @override
  Future<void> get done => _doneCompleter.future;
}

/// Mock WebSocket channel for testing
class MockWebSocketChannel implements WebSocketChannel {
  final MockWebSocketSink _sink = MockWebSocketSink();
  final StreamController<dynamic> _streamController =
      StreamController<dynamic>.broadcast();
  int? _closeCode;

  @override
  WebSocketSink get sink => _sink;

  @override
  Stream<dynamic> get stream => _streamController.stream;

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future.value();

  // StreamChannel interface methods - use noSuchMethod for unneeded methods
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // These methods are not used in tests
    throw UnimplementedError(
      '${invocation.memberName} not implemented in mock',
    );
  }

  /// Simulate receiving a message from the server
  void simulateMessage(dynamic message) {
    _streamController.add(message);
  }

  /// Simulate an error from the server
  void simulateError(Object error) {
    _streamController.addError(error);
  }

  /// Simulate the connection being closed by the server
  void simulateClose() {
    _closeCode = 1000;
    _streamController.close();
  }

  List<dynamic> get sentMessages => _sink.messages;
  bool get isClosed => _sink.closed;
}

/// Mock factory that returns controllable mock channels
class MockWebSocketChannelFactory implements WebSocketChannelFactory {
  final Map<String, MockWebSocketChannel> _channels = {};
  bool shouldFail = false;
  String? failureMessage;

  @override
  WebSocketChannel create(Uri uri) {
    if (shouldFail) {
      throw Exception(failureMessage ?? 'Connection failed');
    }
    final url = uri.toString();
    return _channels.putIfAbsent(
      url,
      () => MockWebSocketChannel(),
    );
  }

  /// Gets the mock channel for a given URL
  MockWebSocketChannel? getChannel(String url) {
    return _channels[url];
  }

  /// Gets the last created channel
  MockWebSocketChannel? get lastChannel =>
      _channels.values.isNotEmpty ? _channels.values.last : null;

  /// Removes a mock channel
  void removeChannel(String url) {
    _channels.remove(url);
  }

  /// Clears all mock channels
  void reset() {
    _channels.clear();
    shouldFail = false;
    failureMessage = null;
  }
}
