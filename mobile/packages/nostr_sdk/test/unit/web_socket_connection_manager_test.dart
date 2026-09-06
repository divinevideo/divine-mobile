// ABOUTME: Unit tests for WebSocketConnectionManager.
// ABOUTME: Tests connection lifecycle and on-demand reconnection logic.

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

  /// When set, [close] does not finish until this completer completes.
  Completer<void>? closeGate;

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
    final gate = closeGate;
    if (gate != null) await gate.future;
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
  MockWebSocketChannel({Future<void>? readyFuture})
    : _readyFuture = readyFuture ?? Future.value();

  final MockWebSocketSink _sink = MockWebSocketSink();
  final StreamController<dynamic> _streamController =
      StreamController<dynamic>.broadcast();
  final Future<void> _readyFuture;
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
  Future<void> get ready => _readyFuture;

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

  /// Holds [sink]'s close in flight until the returned completer completes.
  ///
  /// A real close is a network round trip that can outlive a reconnect; the
  /// mock otherwise finishes it synchronously, which hides ordering bugs.
  Completer<void> blockClose() {
    final gate = Completer<void>();
    _sink.closeGate = gate;
    return gate;
  }

  List<dynamic> get sentMessages => _sink.messages;
  bool get isClosed => _sink.closed;
}

/// Mock factory that returns controllable mock channels
class MockWebSocketChannelFactory implements WebSocketChannelFactory {
  final List<MockWebSocketChannel> createdChannels = [];
  bool shouldFail = false;
  String? failureMessage;

  /// When set, the channel's `ready` future completes with this error
  /// instead of succeeding. Simulates DNS/TLS handshake failures.
  Object? readyError;

  /// When set, the channel's `ready` stays pending until this completes.
  /// A real handshake is a network round trip that other work can run inside.
  Completer<void>? readyGate;

  @override
  WebSocketChannel create(Uri uri) {
    if (shouldFail) {
      throw Exception(failureMessage ?? 'Connection failed');
    }
    final channel = MockWebSocketChannel(
      readyFuture: readyError != null
          ? Future.error(readyError!)
          : (readyGate?.future ?? Future.value()),
    );
    createdChannels.add(channel);
    return channel;
  }

  MockWebSocketChannel? get lastChannel =>
      createdChannels.isNotEmpty ? createdChannels.last : null;

  void reset() {
    createdChannels.clear();
    shouldFail = false;
    failureMessage = null;
    readyError = null;
    readyGate = null;
  }
}

/// Runs [body] in a zone that counts the periodic timers currently armed.
///
/// The heartbeat is a `Timer.periodic` with no accessor, and it does nothing
/// observable while the connection is down, so counting the timers the zone
/// hands out is the only way to see one survive a failed reconnect.
Future<void> countingPeriodicTimers(
  Future<void> Function(int Function() armed) body,
) {
  var armed = 0;
  return runZoned(
    () => body(() => armed),
    zoneSpecification: ZoneSpecification(
      createPeriodicTimer: (self, parent, zone, period, callback) {
        armed++;
        late final _CountingTimer wrapper;
        final inner = parent.createPeriodicTimer(
          zone,
          period,
          (_) => callback(wrapper),
        );
        wrapper = _CountingTimer(inner, () => armed--);
        return wrapper;
      },
    ),
  );
}

class _CountingTimer implements Timer {
  _CountingTimer(this._inner, this._onCancel);

  final Timer _inner;
  final void Function() _onCancel;
  bool _cancelled = false;

  @override
  void cancel() {
    if (!_cancelled) {
      _cancelled = true;
      _onCancel();
    }
    _inner.cancel();
  }

  @override
  bool get isActive => _inner.isActive;

  @override
  int get tick => _inner.tick;
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
          maxReconnectAttempts: 3,
          baseReconnectDelay: Duration(milliseconds: 10),
          maxReconnectDelay: Duration(milliseconds: 100),
          connectionTimeout: Duration(milliseconds: 500),
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

      test('handles DNS lookup failure via ready', () async {
        mockFactory.readyError = WebSocketChannelException(
          'SocketException: Failed host lookup: '
          "'relay.divine.video'",
        );

        final errors = <String>[];
        manager.errorStream.listen(errors.add);

        final result = await manager.connect();
        // Allow broadcast stream event to propagate
        await Future<void>.delayed(Duration.zero);

        expect(result, isFalse);
        expect(manager.state, equals(ConnectionState.disconnected));
        expect(errors, isNotEmpty);
        expect(errors.first, contains('Connection failed'));
      });

