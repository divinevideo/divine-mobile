import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infinite_video_feed/src/services/bunny_playback_selector.dart';
import 'package:models/models.dart';

const hash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const path = '/$hash/hls/master.m3u8';
VideoEvent video([String? url]) => VideoEvent(
  id: 'event',
  pubkey: 'pubkey',
  createdAt: 0,
  content: '',
  timestamp: DateTime(2024),
  videoUrl: url ?? 'https://media.divine.video/$hash',
);
String ready({
  String host = 'media-bunny.divine.video',
  List<String> paths = const [path],
  int version = 1,
}) => jsonEncode({'version': version, 'host': host, 'paths': paths});

void main() {
  group('BunnyPlaybackSelector', () {
    test(
      'requests only canonical selection and validates a complete HLS choice',
      () async {
        Uri? requested;
        Map<String, String>? headers;
        final selector = BunnyPlaybackSelector(
          client: MockClient((request) async {
            requested = request.url;
            headers = request.headers;
            return http.Response(ready(), 200);
          }),
        );
        expect(await selector.select(video()), {path});
        expect(
          requested.toString(),
          'https://media.divine.video/api/bunny-playback/$hash',
        );
        expect(headers, isNot(contains('authorization')));
        expect(
          await selector.select(video('https://media.divine.video$path')),
          {path},
        );
      },
    );

    test(
      'does not request signed, noncanonical, child or encoded event URLs',
      () async {
        var calls = 0;
        final selector = BunnyPlaybackSelector(
          client: MockClient((_) async {
            calls++;
            return http.Response(ready(), 200);
          }),
        );
        for (final url in [
          'https://media.divine.video/$hash?token=private',
          'https://media.divine.video/$hash#fragment',
          'https://media-bunny.divine.video/$hash',
          'https://media.divine.video:443/$hash',
          'https://media.divine.video/$hash/hls/stream_720p.m3u8',
          'https://media.divine.video/%61$hash',
        ]) {
          expect(await selector.select(video(url)), isEmpty);
        }
        expect(calls, 0);
      },
    );

    test(
      'rejects untrusted host, version, parent, child and oversized inventory',
      () async {
        for (final body in [
          ready(host: 'example.test'),
          ready(version: 2),
          ready(
            paths: [
              '/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            ],
          ),
          ready(paths: ['$path?token=private']),
          ready(paths: ['/$hash/hls/stream_720p.m3u8']),
          ready(paths: ['https://media-bunny.divine.video$path']),
          ready(paths: List.filled(9, path)),
          '{',
          '[]',
          ready() + (' ' * 8192),
          jsonEncode({
            'version': 1,
            'host': 'media-bunny.divine.video',
            'paths': [1],
          }),
        ]) {
          final selector = BunnyPlaybackSelector(
            client: MockClient((_) async => http.Response(body, 200)),
          );
          expect(
            await selector.select(video()),
            isEmpty,
            reason: body.substring(0, body.length.clamp(0, 100)),
          );
        }
      },
    );

    test(
      'accepts only exact top-level ready objects, including empty cohorts',
      () async {
        for (final paths in [
          <String>[],
          ['/$hash', '/$hash/720p.mp4', '/$hash/480p.mp4', path],
        ]) {
          final selector = BunnyPlaybackSelector(
            client: MockClient(
              (_) async => http.Response(ready(paths: paths), 200),
            ),
          );
          expect(await selector.select(video()), paths.toSet());
        }
      },
    );

    test(
      'policy denial blocks playback; service errors retain canonical',
      () async {
        for (final status in [401, 403, 404]) {
          final selector = BunnyPlaybackSelector(
            client: MockClient((_) async => http.Response('', status)),
          );
          await expectLater(
            selector.select(video()),
            throwsA(isA<BunnyPlaybackDenied>()),
          );
        }
        for (final status in [302, 429, 500, 503]) {
          final selector = BunnyPlaybackSelector(
            client: MockClient((_) async => http.Response('', status)),
          );
          expect(await selector.select(video()), isEmpty);
        }
        final selector = BunnyPlaybackSelector(
          client: MockClient(
            (_) async => throw http.ClientException('offline'),
          ),
        );
        expect(await selector.select(video()), isEmpty);
      },
    );

    test(
      'deduplicates in-flight parents and expires within thirty seconds',
      () async {
        var now = DateTime(2026);
        var calls = 0;
        final response = Completer<http.Response>();
        final selector = BunnyPlaybackSelector(
          now: () => now,
          client: MockClient((_) {
            calls++;
            return response.future;
          }),
        );
        final first = selector.select(video());
        final duplicate = selector.select(video());
        response.complete(http.Response(ready(), 200));
        expect(await first, {path});
        expect(await duplicate, {path});
        expect(calls, 1);
        expect(await selector.select(video()), {path});
        expect(calls, 1);
        now = now.add(const Duration(seconds: 30));
        expect(await selector.select(video()), {path});
        expect(calls, 2);
      },
    );

    test('bounds concurrent parents and evicts old cached choices', () async {
      final response = Completer<http.Response>();
      var calls = 0;
      final selector = BunnyPlaybackSelector(
        client: MockClient((request) {
          expect(request.followRedirects, isFalse);
          calls++;
          return response.future;
        }),
      );
      String url(int i) =>
          'https://media.divine.video/${i.toRadixString(16).padLeft(64, '0')}';
      final pending = [
        for (var i = 0; i < 8; i++) selector.select(video(url(i))),
      ];
      expect(await selector.select(video(url(8))), isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 8);
      response.complete(http.Response(ready(paths: []), 200));
      await Future.wait(pending);
      for (var i = 8; i < 257; i++) {
        expect(await selector.select(video(url(i))), isEmpty);
      }
      expect(calls, 257);
      expect(await selector.select(video(url(0))), isEmpty);
      expect(calls, 258);
    });

    test('times out instead of holding playback', () async {
      final selector = BunnyPlaybackSelector(
        timeout: const Duration(milliseconds: 5),
        client: MockClient((_) => Completer<http.Response>().future),
      );
      expect(await selector.select(video()), isEmpty);
    });
  });
}
