// Fault-injecting WebSocket proxy for Nostr relay traffic.
//
// Puts a relay you control between the app and its relay so a refusal, a lost
// OK or a slow EOSE happens on demand. Tooling for the validate-issue skill:
// run it from the skill directory with `dart`; nothing in the app imports it.
//
//   dart relay-fault-proxy.dart --upstream ws://localhost:10547 [--listen 47801] [faults]
//
// Faults (counts are for the proxy's lifetime):
//   --refuse-connects N     answer the first N connections with HTTP 503
//   --drop-ok N             swallow the first N ["OK", ...] frames from the relay
//   --delay-eose-ms MS      hold every ["EOSE", ...] frame for MS
//   --delay-ms MS           hold every relay-to-client frame for MS
//   --never-eose            swallow every EOSE (a REQ that never terminates)
//   --close-req PREFIX      answer REQs with ["CLOSED", sub, "PREFIX: injected"]
//   --close-req-count N     how many REQs to refuse that way (default 1)
// Other:
//   --bind-all              listen on every interface (a phone on the LAN), not just loopback
//   --max-seconds S         exit after S seconds (default 1800) so it cannot outlive the session
//
// stdout: one JSON object per frame {t, dir, type, bytes, action, frame}.
// Frames are logged whole: a cut frame can cut an event id or pubkey.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

void _log(Map<String, Object?> entry) {
  stdout.writeln(
    jsonEncode({'t': DateTime.now().toUtc().toIso8601String(), ...entry}),
  );
}

String _frameType(Object? data) {
  if (data is! String) return 'binary';
  try {
    final decoded = jsonDecode(data);
    if (decoded is List && decoded.isNotEmpty && decoded.first is String) {
      return decoded.first as String;
    }
  } on FormatException {
    // Not JSON: reported as such, forwarded untouched.
  }
  return 'non-nostr';
}

String _frame(Object? data) =>
    data is String ? data : '<${(data as List).length} bytes>';

int _size(Object? data) =>
    data is String ? utf8.encode(data).length : (data as List).length;

Map<String, String> _parse(List<String> args) {
  final options = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) continue;
    final name = arg.substring(2);
    final hasValue = i + 1 < args.length && !args[i + 1].startsWith('--');
    options[name] = hasValue ? args[++i] : 'true';
  }
  return options;
}

Future<void> main(List<String> args) async {
  final options = _parse(args);
  final upstream = options['upstream'];
  if (upstream == null) {
    stderr.writeln(
      'usage: dart relay-fault-proxy.dart --upstream ws://host:port '
      '[--listen 47801] [faults]; see the header of this file',
    );
    exit(64);
  }
  final port = int.parse(options['listen'] ?? '47801');
  var refuseConnects = int.parse(options['refuse-connects'] ?? '0');
  var dropOk = int.parse(options['drop-ok'] ?? '0');
  final delayEose = int.parse(options['delay-eose-ms'] ?? '0');
  final delayAll = int.parse(options['delay-ms'] ?? '0');
  final neverEose = options.containsKey('never-eose');
  final closePrefix = options['close-req'];
  var closeCount = closePrefix == null
      ? 0
      : int.parse(options['close-req-count'] ?? '1');
  final maxSeconds = int.parse(options['max-seconds'] ?? '1800');

  final server = await HttpServer.bind(
    options.containsKey('bind-all')
        ? InternetAddress.anyIPv4
        : InternetAddress.loopbackIPv4,
    port,
  );
  _log({'event': 'listening', 'port': port, 'upstream': upstream});
  Timer(Duration(seconds: maxSeconds), () {
    _log({'event': 'exit', 'reason': 'max-seconds reached'});
    exit(0);
  });

  await for (final request in server) {
    if (refuseConnects > 0) {
      refuseConnects--;
      _log({'event': 'refused-connect', 'remaining': refuseConnects});
      request.response.statusCode = HttpStatus.serviceUnavailable;
      await request.response.close();
      continue;
    }
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      // Relay information document (NIP-11) and anything else over plain HTTP.
      await _forwardHttp(request, upstream);
      continue;
    }
    // Compression off on both legs: some clients reject the deflate parameters
    // dart:io offers, and the proxy has to read every frame anyway.
    final client = await WebSocketTransformer.upgrade(
      request,
      compression: CompressionOptions.compressionOff,
    );
    final WebSocket relay;
    try {
      relay = await WebSocket.connect(
        upstream,
        compression: CompressionOptions.compressionOff,
      );
    } on Object catch (error) {
      _log({'event': 'upstream-connect-failed', 'error': '$error'});
      await client.close(WebSocketStatus.internalServerError);
      continue;
    }
    _log({'event': 'client-connected'});

    client.listen(
      (data) {
        final type = _frameType(data);
        if (type == 'REQ' && closeCount > 0) {
          closeCount--;
          final sub = (jsonDecode(data as String) as List)[1];
          client.add(jsonEncode(['CLOSED', sub, '$closePrefix: injected']));
          _log({
            'dir': 'c>r',
            'type': type,
            'bytes': _size(data),
            'action': 'refused-with-CLOSED',
            'frame': _frame(data),
          });
          return;
        }
        relay.add(data);
        _log({
          'dir': 'c>r',
          'type': type,
          'bytes': _size(data),
          'action': 'forwarded',
          'frame': _frame(data),
        });
      },
      onDone: relay.close,
      onError: (Object _) => relay.close(),
    );

    // Relay-to-client frames go through one queue so delays keep their order.
    var queue = Future<void>.value();
    relay.listen(
      (data) {
        queue = queue.then((_) async {
          final type = _frameType(data);
          var action = 'forwarded';
          if (type == 'OK' && dropOk > 0) {
            dropOk--;
            action = 'dropped';
          } else if (type == 'EOSE' && neverEose) {
            action = 'dropped';
          } else {
            final hold = delayAll + (type == 'EOSE' ? delayEose : 0);
            if (hold > 0) {
              await Future<void>.delayed(Duration(milliseconds: hold));
              action = 'delayed ${hold}ms';
            }
            if (client.closeCode == null) client.add(data);
          }
          _log({
            'dir': 'r>c',
            'type': type,
            'bytes': _size(data),
            'action': action,
            'frame': _frame(data),
          });
        });
      },
      onDone: client.close,
      onError: (Object _) => client.close(),
    );
  }
}

Future<void> _forwardHttp(HttpRequest request, String upstream) async {
  final target = Uri.parse(upstream.replaceFirst(RegExp('^ws'), 'http'))
      .replace(path: request.uri.path, query: request.uri.query);
  final httpClient = HttpClient();
  try {
    final outgoing = await httpClient.openUrl(request.method, target);
    final accept = request.headers.value(HttpHeaders.acceptHeader);
    if (accept != null) outgoing.headers.set(HttpHeaders.acceptHeader, accept);
    final incoming = await outgoing.close();
    request.response.statusCode = incoming.statusCode;
    final contentType = incoming.headers.contentType;
    if (contentType != null) request.response.headers.contentType = contentType;
    await incoming.pipe(request.response);
    _log({
      'event': 'http',
      'path': request.uri.path,
      'status': incoming.statusCode,
    });
  } on Object catch (error) {
    _log({'event': 'http-failed', 'error': '$error'});
    request.response.statusCode = HttpStatus.badGateway;
    await request.response.close();
  } finally {
    httpClient.close();
  }
}