      test('handles connection timeout via ready', () async {
        // Create a ready future that never completes
        final neverCompleter = Completer<void>();
        mockFactory.readyError = null;

        // Override the factory to use a channel with a never-completing ready
        final slowFactory = _SlowReadyFactory(neverCompleter.future);
        final slowManager = WebSocketConnectionManager(
          url: 'wss://test.relay.com',
          channelFactory: slowFactory,
          logger: (msg) => logMessages.add(msg),
          config: const WebSocketConfig(
            connectionTimeout: Duration(milliseconds: 100),
          ),
        );

        final errors = <String>[];
        slowManager.errorStream.listen(errors.add);

        final result = await slowManager.connect();

        expect(result, isFalse);
        expect(slowManager.state, equals(ConnectionState.disconnected));
        expect(errors, isNotEmpty);
        expect(errors.first, contains('timed out'));

        await slowManager.dispose();
      });

      test('connection timeout is not held open by channel cleanup', () async {
        final factory = MockWebSocketChannelFactory();
        factory.readyGate = Completer<void>();
        final boundedManager = WebSocketConnectionManager(
          url: 'wss://test.relay.com',
          channelFactory: factory,
          logger: logMessages.add,
          config: const WebSocketConfig(
            connectionTimeout: Duration(milliseconds: 20),
            closeTimeout: Duration(milliseconds: 20),
          ),
        );

        final connecting = boundedManager.connect();
        await Future<void>.delayed(Duration.zero);
        factory.lastChannel!.blockClose();

        expect(
          await connecting.timeout(const Duration(milliseconds: 100)),
          isFalse,
        );
        expect(boundedManager.state, ConnectionState.disconnected);

        await boundedManager.dispose();
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

      test(
        'disconnect is bounded when channel close never completes',
        () async {
          final boundedManager = WebSocketConnectionManager(
            url: 'wss://test.relay.com',
            channelFactory: mockFactory,
            logger: logMessages.add,
            config: const WebSocketConfig(
              closeTimeout: Duration(milliseconds: 20),
            ),
          );
          await boundedManager.connect();
          mockFactory.lastChannel!.blockClose();

          await boundedManager.disconnect().timeout(
            const Duration(milliseconds: 100),
          );
          expect(boundedManager.state, ConnectionState.disconnected);

          await boundedManager.dispose();
        },
      );

      test('emits disconnected state', () async {
        await manager.connect();

        final states = <ConnectionState>[];
        manager.stateStream.listen(states.add);

        await manager.disconnect();
        await Future.delayed(Duration.zero);

        expect(states, contains(ConnectionState.disconnected));
      });

      test('stays disconnected when relay closes connection', () async {
        await manager.connect();

        mockFactory.lastChannel!.simulateClose();
        await Future.delayed(const Duration(milliseconds: 50));

        // Should stay disconnected - no automatic reconnect
        expect(manager.state, equals(ConnectionState.disconnected));
        expect(mockFactory.createdChannels.length, equals(1));
      });
    });

