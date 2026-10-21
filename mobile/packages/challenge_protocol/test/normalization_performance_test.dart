import 'dart:convert';

import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:test/test.dart';

import 'synthetic.dart';

void main() {
  for (final marks in ['\u0301' * 28000, '\u0301\u0316' * 14000]) {
    test('bounded signed normalization ${marks.codeUnitAt(1)}', () {
      final signer = SyntheticSigner();
      Map<String, Object?> record(int padding) => signer.definition(
        relay: 'wss://a$marks',
        extra: [
          ['padding', 'a' * padding],
        ],
      );
      final size = utf8.encode(jsonEncode(record(0))).length;
      final event = record(65536 - size);
      expect(utf8.encode(jsonEncode(event)).length, 65536);
      // Compile/warm the same path before measuring, excluding signing/setup.
      expect(parseChallengeEvent(event).ok, isTrue);
      final watch = Stopwatch()..start();
      expect(parseChallengeEvent(event).ok, isTrue);
      watch.stop();
      // A regression budget, not a latency guarantee on caller devices.
      expect(watch.elapsedMilliseconds, lessThan(1000));
    });
  }
}
