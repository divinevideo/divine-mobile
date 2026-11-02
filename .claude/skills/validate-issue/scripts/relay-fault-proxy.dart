// Fault-injecting WebSocket proxy for Nostr relay traffic.
//
// Puts a relay you control between the app and its relay so a refusal, a lost
// OK or a slow EOSE happens on demand. Tooling for the validate-issue skill:
// run it from the skill directory with `dart`; nothing in the app imports it.
// `relay-fault-proxy-selftest.dart` beside it exercises every fault below.
//
//   dart relay-fault-proxy.dart --upstream ws://localhost:10547 [--listen 47801] [faults]
//
// Faults. Counts are for the proxy's lifetime; "per connection" counts restart
// on every connection the fault is applied to. A delay counts from when the
// relay sent the frame, so holds do not add up; relay frames keep their order,
// so a frame behind a held one arrives with it.
//   --refuse-connects N     answer the first N WebSocket handshakes with HTTP 503.
//                           Plain HTTP (the NIP-11 document) is forwarded and
//                           never counted, so a client that fetches NIP-11
//                           before it connects still meets the refusal
//   --drop-ok N             swallow the first N ["OK", ...] frames from the relay
//   --delay-ok-ms MS        hold every OK for MS: a late OK after the client
//                           gave up (the relay stored the event)
//   --delay-eose-ms MS      hold every ["EOSE", ...] frame for MS
//   --delay-ms MS           hold every relay-to-client frame for MS
//   --never-eose            swallow every EOSE (a REQ that never terminates)
//   --close-req PREFIX      answer REQs with ["CLOSED", sub, "PREFIX: injected"]
//   --close-req-count N     how many REQs to refuse that way (default 1)
//   --drop-event N          swallow the first N client EVENTs: the relay never
//                           saw them and nothing answers (not the same as a
//                           lost OK)
//   --reject-event PREFIX   answer client EVENTs with ["OK", id, false,
//                           "PREFIX: injected"] without forwarding them
//                           (rate-limited, error, restricted, ...)
//   --reject-event-count N  how many EVENTs to reject that way (default 1)
//   --duplicate-event N     deliver the first N relay EVENT frames twice
//   --close-after N         after N relay frames on a connection, close the
//                           client socket with code 4000 (a close frame, not a
//                           TCP reset; ending the proxy process drops sockets
//                           with no close frame at all)
//   --close-after-count K   how many connections get that (default 1)
//   --stall-after N         after N relay frames on a connection, deliver
//                           nothing more in either direction, a close from
//                           the relay included, and keep the socket open: a
//                           half-open connection
//   --stall-after-ms MS     the same, MS after the connection opens: the way to
//                           stall a connection that is idle, which no frame
//                           count can reach
//   --stall-after-count K   how many connections get either (default 1)
// Other:
//   (plain HTTP)            forwarded with its method, path, query and Accept header
//                           only: no body and no Authorization, so a request that
//                           needs a body answers 415 and an authenticated
//                           endpoint 401
//   --bind-all              listen on every interface (a phone on the LAN), not just loopback
//   --max-seconds S         exit after S seconds (default 1800) so it cannot outlive the session
//
// stdout: one JSON object per frame {t, conn, dir, type, bytes, action, frame},
// and per event {t, conn, event, ...}. conn numbers the WebSocket connections in
// the order they open: an app can hold several to one relay.
// Frames are logged whole: a cut frame can cut an event id or pubkey.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _knownOptions = {
  'upstream',
  'listen',
  'refuse-connects',
  'drop-ok',
  'delay-ok-ms',
  'delay-eose-ms',
  'delay-ms',
  'never-eose',
  'close-req',
  'close-req-count',
  'drop-event',
  'reject-event',
  'reject-event-count',
  'duplicate-event',
  'close-after',
  'close-after-count',
  'stall-after',
  'stall-after-ms',
  'stall-after-count',
  'bind-all',
  'max-seconds',
};

const _injectedCloseCode = 4000;

void _log(Map<String, Object?> entry) {
  stdout.writeln(
    jsonEncode({'t': DateTime.now().toUtc().toIso8601String(), ...entry}),
  );
}

