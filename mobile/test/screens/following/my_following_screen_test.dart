// ABOUTME: Widget tests for MyFollowingScreen's sort control
// ABOUTME: Ensures the app bar button opens the sheet and re-orders the list

import 'dart:async';

import 'package:cache_sync/cache_sync.dart';
import 'package:clock/clock.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
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
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/user_ranking_providers.dart';
import 'package:openvine/screens/following/my_following_screen.dart';
import 'package:openvine/services/user_ranking/user_ranking_signals_loader.dart';
import 'package:openvine/widgets/profile/follow_from_profile_button.dart';
import 'package:openvine/widgets/profile/profile_following_stat.dart';
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
  // In contact-list order: `firstFollowed` is the oldest `p` tag.
  const firstFollowed =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const secondFollowed =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const thirdFollowed =
      'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

  final l10n = lookupAppLocalizations(const Locale('en'));

  group(MyFollowingScreen, () {
    late _MockFollowRepository mockFollowRepository;
    late _MockContentBlocklistRepository mockBlocklistRepository;
    late _MockNostrClient mockNostrClient;

    setUp(() async {
      await CacheSync.init(dao: _FakeCacheDao());

      mockFollowRepository = _MockFollowRepository();
      mockBlocklistRepository = _MockContentBlocklistRepository();
      when(() => mockBlocklistRepository.currentState).thenReturn(
        const ContentPolicyState(
          currentUserPubkey: currentUserPubkey,
          mutedPubkeys: {},
          blockedPubkeys: {},
          pubkeysBlockingUs: {},
          pubkeysMutingUs: {},
        ),
      );
      mockNostrClient = _MockNostrClient();

      when(() => mockBlocklistRepository.isBlocked(any())).thenReturn(false);
      when(
        () => mockBlocklistRepository.isFollowSevered(any()),
      ).thenReturn(false);
      when(() => mockFollowRepository.isFollowing(any())).thenReturn(true);
      // All three sources agree on the contact-list order, as they do in
      // production — the screen is what turns it newest-first.
      when(() => mockFollowRepository.followingPubkeys).thenReturn(
        const [firstFollowed, secondFollowed, thirdFollowed],
      );
      when(() => mockFollowRepository.followingStream).thenAnswer(
        (_) => Stream<List<String>>.value(
          const [firstFollowed, secondFollowed, thirdFollowed],
        ),
      );
      when(() => mockNostrClient.publicKey).thenReturn(currentUserPubkey);
      when(() => mockFollowRepository.watchMyFollowingCached()).thenAnswer(
        (_) => Stream.value(
          const CacheResult.live(
            FollowingSnapshot(
              pubkeys: [firstFollowed, secondFollowed, thirdFollowed],
              count: 3,
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
          home: ProviderScope(
            overrides: [?rankingOverride, ...additionalOverrides],
            child: const MyFollowingScreen(displayName: 'Alice'),
          ),
          rankingSignalsLoader: loader,
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
      'same-owner fresh loader preserves manual sort and visible order',
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
        final context = tester.element(find.byType(UserProfileTile).first);
        final old = context.read<MyFollowingBloc>();
        old.add(const MyFollowingSortOrderChanged(FollowListSort.newestFirst));
        await tester.pump();
        final order = visibleOrder(tester);
        ProviderScope.containerOf(context).read(version.notifier).state++;
        await tester.pumpAndSettle();
        final next = tester
            .element(find.byType(UserProfileTile).first)
            .read<MyFollowingBloc>();
        expect(old.isClosed, isTrue);
        expect(next.state.sortOrder, FollowListSort.newestFirst);
        expect(visibleOrder(tester), order);
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
        final context = tester.element(find.byType(UserProfileTile).first);
        final old = context.read<MyFollowingBloc>();
        await tester.tap(
          find.bySemanticsLabel(l10n.followingSortSemanticLabel),
        );
        await tester.pumpAndSettle();
        ProviderScope.containerOf(context).read(version.notifier).state++;
        await tester.pumpAndSettle();
        expect(old.isClosed, isTrue);

        await tester.tap(find.text(l10n.followSortNewest));
        await tester.pumpAndSettle();

        final next = tester
            .element(find.byType(UserProfileTile).first)
            .read<MyFollowingBloc>();
        expect(next.state.sortOrder, FollowListSort.newestFirst);
        expect(
          visibleOrder(tester),
          equals([thirdFollowed, secondFollowed, firstFollowed]),
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
            kind: FollowListKind.following,
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
        final old = context.read<MyFollowingBloc>();
        old.add(const MyFollowingSortOrderChanged(FollowListSort.newestFirst));
        await tester.pump();
        final order = old.state.followingPubkeys;
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
        final next = nextContext.read<MyFollowingBloc>();
        expect(old.isClosed, isTrue);
        expect(next.state.sortOrder, FollowListSort.newestFirst);
        expect(next.state.followingPubkeys, order);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'alice',
        );
        expect(nextContext.read<FollowListSearchBloc>().state.query, 'alice');
        verify(
          () => mockFollowRepository.searchFollowList(
            pubkey: currentUserPubkey,
            query: 'alice',
            kind: FollowListKind.following,
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
        final other = otherContext.read<MyFollowingBloc>();
        expect(next.isClosed, isTrue);
        expect(other.state.sortOrder, FollowListSort.smart);
        expect(other.state.rawFollowingPubkeys, isEmpty);
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
          firstFollowed: UserRankingSignals(
            pubkey: firstFollowed,
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

    testWidgets(
      'lists equal-score follows in deterministic Smart order',
      (
        tester,
      ) async {
        await pumpScreen(tester);

        expect(
          visibleOrder(tester),
          equals([firstFollowed, secondFollowed, thirdFollowed]),
        );
      },
    );

    testWidgets(
      'does not flash cached rows before the local ranking resolves',
      (tester) async {
        final loaded = Completer<Map<String, UserRankingSignals>>();
        final loader = _MockRankingLoader();
        when(() => loader.loadCachedDisplayNames(any()))
            .thenAnswer((_) async => {});
        when(() => loader.isEligible(any())).thenReturn(true);
        when(() => loader.load(any())).thenAnswer((_) => loaded.future);
        await pumpScreen(tester, loader: loader);
        expect(find.byType(UserProfileTile), findsNothing);
        loaded.complete({
          firstFollowed: const UserRankingSignals(pubkey: firstFollowed),
          secondFollowed: const UserRankingSignals(
            pubkey: secondFollowed,
            youFollow: true,
          ),
          thirdFollowed: const UserRankingSignals(pubkey: thirdFollowed),
        });
        await tester.pumpAndSettle();
        expect(visibleOrder(tester), [
          secondFollowed,
          firstFollowed,
          thirdFollowed,
        ]);
      },
    );

    testWidgets('cached following button and count render on the first frame', (
      tester,
    ) async {
      final loaded = Completer<Map<String, UserRankingSignals>>();
      final loader = _MockRankingLoader();
      when(() => loader.loadCachedDisplayNames(any()))
          .thenAnswer((_) async => {});
      when(() => loader.isEligible(any())).thenReturn(true);
      when(() => loader.load(any())).thenAnswer((_) => loaded.future);
      await tester.pumpWidget(
        testMaterialApp(
          home: const Scaffold(
            body: Column(
              children: [
                FollowFromProfileButton(
                  pubkey: firstFollowed,
                  displayName: 'Alice',
                ),
                ProfileFollowingStat(
                  pubkey: currentUserPubkey,
                  displayName: 'Alice',
                  isOwnProfile: true,
                ),
              ],
            ),
          ),
          rankingSignalsLoader: loader,
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
      expect(
        find.bySemanticsLabel(l10n.unfollowUserSemanticLabel),
        findsOneWidget,
      );
      expect(find.text('3'), findsOneWidget);
      loaded.complete({
        for (final key in [firstFollowed, secondFollowed, thirdFollowed])
          key: UserRankingSignals(pubkey: key),
      });
      await tester.pumpAndSettle();
    });

    testWidgets(
      'recreates the list when account-scoped ranking dependencies change',
      (tester) async {
        final first = _MockRankingLoader();
        final second = _MockRankingLoader();
        when(() => first.loadCachedDisplayNames(any()))
            .thenAnswer((_) async => {});
        when(() => second.loadCachedDisplayNames(any()))
            .thenAnswer((_) async => {});
        when(() => first.isEligible(any())).thenReturn(true);
        when(() => second.isEligible(any())).thenReturn(true);
        when(() => first.load(any())).thenAnswer(
          (_) async => {
            firstFollowed: const UserRankingSignals(
              pubkey: firstFollowed,
              youFollow: true,
            ),
          },
        );
        when(() => second.load(any())).thenAnswer(
          (_) async => {
            secondFollowed: const UserRankingSignals(
              pubkey: secondFollowed,
              youFollow: true,
            ),
          },
        );
        await pumpScreen(tester, loader: first);
        await tester.pumpAndSettle();
        final old = tester
            .element(find.byType(UserProfileTile).first)
            .read<MyFollowingBloc>();
        expect(
          visibleOrder(tester),
          containsAll([firstFollowed, secondFollowed, thirdFollowed]),
        );
        expect(old.state.rankingSignals[firstFollowed]?.youFollow, isTrue);
        await pumpScreen(tester, loader: second);
        await tester.pumpAndSettle();
        final next = tester
            .element(find.byType(UserProfileTile).first)
            .read<MyFollowingBloc>();
        expect(next, isNot(same(old)));
        expect(old.isClosed, isTrue);
        expect(
          visibleOrder(tester),
          containsAll([firstFollowed, secondFollowed, thirdFollowed]),
        );
        expect(next.state.rankingSignals[secondFollowed]?.youFollow, isTrue);
        expect(next.state.rankingSignals[firstFollowed]?.youFollow, isFalse);
      },
    );

    testWidgets('opens the sort sheet from the app bar', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.bySemanticsLabel(l10n.followingSortSemanticLabel));
      await tester.pumpAndSettle();

      expect(find.text(l10n.followSortSmart), findsOneWidget);
      expect(find.text(l10n.followSortTitle), findsOneWidget);
      expect(find.text(l10n.followSortNewest), findsOneWidget);
      expect(find.text(l10n.followSortOldest), findsOneWidget);
    });

    testWidgets('picking oldest first restores contact-list order', (
      tester,
    ) async {
      final loader = _MockRankingLoader();
      when(() => loader.loadCachedDisplayNames(any()))
          .thenAnswer((_) async => {});
      when(() => loader.load(any())).thenAnswer(
        (call) async => {
          for (final key in call.positionalArguments.single as Iterable<String>)
            key: UserRankingSignals(
              pubkey: key,
              youFollow: key == secondFollowed,
            ),
        },
      );
      await pumpScreen(tester, loader: loader);
      expect(visibleOrder(tester), [
        secondFollowed,
        firstFollowed,
        thirdFollowed,
      ]);

      await tester.tap(find.bySemanticsLabel(l10n.followingSortSemanticLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.followSortOldest));
      await tester.pumpAndSettle();

      expect(
        visibleOrder(tester),
        equals([firstFollowed, secondFollowed, thirdFollowed]),
      );
    });

    testWidgets('dismissing the sheet leaves the order alone', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.bySemanticsLabel(l10n.followingSortSemanticLabel));
      await tester.pumpAndSettle();
      // Tap the barrier above the sheet to dismiss without choosing.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(
        visibleOrder(tester),
        equals([firstFollowed, secondFollowed, thirdFollowed]),
      );
    });

    testWidgets('confirming Unfollow on a row unfollows it, never follows it', (
      tester,
    ) async {
      when(() => mockFollowRepository.followWithResult(any()))
          .thenAnswer((_) async => FollowOutcome.published);
      when(
        () => mockFollowRepository.unfollow(any()),
      ).thenAnswer((_) async {});
      await pumpScreen(tester);

      await tester.tap(_rowIcon(thirdFollowed, DivineIconName.userMinus));
      await tester.pumpAndSettle();
      // The follow list loses the account while the sheet is open; confirming
      // must still unfollow rather than decide again from the list.
      when(() => mockFollowRepository.isFollowing(any())).thenReturn(false);
      await tester.tap(find.text(l10n.unfollowConfirmButton));
      await tester.pumpAndSettle();

      verify(() => mockFollowRepository.unfollow(thirdFollowed)).called(1);
      verifyNever(() => mockFollowRepository.followWithResult(any()));
    });
  });
}
