// MPL-2.0
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:concord_repository/concord_repository.dart';
import 'package:test/test.dart';

const _eventId =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _event = <String, dynamic>{'id': _eventId, 'kind': 9, 'content': 'hi'};

void main() {
  late _LocalRelay relay;
  late WebSocketRelayGateway gateway;

  setUp(() async {
    relay = await _LocalRelay.start();
    gateway = WebSocketRelayGateway(relay.url);
  });
  tearDown(() async {
    await gateway.close();
    await relay.close();
  });

  test('publish waits for matching positive OK', () async {
    final frame = relay.nextFrame('EVENT');
    var completed = false;
    final publish = gateway.publish(_event).then((_) => completed = true);
    await frame;
    expect(completed, isFalse);
    relay.send(['OK', _eventId, true, '']);
    await publish;
  });

  test('negative OK fails publication', () async {
    final frame = relay.nextFrame('EVENT');
    final result = expectLater(gateway.publish(_event), throwsStateError);
    await frame;
    relay.send(['OK', _eventId, false, 'blocked: policy']);
    await result;
  });

  test('NOTICE fails pending publication', () async {
    final frame = relay.nextFrame('EVENT');
    final result = expectLater(gateway.publish(_event), throwsStateError);
    await frame;
    relay.send(['NOTICE', 'publication unavailable']);
    await result;
  });

  test('unacknowledged publication times out and can be retried', () async {
    gateway = WebSocketRelayGateway(
      relay.url,
      publishTimeout: const Duration(milliseconds: 100),
    );
    await expectLater(
      gateway.publish(_event),
      throwsA(isA<TimeoutException>()),
    );
    final frame = relay.nextFrame('EVENT');
    final retry = gateway.publish(_event);
    await frame;
    expect(relay.sockets, hasLength(2));
    relay.send(['OK', _eventId, true, '']);
    await retry;
  });

  test(
    'concurrent connects and duplicate publishes share one connection',
    () async {
      await Future.wait([gateway.connect(), gateway.connect()]);
      expect(relay.sockets, hasLength(1));
      final frames = <List<dynamic>>[];
      final listener = relay.frames.stream.listen(frames.add);
      addTearDown(listener.cancel);
      final frame = relay.nextFrame('EVENT');
      final one = gateway.publish(_event);
      final two = gateway.publish(_event);
      await frame;
      relay.send(['OK', _eventId, true, '']);
      await Future.wait([one, two]);
      expect(frames.where((f) => f.first == 'EVENT'), hasLength(1));
    },
  );

  test('malformed and unrelated frames cannot complete a publish', () async {
    final frame = relay.nextFrame('EVENT');
    var completed = false;
    final publish = gateway.publish(_event).then((_) => completed = true);
    await frame;
    [
      '{',
      '{}',
      'null',
      '1',
      '[]',
      '["EVENT", 1, {}]',
      '["OK", 1, true, ""]',
      '["OK", "$_eventId", "true", ""]',
    ].forEach(relay.sockets.last.add);
    relay.sockets.last.add([1, 2, 3]);
    relay.send(['OK', 'b' * 64, true, '']);
    // A valid subscription event is a barrier after the ignored frames.
    final request = relay.nextFrame('REQ');
    final received = gateway.subscribe({
      'kinds': [9],
    }).first;
    final req = await request;
    relay.send(['EVENT', req[1], _event]);
    await received;
    expect(completed, isFalse);
    relay.send(['OK', _eventId, true, '']);
    await publish;
  });

  test(
    'disconnect fails an in-flight publish and a new publish reconnects',
    () async {
      final frame = relay.nextFrame('EVENT');
      final failure = expectLater(gateway.publish(_event), throwsStateError);
      await frame;
      await relay.sockets.last.close();
      await failure;
      final nextFrame = relay.nextFrame('EVENT');
      final retry = gateway.publish(_event);
      await nextFrame;
      expect(relay.sockets, hasLength(2));
      relay.send(['OK', _eventId, true, '']);
      await retry;
    },
  );

  test(
    'subscription starts connection and replays its filter after disconnect',
    () async {
      gateway = WebSocketRelayGateway(
        relay.url,
        reconnectDelay: const Duration(milliseconds: 10),
      );
      final request = relay.nextFrame('REQ');
      final received = gateway.subscribe({
        'kinds': [9],
      }).first;
      final firstRequest = await request;
      final replay = relay.nextFrame('REQ');
      await relay.sockets.last.close();
      expect(await replay, firstRequest);
      relay
        ..send(['EOSE', firstRequest[1]])
        ..send(['EVENT', firstRequest[1], _event]);
      expect(await received, _event);
    },
  );

  test(
    'cancel sends CLOSE and cancelled subscriptions are not replayed',
    () async {
      final request = relay.nextFrame('REQ');
      final subscription = gateway
          .subscribe({
            'kinds': [9],
          })
          .listen((_) {});
      final req = await request;
      final closed = relay.nextFrame('CLOSE');
      await subscription.cancel();
      expect(await closed, ['CLOSE', req[1]]);
      final frames = <List<dynamic>>[];
      final listener = relay.frames.stream.listen(frames.add);
      addTearDown(listener.cancel);
      final event = relay.nextFrame('EVENT');
      final publish = expectLater(gateway.publish(_event), throwsStateError);
      await event;
      await relay.sockets.last.close();
      await publish;
      final retried = relay.nextFrame('EVENT');
      final retry = gateway.publish(_event);
      await retried;
      expect(frames.where((f) => f.first == 'REQ'), isEmpty);
      relay.send(['OK', _eventId, true, '']);
      await retry;
    },
  );

  test(
    'relay CLOSED terminates only that subscription with an error',
    () async {
      final request = relay.nextFrame('REQ');
      final stream = gateway.subscribe({
        'kinds': [9],
      });
      final result = expectLater(
        stream,
        emitsInOrder([emitsError(isStateError), emitsDone]),
      );
      final req = await request;
      relay.send(['CLOSED', req[1], 'restricted']);
      await result;
    },
  );

  test('close completes listeners, fails publishes, and is terminal', () async {
    final request = relay.nextFrame('REQ');
    final stream = gateway.subscribe({
      'kinds': [9],
    });
    final done = expectLater(stream, emitsDone);
    await request;
    final event = relay.nextFrame('EVENT');
    final failure = expectLater(gateway.publish(_event), throwsStateError);
    await event;
    await gateway.close();
    await done;
    await failure;
    await expectLater(gateway.connect(), throwsStateError);
    await expectLater(gateway.publish(_event), throwsStateError);
    await expectLater(gateway.subscribe({}), emitsError(isStateError));
  });

  test(
    'failed connection is handled and subscriptions exhaust bounded retries',
    () async {
      await relay.server.close(force: true);
      gateway = WebSocketRelayGateway(
        relay.url,
        reconnectDelay: const Duration(milliseconds: 10),
        connectionTimeout: const Duration(milliseconds: 100),
        maxReconnectAttempts: 2,
      );
      await expectLater(gateway.connect(), throwsA(isA<Exception>()));
      await expectLater(
        gateway.subscribe({}),
        emitsInOrder([emitsError(isStateError), emitsDone]),
      );
    },
  );

  test(
    'concurrent distinct publications match their own acknowledgements',
    () async {
      final received = relay.frames.stream
          .where((f) => f.first == 'EVENT')
          .take(2)
          .toList();
      var firstCompleted = false;
      final one = gateway.publish(_event).then((_) => firstCompleted = true);
      final two = gateway.publish({..._event, 'id': 'b' * 64});
      await received;
      relay.send(['OK', 'b' * 64, true, '']);
      await two;
      expect(firstCompleted, isFalse);
      relay.send(['OK', _eventId, true, '']);
      await one;
    },
  );

  test('close interrupts a handshake and does not reconnect', () async {
    relay.holdHandshake = true;
    gateway = WebSocketRelayGateway(
      relay.url,
      connectionTimeout: const Duration(milliseconds: 50),
    );
    final connecting = expectLater(gateway.connect(), throwsStateError);
    await relay.requestReceived.future;
    await gateway.close();
    await connecting;
    expect(relay.sockets, isEmpty);
  });

  test('handshake timeout fails without an unhandled socket error', () async {
    relay.holdHandshake = true;
    gateway = WebSocketRelayGateway(
      relay.url,
      connectionTimeout: const Duration(milliseconds: 30),
    );
    await expectLater(gateway.connect(), throwsA(isA<TimeoutException>()));
  });

  test(
    'connections that repeatedly close without serving data exhaust retries',
    () async {
      gateway = WebSocketRelayGateway(
        relay.url,
        reconnectDelay: const Duration(milliseconds: 5),
        maxReconnectAttempts: 2,
      );
      final closer = relay.frames.stream.listen((frame) {
        if (frame.first == 'REQ') unawaited(relay.sockets.last.close());
      });
      addTearDown(closer.cancel);
      await expectLater(
        gateway.subscribe({}),
        emitsInOrder([emitsError(isStateError), emitsDone]),
      );
      expect(relay.sockets, hasLength(3));
    },
  );

  test(
    'stream first listened to after close completes without connecting',
    () async {
      final stream = gateway.subscribe({});
      await gateway.close();
      await expectLater(stream, emitsDone);
      expect(relay.sockets, isEmpty);
    },
  );
}

class _LocalRelay {
  _LocalRelay(this.server) : url = 'ws://127.0.0.1:${server.port}' {
    server.listen((request) async {
      if (!requestReceived.isCompleted) requestReceived.complete();
      if (holdHandshake) return;
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      listeners.add(
        socket.listen((data) {
          frames.add(jsonDecode(data as String) as List<dynamic>);
        }),
      );
    });
  }
  static Future<_LocalRelay> start() async =>
      _LocalRelay(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
  final HttpServer server;
  bool holdHandshake = false;
  final requestReceived = Completer<void>();
  final sockets = <WebSocket>[];
  final frames = StreamController<List<dynamic>>.broadcast();
  final String url;
  final listeners = <StreamSubscription<dynamic>>[];
  Future<List<dynamic>> nextFrame(String type) => frames.stream
      .firstWhere((frame) => frame.first == type)
      .timeout(const Duration(seconds: 3));
  void send(List<dynamic> frame) => sockets.last.add(jsonEncode(frame));
  Future<void> close() async {
    for (final socket in sockets) {
      await socket.close();
    }
    for (final listener in listeners) {
      await listener.cancel();
    }
    await frames.close();
    await server.close(force: true);
  }
}