Never _usage(String problem) {
  stderr.writeln(
    '$problem\n'
    'usage: dart relay-fault-proxy.dart --upstream ws://host:port '
    '[--listen 47801] [faults]; see the header of this file',
  );
  exit(64);
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

// A REQ's subscription id; null for a malformed REQ, which the relay answers.
Object? _subscriptionId(String frame) {
  final decoded = jsonDecode(frame);
  return decoded is List && decoded.length > 1 ? decoded[1] : null;
}

// The id of the event in a client ["EVENT", {...}] frame; null when absent.
String? _eventId(String frame) {
  final decoded = jsonDecode(frame);
  if (decoded is! List || decoded.length < 2) return null;
  final event = decoded[1];
  if (event is! Map) return null;
  final id = event['id'];
  return id is String ? id : null;
}

String _frame(Object? data) =>
    data is String ? data : '<${(data as List).length} bytes>';

int _size(Object? data) =>
    data is String ? utf8.encode(data).length : (data as List).length;

Map<String, String> _parse(List<String> args) {
  final options = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) _usage('unexpected argument "$arg"');
    final name = arg.substring(2);
    if (!_knownOptions.contains(name)) _usage('unknown option "$arg"');
    final hasValue = i + 1 < args.length && !args[i + 1].startsWith('--');
    options[name] = hasValue ? args[++i] : 'true';
  }
  return options;
}

int _count(Map<String, String> options, String name, [int fallback = 0]) {
  final raw = options[name];
  if (raw == null) return fallback;
  final value = int.tryParse(raw);
  if (value == null || value < 0) {
    _usage('--$name expects a whole number, got "$raw"');
  }
  return value;
}

