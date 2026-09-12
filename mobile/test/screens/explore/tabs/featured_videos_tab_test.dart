// ABOUTME: Widget tests for featured Explore tab video handoffs.
// ABOUTME: Tapping a featured tile must open the curated snapshot with campaign attribution.

import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/featured_tabs/featured_tabs_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/providers/featured_tabs_providers.dart';
import 'package:openvine/providers/feed_repository_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/repositories/featured_tabs_repository.dart';
import 'package:openvine/screens/explore/tabs/featured_videos_tab.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

import '../../../helpers/go_router.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockFeaturedTabsRepository extends Mock
    implements FeaturedTabsRepository {}

class _MockFeedRepository extends Mock implements FeedRepository {}

FeaturedTabConfig _config({Map<String, String> disclosureLabel = const {}}) {
  return FeaturedTabConfig(
    id: 'ft_a1b2c3d4',
    slug: 'featured-slug',
    label: const {'default': 'Featured'},
    disclosureLabel: disclosureLabel,
    startsAt: null,
    endsAt: null,
    enabled: true,
    hasContent: true,
  );
}

/// A sponsored configuration. The brand is invented — real partner names stay
/// in server config and out of this repository.
FeaturedTabConfig _sponsoredConfig() =>
    _config(disclosureLabel: const {'default': 'Acme Bikes'});

String _sponsoredLine(String sponsor) => lookupAppLocalizations(
  const Locale('en'),
).exploreFeaturedSponsoredBy(sponsor);

/// The disclosure's own wording, with the brand taken out.
///
/// Negative assertions match on this rather than on one brand string. A line
/// that renders with the wrong sponsor — or with none at all — is still a
/// commercial disclosure on a collection that has no sponsor, and a matcher
/// naming a brand the widget was never given cannot fail on either.
String _disclosureWording() => _sponsoredLine('').trim();

VideoEvent _video(String id) {
  return VideoEvent(
    id: id,
    pubkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
    createdAt: 1700000000,
    content: '',
    timestamp: DateTime.utc(2026, 2, 15),
    videoUrl: 'https://media.divine.video/$id.mp4',
    thumbnailUrl: 'https://media.divine.video/$id.jpg',
  );
}

