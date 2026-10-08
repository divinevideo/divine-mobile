// ABOUTME: Tests for the shared fetchSubtitleCues fallback chain.
// ABOUTME: Verifies embedded content, ordered HTTP refs, and relay ref fallback.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/services/subtitle_fetcher.dart';

class _FakeClient extends http.BaseClient {
  _FakeClient(this.handler);
  final Future<http.Response> Function(http.Request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final res = await handler(request as http.Request);
    return http.StreamedResponse(
      Stream.value(res.bodyBytes),
      res.statusCode,
      headers: res.headers,
    );
  }
}

const _vtt = 'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nhello\n';
const _unicodeVtt =
    'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nGöbekli\n\n'
    '00:00:01.000 --> 00:00:02.000\n你好 🌿\n';

void main() {
  group('fetchSubtitleCues', () {
    test('decodes HTTP ref VTT as UTF-8 without a charset', () async {
      final result = await fetchSubtitleCues(
        httpClient: _FakeClient(
          (_) async => http.Response.bytes(
            utf8.encode(_unicodeVtt),
            200,
            headers: const {'content-type': 'text/vtt'},
          ),
        ),
        nostrClient: null,
        delay: (_) async {},
        textTrackRefs: const ['https://media.divine.video/edited.vtt'],
      );

      expect(result.status, SubtitleFetchStatus.available);
      expect(result.cues.map((cue) => cue.text), equals(['Göbekli', '你好 🌿']));
    });

    test('decodes Blossom VTT as UTF-8 without a charset', () async {
      final result = await fetchSubtitleCues(
        httpClient: _FakeClient(
          (_) async => http.Response.bytes(
            utf8.encode(_unicodeVtt),
            200,
            headers: const {'content-type': 'text/vtt'},
          ),
        ),
        nostrClient: null,
        delay: (_) async {},
        sha256: 'abc123',
      );

      expect(result.status, SubtitleFetchStatus.available);
      expect(result.cues.map((cue) => cue.text), equals(['Göbekli', '你好 🌿']));
    });

    test('requests the Blossom transcript with the language query', () async {
      Uri? requested;
      final result = await fetchSubtitleCues(
        httpClient: _FakeClient((request) async {
          requested = request.url;
          return http.Response(_vtt, 200);
        }),
        nostrClient: null,
        delay: (_) async {},
        sha256: 'abc123',
        lang: 'es',
      );

      expect(result.status, SubtitleFetchStatus.available);
      expect(requested?.queryParameters['lang'], equals('es'));
    });

    test('omits the language query when lang is null', () async {
      Uri? requested;
      await fetchSubtitleCues(
        httpClient: _FakeClient((request) async {
          requested = request.url;
          return http.Response(_vtt, 200);
        }),
        nostrClient: null,
        delay: (_) async {},
        sha256: 'abc123',
      );

      expect(requested, isNotNull);
      expect(requested!.queryParameters.containsKey('lang'), isFalse);
    });

    test('parses embedded textTrackContent first (no network)', () async {
      final result = await fetchSubtitleCues(
        httpClient: _FakeClient((_) async => throw StateError('no network')),
        nostrClient: null,
        delay: (_) async {},
        textTrackContent: _vtt,
      );
      expect(result.status, SubtitleFetchStatus.available);
      expect(result.cues, hasLength(1));
      expect(result.cues.first.text, equals('hello'));
    });

    test('can prefer refs before embedded textTrackContent', () async {
      final result = await fetchSubtitleCues(
        httpClient: _FakeClient(
          (_) async => http.Response(
            'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nedited\n',
            200,
          ),
        ),
        nostrClient: null,
        delay: (_) async {},
        textTrackContent: 'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nstale\n',
        textTrackRefs: const ['https://media.divine.video/edited.vtt'],
        sourcePreference: SubtitleSourcePreference.refsFirst,
      );

      expect(result.cues, hasLength(1));
      expect(result.cues.first.text, equals('edited'));
    });

    test(
      'falls back to second ref when first http ref is unavailable',
      () async {
        final result = await fetchSubtitleCues(
          httpClient: _FakeClient((req) async {
            if (req.url.toString() == 'https://media.divine.video/dead') {
              return http.Response('', 404);
            }
            if (req.url.toString() == 'https://media.divine.video/live') {
              return http.Response(_vtt, 200);
            }
            return http.Response('', 500);
          }),
          nostrClient: null,
          delay: (_) async {},
          textTrackRefs: const [
            'https://media.divine.video/dead',
            'https://media.divine.video/live',
          ],
        );
        expect(result.cues, hasLength(1));
        expect(result.cues.first.text, equals('hello'));
      },
    );

    test('keeps trying later sources after a cue-less ref', () async {
      final result = await fetchSubtitleCues(
        httpClient: _FakeClient((req) async {
          if (req.url.toString() == 'https://media.divine.video/silent.vtt') {
            return http.Response('WEBVTT\n\n', 200);
          }
          if (req.url.toString() == 'https://media.divine.video/abc123/vtt') {
            return http.Response(_vtt, 200);
          }
          return http.Response('', 404);
        }),
        nostrClient: null,
        delay: (_) async {},
        textTrackRefs: const ['https://media.divine.video/silent.vtt'],
        sha256: 'abc123',
      );

      expect(result.status, SubtitleFetchStatus.available);
      expect(result.cues.first.text, equals('hello'));
    });

    test('reports empty when a served track holds no cues', () async {
      final result = await fetchSubtitleCues(
        httpClient: _FakeClient((_) async => http.Response('WEBVTT\n\n', 200)),
        nostrClient: null,
        delay: (_) async {},
        sha256: 'abc123',
      );

      expect(result.status, SubtitleFetchStatus.empty);
      expect(result.cues, isEmpty);
    });

    test('a non-VTT 200 body is not a served track', () async {
      // A gateway error page parses to zero cues exactly like a silent
      // video's track does. Calling it empty would tell the creator no
      // speech was detected when the fetch actually failed.
      final result = await fetchSubtitleCues(
        httpClient: _FakeClient(
          (_) async => http.Response('<!DOCTYPE html><html>502</html>', 200),
        ),
        nostrClient: null,
        delay: (_) async {},
        sha256: 'abc123',
      );

      expect(result.status, SubtitleFetchStatus.unavailable);
    });

    test('a non-VTT ref does not hide a later real track', () async {
      final result = await fetchSubtitleCues(
        httpClient: _FakeClient((req) async {
          if (req.url.toString() == 'https://media.divine.video/broken.vtt') {
            return http.Response('{"error":"not found"}', 200);
          }
          return http.Response(_vtt, 200);
        }),
        nostrClient: null,
        delay: (_) async {},
        textTrackRefs: const ['https://media.divine.video/broken.vtt'],
        sha256: 'abc123',
      );

      expect(result.status, SubtitleFetchStatus.available);
      expect(result.cues.first.text, equals('hello'));
    });

    test('a direct ref answering 202 reports processing', () async {
      final result = await fetchSubtitleCues(
        httpClient: _FakeClient((_) async => http.Response('', 202)),
        nostrClient: null,
        delay: (_) async {},
        textTrackRefs: const ['https://media.divine.video/pending.vtt'],
      );

      expect(result.status, SubtitleFetchStatus.processing);
    });

    test('reports processing while Blossom keeps answering 202', () async {
      var calls = 0;
      final result = await fetchSubtitleCues(
        httpClient: _FakeClient((_) async {
          calls++;
          return http.Response('', 202, headers: const {'retry-after': '1'});
        }),
        nostrClient: null,
        delay: (_) async {},
        sha256: 'abc123',
      );

      expect(result.status, SubtitleFetchStatus.processing);
      expect(calls, greaterThan(1));
    });

    test(
      'processing outranks empty when both sources are consulted',
      () async {
        final result = await fetchSubtitleCues(
          httpClient: _FakeClient((req) async {
            if (req.url.toString() == 'https://media.divine.video/silent.vtt') {
              return http.Response('WEBVTT\n\n', 200);
            }
            return http.Response('', 202, headers: const {'retry-after': '1'});
          }),
          nostrClient: null,
          delay: (_) async {},
          textTrackRefs: const ['https://media.divine.video/silent.vtt'],
          sha256: 'abc123',
        );

        expect(result.status, SubtitleFetchStatus.processing);
      },
    );

    test('reports unavailable when all sources fail', () async {
      final result = await fetchSubtitleCues(
        httpClient: _FakeClient((_) async => http.Response('', 404)),
        nostrClient: null,
        delay: (_) async {},
        textTrackRefs: const ['https://media.divine.video/missing'],
      );
      expect(result.status, SubtitleFetchStatus.unavailable);
      expect(result.cues, isEmpty);
    });

    test('reports unavailable when no sources provided', () async {
      final result = await fetchSubtitleCues(
        httpClient: _FakeClient(
          (_) async => throw StateError('should not be called'),
        ),
        nostrClient: null,
        delay: (_) async {},
      );
      expect(result.status, SubtitleFetchStatus.unavailable);
      expect(result.cues, isEmpty);
    });

    test(
      'fetches from sha256 Blossom path when no refs and sha256 provided',
      () async {
        final result = await fetchSubtitleCues(
          httpClient: _FakeClient((req) async {
            if (req.url.toString() == 'https://media.divine.video/abc123/vtt') {
              return http.Response(_vtt, 200);
            }
            return http.Response('', 404);
          }),
          nostrClient: null,
          delay: (_) async {},
          sha256: 'abc123',
        );
        expect(result.cues, hasLength(1));
        expect(result.cues.first.text, equals('hello'));
      },
    );
  });
}
