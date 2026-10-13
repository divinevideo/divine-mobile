// MPL-2.0
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:concord_repository/concord_repository.dart';
import 'package:test/test.dart';

void main() {
  test(
    'WebSocketRelayGateway publishes and receives over a local relay',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final stored = <Map<String, dynamic>>[];
      final subs = <WebSocket, String>{};
      unawaited(
        server.forEach((req) async {
          final ws = await WebSocketTransformer.upgrade(req);
          ws.listen((data) {
            final msg = jsonDecode(data as String) as List<dynamic>;
            if (msg[0] == 'EVENT') {
              final ev = Map<String, dynamic>.from(msg[1] as Map);
              stored.add(ev);
              ws.add(jsonEncode(['OK', ev['id'], true, '']));
              for (final e in subs.entries) {
                e.key.add(jsonEncode(['EVENT', e.value, ev]));
              }
            } else if (msg[0] == 'REQ') {
              subs[ws] = msg[1] as String;
              for (final ev in stored) {
                ws.add(jsonEncode(['EVENT', msg[1], ev]));
              }
              ws.add(jsonEncode(['EOSE', msg[1]]));
            }
          });
        }),
      );
      addTearDown(() => server.close(force: true));
      final gateway = WebSocketRelayGateway('ws://127.0.0.1:${server.port}');
      final received = gateway
          .subscribe({
            'kinds': [9],
          })
          .first
          .timeout(const Duration(seconds: 5));
      await gateway.connect();
      await gateway.publish({'id': 'ev1', 'kind': 9, 'content': 'hi'});
      final ev = await received;
      expect(ev['content'], 'hi');
      await gateway.close();
    },
  );
}