void main() {
  group(FeaturedVideosTab, () {
    late _MockFeaturedTabsRepository featuredRepository;
    late _MockFeedRepository feedRepository;
    late MockGoRouter router;
    late FeaturedTabsCubit featuredTabsCubit;

    setUp(() {
      featuredRepository = _MockFeaturedTabsRepository();
      feedRepository = _MockFeedRepository();
      router = MockGoRouter();
      when(
        () => featuredRepository.refresh(
          gateAgeRestrictedContent: any(named: 'gateAgeRestrictedContent'),
        ),
      ).thenAnswer(
        // Zero cadence keeps the cubit from arming a poll timer that would
        // outlive the widget test.
        (_) async => const FeaturedTabsSnapshot(pollInterval: Duration.zero),
      );
      featuredTabsCubit = FeaturedTabsCubit(
        repository: featuredRepository,
        gateAgeRestrictedContent: () => false,
      );
      addTearDown(featuredTabsCubit.close);
      when(
        () => featuredRepository.loadVideos(
          tabId: 'ft_a1b2c3d4',
          cursor: any(named: 'cursor'),
        ),
      ).thenAnswer(
        (_) async =>
            FeaturedTabVideosPage(videos: [_video('first'), _video('second')]),
      );
      when(
        () => router.push<Object?>(any(), extra: any(named: 'extra')),
      ).thenAnswer((_) async => null);
    });

    Widget buildSubject({FeaturedTabConfig? config}) {
      return testMaterialApp(
        additionalOverrides: [
          featuredTabsRepositoryProvider.overrideWithValue(featuredRepository),
          feedRepositoryProvider.overrideWithValue(feedRepository),
          subscribedListVideoCacheProvider.overrideWithValue(null),
        ],
        home: BlocProvider<FeaturedTabsCubit>.value(
          value: featuredTabsCubit,
          child: MockGoRouterProvider(
            goRouter: router,
            child: FeaturedVideosTab(config: config ?? _config()),
          ),
        ),
      );
    }

    testWidgets('opens the curated snapshot with config attribution', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(VideoThumbnailWidget).first);
      await tester.pump();

      final captured = verify(
        () => router.push<Object?>(any(), extra: captureAny(named: 'extra')),
      ).captured.single;
      final args = captured as PooledFullscreenVideoFeedArgs;

      expect(args.source, isA<VideoListViewSource>());
      expect(args.initialIndex, 0);
      expect(args.initialVideoId, 'first');
      expect(args.sponsorName, isNull);
      expect(args.trafficSource, ViewTrafficSource.discoveryFeatured);
      expect(args.sourceDetail, 'ft_a1b2c3d4');
      expect(args.feedRepository, same(feedRepository));

      final source = args.source as VideoListViewSource;
      expect(source.videos.map((video) => video.id), ['first', 'second']);
    });

    testWidgets('carries the resolved sponsor into the fullscreen feed', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(config: _sponsoredConfig()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(VideoThumbnailWidget).first);
      await tester.pump();

      final captured = verify(
        () => router.push<Object?>(any(), extra: captureAny(named: 'extra')),
      ).captured.single;
      final args = captured as PooledFullscreenVideoFeedArgs;

      expect(args.sponsorName, 'Acme Bikes');
    });

    testWidgets('carries the sanitized sponsor into the fullscreen feed', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          config: _config(
            disclosureLabel: const {
              'default': '\u0000Acme Bikes and Accessories Beyond Limit',
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(VideoThumbnailWidget).first);
      await tester.pump();

      final captured = verify(
        () => router.push<Object?>(any(), extra: captureAny(named: 'extra')),
      ).captured.single;
      final args = captured as PooledFullscreenVideoFeedArgs;

      expect(args.sponsorName, 'Acme Bikes and Accessor…');
    });

    testWidgets('refetches an empty page when a config poll lands', (
      tester,
    ) async {
      // has_content runs on a 15-minute snapshot cadence and can lead the
      // videos endpoint, so funnelcake asks clients to treat an empty page as
      // transient and retry on the next poll. FeaturedTabVideosState.isEmpty
      // already documented that; nothing acted on it.
      when(
        () => featuredRepository.loadVideos(
          tabId: 'ft_a1b2c3d4',
          cursor: any(named: 'cursor'),
        ),
      ).thenAnswer((_) async => const FeaturedTabVideosPage(videos: []));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      verify(
        () => featuredRepository.loadVideos(tabId: 'ft_a1b2c3d4'),
      ).called(1);

      await featuredTabsCubit.refresh();
      await tester.pumpAndSettle();

      verify(
        () => featuredRepository.loadVideos(tabId: 'ft_a1b2c3d4'),
      ).called(1);
    });

    testWidgets('leaves a populated page alone when a config poll lands', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      verify(
        () => featuredRepository.loadVideos(tabId: 'ft_a1b2c3d4'),
      ).called(1);

      await featuredTabsCubit.refresh();
      await tester.pumpAndSettle();

      verifyNever(() => featuredRepository.loadVideos(tabId: 'ft_a1b2c3d4'));
    });

    testWidgets('reloads when the configuration is retargeted in place', (
      tester,
    ) async {
      // The admin endpoint upserts by id, so a tab can be retargeted without
      // its id changing, and the backing hashtag never reaches the client. The
      // visible fields are the only retarget signal there is, so any change to
      // them has to refetch rather than leave the previous collection up.
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      verify(
        () => featuredRepository.loadVideos(tabId: 'ft_a1b2c3d4'),
      ).called(1);

      await tester.pumpWidget(
        buildSubject(
          config: const FeaturedTabConfig(
            id: 'ft_a1b2c3d4',
            slug: 'featured-slug',
            label: {'default': 'Retargeted'},
            startsAt: null,
            endsAt: null,
            enabled: true,
            hasContent: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      verify(
        () => featuredRepository.loadVideos(tabId: 'ft_a1b2c3d4'),
      ).called(1);
    });
    testWidgets('discloses the sponsor above the grid', (tester) async {
      await tester.pumpWidget(buildSubject(config: _sponsoredConfig()));
      await tester.pumpAndSettle();

      final line = find.text(_sponsoredLine('Acme Bikes'));
      expect(line, findsOneWidget);
      // Pinned above the grid rather than scrolled into it.
      expect(
        tester.getCenter(line).dy,
        lessThan(tester.getCenter(find.byType(VideoThumbnailWidget).first).dy),
      );
    });

    testWidgets('discloses nothing when the collection is unsponsored', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.textContaining(_disclosureWording()), findsNothing);
    });

    testWidgets(
      'discloses nothing when the sponsor resolves only for another locale',
      (tester) async {
        // Mirrors the pill: a sponsor this viewer cannot see must not half-
        // appear as a line naming somebody else's locale either.
        await tester.pumpWidget(
          buildSubject(
            config: _config(disclosureLabel: const {'pt': 'Acme Bicicletas'}),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining(_disclosureWording()), findsNothing);
      },
    );

    testWidgets('keeps the disclosure above an empty grid', (tester) async {
      // The tab can be scheduled ahead of its content snapshot, so a live
      // partnership is reachable with nothing to show.
      when(
        () => featuredRepository.loadVideos(
          tabId: 'ft_a1b2c3d4',
          cursor: any(named: 'cursor'),
        ),
      ).thenAnswer((_) async => const FeaturedTabVideosPage(videos: []));

      await tester.pumpWidget(buildSubject(config: _sponsoredConfig()));
      await tester.pumpAndSettle();

      expect(find.text(_sponsoredLine('Acme Bikes')), findsOneWidget);
    });

    testWidgets('keeps the disclosure when the videos request fails', (
      tester,
    ) async {
      when(
        () => featuredRepository.loadVideos(
          tabId: 'ft_a1b2c3d4',
          cursor: any(named: 'cursor'),
        ),
      ).thenThrow(const FunnelcakeException('network down'));

      await tester.pumpWidget(buildSubject(config: _sponsoredConfig()));
      await tester.pumpAndSettle();
      // It describes the tab's commercial arrangement, not its contents.
      expect(find.text(_sponsoredLine('Acme Bikes')), findsOneWidget);
    });
  });
}
