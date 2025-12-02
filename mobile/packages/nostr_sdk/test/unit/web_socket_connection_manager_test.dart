// ABOUTME: Unit tests for WebSocketConnectionManager.
// ABOUTME: Tests connection lifecycle, reconnection logic, and heartbeat mechanism.

import 'dart:async';

import 'package:nostr_sdk/relay/web_socket_connection_manager.dart';
import 'package:test/test.dart';
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
  Future addStream(Stream stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future close([int? closeCode, String? closeReason]) async {
    this.closeCode = closeCode;
    this.closeReason = closeReason;
    closed = true;
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }

  @override
  Future get done => _doneCompleter.future;
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
  Stream get stream => _streamController.stream;

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
  final List<MockWebSocketChannel> createdChannels = [];
  bool shouldFail = false;
  String? failureMessage;

  @override
  WebSocketChannel create(Uri uri) {
    if (shouldFail) {
      throw Exception(failureMessage ?? 'Connection failed');
    }
    final channel = MockWebSocketChannel();
    createdChannels.add(channel);
    return channel;
  }

  MockWebSocketChannel? get lastChannel =>
      createdChannels.isNotEmpty ? createdChannels.last : null;

  void reset() {
    createdChannels.clear();
    shouldFail = false;
    failureMessage = null;
  }
}

