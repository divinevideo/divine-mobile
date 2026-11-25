import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/features/guest_classics/guest_classics_manifest.dart';

void main() {
  group(GuestClassicsManifest, () {
    final base = Uri.parse('https://example.test/seeds/');
    final now = DateTime.utc(2026, 11, 25);
    final item = {
      'event_id': 'ab' * 32,
      'sha256': 'cd' * 32,
      'video_url': 'https://media.divine.video/classic.mp4',
      'attribution': 'A creator',
      'original_loops': 750000000,
    };
    Map<String, Object> manifest() => {
      'schema_version': 1,
      'revision': 'pilot-1',
      'expires_at': now.add(const Duration(minutes: 10)).toIso8601String(),
      'items': [item],
    };

    test(
      'tries language files in order and falls back to shared visual clips',
      () async {
        final requested = <String>[];
        final client = MockClient((request) async {
          requested.add(request.url.path);
          expect(request.headers.containsKey('authorization'), isFalse);
          expect(request.url.query, isEmpty);
          return request.url.path.contains('/und/')
              ? http.Response(jsonEncode(manifest()), 200)
              : http.Response('', 404);
        });
        final result = await fetchGuestClassics(
          base: base,
          client: client,
          languages: ['ja', 'es', 'ja'],
          now: () => now,
        );
        expect(requested, [
          '/seeds/v1/ja/muted.json',
          '/seeds/v1/es/muted.json',
          '/seeds/v1/und/muted.json',
        ]);
        expect(result?.clips.single.attribution, 'A creator');
      },
    );

    test('only a valid explicit empty or missing locale continues to the next preference', () async {
      for (final first in [
        http.Response(jsonEncode({...manifest(), 'items': []}), 200),
        http.Response('', 410),
        http.Response('{invalid', 200),
        http.Response(' ' * 65537, 200),
        http.Response(
          jsonEncode({
            ...manifest(),
            'expires_at': now.toIso8601String(),
            'items': [],
          }),
          200,
        ),
        http.Response(
          jsonEncode({
            ...manifest(),
            'items': [{}],
          }),
          200,
        ),
      ]) {
        final paths = <String>[];
        final result = await fetchGuestClassics(
          base: base,
          client: MockClient((request) async {
            paths.add(request.url.path);
            return paths.length == 1
                ? first
                : http.Response(jsonEncode(manifest()), 200);
          }),
          languages: ['fr', 'ja'],
          now: () => now,
        );
        final shouldFallBack =
            first.body == jsonEncode({...manifest(), 'items': []});
        expect(result != null, shouldFallBack);
        expect(paths.length, shouldFallBack ? 2 : 1);
      }
    });

    test(
      'expired, unknown schema and insecure media yield no playable manifest',
      () {
        for (final data in [
          {...manifest(), 'expires_at': now.toIso8601String()},
          {...manifest(), 'schema_version': 2},
          {
            ...manifest(),
            'expires_at': now
                .add(const Duration(hours: 1, seconds: 1))
                .toIso8601String(),
          },
          {
            ...manifest(),
            'items': [
              {...item, 'video_url': 'file:///private.mp4'},
            ],
          },
        ]) {
          expect(GuestClassicsManifest.parse(data, now: now), isNull);
        }
      },
    );

    test('old manifests and invalid optional tags still play', () {
      for (final (tags, expected) in [
        (null, <String>[]),
        (['format:sketch', 'topic:music'], ['format:sketch', 'topic:music']),
        (['format:sketch', 'moderation:adult'], <String>[]),
        (['format:sketch', 'format:sketch'], <String>[]),
      ]) {
        final parsed = GuestClassicsManifest.parse({
          ...manifest(),
          'items': [
            {...item, 'discovery_tags': ?tags},
          ],
        }, now: now);
        expect(parsed?.clips.single.discoveryTags, expected);
      }
    });
  });
}
