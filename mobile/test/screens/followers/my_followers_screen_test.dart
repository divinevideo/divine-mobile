// ABOUTME: Widget tests for MyFollowersScreen's sort control
// ABOUTME: Ensures the app bar button opens the sheet and re-orders the list

import 'package:cache_sync/cache_sync.dart';
import 'package:clock/clock.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/follow_list_search/follow_list_search_bloc.dart';
import 'package:openvine/blocs/follow_list_sort.dart';
import 'package:openvine/blocs/my_followers/my_followers_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/user_ranking_providers.dart';
import 'package:openvine/screens/followers/my_followers_screen.dart';
import 'package:openvine/services/user_ranking/user_ranking_signals_loader.dart';
import 'package:openvine/widgets/user_profile_tile.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:user_ranking/user_ranking.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockRankingLoader extends Mock implements UserRankingSignalsLoader {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockNostrClient extends Mock implements NostrClient {}

class _TestNostrSession extends NostrSession {
  _TestNostrSession(this.owner);
  final String owner;
  @override
  NostrSessionReadiness build() =>
      NostrSessionReadiness.identityKnown(pubkey: owner);
}

class _FakeCacheDao implements CacheDao {
  @override
  Future<CacheEntry?> readEntry(String key) async => null;

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {}

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deletePrefix(String prefix) async {}

  @override
  Future<int> totalPayloadBytes() async => 0;

  @override
  Future<void> evictOldest(int bytesToFree) async {}
}

Finder _rowIcon(String pubkey, DivineIconName icon) => find.descendant(
  of: find.byWidgetPredicate(
    (w) => w is UserProfileTile && w.pubkey == pubkey,
  ),
  matching: find.byWidgetPredicate((w) => w is DivineIcon && w.icon == icon),
);