Future<void> main(List<String> args) async {
  final options = _parse(args);
  final upstream = options['upstream'];
  if (upstream == null) _usage('--upstream is required');
  final port = _count(options, 'listen', 47801);
  var refuseConnects = _count(options, 'refuse-connects');
  var dropOk = _count(options, 'drop-ok');
  final delayOk = _count(options, 'delay-ok-ms');
  final delayEose = _count(options, 'delay-eose-ms');
  final delayAll = _count(options, 'delay-ms');
  final neverEose = options.containsKey('never-eose');
  final closePrefix = options['close-req'];
  var closeCount = closePrefix == null
      ? 0
      : _count(options, 'close-req-count', 1);
  var dropEvent = _count(options, 'drop-event');
  final rejectPrefix = options['reject-event'];
  var rejectCount = rejectPrefix == null
      ? 0
      : _count(options, 'reject-event-count', 1);
  var duplicateEvent = _count(options, 'duplicate-event');
  final closeAfter = _count(options, 'close-after');
  var closeAfterLeft = closeAfter == 0
      ? 0
      : _count(options, 'close-after-count', 1);
  final stallAfter = _count(options, 'stall-after');
  final stallAfterMs = _count(options, 'stall-after-ms');
  var stallAfterLeft = stallAfter == 0 && stallAfterMs == 0
      ? 0
      : _count(options, 'stall-after-count', 1);
  final maxSeconds = _count(options, 'max-seconds', 1800);

  final server = await HttpServer.bind(
    options.containsKey('bind-all')
        ? InternetAddress.anyIPv4
        : InternetAddress.loopbackIPv4,
    port,
  );
  _log({'event': 'listening', 'port': server.port, 'upstream': upstream});
  Timer(Duration(seconds: maxSeconds), () {
    _log({'event': 'exit', 'reason': 'max-seconds reached'});
    exit(0);
  });

  var connections = 0;

  Future<void> serve(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      // Relay information document (NIP-11) and anything else over plain HTTP.
      await _forwardHttp(request, upstream);
      return;
    }
    if (refuseConnects > 0) {
      refuseConnects--;
      _log({'event': 'refused-connect', 'remaining': refuseConnects});
      request.response.statusCode = HttpStatus.serviceUnavailable;
      await request.response.close();
      return;
    }
    // Numbered in the order the sockets open, so a log from an app that holds
    // several connections to one relay says which one each line belongs to.
    final conn = ++connections;
    void log(Map<String, Object?> entry) => _log({'conn': conn, ...entry});
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
      log({'event': 'upstream-connect-failed', 'error': '$error'});
      await client.close(WebSocketStatus.internalServerError);
      return;
    }
    log({'event': 'client-connected'});

    // Chosen once per connection, so a reconnect after the fault is clean.
    final closeThisOne = closeAfterLeft > 0 && closeAfterLeft-- > 0;
    final stallThisOne = stallAfterLeft > 0 && stallAfterLeft-- > 0;
    var relayFrames = 0;
    var stalled = false;
    Timer? stallTimer;
    if (stallThisOne && stallAfterMs > 0) {
      stallTimer = Timer(Duration(milliseconds: stallAfterMs), () {
        if (stalled) return;
        stalled = true;
        log({'event': 'stalled', 'after_ms': stallAfterMs});
      });
    }
    final clock = Stopwatch()..start();

    // Set when the relay leg ends so client->relay frames stop. The client
    // close is scheduled after the relay->client queue drains, so the last
    // OK/CLOSED/NOTICE the relay sent before disconnecting is not dropped.
    var queue = Future<void>.value();
    var relayEnded = false;
    var clientClosed = false;
    void endRelay() {
      if (relayEnded) return;
      relayEnded = true;
      stallTimer?.cancel();
      // A half-open socket never hears its peer close, so a stalled connection
      // keeps the client's socket as it is.
      log({'event': 'relay-closed', 'told_client': !stalled});
      if (stalled) return;
      queue = queue.then((_) {
        clientClosed = true;
        client.close();
      });
    }

    void logClientFrame(Object? data, String type, String action) => log({
      'dir': 'c>r',
      'type': type,
      'bytes': _size(data),
      'action': action,
      'frame': _frame(data),
    });

    client.listen(
      (data) {
        final type = _frameType(data);
        if (relayEnded) {
          logClientFrame(data, type, 'dropped: relay closed');
          return;
        }
        if (stalled) {
          logClientFrame(data, type, 'dropped: stalled');
          return;
        }
        final sub = type == 'REQ' ? _subscriptionId(data as String) : null;
        if (sub != null && closeCount > 0) {
          closeCount--;
          client.add(jsonEncode(['CLOSED', sub, '$closePrefix: injected']));
          logClientFrame(data, type, 'refused-with-CLOSED');
          return;
        }
        if (type == 'EVENT' && dropEvent > 0) {
          dropEvent--;
          logClientFrame(data, type, 'dropped: never reached the relay');
          return;
        }
        final eventId = type == 'EVENT' && rejectCount > 0
            ? _eventId(data as String)
            : null;
        if (eventId != null) {
          rejectCount--;
          client.add(
            jsonEncode(['OK', eventId, false, '$rejectPrefix: injected']),
          );
          logClientFrame(data, type, 'rejected-with-OK-false');
          return;
        }
        relay.add(data);
        logClientFrame(data, type, 'forwarded');
      },
      onDone: () {
        stallTimer?.cancel();
        log({'event': 'client-closed'});
        unawaited(relay.close());
      },
      onError: (Object _) {
        stallTimer?.cancel();
        unawaited(relay.close());
      },
    );

    // Relay-to-client frames go through one queue so delays keep their order.
    relay.listen(
      (data) {
        // A hold runs from the frame's arrival, so held frames do not add up.
        final arrived = clock.elapsed;
        queue = queue.then((_) async {
          final type = _frameType(data);
          relayFrames++;
          var action = 'forwarded';
          var copies = 1;
          if (stalled) {
            action = 'dropped: stalled';
            copies = 0;
          } else if (type == 'OK' && dropOk > 0) {
            dropOk--;
            action = 'dropped';
            copies = 0;
          } else if (type == 'EOSE' && neverEose) {
            action = 'dropped';
            copies = 0;
          } else {
            if (type == 'EVENT' && duplicateEvent > 0) {
              duplicateEvent--;
              copies = 2;
            }
            final hold =
                delayAll +
                (type == 'EOSE' ? delayEose : 0) +
                (type == 'OK' ? delayOk : 0);
            if (hold > 0) {
              final wait =
                  arrived + Duration(milliseconds: hold) - clock.elapsed;
              if (wait > Duration.zero) await Future<void>.delayed(wait);
              action = 'delayed ${hold}ms';
            }
            if (clientClosed || client.closeCode != null) {
              action = 'dropped: client closed';
              copies = 0;
            } else {
              for (var i = 0; i < copies; i++) {
                client.add(data);
              }
              if (copies > 1) action = '$action, sent twice';
            }
          }
          log({
            'dir': 'r>c',
            'type': type,
            'bytes': _size(data),
            'action': action,
            'frame': _frame(data),
          });
          if (stallThisOne &&
              stallAfter > 0 &&
              relayFrames >= stallAfter &&
              !stalled) {
            stalled = true;
            log({'event': 'stalled', 'after_relay_frames': relayFrames});
          }
          if (closeThisOne && relayFrames >= closeAfter && !clientClosed) {
            clientClosed = true;
            log({'event': 'closing-client', 'code': _injectedCloseCode});
            unawaited(
              client.close(_injectedCloseCode, 'proxy: injected close'),
            );
            unawaited(relay.close());
          }
        });
      },
      onDone: endRelay,
      onError: (Object _) => endRelay(),
    );
  }

  // Each connection is served on its own: a stalled upstream connect for one
  // client must not hold up the next client's handshake. Its own error zone
  // also catches what its socket listeners throw later, so a failure in one
  // connection is logged and never ends the proxy.
  await for (final request in server) {
    runZonedGuarded(
      () => unawaited(serve(request)),
      (error, _) => _log({'event': 'connection-failed', 'error': '$error'}),
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
