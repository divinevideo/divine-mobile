// Self-test for relay-fault-proxy.dart: a fake relay, the proxy in front of it,
// and one scenario per fault. Exits 0 when every scenario passes.
//
//   dart relay-fault-proxy-selftest.dart
//
// dart:io only. Each scenario starts its own proxy on a free port, so run it
// from anywhere; it finds the proxy beside itself.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef _Frame = List<Object?>;

class _FakeRelay {
  late final HttpServer _server;
  final received = <_Frame>[];
  final _sockets = <WebSocket>[];

  int get port => _server.port;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        request.response
          ..headers.contentType = ContentType('application', 'nostr+json')
          ..write('{"name":"fake-relay"}');
        await request.response.close();
        return;
      }
      final socket = await WebSocketTransformer.upgrade(request);
      _sockets.add(socket);
      socket.listen((data) {
        final message = jsonDecode(data as String) as _Frame;
        received.add(message);
        switch (message.first) {
          case 'REQ':
            socket.add(
              jsonEncode([
                'EVENT',
                message[1],
                {'id': 'ev1'},
              ]),
            );
            socket.add(jsonEncode(['EOSE', message[1]]));
          case 'EVENT':
            final id = (message[1]! as Map<String, Object?>)['id'];
            socket.add(jsonEncode(['OK', id, true, '']));
        }
      });
    });
  }

  int count(String type) => received.where((m) => m.first == type).length;

  Future<void> closeSockets() async {
    for (final socket in _sockets) {
      await socket.close();
    }
    _sockets.clear();
  }

  Future<void> stop() => _server.close(force: true);
}

class _Client {
  _Client(this.socket) {
    socket.listen(
      (data) => frames.add(jsonDecode(data as String) as _Frame),
      onDone: () => done = true,
    );
  }

  final WebSocket socket;
  final frames = <_Frame>[];
  bool done = false;

  void send(_Frame message) => socket.add(jsonEncode(message));

  List<_Frame> of(String type) => frames.where((f) => f.first == type).toList();
}

class _Proxy {
  _Proxy(this.process, this.port, this.events);

  final Process process;
  final int port;

  /// Every `event` line the proxy has logged so far.
  final List<Map<String, Object?>> events;

  List<Map<String, Object?>> eventsNamed(String name) =>
      events.where((e) => e['event'] == name).toList();

  Future<_Client> connect() async =>
      _Client(await WebSocket.connect('ws://127.0.0.1:$port'));

  Future<void> stop() async {
    process.kill();
    await process.exitCode;
  }
}

