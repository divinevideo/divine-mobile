import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:videos_repository/videos_repository.dart';

class _Nostr extends Mock implements NostrClient {}

class _Api extends Mock implements FunnelcakeApiClient {}

class _Storage extends Mock implements VideoLocalStorage {}

const _id = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _author =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _stableId = 'portrait-video';
const _coordinate = '34236:$_author:$_stableId';

Event _portrait() => Event.fromJson({
  'id': _id,
  'pubkey': _author,
  'created_at': 1700000000,
  'kind': 34236,
  'content': '',
  'sig': 'c' * 128,
  'tags': [
    ['d', _stableId],
    [
      'imeta',
      'url https://example.com/video.mp4',
      'm video/mp4',
      'dim 720x1280',
    ],
  ],
});

void main() {
  setUpAll(() => registerFallbackValue(<Filter>[]));

  group('single-video shape policy', () {
    late _Nostr nostr;
    late _Api api;
    late _Storage storage;

    setUp(() {
      nostr = _Nostr();
      api = _Api();
      storage = _Storage();
      when(() => api.isAvailable).thenReturn(false);
      when(() => nostr.queryEvents(any())).thenAnswer((_) async => []);
      when(() => storage.getEventsByIds(any())).thenAnswer((_) async => []);
      when(() => storage.getEventsByDTag(any())).thenAnswer((_) async => []);
      when(() => api.getVideoEvent(any())).thenAnswer((_) async => null);
      when(() => api.getBulkVideoStats(any())).thenAnswer(
        (_) async => const BulkVideoStatsResponse(stats: {}),
      );
    });

    VideosRepository build({bool contentHidden = false}) => VideosRepository(
      nostrClient: nostr,
      funnelcakeApiClient: api,
      localStorage: storage,
      feedShapeFilter: (video) => video.width != video.height,
      contentFilter: (_) => contentHidden,
      warningLabelsResolver: (_) => const ['violence'],
    );

    for (final source in [
      'cache',
      'REST',
      'relay event',
      'relay address',
      'relay stable',
    ]) {
      for (final hidden in [false, true]) {
        test(
          '$source ignores shape but preserves content policy (hide=$hidden)',
          () async {
            var route = _id;
            switch (source) {
              case 'cache':
                when(
                  () => storage.getEventsByIds(any()),
                ).thenAnswer((_) async => [_portrait()]);
              case 'REST':
                when(() => api.isAvailable).thenReturn(true);
                when(
                  () => api.getVideoEvent(any()),
                ).thenAnswer((_) async => _portrait());
              case 'relay address':
                route = _coordinate;
                when(
                  () => nostr.queryEvents(any()),
                ).thenAnswer((_) async => [_portrait()]);
              case 'relay stable':
                route = _stableId;
                when(
                  () => nostr.queryEvents(any()),
                ).thenAnswer((_) async => [_portrait()]);
              case 'relay event':
                when(
                  () => nostr.queryEvents(any()),
                ).thenAnswer((_) async => [_portrait()]);
            }
            final result = await build(
              contentHidden: hidden,
            ).lookupVideoForRouteId(route);
            if (hidden) {
              expect(result, isA<VideoRouteHiddenByFilter>());
            } else {
              expect(result, isA<VideoRouteFound>());
              final video = (result as VideoRouteFound).video;
              expect(video.id, _id);
              expect(video.warnLabels, ['violence']);
            }
          },
        );
      }
    }

    for (final restFallback in [false, true]) {
      test(
        'profile pin lookup opts out of shape (REST=$restFallback)',
        () async {
          if (restFallback) {
            when(() => api.isAvailable).thenReturn(true);
            when(() => api.getVideosByAuthor(pubkey: _author)).thenAnswer(
              (_) async => VideosByAuthorResponse(
                videos: [
                  VideoStats(
                    id: _id,
                    pubkey: _author,
                    createdAt: DateTime.fromMillisecondsSinceEpoch(
                      1700000000000,
                    ),
                    kind: 34236,
                    title: 'Portrait',
                    thumbnail: 'https://example.com/thumb.jpg',
                    dTag: _stableId,
                    videoUrl: 'https://example.com/video.mp4',
                    dimensions: '720x1280',
                    reactions: 0,
                    comments: 0,
                    reposts: 0,
                    engagementScore: 0,
                  ),
                ],
              ),
            );
          } else {
            when(
              () => nostr.queryEvents(any()),
            ).thenAnswer((_) async => [_portrait()]);
          }
          final repo = build();
          expect(await repo.getVideosByAddressableIds([_coordinate]), isEmpty);
          final pins = await repo.getVideosByAddressableIds([
            _coordinate,
          ], includeFeedShape: false);
          expect(pins.map((v) => v.id), [_id]);
          expect(pins.single.warnLabels, ['violence']);
          expect(
            await build(
              contentHidden: true,
            ).getVideosByAddressableIds([_coordinate], includeFeedShape: false),
            isEmpty,
          );
        },
      );
    }

    for (final cached in [false, true]) {
      test('fetchVideoWithStats ignores shape (cached=$cached)', () async {
        if (cached) {
          when(
            () => storage.getEventsByIds(any()),
          ).thenAnswer((_) async => [_portrait()]);
        } else {
          when(
            () => nostr.queryEvents(any()),
          ).thenAnswer((_) async => [_portrait()]);
        }
        final repo = build();
        expect((await repo.fetchVideoWithStats(_id))?.id, _id);
        expect(await repo.getVideosByIds([_id]), isEmpty);
        expect(
          await build(contentHidden: true).fetchVideoWithStats(_id),
          isNull,
        );
      });
    }
  });
}
