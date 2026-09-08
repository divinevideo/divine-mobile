// ABOUTME: Tests for subtitle providers triple fetch strategy.
// ABOUTME: Verifies parsing embedded content (REST API), Blossom VTT fetch,
// ABOUTME: and relay query fallback.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/subtitle_providers.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  const testPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  late _MockNostrClient mockNostrClient;
  late _MockHttpClient mockHttpClient;
  late List<Duration> requestedDelays;

  setUp(() {
    mockNostrClient = _MockNostrClient();
    mockHttpClient = _MockHttpClient();
    requestedDelays = [];
  });

  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(Uri.parse('https://media.divine.video/fallback/vtt'));
  });

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        nostrServiceProvider.overrideWith(
          () => _FakeNostrService(mockNostrClient),
        ),
        subtitleHttpClientProvider.overrideWithValue(mockHttpClient),
        subtitlePollDelayProvider.overrideWithValue((duration) async {
          requestedDelays.add(duration);
        }),
      ],
    );
  }

  group('subtitleCues', () {
    test('returns empty list when no subtitle data available', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final cues = await container.read(
        subtitleCuesProvider(videoId: 'test-id').future,
      );

      expect(cues, isEmpty);
    });

    test('parses embedded textTrackContent directly (REST API path)', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      const vttContent =
          'WEBVTT\n\n1\n00:00:00.500 --> 00:00:03.200\n'
          'Hello world\n\n2\n00:00:03.500 --> 00:00:06.000\nSecond cue\n';

      final cues = await container.read(
        subtitleCuesProvider(
          videoId: 'test-id',
          textTrackContent: vttContent,
        ).future,
      );

      expect(cues, hasLength(2));
      expect(cues[0].text, equals('Hello world'));
      expect(cues[0].start, equals(500));
      expect(cues[0].end, equals(3200));
      expect(cues[1].text, equals('Second cue'));

      // Should NOT query the relay
      verifyNever(
        () => mockNostrClient.queryEvents(
          any(),
          tempRelays: any(named: 'tempRelays'),
        ),
      );
    });

    test('queries NostrClient when only textTrackRef available', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      const vttFromRelay =
          'WEBVTT\n\n1\n00:00:01.000 --> 00:00:02.000\n'
          'From relay\n';

      when(
        () => mockNostrClient.queryEvents(
          any(),
          tempRelays: any(named: 'tempRelays'),
        ),
      ).thenAnswer(
        (_) async => [
          Event(
            testPubkey,
            39307,
            [
              ['d', 'subtitles:test-vine-id'],
              ['m', 'text/vtt'],
            ],
            vttFromRelay,
            createdAt: 1757385263,
          ),
        ],
      );

      final cues = await container.read(
        subtitleCuesProvider(
          videoId: 'test-id',
          textTrackRef: '39307:$testPubkey:subtitles:test-vine-id',
        ).future,
      );

      expect(cues, hasLength(1));
      expect(cues[0].text, equals('From relay'));
      expect(cues[0].start, equals(1000));
      expect(cues[0].end, equals(2000));

      verify(
        () => mockNostrClient.queryEvents(
          any(),
          tempRelays: any(named: 'tempRelays'),
        ),
      ).called(1);
    });

    test('fetches VTT directly when textTrackRef is an HTTP URL', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      when(
        () =>
            mockHttpClient.get(Uri.parse('https://example.com/subtitles.vtt')),
      ).thenAnswer(
        (_) async => http.Response(
          'WEBVTT\n\n1\n00:00:00.000 --> 00:00:01.500\nFrom URL\n',
          200,
        ),
      );

      final cues = await container.read(
        subtitleCuesProvider(
          videoId: 'test-id',
          textTrackRef: 'https://example.com/subtitles.vtt',
        ).future,
      );

      expect(cues, hasLength(1));
      expect(cues.first.text, equals('From URL'));

      verify(
        () =>
            mockHttpClient.get(Uri.parse('https://example.com/subtitles.vtt')),
      ).called(1);
      verifyNever(
        () => mockNostrClient.queryEvents(
          any(),
          tempRelays: any(named: 'tempRelays'),
        ),
      );
    });

    test(
      'prefers embedded content over relay fetch when both present',
      () async {
        final container = createContainer();
        addTearDown(container.dispose);

        const embeddedVtt =
            'WEBVTT\n\n1\n00:00:00.500 --> 00:00:01.000\n'
            'Embedded\n';

        final cues = await container.read(
          subtitleCuesProvider(
            videoId: 'test-id',
            textTrackRef: '39307:$testPubkey:subtitles:test-vine-id',
            textTrackContent: embeddedVtt,
          ).future,
        );

        expect(cues, hasLength(1));
        expect(cues[0].text, equals('Embedded'));

        // Should NOT query relay since embedded content is available
        verifyNever(
          () => mockNostrClient.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
          ),
        );
      },
    );

    test(
      'returns empty list when relay query finds no subtitle event',
      () async {
        final container = createContainer();
        addTearDown(container.dispose);

        when(
          () => mockNostrClient.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
          ),
        ).thenAnswer((_) async => []);

        final cues = await container.read(
          subtitleCuesProvider(
            videoId: 'test-id',
            textTrackRef: '39307:$testPubkey:subtitles:test-vine-id',
          ).future,
        );

        expect(cues, isEmpty);
      },
    );

    test('parses VTT content from relay event content field', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      const vttContent =
          'WEBVTT\n\n'
          '1\n00:00:00.000 --> 00:00:01.500\nFirst line\n\n'
          '2\n00:00:02.000 --> 00:00:03.500\nSecond line\n';

      when(
        () => mockNostrClient.queryEvents(
          any(),
          tempRelays: any(named: 'tempRelays'),
        ),
      ).thenAnswer(
        (_) async => [
          Event(
            testPubkey,
            39307,
            [
              ['d', 'subtitles:test-vine-id'],
            ],
            vttContent,
            createdAt: 1757385263,
          ),
        ],
      );

      final cues = await container.read(
        subtitleCuesProvider(
          videoId: 'test-id',
          textTrackRef: '39307:$testPubkey:subtitles:test-vine-id',
        ).future,
      );

      expect(cues, hasLength(2));
      expect(cues[0].text, equals('First line'));
      expect(cues[0].start, equals(0));
      expect(cues[0].end, equals(1500));
      expect(cues[1].text, equals('Second line'));
      expect(cues[1].start, equals(2000));
      expect(cues[1].end, equals(3500));
    });

    test('returns empty list for malformed textTrackRef', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final cues = await container.read(
        subtitleCuesProvider(
          videoId: 'test-id',
          textTrackRef: 'invalid-ref',
        ).future,
      );

      expect(cues, isEmpty);

      // Should NOT attempt to query relay with bad coordinates
      verifyNever(
        () => mockNostrClient.queryEvents(
          any(),
          tempRelays: any(named: 'tempRelays'),
        ),
      );
    });

    test('returns empty for empty textTrackContent string', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final cues = await container.read(
        subtitleCuesProvider(videoId: 'test-id', textTrackContent: '').future,
      );

      expect(cues, isEmpty);
    });
  });

  group('subtitleCues Blossom VTT path', () {
    test('retries Blossom fetch on 202 using Retry-After', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      var callCount = 0;
      when(() => mockHttpClient.get(any())).thenAnswer((_) async {
        callCount += 1;
        if (callCount == 1) {
          return http.Response(
            '{"status":"cooling_down"}',
            202,
            headers: {'retry-after': '5'},
          );
        }
        return http.Response(
          'WEBVTT\n\n1\n00:00:00.000 --> 00:00:01.000\nReady now\n',
          200,
        );
      });

      final cues = await container.read(
        subtitleCuesProvider(videoId: 'test-id', sha256: 'abc123').future,
      );

      expect(cues, hasLength(1));
      expect(cues.first.text, equals('Ready now'));
      expect(callCount, equals(2));
      expect(requestedDelays, equals([const Duration(seconds: 5)]));
    });

    test('prefers relay textTrackRef over auto-gen sha256 Blossom', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      when(
        () => mockHttpClient.get(any()),
      ).thenAnswer((_) async => http.Response('missing', 404));
      when(
        () => mockNostrClient.queryEvents(
          any(),
          tempRelays: any(named: 'tempRelays'),
        ),
      ).thenAnswer(
        (_) async => [
          Event(
            testPubkey,
            39307,
            [
              ['d', 'subtitles:test-vine-id'],
            ],
            'WEBVTT\n\n1\n00:00:01.000 --> 00:00:02.000\nFrom relay ref\n',
            createdAt: 1757385263,
          ),
        ],
      );

      final cues = await container.read(
        subtitleCuesProvider(
          videoId: 'test-id',
          sha256: 'abc123',
          textTrackRef: '39307:$testPubkey:subtitles:test-vine-id',
        ).future,
      );

      expect(cues, hasLength(1));
      expect(cues.first.text, equals('From relay ref'));
    });

    test(
      'returns empty when relay ref misses and Blossom sha256 404s',
      () async {
        final container = createContainer();
        addTearDown(container.dispose);

        when(
          () => mockHttpClient.get(any()),
        ).thenAnswer((_) async => http.Response('missing', 404));
        when(
          () => mockNostrClient.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
          ),
        ).thenAnswer((_) async => []);

        final cues = await container.read(
          subtitleCuesProvider(
            videoId: 'test-id',
            sha256: 'abc123',
            textTrackRef: '39307:$testPubkey:subtitles:test-vine-id',
          ).future,
        );

        expect(cues, isEmpty);
      },
    );

    test('parses Blossom VTT immediately on 200', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      when(() => mockHttpClient.get(any())).thenAnswer(
        (_) async => http.Response(
          'WEBVTT\n\n1\n00:00:00.000 --> 00:00:01.000\nImmediate\n',
          200,
        ),
      );

      final cues = await container.read(
        subtitleCuesProvider(videoId: 'test-id', sha256: 'abc123').future,
      );

      expect(cues, hasLength(1));
      expect(cues.first.text, equals('Immediate'));
      verifyNever(
        () => mockNostrClient.queryEvents(
          any(),
          tempRelays: any(named: 'tempRelays'),
        ),
      );
    });

    test('stops polling after bounded 202 retries', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      var callCount = 0;
      when(() => mockHttpClient.get(any())).thenAnswer((_) async {
        callCount += 1;
        return http.Response(
          '{"status":"in_progress"}',
          202,
          headers: {'retry-after': '5'},
        );
      });

      final cues = await container.read(
        subtitleCuesProvider(videoId: 'test-id', sha256: 'abc123').future,
      );

      expect(cues, isEmpty);
      expect(callCount, equals(4));
      expect(requestedDelays, hasLength(3));
    });

    test(
      'prefers embedded textTrackContent over Blossom sha256 fetch',
      () async {
        final container = createContainer();
        addTearDown(container.dispose);

        const embeddedVtt =
            'WEBVTT\n\n1\n00:00:00.500 --> 00:00:01.000\n'
            'Embedded\n';

        final cues = await container.read(
          subtitleCuesProvider(
            videoId: 'test-id',
            textTrackContent: embeddedVtt,
            sha256: 'abc123def456abc123def456abc123def456abc123def456abc123def456abcd',
          ).future,
        );

        expect(cues, hasLength(1));
        expect(cues[0].text, equals('Embedded'));
      },
    );

    test('returns empty list when sha256 is empty string', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final cues = await container.read(
        subtitleCuesProvider(videoId: 'test-id', sha256: '').future,
      );

      expect(cues, isEmpty);
    });
  });
}

/// Fake Notifier that returns a pre-configured mock NostrClient.
class _FakeNostrService extends NostrService {
  _FakeNostrService(this._mockClient);
  final NostrClient _mockClient;

  @override
  NostrClient build() => _mockClient;
}
