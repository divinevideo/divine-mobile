// ABOUTME: Widget tests for MyFollowingScreen's sort control
// ABOUTME: Ensures the app bar button opens the sheet and re-orders the list

import 'dart:async';

import 'package:cache_sync/cache_sync.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/following/my_following_screen.dart';
import 'package:openvine/services/user_ranking/user_ranking_signals_loader.dart';
import 'package:openvine/widgets/profile/follow_from_profile_button.dart';
import 'package:openvine/widgets/profile/profile_following_stat.dart';
import 'package:openvine/widgets/user_profile_tile.dart';
import 'package:user_ranking/user_ranking.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockRankingLoader extends Mock implements UserRankingSignalsLoader {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockNostrClient extends Mock implements NostrClient {}

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
    }) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: const MyFollowingScreen(displayName: 'Alice'),
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
            firstFollowed: const UserRankingSignals(pubkey: firstFollowed),
          },
        );
        when(() => second.load(any())).thenAnswer(
          (_) async => {
            secondFollowed: const UserRankingSignals(pubkey: secondFollowed),
          },
        );
        await pumpScreen(tester, loader: first);
        await tester.pumpAndSettle();
        expect(visibleOrder(tester), [firstFollowed]);
        await pumpScreen(tester, loader: second);
        await tester.pumpAndSettle();
        expect(visibleOrder(tester), [secondFollowed]);
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
      await pumpScreen(tester);

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
      when(() => mockFollowRepository.follow(any())).thenAnswer((_) async {});
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
      verifyNever(() => mockFollowRepository.follow(any()));
    });
  });
}
