import 'dart:convert';

import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:test/test.dart';

import 'fixture_file.dart';
import 'fixture_loader.dart';

void main() {
  final data = fixture('events.json');
  final cases = data['cases']! as List<Object?>;
  test('pinned manifest and complete parser corpus', () {
    final manifest = jsonDecode(
      fixtureFile('v1/manifest.json').readAsStringSync(),
    ) as Map<String, Object?>;
    expect(manifest['version'], 1);
    expect(manifest['convention'], 'divine-challenge');
    expect(manifest['synthetic'], true);
    expect(manifest['files'], fixtureHashes);
    expect(data['version'], 1);
    expect(cases, hasLength(89));
  });
  test('checksum mismatch fails before JSON decoding', () {
    expect(
      () => decodeFixture('events.json', utf8.encode('not JSON')),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'Fixture checksum mismatch',
        ),
      ),
    );
  });
  for (final item in cases) {
    final c = item! as Map<String, Object?>;
    test(c['name']! as String, () {
      final expected = c['expected']! as Map<String, Object?>;
      final actual = parseChallengeEvent(c['event']);
      expect(actual.ok, expected['ok']);
      if (actual.ok) {
        expect(actual.value!.action, expected['action']);
      } else {
        expect(actual.code, expected['code']);
      }
    });
  }
}