void main() {
  const currentUserPubkey =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const newestFollower =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const oldestFollower =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const undatedFollower =
      'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

  final l10n = lookupAppLocalizations(const Locale('en'));

  group(MyFollowersScreen, () {
    late _MockFollowRepository mockFollowRepository;
    late _MockContentBlocklistRepository mockBlocklistRepository;
    late _MockNostrClient mockNostrClient;

    setUp(() async {
      await CacheSync.init(dao: _FakeCacheDao());

      mockFollowRepository = _MockFollowRepository();
      mockBlocklistRepository = _MockContentBlocklistRepository();
      mockNostrClient = _MockNostrClient();

      when(() => mockBlocklistRepository.isBlocked(any())).thenReturn(false);
      when(
        () => mockBlocklistRepository.isFollowSevered(any()),
      ).thenReturn(false);
      when(() => mockFollowRepository.isFollowing(any())).thenReturn(false);
      when(() => mockFollowRepository.followingPubkeys).thenReturn(const []);
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => Stream<List<String>>.value(const []));
      when(() => mockNostrClient.publicKey).thenReturn(currentUserPubkey);
      when(() => mockFollowRepository.watchMyFollowingCached()).thenAnswer(
        (_) => Stream.value(
          const CacheResult.live(
            FollowingSnapshot(pubkeys: <String>[], count: 0),
          ),
        ),
      );
      // Newest first, with one follower the REST source could not date.
      when(() => mockFollowRepository.watchMyFollowersCached()).thenAnswer(
        (_) => Stream.value(
          const CacheResult.live(
            FollowersSnapshot(
              pubkeys: [newestFollower, oldestFollower, undatedFollower],
              count: 3,
              datedCount: 2,
            ),
          ),
        ),
      );
    });

    Future<void> pumpScreen(
      WidgetTester tester, {
      UserRankingSignalsLoader? loader,
      Override? rankingOverride,
      List<Override> additionalOverrides = const [],
    }) async {
      await tester.pumpWidget(
        testMaterialApp(
          rankingSignalsLoader: loader,
          home: ProviderScope(
            overrides: [?rankingOverride, ...additionalOverrides],
            child: const MyFollowersScreen(displayName: 'Alice'),
          ),
          mockProfileRepository: createMockProfileRepository(),
          mockNostrService: mockNostrClient,
          mockFollowRepository: mockFollowRepository,
          additionalOverrides: [
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockBlocklistRepository,
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    List<String> visibleOrder(WidgetTester tester) => tester
        .widgetList<UserProfileTile>(find.byType(UserProfileTile))
        .map((tile) => tile.pubkey)
        .toList();

    testWidgets(
      'same-owner fresh loader preserves chronological follower order',
      (tester) async {
        final version = StateProvider<int>((ref) => 0);
        final loaders = <_MockRankingLoader>[];
        await pumpScreen(
          tester,
          rankingOverride: ownFollowListRankingSignalsLoaderProvider
              .overrideWith((ref) {
                ref.watch(version);
                final loader = _MockRankingLoader();
                loaders.add(loader);
                when(() => loader.isEligible(any())).thenReturn(true);
                when(() => loader.loadCachedDisplayNames(any()))
                    .thenAnswer((_) async => {});
                when(() => loader.load(any())).thenAnswer(
                  (call) async => {
                    for (final key
                        in call.positionalArguments.single as Iterable<String>)
                      key: UserRankingSignals(pubkey: key),
                  },
                );
                return loader;
              }),
        );
        final old = tester
            .element(find.byType(UserProfileTile).first)
            .read<MyFollowersBloc>();
        old.add(const MyFollowersSortOrderChanged(FollowListSort.oldestFirst));
        await tester.pump();
        final order = visibleOrder(tester);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MyFollowersScreen)),
        );
        container.read(version.notifier).state++;
        await tester.pump();
        await tester.pump();
        final next = tester
            .element(find.byType(UserProfileTile).first)
            .read<MyFollowersBloc>();
        expect(old.isClosed, isTrue);
        expect(next.state.sortOrder, FollowListSort.oldestFirst);
        expect(visibleOrder(tester), order);
        expect(loaders, hasLength(2));
      },
    );

    testWidgets(
      'a sort picked after the bloc is replaced reaches the replacement',
      (tester) async {
        final version = StateProvider<int>((ref) => 0);
        await pumpScreen(
          tester,
          rankingOverride: ownFollowListRankingSignalsLoaderProvider
              .overrideWith((ref) {
                ref.watch(version);
                final loader = _MockRankingLoader();
                when(() => loader.isEligible(any())).thenReturn(true);
                when(() => loader.loadCachedDisplayNames(any()))
                    .thenAnswer((_) async => {});
                when(() => loader.load(any())).thenAnswer(
                  (call) async => {
                    for (final key
                        in call.positionalArguments.single as Iterable<String>)
                      key: UserRankingSignals(pubkey: key),
                  },
                );
                return loader;
              }),
        );
        final old = tester
            .element(find.byType(UserProfileTile).first)
            .read<MyFollowersBloc>();
        await tester.tap(
          find.bySemanticsLabel(l10n.followersSortSemanticLabel),
        );
        await tester.pumpAndSettle();
        ProviderScope.containerOf(
          tester.element(find.byType(MyFollowersScreen)),
        ).read(version.notifier).state++;
        await tester.pumpAndSettle();
        expect(old.isClosed, isTrue);

        await tester.tap(find.text(l10n.followSortOldest));
        await tester.pumpAndSettle();

        final next = tester
            .element(find.byType(UserProfileTile).first)
            .read<MyFollowersBloc>();
        expect(next.state.sortOrder, FollowListSort.oldestFirst);
        expect(
          visibleOrder(tester),
          equals([oldestFollower, newestFollower, undatedFollower]),
        );
      },
    );

    testWidgets(
      'client readiness preserves same-owner sort and query but owner changes reset them',
      (tester) async {
        final version = StateProvider<int>((ref) => 0);
        final freshProfiles = createMockProfileRepository();
        final otherOwnerRepository = createMockFollowRepository();
        when(otherOwnerRepository.watchMyFollowingCached).thenAnswer(
          (_) => Stream.value(
            const CacheResult.live(FollowingSnapshot(pubkeys: [], count: 0)),
          ),
        );
        when(otherOwnerRepository.watchMyFollowersCached).thenAnswer(
          (_) => Stream.value(
            const CacheResult.live(FollowersSnapshot(pubkeys: [], count: 0)),
          ),
        );
        when(() => mockNostrClient.publicKey).thenReturn('');
        when(
          () => mockFollowRepository.searchFollowList(
            pubkey: currentUserPubkey,
            query: 'alice',
            kind: FollowListKind.followers,
          ),
        ).thenAnswer((_) async => {});
        await pumpScreen(
          tester,
          rankingOverride: ownFollowListRankingSignalsLoaderProvider
              .overrideWith((ref) {
                ref.watch(version);
                final loader = _MockRankingLoader();
                when(() => loader.isEligible(any())).thenReturn(true);
                when(() => loader.loadCachedDisplayNames(any()))
                    .thenAnswer((_) async => {});
                when(() => loader.load(any())).thenAnswer(
                  (call) async => {
                    for (final key
                        in call.positionalArguments.single as Iterable<String>)
                      key: UserRankingSignals(pubkey: key),
                  },
                );
                return loader;
              }),
          additionalOverrides: [
            nostrSessionProvider.overrideWith(
              () => _TestNostrSession(currentUserPubkey),
            ),
            profileRepositoryProvider.overrideWith(
              (ref) => ref.watch(version) == 0 ? null : freshProfiles,
            ),
            followRepositoryProvider.overrideWith(
              (ref) =>
                  ref.watch(nostrSessionProvider).pubkey == currentUserPubkey
                  ? mockFollowRepository
                  : otherOwnerRepository,
            ),
          ],
        );
        final context = tester.element(find.byType(TextField));
        final container = ProviderScope.containerOf(context);
        final old = context.read<MyFollowersBloc>();
        old.add(const MyFollowersSortOrderChanged(FollowListSort.oldestFirst));
        await tester.pump();
        final order = old.state.followersPubkeys;
        await tester.enterText(find.byType(TextField), 'alice');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(context.read<FollowListSearchBloc>().state.query, 'alice');

        when(() => mockNostrClient.publicKey).thenReturn(currentUserPubkey);
        container.read(version.notifier).state++;
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        final nextContext = tester.element(find.byType(TextField));
        final next = nextContext.read<MyFollowersBloc>();
        expect(old.isClosed, isTrue);
        expect(next.state.sortOrder, FollowListSort.oldestFirst);
        expect(next.state.followersPubkeys, order);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'alice',
        );
        expect(nextContext.read<FollowListSearchBloc>().state.query, 'alice');
        verify(
          () => mockFollowRepository.searchFollowList(
            pubkey: currentUserPubkey,
            query: 'alice',
            kind: FollowListKind.followers,
          ),
        ).called(1);

        when(() => mockNostrClient.publicKey).thenReturn('');
        container
            .read(nostrSessionProvider.notifier)
            .update(
              const NostrSessionReadiness.identityKnown(
                pubkey: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
              ),
            );
        await tester.pumpAndSettle();
        final otherContext = tester.element(find.byType(Scaffold));
        final other = otherContext.read<MyFollowersBloc>();
        expect(next.isClosed, isTrue);
        expect(other.state.sortOrder, FollowListSort.smart);
        expect(other.state.rawFollowersPubkeys, isEmpty);
        expect(other.state.rankingSignals, isEmpty);
        expect(otherContext.read<FollowListSearchBloc>().state.query, isEmpty);
      },
    );

    testWidgets('renders cached activity from the list ranking state', (
      tester,
    ) async {
      final loader = _MockRankingLoader();
      when(() => loader.isEligible(any())).thenReturn(true);
      when(() => loader.loadCachedDisplayNames(any()))
          .thenAnswer((_) async => {});
      when(() => loader.load(any())).thenAnswer(
        (_) async => {
          newestFollower: UserRankingSignals(
            pubkey: newestFollower,
            videoCount: 18,
            lastPostedAt: clock.now().subtract(const Duration(hours: 2)),
          ),
        },
      );
      await pumpScreen(tester, loader: loader);
      await tester.pumpAndSettle();
      expect(
        find.textContaining(l10n.searchUserVideoCount(18, '18')),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          l10n.userRowPosted(l10n.timeAgo(l10n.timeShortHours(2))),
        ),
        findsOneWidget,
      );
    });

    testWidgets('lists equal-score followers in deterministic Smart order', (
      tester,
    ) async {
      final loader = _MockRankingLoader();
      when(() => loader.loadCachedDisplayNames(any())).thenAnswer(
        (_) async => {
          newestFollower: 'Zulu',
          oldestFollower: 'Alpha',
          undatedFollower: 'Mike',
        },
      );
      when(() => loader.load(any())).thenAnswer(
        (call) async => {
          for (final key in call.positionalArguments.single as Iterable<String>)
            key: UserRankingSignals(pubkey: key),
        },
      );
      await pumpScreen(tester, loader: loader);

      expect(
        visibleOrder(tester),
        equals([oldestFollower, undatedFollower, newestFollower]),
      );
    });

    testWidgets('opens the sort sheet from the app bar', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.bySemanticsLabel(l10n.followersSortSemanticLabel));
      await tester.pumpAndSettle();

      expect(find.text(l10n.followSortSmart), findsOneWidget);
      expect(find.text(l10n.followSortTitle), findsOneWidget);
      expect(find.text(l10n.followSortNewest), findsOneWidget);
      expect(find.text(l10n.followSortOldest), findsOneWidget);
    });

    testWidgets('picking oldest first flips the dated followers', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.bySemanticsLabel(l10n.followersSortSemanticLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.followSortOldest));
      await tester.pumpAndSettle();

      // The undated follower stays last — only the datable pair swaps.
      expect(
        visibleOrder(tester),
        equals([oldestFollower, newestFollower, undatedFollower]),
      );
    });

    testWidgets('dismissing the sheet leaves the order alone', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.bySemanticsLabel(l10n.followersSortSemanticLabel));
      await tester.pumpAndSettle();
      // Tap the barrier above the sheet to dismiss without choosing.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(
        visibleOrder(tester),
        equals([newestFollower, oldestFollower, undatedFollower]),
      );
    });

    testWidgets('tapping Follow on a row follows it, never unfollows it', (
      tester,
    ) async {
      when(() => mockFollowRepository.followWithResult(any()))
          .thenAnswer((_) async => FollowOutcome.published);
      when(
        () => mockFollowRepository.unfollow(any()),
      ).thenAnswer((_) async {});
      await pumpScreen(tester);

      // The follow list gains the account after the row drew Follow; the tap
      // must still follow rather than decide again from the list.
      when(() => mockFollowRepository.isFollowing(any())).thenReturn(true);
      await tester.tap(_rowIcon(newestFollower, DivineIconName.userPlus));
      await tester.pump();

      verify(() => mockFollowRepository.followWithResult(newestFollower))
          .called(1);
      verifyNever(() => mockFollowRepository.unfollow(any()));
    });
  });
}
