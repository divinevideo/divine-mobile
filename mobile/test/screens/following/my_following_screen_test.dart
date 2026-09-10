// ABOUTME: Widget tests for MyFollowingScreen's sort control
// ABOUTME: Ensures the app bar button opens the sheet and re-orders the list

import 'package:cache_sync/cache_sync.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/following/my_following_screen.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeCacheDao implements CacheDao {
  @override
  Future<String?> read(String key) async => null;

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

    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: const MyFollowingScreen(displayName: 'Alice'),
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
      'lists the most recent follow first before any sort is picked',
      (
        tester,
      ) async {
        await pumpScreen(tester);

        expect(
          visibleOrder(tester),
          equals([thirdFollowed, secondFollowed, firstFollowed]),
        );
      },
    );

    testWidgets('opens the sort sheet from the app bar', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.bySemanticsLabel(l10n.followingSortSemanticLabel));
      await tester.pumpAndSettle();

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
        equals([thirdFollowed, secondFollowed, firstFollowed]),
      );
    });
  });
}
