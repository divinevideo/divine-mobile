// ABOUTME: Pins that a filtered video is reported as hidden, not as missing.
// ABOUTME: Collapsing both to null renders "not found" for a playable video.

import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {
  // A live client reports false; an unstubbed mock getter would return null.
  @override
  bool isDisposed = false;
}

const _pubkey =
    'd95aa8fc0eff8e488952495b8064991d27fb96ed8652f12cdedc5a4e8b5ae540';
const _dTag =
    '7465a9b8a671506e748391248e6ce7538608f0d430458daa5a0b38aa3a01c180';
const _eventId =
    '72440ed755f6a4ccabf91adaa28e90a3940fdabd2537110ad945f8d41b2e22e1';

/// Mirrors the real event behind #7892: media on a non-Divine host.
Event _offHostVideo() => Event.fromJson({
  'id': _eventId,
  'pubkey': _pubkey,
  'created_at': 1765250795,
  'kind': 34236,
  'content': '',
  'sig': 'a' * 128,
  'tags': [
    ['d', _dTag],
    [
      'imeta',
      'url https://separately-robust-roughy.edgecompute.app/$_dTag',
      'm video/mp4',
    ],
    ['title', 'unsteady shot of the water'],
  ],
});

void main() {
  setUpAll(() => registerFallbackValue(<Filter>[]));

  group('lookupVideoForRouteId', () {
    late _MockNostrClient nostr;
    late _MockFunnelcakeApiClient funnelcake;

    setUp(() {
      nostr = _MockNostrClient();
      funnelcake = _MockFunnelcakeApiClient();
      when(() => funnelcake.isAvailable).thenReturn(false);
      when(() => nostr.queryEvents(any())).thenAnswer((_) async => []);
    });

    VideosRepository build({VideoContentFilter? contentFilter}) =>
        VideosRepository(
          nostrClient: nostr,
          funnelcakeApiClient: funnelcake,
          contentFilter: contentFilter,
        );

    test('reports a content-filtered video as hidden, not missing', () async {
      when(
        () => nostr.queryEvents(any()),
      ).thenAnswer((_) async => [_offHostVideo()]);
      when(
        () => funnelcake.getBulkVideoStats(any()),
      ).thenThrow(const FunnelcakeException('no stats'));

      // Stands in for the app's "only show Divine-hosted videos" filter.
      final repo = build(
        contentFilter: (video) =>
            !Uri.parse(video.videoUrl ?? '').host.endsWith('.divine.video'),
      );

      final result = await repo.lookupVideoForRouteId('34236:$_pubkey:$_dTag');

      expect(result, isA<VideoRouteHiddenByFilter>());
      expect((result as VideoRouteHiddenByFilter).video.id, equals(_eventId));
    });

    test('reports a genuinely absent video as missing', () async {
      final repo = build();

      final result = await repo.lookupVideoForRouteId('34236:$_pubkey:$_dTag');

      expect(result, isA<VideoRouteMissing>());
    });

    test('reports an allowed video as found', () async {
      when(
        () => nostr.queryEvents(any()),
      ).thenAnswer((_) async => [_offHostVideo()]);
      when(
        () => funnelcake.getBulkVideoStats(any()),
      ).thenThrow(const FunnelcakeException('no stats'));

      final repo = build();

      final result = await repo.lookupVideoForRouteId('34236:$_pubkey:$_dTag');

      expect(result, isA<VideoRouteFound>());
    });

    test(
      'fetchVideoWithStatsForRouteId still returns null when hidden',
      () async {
        when(
          () => nostr.queryEvents(any()),
        ).thenAnswer((_) async => [_offHostVideo()]);
        when(
          () => funnelcake.getBulkVideoStats(any()),
        ).thenThrow(const FunnelcakeException('no stats'));

        final repo = build(contentFilter: (_) => true);

        // Existing callers keep their contract.
        expect(
          await repo.fetchVideoWithStatsForRouteId('34236:$_pubkey:$_dTag'),
          isNull,
        );
      },
    );
  });
}
