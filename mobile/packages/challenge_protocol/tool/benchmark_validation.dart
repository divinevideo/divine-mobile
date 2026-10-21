// Reproducible local measurement, not a latency guarantee or CI speed test.
import 'dart:convert';
import 'dart:io';

import 'package:challenge_protocol/challenge_protocol.dart';

import '../test/synthetic.dart';

void main() {
  final signer = SyntheticSigner();
  final original = definitionOf(signer.definition());
  final baseline = original.event.toJson();
  Map<String, Object?> sized(String host) {
    Map<String, Object?> event(int padding) => signer.definition(
      createdAt: 150,
      relay: 'wss://$host',
      extra: [
        ['padding', 'a' * padding],
      ],
    );
    return event(65536 - utf8.encode(jsonEncode(event(0))).length);
  }

  final records = {
    'baseline': baseline,
    'combining': sized('a${'\u0301' * 28000}'),
    'alternating': sized('a${'\u0301\u0316' * 14000}'),
    'ace': sized('xn--${'a' * 58000}'),
  };
  final older = List.generate(49, (i) => signer.definition(createdAt: 100 + i));
  for (final item in records.entries) {
    if (item.key != 'baseline' &&
        utf8.encode(jsonEncode(item.value)).length != 65536) {
      throw StateError('Benchmark record must be exactly 64 KiB');
    }
    if (parseChallengeEvent(item.value).ok != (item.key != 'ace')) {
      throw StateError('Unexpected parser verdict for ${item.key}');
    }
    _measure('parse/${item.key}', () => parseChallengeEvent(item.value));
    _measure(
      'reduce50/${item.key}',
      () => reduceChallenge(
        [...older, item.value],
        original.coordinate,
        175,
        (_) => true,
      ),
    );
  }

  final foreign = SyntheticSigner();
  Map<String, Object?> entry(int sequence, int padding) => signer.sign(
    kind: 1111,
    createdAt: 150 + sequence,
    tags: [
      ['t', 'divine-challenge'],
      ['challenge', '1', 'entry'],
      ['A', original.coordinate],
      ['K', '31923'],
      ['P', original.event.pubkey],
      [
        'challenge_snapshot',
        jsonEncode(
          foreign.definition(
            relay: 'wss://a${'\u0301\u0316' * 14000}',
            extra: [
              ['padding', 'a' * padding],
            ],
          ),
        ),
      ],
    ],
  );
  final padding = 65536 - utf8.encode(jsonEncode(entry(0, 0))).length;
  final entries = List.generate(49, (i) => entry(i, padding));
  if (utf8.encode(jsonEncode(entries.first)).length != 65536 ||
      parseChallengeEvent(entries.first).code != 'parent') {
    throw StateError('Foreign snapshot must reach authenticated parent check');
  }
  _measure('parse/foreign-snapshot', () => parseChallengeEvent(entries.first));
  _measure(
    'reduce50/foreign-snapshots',
    () => reduceChallenge(
      [baseline, ...entries],
      original.coordinate,
      175,
      (_) => true,
    ),
  );
}

void _measure(String name, Object? Function() action) {
  action();
  final samples = <double>[];
  for (var i = 0; i < 5; i++) {
    final watch = Stopwatch()..start();
    action();
    watch.stop();
    samples.add(watch.elapsedMicroseconds / 1000);
  }
  samples.sort();
  // This command-line benchmark writes its measurements to standard output.
  stdout.writeln(
    jsonEncode({'case': name, 'median_ms': samples[2], 'samples_ms': samples}),
  );
}
