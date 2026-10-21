import 'dart:convert';

import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:test/test.dart';

import 'synthetic.dart';

void main() {
  late SyntheticSigner signer;
  late ChallengeDefinition original;
  setUpAll(() {
    signer = SyntheticSigner();
    original = definitionOf(signer.definition());
  });

  // Expected verdicts independently checked through canonical new URL().
  const relays = <String, bool>{
    'wss://relay.example': true,
    'ws:relay.example': true,
    r'WSS:\\relay.example\path': true,
    ' \twss://relay.example\r\n': true,
    'wss://:@relay.example': true,
    'wss://@relay.example': true,
    'wss://user@relay.example': false,
    'wss://:password@relay.example': false,
    'wss://::@relay.example': false,
    'wss://@@relay.example': false,
    'wss://relay.example#': true,
    'wss://relay.example#fragment': false,
    'wss://relay.example:65535/path?x=%zz': true,
    'wss://relay.example:65536': false,
    'wss://relay.example:abc': false,
    'wss://a b.example': false,
    'wss://a%20b.example': false,
    'wss://a%2Fb.example': false,
    'wss://a%5Cb.example': false,
    'wss://a%00b.example': false,
    'wss://a%zz.example': false,
    'wss://a%2.example': false,
    'wss://%72elay.example': true,
    'wss://1.2.3.256': false,
    'wss://999999999999': false,
    'wss://0xffffffff': true,
    'wss://0x100000000': false,
    'wss://0177.0.0.1': true,
    'wss://09': false,
    'wss://1.2.65535': true,
    'wss://1.2.65536': false,
    'wss://1.2.3.4.': true,
    'wss://1.2.3.4.5': false,
    'wss://example.123': false,
    'wss://[::1]': true,
    'wss://[::ffff:192.0.2.1]': true,
    'wss://[::ffff:192.0.2.256]': false,
    'wss://[fe80::1%25zone]': false,
    'wss://[1:2:3:4:5:6:7:8:9]': false,
    'wss://１２７。０。０。１': true,
    'wss://９９９９９９９９９９９９': false,
    'wss://a\u034fb.example': true,
    'wss://a\u200cb.example': false,
    'wss://%C0%AF.example': false,
    'wss://xn--a-ecp.example': false,
    'wss://bücher.example': true,
    'wss://xn--bcher-kva.example': true,
    'wss://xn--.example': false,
    'wss://\u200D.example': false,
    'wss://\uFF0F.example': false,
  };
  for (final item in relays.entries) {
    test('signed relay normalization ${item.key}', () {
      final replacement = signer.definition(createdAt: 110, relay: item.key);
      final parsed = parseChallengeEvent(replacement);
      expect(parsed.ok, item.value);
      if (!item.value) expect(parsed.code, 'relay');
      for (final events in [
        [original.event, replacement],
        [replacement, original.event],
      ]) {
        expect(
          reduceChallenge(events, original.coordinate, 150, (_) => true).state,
          item.value ? 'open' : 'unavailable',
        );
      }
    });
  }

  for (final item in <String, bool>{
    'wss://a${'\u0301' * 28000}': true,
    'wss://xn--${'a' * 58000}': false,
  }.entries) {
    test(
      'signed long ${item.value ? 'combining' : 'ACE'} host at 64 KiB',
      () {
        Map<String, Object?> event(int padding) => signer.definition(
          createdAt: 110,
          relay: item.key,
          extra: [
            ['padding', 'a' * padding],
          ],
        );
        final baseSize = utf8.encode(jsonEncode(event(0))).length;
        final atLimit = event(65536 - baseSize);
        expect(utf8.encode(jsonEncode(atLimit)).length, 65536);
        final parsed = parseChallengeEvent(atLimit);
        expect(parsed.ok, item.value);
        if (!item.value) expect(parsed.code, 'relay');
        final overLimit = event(65537 - baseSize);
        expect(parseChallengeEvent(overLimit).code, 'size');
        for (final newest in [atLimit, overLimit]) {
          for (final events in [
            [original.event, newest],
            [newest, original.event],
          ]) {
            expect(
              reduceChallenge(
                events,
                original.coordinate,
                150,
                (_) => true,
              ).state,
              identical(newest, atLimit) && item.value ? 'open' : 'unavailable',
            );
          }
        }
      },
      // Regression budget only, not a performance guarantee for callers.
      timeout: const Timeout(Duration(seconds: 30)),
    );
  }

  for (final zone in [
    'Pacific/\u212Airitimati',
    'Europe/\u212Aiev',
    'America/New_Yor\u212A',
  ]) {
    for (final endField in [false, true]) {
      test('ASCII timezone matching $zone end=$endField', () {
        final replacement = signer.definition(
          createdAt: 110,
          timezone: endField ? 'UTC' : zone,
          endTimezone: endField ? zone : 'UTC',
        );
        expect(parseChallengeEvent(replacement).code, 'timezone');
        for (final events in [
          [original.event, replacement],
          [replacement, original.event],
        ]) {
          expect(
            reduceChallenge(
              events,
              original.coordinate,
              150,
              (_) => true,
            ).state,
            'unavailable',
          );
        }
      });
    }
  }
}
