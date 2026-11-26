// ABOUTME: Tests reading one series by its address: the relay read, the
// ABOUTME: one-minute cache, and the fresh read before an episode is denied.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cache_sync/cache_sync.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event;
import 'package:test/test.dart';

import '../../../cache_sync/test/fake_cache_dao.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

void main() {
  group('CuratedListRepository.fetchSeriesContaining', () {
    final author = 'a' * 64;
    final someoneElse = 'd' * 64;
    final seriesCoordinate = '30005:$author:our-story';
    final episode1 = '34236:$author:episode-1';
    final episode2 = '34236:$author:episode-2';
    final episode3 = '34236:$author:episode-3';

    late _MockNostrClient nostrClient;
    late DateTime now;

    Event seriesEvent({
      List<String>? episodes,
      bool marked = true,
      String? pubkey,
      String dTag = 'our-story',
      int createdAt = 1778120000,
    }) => Event(
      pubkey ?? author,
      30005,
      [
        ['d', dTag],
        ['title', 'Our Story'],
        if (marked) ['series', 'true'],
        for (final episode in episodes ?? [episode1, episode2]) ['a', episode],
      ],
      '',
      createdAt: createdAt,
    );

    /// Answers relay reads with [answers] in turn, repeating the last one,
    /// and returns how many reads there have been.
    int Function() answerRelays(List<List<Event>> answers) {
      var reads = 0;
      when(
        () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
      ).thenAnswer(
        (_) async => answers[math.min(reads++, answers.length - 1)],
      );
      return () => reads;
    }

    CuratedListRepository createRepository() => CuratedListRepository(
      nostrClient: nostrClient,
      funnelcakeApiClient: _MockFunnelcakeApiClient(),
    );

    Future<CuratedList?> fetch(
      CuratedListRepository repository,
      String episode, {
      String? series,
    }) => repository.fetchSeriesContaining(
      seriesCoordinate: series ?? seriesCoordinate,
      episodeCoordinate: episode,
    );

    setUp(() async {
      registerFallbackValue(Duration.zero);
      nostrClient = _MockNostrClient();
      now = DateTime.utc(2026, 11, 26, 12);
      await CacheSync.init(dao: FakeCacheDao(now: () => now));
    });

    test('returns the series that holds the episode', () async {
      answerRelays([
        [seriesEvent()],
      ]);

      final series = await fetch(createRepository(), episode2);

      expect(series?.name, equals('Our Story'));
      expect(series?.seriesEpisodes, equals([episode1, episode2]));
    });

    test('asks the relays for that one list', () async {
      answerRelays([
        [seriesEvent()],
      ]);

      await fetch(createRepository(), episode1);

      final [List<Filter> filters] = verify(
        () => nostrClient.queryEvents(
          captureAny(),
          timeout: any(named: 'timeout'),
        ),
      ).captured.cast<List<Filter>>();
      final filter = filters.single;
      expect(filter.kinds, equals([30005]));
      expect(filter.authors, equals([author]));
      expect(filter.d, equals(['our-story']));
    });

    test('reads the series once for the episodes of a feed', () async {
      final reads = answerRelays([
        [seriesEvent()],
      ]);
      final repository = createRepository();

      final together = await Future.wait([
        fetch(repository, episode1),
        fetch(repository, episode2),
      ]);
      final later = await fetch(repository, episode1);

      expect(together, everyElement(isNotNull));
      expect(later, isNotNull);
      expect(reads(), equals(1));
    });

    test('keeps the series in the cache, not in the repository', () async {
      final reads = answerRelays([
        [seriesEvent()],
      ]);

      await fetch(createRepository(), episode1);
      final series = await fetch(createRepository(), episode2);

      expect(series, isNotNull);
      expect(reads(), equals(1));
    });

    test(
      'reads the series again once its cached copy is a minute old',
      () async {
        final reads = answerRelays([
          [seriesEvent()],
        ]);
        final repository = createRepository();

        await fetch(repository, episode1);
        now = now.add(const Duration(seconds: 59));
        await fetch(repository, episode1);
        expect(reads(), equals(1));

        now = now.add(const Duration(seconds: 2));
        await fetch(repository, episode1);
        expect(reads(), equals(2));
      },
    );

    test(
      'reads the series again before saying an episode is not in it',
      () async {
        final reads = answerRelays([
          [seriesEvent()],
          [
            seriesEvent(
              episodes: [episode1, episode2, episode3],
              createdAt: 1778120100,
            ),
          ],
        ]);
        final repository = createRepository();

        await fetch(repository, episode1);
        final series = await fetch(repository, episode3);
        await fetch(repository, episode3);

        expect(series?.seriesEpisodes, contains(episode3));
        expect(reads(), equals(2));
      },
    );

    test('returns null when a fresh read does not hold the episode', () async {
      answerRelays([
        [seriesEvent()],
      ]);

      expect(await fetch(createRepository(), episode3), isNull);
    });

    test('forgets a cached series its creator no longer marks', () async {
      final reads = answerRelays([
        [seriesEvent()],
        [seriesEvent(marked: false, createdAt: 1778120100)],
      ]);
      final repository = createRepository();

      await fetch(repository, episode1);
      expect(await fetch(repository, episode3), isNull);
      expect(await fetch(repository, episode1), isNull);
      expect(reads(), equals(3));
    });

    test('returns null for a list not marked as a series', () async {
      final reads = answerRelays([
        [seriesEvent(marked: false)],
      ]);
      final repository = createRepository();

      expect(await fetch(repository, episode1), isNull);
      expect(await fetch(repository, episode1), isNull);
      expect(reads(), equals(2));
    });

    test('takes the newest revision of the series', () async {
      answerRelays([
        [
          seriesEvent(),
          seriesEvent(
            episodes: [episode1, episode2, episode3],
            createdAt: 1778120100,
          ),
        ],
      ]);

      final series = await fetch(createRepository(), episode3);

      expect(series?.seriesEpisodes, hasLength(3));
    });

    test('ignores another list of the creator the relays return', () async {
      answerRelays([
        [seriesEvent(dTag: 'their-other-story')],
      ]);

      expect(await fetch(createRepository(), episode1), isNull);
    });

    test('ignores a list by someone else the relays return', () async {
      final theirEpisode = '34236:$someoneElse:episode-1';
      answerRelays([
        [
          seriesEvent(pubkey: someoneElse, episodes: [theirEpisode]),
        ],
      ]);

      expect(await fetch(createRepository(), theirEpisode), isNull);
    });

    for (final malformed in [
      '30000:$author:our-story',
      '30005:${'A' * 64}:our-story',
      '30005:$author:',
      'our-story',
    ]) {
      test('returns null for the malformed address $malformed', () async {
        final reads = answerRelays([
          [seriesEvent()],
        ]);

        expect(
          await fetch(createRepository(), episode1, series: malformed),
          isNull,
        );
        expect(reads(), equals(0));
      });
    }

    test('returns null when the relays cannot be read, and retries', () async {
      var reads = 0;
      when(
        () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async {
        if (reads++ == 0) throw TimeoutException('relays');
        return [seriesEvent()];
      });
      final repository = createRepository();

      expect(await fetch(repository, episode1), isNull);
      expect(await fetch(repository, episode1), isNotNull);
    });

    group('when the cache fails', () {
      test('answers from relays when it cannot read or write', () async {
        await CacheSync.init(
          dao: ThrowingCacheDao(throwOnRead: true, throwOnWrite: true),
        );
        answerRelays([
          [seriesEvent()],
        ]);

        expect(await fetch(createRepository(), episode1), isNotNull);
      });

      test('reads relays when a stale copy cannot be removed', () async {
        final cached = CuratedListConverter.fromEvent(seriesEvent())!;
        await CacheSync.init(
          dao: ThrowingCacheDao(
            readPayload: jsonEncode(cached.toJson()),
            throwOnDelete: true,
          ),
        );
        final reads = answerRelays([
          [
            seriesEvent(episodes: [episode1, episode2, episode3]),
          ],
        ]);

        expect(await fetch(createRepository(), episode3), isNotNull);
        expect(reads(), equals(1));
      });
    });
  });
}
