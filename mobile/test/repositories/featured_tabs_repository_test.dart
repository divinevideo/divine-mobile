// ABOUTME: Tests for FeaturedTabsRepository cache TTL, eligibility and paging.
// ABOUTME: Covers the visibility matrix, stale-serve-then-drop and Vine loops.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/repositories/featured_tabs_repository.dart';

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

FeaturedTabConfig _tab({
  String id = 'ft_a1b2c3d4',
  bool enabled = true,
  bool hasContent = true,
  bool visibleToMinors = false,
  DateTime? startsAt,
  DateTime? endsAt,
}) {
  return FeaturedTabConfig(
    id: id,
    slug: 'featured-slug',
    label: const {'default': 'Featured'},
    startsAt: startsAt,
    endsAt: endsAt,
    enabled: enabled,
    hasContent: hasContent,
    visibleToMinors: visibleToMinors,
  );
}

void main() {
  group(FeaturedTabsRepository, () {
    late _MockFunnelcakeApiClient apiClient;
    late DateTime clock;

    setUp(() {
      apiClient = _MockFunnelcakeApiClient();
      clock = DateTime.utc(2026, 2, 15, 12);
    });

    FeaturedTabsRepository buildRepository() {
      return FeaturedTabsRepository(
        apiClient: apiClient,
        now: () => clock,
      );
    }

    void stubTabs(List<FeaturedTabConfig> tabs, {int pollSeconds = 300}) {
      when(apiClient.getFeaturedTabs).thenAnswer(
        (_) async => FeaturedTabsResponse(
          tabs: tabs,
          pollInterval: Duration(seconds: pollSeconds),
        ),
      );
    }

    void stubFailure() {
      when(apiClient.getFeaturedTabs).thenThrow(
        const FunnelcakeException('offline'),
      );
    }

    group('eligibility', () {
      test('returns the tab when every gate passes', () async {
        stubTabs([_tab()]);

        final snapshot = await buildRepository().refresh(
          gateAgeRestrictedContent: false,
        );

        expect(snapshot.hasTab, isTrue);
        expect(snapshot.tab?.id, equals('ft_a1b2c3d4'));
      });

      test('drops a disabled tab', () async {
        stubTabs([_tab(enabled: false)]);

        final snapshot = await buildRepository().refresh(
          gateAgeRestrictedContent: false,
        );

        expect(snapshot.hasTab, isFalse);
      });

      test('drops a tab with no server-side content', () async {
        stubTabs([_tab(hasContent: false)]);

        final snapshot = await buildRepository().refresh(
          gateAgeRestrictedContent: false,
        );

        expect(snapshot.hasTab, isFalse);
      });

      test('drops a tab whose window has not opened', () async {
        stubTabs([_tab(startsAt: clock.add(const Duration(days: 1)))]);

        final snapshot = await buildRepository().refresh(
          gateAgeRestrictedContent: false,
        );

        expect(snapshot.hasTab, isFalse);
      });

      test('drops a tab whose window has closed', () async {
        stubTabs([_tab(endsAt: clock.subtract(const Duration(days: 1)))]);

        final snapshot = await buildRepository().refresh(
          gateAgeRestrictedContent: false,
        );

        expect(snapshot.hasTab, isFalse);
      });

      test('hides an 18+ tab from an unverified viewer', () async {
        stubTabs([_tab()]);

        final snapshot = await buildRepository().refresh(
          gateAgeRestrictedContent: true,
        );

        expect(snapshot.hasTab, isFalse);
      });

      test('shows an under-18-enabled tab to an unverified viewer', () async {
        stubTabs([_tab(visibleToMinors: true)]);

        final snapshot = await buildRepository().refresh(
          gateAgeRestrictedContent: true,
        );

        expect(snapshot.hasTab, isTrue);
      });

      test('drops a tab with no id to fetch or attribute', () async {
        stubTabs([_tab(id: '')]);

        final snapshot = await buildRepository().refresh(
          gateAgeRestrictedContent: false,
        );

        expect(snapshot.hasTab, isFalse);
      });

      test('returns no tab when the server sends an empty list', () async {
        stubTabs(const []);

        final snapshot = await buildRepository().refresh(
          gateAgeRestrictedContent: false,
        );

        expect(snapshot.hasTab, isFalse);
      });

      test(
        'takes the first eligible entry when several are returned',
        () async {
          stubTabs([
            _tab(id: 'ft_disabled', enabled: false),
            _tab(id: 'ft_winner'),
            _tab(id: 'ft_runner_up'),
          ]);

          final snapshot = await buildRepository().refresh(
            gateAgeRestrictedContent: false,
          );

          expect(snapshot.tab?.id, equals('ft_winner'));
        },
      );

      test('surfaces the server poll interval', () async {
        stubTabs([_tab()], pollSeconds: 120);

        final snapshot = await buildRepository().refresh(
          gateAgeRestrictedContent: false,
        );

        expect(snapshot.pollInterval, equals(const Duration(seconds: 120)));
      });
    });

    group('cache', () {
      test('serves the cached tab through a transient failure', () async {
        final repository = buildRepository();
        stubTabs([_tab()]);
        await repository.refresh(gateAgeRestrictedContent: false);

        stubFailure();
        clock = clock.add(const Duration(minutes: 1));
        final snapshot = await repository.refresh(
          gateAgeRestrictedContent: false,
        );

        expect(snapshot.hasTab, isTrue);
      });

      test('drops the tab once the cache passes its TTL', () async {
        final repository = buildRepository();
        stubTabs([_tab()]);
        await repository.refresh(gateAgeRestrictedContent: false);

        stubFailure();
        clock = clock.add(FeaturedTabsRepository.defaultCacheTtl);
        final snapshot = await repository.refresh(
          gateAgeRestrictedContent: false,
        );

        expect(snapshot.hasTab, isFalse);
      });

      test('serves the cache right up to the contract TTL', () async {
        // funnelcake's API contract is "drop a cached config after 5 minutes
        // without a successful refresh". Serving longer than that would let an
        // outage strand a killed tab, so the boundary is pinned rather than
        // widened to absorb a failed poll.
        final repository = buildRepository();
        stubTabs([_tab()]);
        await repository.refresh(gateAgeRestrictedContent: false);

        stubFailure();
        clock = clock.add(
          FeaturedTabsRepository.defaultCacheTtl - const Duration(seconds: 1),
        );

        expect(
          (await repository.refresh(gateAgeRestrictedContent: false)).hasTab,
          isTrue,
        );
      });

      test('a superseded refresh does not become the cache', () async {
        // The poll, a foreground resume, and an age-gate change can all be in
        // flight at once. If a request issued before a server kill lands after
        // the one that removed the tab, the stale config it leaves behind gets
        // served to the next failed refresh and the killed tab comes back.
        final beforeKill = Completer<FeaturedTabsResponse>();
        final afterKill = Completer<FeaturedTabsResponse>();
        var call = 0;
        when(apiClient.getFeaturedTabs).thenAnswer((_) {
          call++;
          return call == 1 ? beforeKill.future : afterKill.future;
        });

        final repository = buildRepository();
        final stale = repository.refresh(gateAgeRestrictedContent: false);
        final fresh = repository.refresh(gateAgeRestrictedContent: false);

        afterKill.complete(
          const FeaturedTabsResponse(
            tabs: [],
            pollInterval: Duration(minutes: 5),
          ),
        );
        expect((await fresh).hasTab, isFalse);

        beforeKill.complete(
          FeaturedTabsResponse(
            tabs: [_tab()],
            pollInterval: const Duration(minutes: 5),
          ),
        );
        await stale;

        stubFailure();
        clock = clock.add(const Duration(minutes: 1));
        final snapshot = await repository.refresh(
          gateAgeRestrictedContent: false,
        );

        expect(
          snapshot.hasTab,
          isFalse,
          reason: 'the killed config must not be resurrected from cache',
        );
      });

      test('returns no tab when the first fetch fails with no cache', () async {
        stubFailure();

        final snapshot = await buildRepository().refresh(
          gateAgeRestrictedContent: false,
        );

        expect(snapshot.hasTab, isFalse);
      });

      test('recovers on the next successful fetch after expiry', () async {
        final repository = buildRepository();
        stubTabs([_tab()]);
        await repository.refresh(gateAgeRestrictedContent: false);

        stubFailure();
        clock = clock.add(FeaturedTabsRepository.defaultCacheTtl);
        await repository.refresh(gateAgeRestrictedContent: false);

        stubTabs([_tab()]);
        final snapshot = await repository.refresh(
          gateAgeRestrictedContent: false,
        );

        expect(snapshot.hasTab, isTrue);
      });

      test('re-gates the cached config for the current viewer', () async {
        final repository = buildRepository();
        stubTabs([_tab()]);
        await repository.refresh(gateAgeRestrictedContent: false);

        stubFailure();
        final snapshot = await repository.refresh(
          gateAgeRestrictedContent: true,
        );

        expect(snapshot.hasTab, isFalse);
      });

      test('stops serving a cached tab after clearCache', () async {
        final repository = buildRepository();
        stubTabs([_tab()]);
        await repository.refresh(gateAgeRestrictedContent: false);

        repository.clearCache();
        stubFailure();
        final snapshot = await repository.refresh(
          gateAgeRestrictedContent: false,
        );

        expect(snapshot.hasTab, isFalse);
      });

      test('drops a tab the server has since killed', () async {
        final repository = buildRepository();
        stubTabs([_tab()]);
        await repository.refresh(gateAgeRestrictedContent: false);

        stubTabs(const []);
        final snapshot = await repository.refresh(
          gateAgeRestrictedContent: false,
        );

        expect(snapshot.hasTab, isFalse);
      });
    });

    group('loadVideos', () {
      const tabId = 'ft_a1b2c3d4';

      // Featured-tab rows arrive without event tags, and `loops` is the
      // live Divine count.
      VideoStats featuredRow(String id, {String? platform}) {
        return VideoStats.fromJson({
          'id': id,
          'pubkey': 'a' * 64,
          'created_at': 1457922740,
          'kind': 34236,
          'd_tag': 'd-$id',
          'title': 'Featured video',
          'video_url': 'https://media.divine.video/$id.mp4',
          'platform': ?platform,
          'loops': 2564,
          'views': 8664,
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        });
      }

      void stubPage(List<VideoStats> videos) {
        when(
          () => apiClient.getFeaturedTabVideos(
            id: tabId,
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer((_) async => FeaturedTabVideosResponse(videos: videos));
      }

      test('restores the archived loops of a classic Vine', () async {
        stubPage([featuredRow('vine-1', platform: 'vine')]);
        when(() => apiClient.getBulkVideoStats(['vine-1'])).thenAnswer(
          (_) async => const BulkVideoStatsResponse(
            stats: {
              'vine-1': BulkVideoStatsEntry(
                eventId: 'vine-1',
                reactions: 0,
                comments: 0,
                reposts: 0,
                loops: 2564,
                embeddedLoops: 123411921,
                views: 8664,
              ),
            },
          ),
        );

        final page = await buildRepository().loadVideos(tabId: tabId);

        expect(page.videos.single.originalLoops, equals(123411921));
        expect(page.videos.single.totalLoops, equals(123411921 + 8664));
      });

      test(
        'does not look up archived loops for videos made on Divine',
        () async {
          stubPage([featuredRow('native-1')]);

          final page = await buildRepository().loadVideos(tabId: tabId);

          expect(page.videos.single.originalLoops, isNull);
          expect(page.videos.single.totalLoops, equals(8664));
          verifyNever(() => apiClient.getBulkVideoStats(any()));
        },
      );

      test('serves the page as-is when the archive lookup fails', () async {
        stubPage([featuredRow('vine-1', platform: 'vine')]);
        when(
          () => apiClient.getBulkVideoStats(['vine-1']),
        ).thenThrow(const FunnelcakeTimeoutException('bulk'));

        final page = await buildRepository().loadVideos(tabId: tabId);

        expect(page.videos.single.id, equals('vine-1'));
        expect(page.videos.single.originalLoops, isNull);
      });
    });
  });
}