Future<bool> _within(
  bool Function() test, [
  Duration limit = const Duration(seconds: 3),
]) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < limit) {
    if (test()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return test();
}

Future<void> _quiet([int ms = 600]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void _expect(bool condition, String what) {
  if (!condition) throw StateError(what);
}

Future<_Proxy> _startProxy(int upstreamPort, List<String> flags) async {
  final script = Platform.script.resolve('relay-fault-proxy.dart');
  final process = await Process.start(Platform.resolvedExecutable, [
    script.toFilePath(),
    '--upstream',
    'ws://127.0.0.1:$upstreamPort',
    '--listen',
    '0',
    '--max-seconds',
    '60',
    ...flags,
  ]);
  final listening = Completer<int>();
  final events = <Map<String, Object?>>[];
  process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(
    (line) {
      final entry = jsonDecode(line) as Map<String, Object?>;
      if (entry.containsKey('event')) events.add(entry);
      if (entry['event'] == 'listening' && !listening.isCompleted) {
        listening.complete(entry['port']! as int);
      }
    },
  );
  unawaited(process.stderr.drain<void>());
  final port = await listening.future.timeout(const Duration(seconds: 15));
  return _Proxy(process, port, events);
}

Future<void> main() async {
  final relay = _FakeRelay();
  await relay.start();
  var failures = 0;

  Future<void> scenario(
    String name,
    List<String> flags,
    Future<void> Function(_Proxy proxy) body,
  ) async {
    relay.received.clear();
    _Proxy? proxy;
    try {
      proxy = await _startProxy(relay.port, flags);
      await body(proxy);
      stdout.writeln('PASS  $name');
    } on Object catch (error) {
      failures++;
      stdout.writeln('FAIL  $name: $error');
    } finally {
      await proxy?.stop();
    }
  }

  await scenario('passes REQ and EVENT through untouched', [], (proxy) async {
    final client = await proxy.connect();
    client
      ..send(['REQ', 's1', <String, Object?>{}])
      ..send([
        'EVENT',
        {'id': 'a1'},
      ]);
    _expect(
      await _within(
        () =>
            client.of('EVENT').length == 1 &&
            client.of('EOSE').length == 1 &&
            client.of('OK').length == 1,
      ),
      'expected EVENT, EOSE and OK, got ${client.frames}',
    );
    _expect(client.of('OK').single[2] == true, 'OK should be true');
  });

  await scenario(
    '--refuse-connects spends itself on handshakes, not on NIP-11 fetches',
    ['--refuse-connects', '1'],
    (proxy) async {
      final http = HttpClient();
      final request = await http.getUrl(
        Uri.parse('http://127.0.0.1:${proxy.port}/'),
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/nostr+json');
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      http.close();
      _expect(
        response.statusCode == 200 && body.contains('fake-relay'),
        'the NIP-11 document should be forwarded, got ${response.statusCode}',
      );
      var refused = false;
      try {
        await proxy.connect();
      } on WebSocketException {
        refused = true;
      }
      _expect(refused, 'the first handshake should be refused');
      final client = await proxy.connect();
      client.send(['REQ', 's1', <String, Object?>{}]);
      _expect(
        await _within(() => client.of('EOSE').isNotEmpty),
        'the second handshake should reach the relay',
      );
    },
  );

  await scenario(
    '--drop-ok swallows one OK; the relay still stored the event',
    ['--drop-ok', '1'],
    (proxy) async {
      final client = await proxy.connect();
      client.send([
        'EVENT',
        {'id': 'a1'},
      ]);
      await _quiet();
      _expect(client.of('OK').isEmpty, 'the first OK should be dropped');
      _expect(relay.count('EVENT') == 1, 'the relay should have received it');
      client.send([
        'EVENT',
        {'id': 'a2'},
      ]);
      _expect(
        await _within(() => client.of('OK').length == 1),
        'the second OK should arrive',
      );
    },
  );

  await scenario(
    '--delay-ok-ms holds every OK for the delay, not one after another',
    ['--delay-ok-ms', '700'],
    (proxy) async {
      final client = await proxy.connect();
      final sent = Stopwatch()..start();
      client.send(['REQ', 's1', <String, Object?>{}]);
      for (final id in ['a1', 'a2', 'a3']) {
        client.send([
          'EVENT',
          {'id': id},
        ]);
      }
      _expect(
        await _within(
          () => client.of('EOSE').isNotEmpty,
          const Duration(milliseconds: 500),
        ),
        'EOSE should not be delayed',
      );
      _expect(client.of('OK').isEmpty, 'the OKs should still be held');
      _expect(
        await _within(() => client.of('OK').length == 3),
        'the OKs should arrive after the delay',
      );
      _expect(
        sent.elapsedMilliseconds < 1300,
        'three OKs took ${sent.elapsedMilliseconds} ms: the holds added up',
      );
    },
  );

  await scenario(
    '--delay-eose-ms holds every EOSE for the delay, not one after another',
    ['--delay-eose-ms', '700'],
    (proxy) async {
      final client = await proxy.connect();
      final sent = Stopwatch()..start();
      for (final sub in ['s1', 's2', 's3']) {
        client.send(['REQ', sub, <String, Object?>{}]);
      }
      _expect(
        await _within(
          () => client.of('EVENT').isNotEmpty,
          const Duration(milliseconds: 500),
        ),
        'the first EVENT should not be delayed',
      );
      _expect(client.of('EOSE').isEmpty, 'the EOSEs should still be held');
      _expect(
        await _within(() => client.of('EOSE').length == 3),
        'the EOSEs should arrive after the delay',
      );
      _expect(
        sent.elapsedMilliseconds < 1300,
        'three EOSEs took ${sent.elapsedMilliseconds} ms: the holds added up',
      );
    },
  );

  await scenario('--never-eose swallows every EOSE', ['--never-eose'], (
    proxy,
  ) async {
    final client = await proxy.connect();
    client
      ..send(['REQ', 's1', <String, Object?>{}])
      ..send(['REQ', 's2', <String, Object?>{}]);
    _expect(
      await _within(() => client.of('EVENT').length == 2),
      'both EVENTs should arrive',
    );
    await _quiet();
    _expect(client.of('EOSE').isEmpty, 'no EOSE should be delivered');
  });

  await scenario(
    '--delay-ms holds every relay frame, not the client leg',
    ['--delay-ms', '700'],
    (proxy) async {
      final client = await proxy.connect();
      final sent = Stopwatch()..start();
      for (final sub in ['s1', 's2', 's3']) {
        client.send(['REQ', sub, <String, Object?>{}]);
      }
      await _quiet(400);
      _expect(
        relay.count('REQ') == 3,
        'the REQs should reach the relay at once',
      );
      _expect(client.frames.isEmpty, 'nothing should arrive before the delay');
      _expect(
        await _within(() => client.of('EOSE').length == 3),
        'the frames should arrive after the delay',
      );
      _expect(
        sent.elapsedMilliseconds < 1300,
        'six frames took ${sent.elapsedMilliseconds} ms: the holds added up',
      );
    },
  );

  await scenario(
    '--close-req answers a REQ with CLOSED',
    ['--close-req', 'auth-required'],
    (proxy) async {
      final client = await proxy.connect();
      client.send(['REQ', 's1', <String, Object?>{}]);
      _expect(
        await _within(() => client.of('CLOSED').isNotEmpty),
        'expected CLOSED',
      );
      _expect(
        client.of('CLOSED').single[2] == 'auth-required: injected',
        'wrong CLOSED message: ${client.of('CLOSED')}',
      );
      _expect(relay.count('REQ') == 0, 'the relay should never see the REQ');
    },
  );

  await scenario(
    '--reject-event answers OK false without forwarding',
    ['--reject-event', 'rate-limited'],
    (proxy) async {
      final client = await proxy.connect();
      client.send([
        'EVENT',
        {'id': 'a1'},
      ]);
      _expect(
        await _within(() => client.of('OK').isNotEmpty),
        'expected an injected OK',
      );
      final ok = client.of('OK').single;
      _expect(
        ok[1] == 'a1' && ok[2] == false && ok[3] == 'rate-limited: injected',
        'wrong injected OK: $ok',
      );
      _expect(relay.count('EVENT') == 0, 'the relay should never see it');
      client.send([
        'EVENT',
        {'id': 'a2'},
      ]);
      _expect(
        await _within(() => client.of('OK').length == 2),
        'the next EVENT should be forwarded',
      );
      _expect(client.of('OK').last[2] == true, 'the relay OK should be true');
      _expect(relay.count('EVENT') == 1, 'only the second EVENT is forwarded');
    },
  );

  await scenario(
    '--drop-event loses the EVENT before the relay',
    ['--drop-event', '1'],
    (proxy) async {
      final client = await proxy.connect();
      client.send([
        'EVENT',
        {'id': 'a1'},
      ]);
      await _quiet();
      _expect(client.of('OK').isEmpty, 'nothing should answer');
      _expect(relay.count('EVENT') == 0, 'the relay should never see it');
      client.send([
        'EVENT',
        {'id': 'a2'},
      ]);
      _expect(
        await _within(() => client.of('OK').length == 1),
        'the next EVENT should get through',
      );
    },
  );

  await scenario(
    '--duplicate-event delivers a relay EVENT twice, once',
    ['--duplicate-event', '1'],
    (proxy) async {
      final client = await proxy.connect();
      client.send(['REQ', 's1', <String, Object?>{}]);
      _expect(
        await _within(() => client.of('EOSE').length == 1),
        'expected EOSE',
      );
      _expect(client.of('EVENT').length == 2, 'expected the EVENT twice');
      client.send(['REQ', 's2', <String, Object?>{}]);
      _expect(
        await _within(() => client.of('EOSE').length == 2),
        'expected the second EOSE',
      );
      _expect(
        client.of('EVENT').length == 3,
        'the second REQ is not duplicated',
      );
    },
  );

  await scenario(
    '--close-after closes the first connection only',
    ['--close-after', '2'],
    (proxy) async {
      final client = await proxy.connect();
      client.send(['REQ', 's1', <String, Object?>{}]);
      _expect(
        await _within(() => client.done),
        'the socket should be closed after two frames',
      );
      _expect(
        client.of('EVENT').length == 1 && client.of('EOSE').length == 1,
        'both frames should arrive before the close: ${client.frames}',
      );
      _expect(
        client.socket.closeCode == 4000,
        'expected close code 4000, got ${client.socket.closeCode}',
      );
      final again = await proxy.connect();
      again.send(['REQ', 's1', <String, Object?>{}]);
      await _quiet();
      _expect(
        again.of('EOSE').length == 1 && !again.done,
        'reconnect is clean',
      );
    },
  );

  await scenario(
    '--stall-after keeps the socket open and goes silent',
    ['--stall-after', '1'],
    (proxy) async {
      final client = await proxy.connect();
      client.send(['REQ', 's1', <String, Object?>{}]);
      _expect(
        await _within(() => client.of('EVENT').isNotEmpty),
        'the first frame should arrive',
      );
      await _quiet();
      _expect(client.of('EOSE').isEmpty, 'nothing more should be delivered');
      _expect(!client.done, 'the socket should stay open');
      client.send([
        'EVENT',
        {'id': 'a1'},
      ]);
      await _quiet();
      _expect(
        relay.count('EVENT') == 0,
        'client frames should be swallowed too',
      );
    },
  );

  await scenario(
    '--stall-after-ms stalls a connection that is idle',
    ['--stall-after-ms', '600'],
    (proxy) async {
      final client = await proxy.connect();
      client.send(['REQ', 's1', <String, Object?>{}]);
      _expect(
        await _within(() => client.of('EOSE').isNotEmpty),
        'the first REQ should be answered before the stall',
      );
      await _quiet(900);
      client.send(['REQ', 's2', <String, Object?>{}]);
      await _quiet();
      _expect(client.of('EOSE').length == 1, 'nothing should arrive after');
      _expect(relay.count('REQ') == 1, 'the second REQ should be swallowed');
      _expect(!client.done, 'the socket should stay open');
    },
  );

  await scenario(
    '--stall-after-ms says nothing for a connection that has ended',
    ['--stall-after-ms', '400'],
    (proxy) async {
      final client = await proxy.connect();
      client.send(['REQ', 's1', <String, Object?>{}]);
      _expect(
        await _within(() => client.of('EOSE').isNotEmpty),
        'the first REQ should be answered',
      );
      await client.socket.close();
      _expect(
        await _within(() => proxy.eventsNamed('client-closed').isNotEmpty),
        'the proxy should log the client leaving',
      );
      await _quiet(900);
      _expect(
        proxy.eventsNamed('stalled').isEmpty,
        'a stall was reported for a connection that had already ended',
      );
    },
  );

  await scenario(
    'a close from the relay is not passed on to a stalled connection',
    ['--stall-after-ms', '300'],
    (proxy) async {
      final client = await proxy.connect();
      client.send(['REQ', 's1', <String, Object?>{}]);
      _expect(
        await _within(() => proxy.eventsNamed('stalled').isNotEmpty),
        'the connection should stall',
      );
      await relay.closeSockets();
      _expect(
        await _within(() => proxy.eventsNamed('relay-closed').isNotEmpty),
        'the proxy should log the relay closing',
      );
      await _quiet();
      _expect(
        proxy.eventsNamed('relay-closed').first['told_client'] == false,
        'the proxy should not report telling a stalled client',
      );
      _expect(!client.done, 'a half-open socket should not hear the close');
    },
  );

  await scenario(
    'a close from the relay reaches a client that is not stalled',
    [],
    (proxy) async {
      final client = await proxy.connect();
      client.send(['REQ', 's1', <String, Object?>{}]);
      _expect(
        await _within(() => client.of('EOSE').isNotEmpty),
        'the REQ should be answered',
      );
      await relay.closeSockets();
      _expect(
        await _within(() => client.done),
        'the client should hear the relay close',
      );
      _expect(
        proxy.eventsNamed('relay-closed').first['told_client'] == true,
        'the proxy should report telling the client',
      );
    },
  );

  await scenario(
    'ending the proxy process drops the socket with no close frame',
    [],
    (proxy) async {
      final client = await proxy.connect();
      client.send(['REQ', 's1', <String, Object?>{}]);
      _expect(
        await _within(() => client.of('EOSE').isNotEmpty),
        'expected EOSE',
      );
      proxy.process.kill();
      _expect(
        await _within(() => client.done),
        'the client should see the drop',
      );
      _expect(
        client.socket.closeCode == 1006 || client.socket.closeCode == null,
        'expected an abnormal close, got ${client.socket.closeCode}',
      );
    },
  );

  for (final bad in [
    ['--drop-ok', 'abc'],
    ['--bogus'],
  ]) {
    final name = 'rejects ${bad.join(' ')} with exit 64';
    final result = await Process.run(Platform.resolvedExecutable, [
      Platform.script.resolve('relay-fault-proxy.dart').toFilePath(),
      '--upstream',
      'ws://127.0.0.1:1',
      ...bad,
    ]);
    if (result.exitCode == 64 && '${result.stderr}'.contains('usage:')) {
      stdout.writeln('PASS  $name');
    } else {
      failures++;
      stdout.writeln('FAIL  $name: exit ${result.exitCode} ${result.stderr}');
    }
  }

  await relay.stop();
  stdout.writeln(failures == 0 ? 'all scenarios passed' : '$failures failed');
  exit(failures == 0 ? 0 : 1);
}
