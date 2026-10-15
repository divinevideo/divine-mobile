// Throwaway relay compatibility probe. Reads public event JSON only.
import 'dart:convert';
import 'dart:io';

import '../../../mobile/packages/nostr_sdk/lib/event.dart' as nostr;

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    throw ArgumentError(
      'Usage: relay_round_trip.dart <loopback-ws-url> <public-event.json>',
    );
  }
  final uri = Uri.parse(args[0]);
  if (uri.scheme != 'ws' ||
      !['127.0.0.1', 'localhost', '::1'].contains(uri.host)) {
    throw ArgumentError(
      'This throwaway probe only publishes to a local test relay',
    );
  }
  final event =
      jsonDecode(File(args[1]).readAsStringSync()) as Map<String, dynamic>;
  final parsed = nostr.Event.fromJson(event);
  if (!parsed.isValid || !parsed.isSigned)
    throw StateError('Invalid input event');
  // Try an invalid signature before publishing the valid event, so a relay
  // cannot pass this probe by accepting arbitrary JSON or returning a duplicate.
  final signature = event['sig'] as String;
  final bad = {
    ...event,
    'sig': '${signature[0] == '0' ? '1' : '0'}${signature.substring(1)}',
  };
  final socket = await WebSocket.connect(
    uri.toString(),
  ).timeout(const Duration(seconds: 10));
  try {
    var stage = 0;
    socket.add(jsonEncode(['EVENT', bad]));
    await for (final data in socket.timeout(const Duration(seconds: 10))) {
      final message = jsonDecode(data as String) as List<dynamic>;
      if (message[0] == 'OK' && message[1] == event['id']) {
        if (stage == 0) {
          if (message[2] != false)
            throw StateError('Relay accepted an invalid signature');
          stage = 1;
          socket.add(jsonEncode(['EVENT', event]));
        } else if (stage == 1) {
          if (message[2] != true)
            throw StateError(
              'Relay rejected the valid threshold event: ${message.length > 3 ? message[3] : 'no reason'}',
            );
          stage = 2;
          socket.add(
            jsonEncode([
              'REQ',
              'spike',
              {
                'ids': [event['id']],
              },
            ]),
          );
        }
      } else if (message[0] == 'EVENT' && stage == 2 && message[1] == 'spike') {
        final received = nostr.Event.fromJson(
          message[2] as Map<String, dynamic>,
        );
        if (received.id != parsed.id ||
            !received.isValid ||
            !received.isSigned) {
          throw StateError('Relay read-back did not match the valid event');
        }
        socket.add(jsonEncode(['CLOSE', 'spike']));
        stdout.writeln(
          'Invalid signature rejected; threshold event accepted and read back; Divine SDK verified.',
        );
        return;
      } else if (message[0] == 'EOSE' && stage == 2 && message[1] == 'spike') {
        throw StateError('Relay did not return the published event');
      }
    }
    throw StateError('Relay closed before completing the probe');
  } finally {
    await socket.close();
  }
}
