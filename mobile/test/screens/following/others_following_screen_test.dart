// ABOUTME: Widget tests for OthersFollowingScreen loading behavior
// ABOUTME: Ensures retained following content stays visible during reloads

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/others_following/others_following_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/following/others_following_screen.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  const targetPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const followingOne =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const followingTwo =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const currentUserPubkey =
      'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

  group(OthersFollowingScreen, () {
    late _MockFollowRepository mockFollowRepository;
    late _MockContentBlocklistRepository mockBlocklistRepository;
    late _MockNostrClient mockNostrClient;

    setUp(() {
      mockFollowRepository = _MockFollowRepository();
      mockBlocklistRepository = _MockContentBlocklistRepository();
      mockNostrClient = _MockNostrClient();

      when(() => mockBlocklistRepository.isBlocked(any())).thenReturn(false);
      when(
        () => mockBlocklistRepository.isFollowSevered(any()),
      ).thenReturn(false);
      when(() => mockFollowRepository.followingPubkeys).thenReturn(const []);
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => Stream<List<String>>.value([]));
      when(() => mockFollowRepository.isInitialized).thenReturn(true);
      when(() => mockFollowRepository.followingCount).thenReturn(0);
      when(() => mockFollowRepository.isFollowing(any())).thenReturn(false);
      when(() => mockFollowRepository.watchMyFollowingCached()).thenAnswer(
        (_) => const Stream<CacheResult<FollowingSnapshot>>.empty(),
      );
      when(() => mockNostrClient.publicKey).thenReturn(currentUserPubkey);
    });

    testWidgets('keeps following tiles visible while a reload is pending', (
      tester,
    ) async {
      final reloadController =
          StreamController<CacheResult<FollowingSnapshot>>();
      var callCount = 0;

      when(
        () => mockFollowRepository.watchOthersFollowingCached(
          any(),
          forceRefresh: any(named: 'forceRefresh'),
        ),
      ).thenAnswer((_) {
        callCount++;
        if (callCount == 1) {
          return Stream.value(
            const CacheResult.live(
              FollowingSnapshot(
                pubkeys: [followingOne, followingTwo],
                count: 2,
              ),
            ),
          );
        }
        reloadController.add(
          const CacheResult.cached(
            FollowingSnapshot(
              pubkeys: [followingOne, followingTwo],
              count: 2,
            ),
          ),
        );
        return reloadController.stream;
      });

      await tester.pumpWidget(
        testMaterialApp(
          home: const OthersFollowingScreen(
            pubkey: targetPubkey,
            displayName: 'Alice',
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

      expect(find.byType(UserProfileTile), findsNWidgets(2));

      final listContext = tester.element(find.byType(ListView));
      listContext.read<OthersFollowingBloc>().add(
        const OthersFollowingListLoadRequested(targetPubkey),
      );
      await tester.pump();

      expect(find.byType(UserProfileTile), findsNWidgets(2));
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await reloadController.close();
    });
  });
}