    // The idle heartbeat and checkHealth() tear down a *live* socket, unlike
    // the stream-error/stream-done paths where the transport is already gone.
    // Dropping the channel reference without closing the sink strands an open
    // connection the manager no longer has a handle to.
    group('idle disconnect', () {
      test('closes the channel sink when the heartbeat forces a '
          'disconnect', () async {
        final factory = MockWebSocketChannelFactory();
        final idleManager = WebSocketConnectionManager(
          url: 'wss://test.relay.com',
          channelFactory: factory,
          logger: logMessages.add,
          config: const WebSocketConfig(
            heartbeatInterval: Duration(milliseconds: 20),
            idleTimeout: Duration(milliseconds: 10),
          ),
        );
        addTearDown(idleManager.dispose);

        await idleManager.connect();
        final idleChannel = factory.lastChannel!;
        expect(idleChannel.isClosed, isFalse);

        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(idleManager.state, equals(ConnectionState.disconnected));
        expect(idleChannel.isClosed, isTrue);
      });

      test('closes the channel sink when checkHealth finds a stale '
          'connection', () async {
        final factory = MockWebSocketChannelFactory();
        final staleManager = WebSocketConnectionManager(
          url: 'wss://test.relay.com',
          channelFactory: factory,
          logger: logMessages.add,
          config: const WebSocketConfig(
            // No heartbeat timer: checkHealth is the only disconnect trigger.
            heartbeatInterval: Duration.zero,
            idleTimeout: Duration(milliseconds: 10),
          ),
        );
        addTearDown(staleManager.dispose);

        await staleManager.connect();
        final staleChannel = factory.lastChannel!;
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(staleManager.checkHealth(), isFalse);
        await Future<void>.delayed(Duration.zero);

        expect(staleManager.state, equals(ConnectionState.disconnected));
        expect(staleChannel.isClosed, isTrue);
      });

      test('reconnects onto a usable fresh channel after an idle '
          'disconnect', () async {
        final factory = MockWebSocketChannelFactory();
        final staleManager = WebSocketConnectionManager(
          url: 'wss://test.relay.com',
          channelFactory: factory,
          logger: logMessages.add,
          config: const WebSocketConfig(
            baseReconnectDelay: Duration(milliseconds: 10),
            heartbeatInterval: Duration.zero,
            idleTimeout: Duration(milliseconds: 10),
          ),
        );
        addTearDown(staleManager.dispose);

        await staleManager.connect();
        final staleChannel = factory.lastChannel!;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        staleManager.checkHealth();

        final sent = await staleManager.send('["REQ","sub1",{}]');

        // Exactly one live socket per cycle: the idle one is closed and the
        // fresh one still works.
        expect(sent, isTrue);
        expect(staleChannel.isClosed, isTrue);
        expect(factory.createdChannels, hasLength(2));
        final freshChannel = factory.lastChannel!;
        expect(freshChannel, isNot(same(staleChannel)));
        expect(freshChannel.isClosed, isFalse);
        expect(freshChannel.sentMessages, contains('["REQ","sub1",{}]'));
      });

      test('keeps the reconnected channel when a slow close lands '
          'late', () async {
        final factory = MockWebSocketChannelFactory();
        final staleManager = WebSocketConnectionManager(
          url: 'wss://test.relay.com',
          channelFactory: factory,
          logger: logMessages.add,
          config: const WebSocketConfig(
            baseReconnectDelay: Duration(milliseconds: 10),
            heartbeatInterval: Duration.zero,
            idleTimeout: Duration(milliseconds: 10),
          ),
        );
        addTearDown(staleManager.dispose);

        await staleManager.connect();
        final staleChannel = factory.lastChannel!;
        final closeGate = staleChannel.blockClose();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        staleManager.checkHealth();

        expect(await staleManager.send('["REQ","sub1",{}]'), isTrue);
        final freshChannel = factory.lastChannel!;

        closeGate.complete();
        await Future<void>.delayed(Duration.zero);

        // The late close must not detach the channel it never owned, or the
        // manager reports connected while every send drops on the floor.
        expect(staleChannel.isClosed, isTrue);
        expect(staleManager.isConnected, isTrue);
        expect(await staleManager.send('["REQ","sub2",{}]'), isTrue);
        expect(freshChannel.sentMessages, contains('["REQ","sub2",{}]'));
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

        final result = await manager.send('["REQ", "sub1", {}]');

        expect(result, isTrue);
        expect(
          mockFactory.lastChannel!.sentMessages,
          contains('["REQ", "sub1", {}]'),
        );
      });

      test('sendJson encodes and sends', () async {
        await manager.connect();

        final result = await manager.sendJson(['REQ', 'sub1', {}]);

        expect(result, isTrue);
        expect(
          mockFactory.lastChannel!.sentMessages.last,
          equals('["REQ","sub1",{}]'),
        );
      });

      test('sendJson reports unencodable payloads without sending', () async {
        await manager.connect();
        final errors = <String>[];
        manager.errorStream.listen(errors.add);

        final result = await manager.sendJson(Object());
        await Future.delayed(Duration.zero);

        expect(result, isFalse);
        expect(mockFactory.lastChannel!.sentMessages, isEmpty);
        expect(errors, hasLength(1));
        expect(errors.single, startsWith('JSON encode error:'));
        expect(
          logMessages.any((m) => m.startsWith('JSON encode error:')),
          isTrue,
        );
      });
    });