void main() {
  group('WebSocketConnectionManager', () {
    late MockWebSocketChannelFactory mockFactory;
    late WebSocketConnectionManager manager;
    late List<String> logMessages;

    setUp(() {
      mockFactory = MockWebSocketChannelFactory();
      logMessages = [];
      manager = WebSocketConnectionManager(
        url: 'wss://test.relay.com',
        channelFactory: mockFactory,
        logger: (msg) => logMessages.add(msg),
        config: const WebSocketConfig(
          pingInterval: Duration(milliseconds: 100),
          pongTimeout: Duration(milliseconds: 50),
          maxReconnectAttempts: 3,
          baseReconnectDelay: Duration(milliseconds: 10),
          maxReconnectDelay: Duration(milliseconds: 100),
        ),
      );
    });

    tearDown(() async {
      await manager.dispose();
    });

    group('connection', () {
      test('connects successfully', () async {
        final result = await manager.connect();

        expect(result, isTrue);
        expect(manager.state, equals(ConnectionState.connected));
        expect(manager.isConnected, isTrue);
        expect(mockFactory.createdChannels.length, equals(1));
      });

      test('emits state changes on connect', () async {
        final states = <ConnectionState>[];
        manager.stateStream.listen(states.add);

        await manager.connect();
        await Future.delayed(Duration.zero);

        expect(states, contains(ConnectionState.connecting));
        expect(states, contains(ConnectionState.connected));
      });

      test('rejects invalid URL scheme', () async {
        final badManager = WebSocketConnectionManager(
          url: 'http://invalid.com',
          channelFactory: mockFactory,
          logger: (msg) => logMessages.add(msg),
        );

        final result = await badManager.connect();

        expect(result, isFalse);
        expect(badManager.state, equals(ConnectionState.disconnected));

        await badManager.dispose();
      });

      test('returns true if already connected', () async {
        await manager.connect();

        final result = await manager.connect();

        expect(result, isTrue);
        expect(mockFactory.createdChannels.length, equals(1));
      });

      test('handles connection failure', () async {
        mockFactory.shouldFail = true;
        mockFactory.failureMessage = 'Network error';

        final errors = <String>[];
        manager.errorStream.listen(errors.add);

        final result = await manager.connect();

        expect(result, isFalse);
        expect(manager.state, equals(ConnectionState.disconnected));
        expect(errors, isNotEmpty);
      });
    });

    group('disconnection', () {
      test('disconnects cleanly', () async {
        await manager.connect();

        await manager.disconnect();

        expect(manager.state, equals(ConnectionState.disconnected));
        expect(manager.isConnected, isFalse);
        expect(mockFactory.lastChannel!.isClosed, isTrue);
      });

      test('emits disconnected state', () async {
        await manager.connect();

        final states = <ConnectionState>[];
        manager.stateStream.listen(states.add);

        await manager.disconnect();
        await Future.delayed(Duration.zero);

        expect(states, contains(ConnectionState.disconnected));
      });
    });

    group('messaging', () {
      test('receives messages', () async {
        await manager.connect();

        final messages = <String>[];
        manager.messageStream.listen(messages.add);

        mockFactory.lastChannel!.simulateMessage('["EVENT", "sub1", {}]');
        await Future.delayed(Duration.zero);

        expect(messages, equals(['["EVENT", "sub1", {}]']));
      });

      test('sends messages when connected', () async {
        await manager.connect();

        final result = manager.send('["REQ", "sub1", {}]');

        expect(result, isTrue);
        expect(
          mockFactory.lastChannel!.sentMessages,
          contains('["REQ", "sub1", {}]'),
        );
      });

      test('sendJson encodes and sends', () async {
        await manager.connect();

        final result = manager.sendJson(['REQ', 'sub1', {}]);

        expect(result, isTrue);
        expect(
          mockFactory.lastChannel!.sentMessages.last,
          equals('["REQ","sub1",{}]'),
        );
      });

      test('send returns false when disconnected', () async {
        final result = manager.send('test');

        expect(result, isFalse);
      });
    });

    group('reconnection', () {
      test('schedules reconnect on connection close', () async {
        await manager.connect();

        // Listen for state changes to detect disconnect
        final stateCompleter = Completer<void>();
        final subscription = manager.stateStream.listen((state) {
          if (state == ConnectionState.disconnected) {
            stateCompleter.complete();
          }
        });

        mockFactory.lastChannel!.simulateClose();

        // Wait for disconnect state
        await stateCompleter.future.timeout(const Duration(milliseconds: 100));

        // At the moment of disconnect, reconnectAttempts should have been incremented
        // It may have already reconnected and reset to 0, so check channels created
        expect(
          manager.reconnectAttempts > 0 ||
              mockFactory.createdChannels.length > 1,
          isTrue,
        );

        await subscription.cancel();
      });

      test('reconnects with exponential backoff', () async {
        await manager.connect();
        expect(mockFactory.createdChannels.length, equals(1));

        // Simulate disconnect
        mockFactory.lastChannel!.simulateClose();

        // Wait for reconnection to complete (not just disconnect)
        await Future.delayed(const Duration(milliseconds: 100));

        // Should have created a second channel for reconnection
        expect(mockFactory.createdChannels.length, greaterThanOrEqualTo(2));
      });

      test('stops reconnecting after max attempts', () async {
        mockFactory.shouldFail = true;

        await manager.connect();

        // Wait for all reconnect attempts
        await Future.delayed(const Duration(milliseconds: 500));

        expect(manager.reconnectAttempts, equals(3));
        expect(
          logMessages.any((m) => m.contains('Max reconnect attempts')),
          isTrue,
        );
      });

      test('resetReconnection clears attempt counter', () async {
        mockFactory.shouldFail = true;
        await manager.connect();
        await Future.delayed(const Duration(milliseconds: 100));

        manager.resetReconnection();

        expect(manager.reconnectAttempts, equals(0));
      });

      test('reconnect forces immediate reconnection', () async {
        await manager.connect();
        final firstChannel = mockFactory.lastChannel;

        await manager.reconnect();

        expect(mockFactory.createdChannels.length, equals(2));
        expect(mockFactory.lastChannel, isNot(equals(firstChannel)));
        expect(manager.isConnected, isTrue);
      });

      test('does not reconnect after explicit disconnect', () async {
        await manager.connect();

        await manager.disconnect();
        await Future.delayed(const Duration(milliseconds: 50));

        // Should still be disconnected, no reconnect attempts
        expect(manager.state, equals(ConnectionState.disconnected));
        expect(mockFactory.createdChannels.length, equals(1));
      });
    });

    group('heartbeat', () {
      test('sends ping messages periodically', () async {
        await manager.connect();

        // Wait for ping interval
        await Future.delayed(const Duration(milliseconds: 150));

        final pings = mockFactory.lastChannel!.sentMessages
            .where((m) => m.toString().contains('_ping_'))
            .toList();

        expect(pings, isNotEmpty);
      });

      test('any message resets pong timeout', () async {
        await manager.connect();

        // Wait for ping
        await Future.delayed(const Duration(milliseconds: 120));

        // Simulate response
        mockFactory.lastChannel!.simulateMessage('["EOSE", "_ping_123"]');
        await Future.delayed(Duration.zero);

        // Should still be connected
        expect(manager.isConnected, isTrue);
      });

      test('triggers reconnect on pong timeout', () async {
        await manager.connect();

        // Wait for ping + pong timeout
        await Future.delayed(const Duration(milliseconds: 200));

        // Should have disconnected and possibly reconnected
        expect(
          mockFactory.createdChannels.length > 1 ||
              manager.state == ConnectionState.disconnected,
          isTrue,
        );
      });
    });

    group('error handling', () {
      test('emits errors on stream error', () async {
        await manager.connect();

        final errors = <String>[];
        manager.errorStream.listen(errors.add);

        mockFactory.lastChannel!.simulateError('Test error');
        await Future.delayed(Duration.zero);

        expect(errors, isNotEmpty);
      });

      test('disconnects on stream error', () async {
        await manager.connect();

        mockFactory.lastChannel!.simulateError('Test error');
        await Future.delayed(const Duration(milliseconds: 10));

        // Should be disconnected (may be reconnecting)
        expect(
          manager.state == ConnectionState.disconnected ||
              manager.state == ConnectionState.connecting,
          isTrue,
        );
      });
    });

    group('dispose', () {
      test('cleans up resources', () async {
        await manager.connect();

        await manager.dispose();

        expect(manager.state, equals(ConnectionState.disconnected));
        expect(mockFactory.lastChannel!.isClosed, isTrue);
      });

      test('closes streams', () async {
        await manager.connect();

        var stateStreamClosed = false;
        manager.stateStream.listen(
          (_) {},
          onDone: () => stateStreamClosed = true,
        );

        await manager.dispose();
        await Future.delayed(Duration.zero);

        expect(stateStreamClosed, isTrue);
      });
    });
  });
}
