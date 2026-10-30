import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/features/creator_highlights/creator_highlights_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const other =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const videoId =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
final now = DateTime.utc(2026, 10, 30, 12);
Map<String, Object?> video({
  String id = videoId,
  String pubkey = owner,
  int? views = 0,
  DateTime? published,
  String dTag = 'one',
  bool archive = false,
}) => {
  'id': id,
  'pubkey': pubkey,
  'kind': 34236,
  'created_at': (published ?? now).millisecondsSinceEpoch ~/ 1000,
  'tags': [
    ['d', dTag],
  ],
  'video_url': 'https://example.com/video.mp4',
  'title': 'A tiny dance',
  'views': views,
  'verified_archive': archive,
};

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  CreatorHighlightsRepository repository(
    List<Map<String, Object?>> videos, {
    bool hasMore = false,
    Set<String> deleted = const {},
    Map<String, int> deletedAddresses = const {},
    bool bulkFails = false,
    List<List<Map<String, Object?>>>? pages,
    DateTime Function()? clock,
  }) {
    var page = 0;
    final client = FunnelcakeApiClient(
      baseUrl: 'https://example.com',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/videos')) {
          return http.Response(
            jsonEncode({
              'data': pages == null ? videos : pages[page++],
              'pagination': {'has_more': hasMore},
            }),
            200,
          );
        }
        return http.Response(
          bulkFails
              ? '{}'
              : jsonEncode({
                  'stats': {
                    for (final v in videos)
                      v['id']: {'event_id': v['id'], 'views': v['views']},
                  },
                }),
          bulkFails ? 503 : 200,
        );
      }),
    );
    return FunnelcakeCreatorHighlightsRepository(
      client: client,
      preferences: prefs,
      now: clock ?? () => now,
      locallyDeletedEventIds: () => deleted,
      locallyDeletedAddresses: () => deletedAddresses,
    );
  }

  group('load', () {
    test(
      'a zero-audience original creation day earns a card automatically',
      () async {
        final card = await repository([video()]).load(owner);
        expect(card?.createdToday, 1);
        expect(card?.creationDaysThisWeek, 1);
        expect(card?.views, 0);
        expect(card?.topVideo?.pubkey, owner);
      },
    );
    test(
      'missing views stay unknown and do not become archive loops',
      () async {
        final raw = video(views: null)..['embedded_loops'] = 9000000;
        final card = await repository([raw], bulkFails: true).load(owner);
        expect(card?.createdToday, 1);
        expect(card?.views, isNull);
        expect(card?.topVideo, isNull);
      },
    );
    for (final key in ['views', 'view_count', 'total_views']) {
      test('an event $key tag cannot supply missing API metrics', () async {
        final raw = video(views: null);
        (raw['tags']! as List<List<String>>).add([key, '999999']);
        for (final failed in [false, true]) {
          final card = await repository([raw], bulkFails: failed).load(owner);
          expect(card?.createdToday, 1);
          expect(card?.views, isNull);
          expect(card?.topVideo, isNull);
        }
      });
    }
    test(
      'known view counts total only original videos published this week',
      () async {
        final card = await repository([
          video(views: 20),
          video(
            id: other,
            dTag: 'two',
            views: 7,
            published: now.subtract(const Duration(days: 2)),
          ),
        ]).load(owner);
        expect(card?.views, 27);
        expect(card?.creationDaysThisWeek, 2);
        expect(card?.topVideo?.id, videoId);
      },
    );
    test(
      'foreign, archived, deleted and future videos never earn a card',
      () async {
        expect(
          await repository([
            video(pubkey: other),
            video(archive: true),
            video(published: now.add(const Duration(days: 1))),
          ]).load(owner),
          isNull,
        );
        expect(
          await repository([video()], deleted: {videoId}).load(owner),
          isNull,
        );
      },
    );
    test(
      'an incomplete scan never claims a weekly total or top video',
      () async {
        final card = await repository([video()], hasMore: true).load(owner);
        expect(card?.createdToday, 1);
        expect(card?.views, isNull);
        expect(card?.topVideo, isNull);
      },
    );
    test(
      'an empty partial page does not certify complete statistics',
      () async {
        final card = await repository(
          [video()],
          hasMore: true,
          pages: [
            [video()],
            [],
          ],
        ).load(owner);
        expect(card?.createdToday, 1);
        expect(card?.views, isNull);
        expect(card?.topVideo, isNull);
      },
    );
    test(
      'editing an old publication does not invent a new creative day',
      () async {
        final edited = video()
          ..['published_at'] =
              now.subtract(const Duration(days: 10)).millisecondsSinceEpoch ~/
              1000;
        expect(await repository([edited]).load(owner), isNull);
      },
    );
    test('edit siblings count as one publication', () async {
      final card = await repository([
        video(views: 3),
        video(id: other, views: 4),
      ]).load(owner);
      expect(card?.createdToday, 1);
      expect(card?.creationDaysThisWeek, 1);
    });
    test(
      'a local calendar rollover never calls yesterday’s creation today',
      () async {
        var time = now;
        final repo = repository([video()], clock: () => time);
        final first = (await repo.load(owner))!;
        await repo.markPresented(owner, first.localDate);
        time = now.add(const Duration(days: 1));
        final next = (await repo.load(owner))!;
        expect(next.createdToday, 0);
        expect(next.localDate, isNot(first.localDate));
        expect(next.celebrate, isTrue);
      },
    );
    test(
      'older sibling evidence prevents an edit earning a new creation day',
      () async {
        expect(
          await repository([
            video(),
            video(id: other, published: now.subtract(const Duration(days: 10))),
          ]).load(owner),
          isNull,
        );
      },
    );
    test('a coordinate deletion also removes an older revision', () async {
      expect(
        await repository(
          [video(id: other)],
          deleted: {videoId},
          deletedAddresses: {
            '34236:$owner:one': now.millisecondsSinceEpoch ~/ 1000,
          },
        ).load(owner),
        isNull,
      );
    });
    test(
      'a later revision is not hidden by an older coordinate tombstone',
      () async {
        final card = await repository(
          [video()],
          deletedAddresses: {
            '34236:$owner:one':
                now.subtract(const Duration(days: 1)).millisecondsSinceEpoch ~/
                1000,
          },
        ).load(owner);
        expect(card?.createdToday, 1);
      },
    );
    test(
      'a deleted sibling cannot replace a surviving later revision',
      () async {
        final publication = now.subtract(const Duration(days: 2));
        final card = await repository(
          [
            video(id: other, views: 900, published: publication)
              ..['published_at'] = publication.millisecondsSinceEpoch ~/ 1000,
            video(views: 3)
              ..['published_at'] = publication.millisecondsSinceEpoch ~/ 1000,
          ],
          deletedAddresses: {
            '34236:$owner:one':
                now.subtract(const Duration(days: 1)).millisecondsSinceEpoch ~/
                1000,
          },
        ).load(owner);
        expect(card?.topVideo?.id, videoId);
        expect(card?.views, 3);
        expect(card?.createdToday, 0);
        expect(card?.creationDaysThisWeek, 1);
      },
    );
    test(
      'a deleted original still establishes an old publication date',
      () async {
        final card = await repository(
          [
            video(id: other, published: now.subtract(const Duration(days: 10))),
            video(),
          ],
          deleted: {other},
        ).load(owner);
        expect(card, isNull);
      },
    );
    test(
      'a deleted original preserves its day without contributing views',
      () async {
        final card = await repository(
          [
            video(
              id: other,
              views: 900,
              published: now.subtract(const Duration(days: 2)),
            ),
            video(views: 3)
              ..['published_at'] = now.millisecondsSinceEpoch ~/ 1000,
          ],
          deleted: {other},
        ).load(owner);
        expect(card?.topVideo?.id, videoId);
        expect(card?.views, 3);
        expect(card?.createdToday, 0);
        expect(card?.creationDaysThisWeek, 1);
        expect(
          card?.topVideo?.publishedAt,
          '${now.subtract(const Duration(days: 2)).millisecondsSinceEpoch ~/ 1000}',
        );
      },
    );
    test('an empty creator account does not invent activity', () async {
      expect(await repository([]).load(owner), isNull);
    });
  });

  group('markPresented', () {
    test(
      'daily animation claims are private to owner and calendar date',
      () async {
        final repo = repository([video()]);
        final card = (await repo.load(owner))!;
        expect(card.celebrate, isTrue);
        await repo.markPresented(owner, card.localDate);
        expect((await repo.load(owner))?.celebrate, isFalse);
        expect(
          prefs.getString(
            '${FunnelcakeCreatorHighlightsRepository.presentationPrefix}$other',
          ),
          isNull,
        );
      },
    );
  });
}