    group('on-demand reconnection', () {
      test('send without a deadline stops at the reconnect budget', () async {
        mockFactory.shouldFail = true;
        final boundedManager = WebSocketConnectionManager(
          url: 'wss://test.relay.com',
          channelFactory: mockFactory,
          logger: logMessages.add,
          config: const WebSocketConfig(
            maxReconnectAttempts: 10,
            baseReconnectDelay: Duration(milliseconds: 10),
            maxReconnectDelay: Duration(milliseconds: 100),
            connectionTimeout: Duration(milliseconds: 500),
            reconnectBudget: Duration(milliseconds: 25),
          ),
        );
        addTearDown(boundedManager.dispose);

        expect(await boundedManager.send('test'), isFalse);
        expect(boundedManager.reconnectAttempts, lessThan(10));
      });

      test('an explicit deadline overrides the reconnect budget', () async {
        mockFactory.shouldFail = true;
        final boundedManager = WebSocketConnectionManager(
          url: 'wss://test.relay.com',
          channelFactory: mockFactory,
          logger: logMessages.add,
          config: const WebSocketConfig(
            maxReconnectAttempts: 10,
            baseReconnectDelay: Duration(milliseconds: 10),
            maxReconnectDelay: Duration(milliseconds: 100),
            connectionTimeout: Duration(milliseconds: 500),
            reconnectBudget: Duration(seconds: 1),
          ),
        );
        addTearDown(boundedManager.dispose);

        expect(
          await boundedManager.send(
            'test',
            deadline: DateTime.now().add(const Duration(milliseconds: 25)),
          ),
          isFalse,
        );
        expect(boundedManager.reconnectAttempts, lessThan(10));
      });

      test('reconnect budget bounds a pending handshake', () async {
        final readyGate = Completer<void>();
        mockFactory.readyGate = readyGate;
        final boundedManager = WebSocketConnectionManager(
          url: 'wss://test.relay.com',
          channelFactory: mockFactory,
          logger: logMessages.add,
          config: const WebSocketConfig(
            maxReconnectAttempts: 10,
            baseReconnectDelay: Duration(milliseconds: 1),
            maxReconnectDelay: Duration(milliseconds: 1),
            connectionTimeout: Duration(seconds: 1),
            closeTimeout: Duration(milliseconds: 5),
            reconnectBudget: Duration(milliseconds: 20),
          ),
        );
        addTearDown(boundedManager.dispose);

        expect(await boundedManager.send('test'), isFalse);
        expect(boundedManager.state, ConnectionState.disconnected);

        readyGate.complete();
        await Future<void>.delayed(Duration.zero);
        expect(boundedManager.state, ConnectionState.disconnected);
        expect(mockFactory.lastChannel!.isClosed, isTrue);
      });

      test('send reconnects when disconnected', () async {
        // Start disconnected
        expect(manager.state, equals(ConnectionState.disconnected));

        final result = await manager.send('["REQ", "sub1", {}]');

        expect(result, isTrue);
        expect(manager.state, equals(ConnectionState.connected));
        expect(mockFactory.createdChannels.length, equals(1));
        expect(
          mockFactory.lastChannel!.sentMessages,
          contains('["REQ", "sub1", {}]'),
        );
      });

      test('send waits when connecting', () async {
        // Start a connection
        final connectFuture = manager.connect();

        // Immediately try to send
        final sendFuture = manager.send('["REQ", "sub1", {}]');

        // Both should complete successfully
        await connectFuture;
        final result = await sendFuture;

        expect(result, isTrue);
        expect(mockFactory.createdChannels.length, equals(1));
      });

      test('send fails after max reconnect attempts', () async {
        mockFactory.shouldFail = true;

        final result = await manager.send('test');

        expect(result, isFalse);
        expect(manager.reconnectAttempts, equals(3));
        expect(
          logMessages.any((m) => m.contains('Max reconnect attempts')),
          isTrue,
        );
      });

      test('send with skipReconnect returns false when disconnected', () async {
        // Manager starts disconnected — skipReconnect should return
        // false immediately without attempting to create a connection.
        final result = await manager.send('test', skipReconnect: true);

        expect(result, isFalse);
        expect(mockFactory.createdChannels, isEmpty);
        expect(logMessages.any((m) => m.contains('skipReconnect')), isTrue);
      });

      test(
        'sendJson with skipReconnect returns false when disconnected',
        () async {
          final result = await manager.sendJson([
            'REQ',
            'sub1',
            {},
          ], skipReconnect: true);

          expect(result, isFalse);
          expect(mockFactory.createdChannels, isEmpty);
        },
      );

      test('sendJson reconnects when disconnected', () async {
        final result = await manager.sendJson(['REQ', 'sub1', {}]);

        expect(result, isTrue);
        expect(manager.state, equals(ConnectionState.connected));
      });

      test('resetReconnection clears attempt counter', () async {
        mockFactory.shouldFail = true;
        await manager.send('test');

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

      test('a failed reconnect does not leave the heartbeat armed', () async {
        await countingPeriodicTimers((armed) async {
          final factory = MockWebSocketChannelFactory();
          final reconnecting = WebSocketConnectionManager(
            url: 'wss://test.relay.com',
            channelFactory: factory,
            logger: logMessages.add,
          );

          expect(await reconnecting.connect(), isTrue);
          expect(armed(), equals(1), reason: 'the connect arms the heartbeat');

          // A relay that has gone quiet gets force-reconnected, and on a bad
          // network that reconnect is the one most likely to fail.
          factory.shouldFail = true;
          expect(await reconnecting.reconnect(), isFalse);

          expect(
            armed(),
            isZero,
            reason: 'the old heartbeat has no connection left to beat on',
          );

          await reconnecting.dispose();
        });
      });

      test('does not reconnect after explicit disconnect', () async {
        await manager.connect();
        await manager.disconnect();

        // send should fail without reconnecting after explicit disconnect
        final result = await manager.send('test');

        expect(result, isFalse);
        expect(mockFactory.createdChannels.length, equals(1));
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

        // Should be disconnected (no automatic reconnect)
        expect(manager.state, equals(ConnectionState.disconnected));
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

      // A connect that is already in flight when dispose runs would otherwise
      // finish onto a manager nobody holds a reference to any more, arming a
      // heartbeat `Timer.periodic` on a socket nothing can ever close (#7367).
      // The reconnect here is only how the connect gets parked; what refuses
      // on resume is _doConnect's own guard, not reconnect's entry guard.
      test('a connect in flight when dispose runs opens no socket', () async {
        await manager.connect();
        final closeGate = mockFactory.lastChannel!.blockClose();

        // Parks inside reconnect's own close of the old channel.
        final reconnecting = manager.reconnect();
        await Future<void>.delayed(Duration.zero);

        // The owner tears the manager down while the reconnect is parked.
        await manager.dispose();
        closeGate.complete();

        expect(await reconnecting, isFalse);
        expect(
          mockFactory.createdChannels,
          hasLength(1),
          reason: 'a disposed manager must not open another socket',
        );
        expect(manager.state, equals(ConnectionState.disconnected));
      });

      test(
        'a handshake superseded by a newer connect is not adopted',
        () async {
          final gate = Completer<void>();
          mockFactory.readyGate = gate;

          final superseded = manager.connect();
          await Future<void>.delayed(Duration.zero);
          final supersededChannel = mockFactory.lastChannel!;

          // A newer connect lands while the first handshake is still parked,
          // and takes ownership of the manager.
          mockFactory.readyGate = null;
          expect(await manager.reconnect(), isTrue);
          expect(mockFactory.createdChannels, hasLength(2));
          final owner = mockFactory.lastChannel!;

          gate.complete();

          expect(
            await superseded,
            isFalse,
            reason: 'the newer connect owns the manager now',
          );

          // Adopting the stale channel would repoint the message subscription
          // at a socket nobody is writing to.
          final received = <dynamic>[];
          manager.messageStream.listen(received.add);
          owner.simulateMessage('still listening to the live socket');
          await Future<void>.delayed(Duration.zero);

          expect(received, equals(['still listening to the live socket']));
          expect(supersededChannel.isClosed, isTrue);
        },
      );

      test('a handshake that completes after dispose closes its own '
          'socket', () async {
        final factory = MockWebSocketChannelFactory();
        final gate = Completer<void>();
        factory.readyGate = gate;
        final racing = WebSocketConnectionManager(
          url: 'wss://test.relay.com',
          channelFactory: factory,
          logger: logMessages.add,
        );

        final connecting = racing.connect();
        await Future<void>.delayed(Duration.zero);
        final orphan = factory.lastChannel!;

        await racing.dispose();
        gate.complete();

        expect(
          await connecting,
          isFalse,
          reason: 'the handshake has no owner left to hand the socket to',
        );
        expect(orphan.isClosed, isTrue);
        expect(
          racing.state,
          isNot(equals(ConnectionState.connected)),
          reason: 'reaching connected is what arms the heartbeat timer',
        );
      });
    });
  });
}

/// Factory that creates channels with a custom ready future (e.g. one that
/// never completes, for testing connection timeout).
class _SlowReadyFactory implements WebSocketChannelFactory {
  _SlowReadyFactory(this._readyFuture);

  final Future<void> _readyFuture;

  @override
  WebSocketChannel create(Uri uri) {
    return MockWebSocketChannel(readyFuture: _readyFuture);
  }
}
