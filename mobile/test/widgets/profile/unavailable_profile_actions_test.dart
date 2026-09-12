// ABOUTME: Tests unavailable-profile more-sheet side effects.
// ABOUTME: Pins safety actions that remain reachable when a profile is hidden.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/widgets/profile/unavailable_profile_actions.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

const _userIdHex =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(UnavailableProfileActions, () {
    late _MockFollowRepository followRepository;
    late _MockContentBlocklistRepository blocklistRepository;
    late AppLocalizations l10n;

    setUp(() {
      followRepository = _MockFollowRepository();
      blocklistRepository = _MockContentBlocklistRepository();
      l10n = lookupAppLocalizations(const Locale('en'));
    });

    Widget buildSubject({required bool isFollowing, required bool isBlocked}) {
      when(
        () => followRepository.isFollowing(_userIdHex),
      ).thenReturn(isFollowing);
      when(
        () => blocklistRepository.canUnblock(_userIdHex),
      ).thenReturn(isBlocked);

      return ProviderScope(
        overrides: [
          followRepositoryProvider.overrideWithValue(followRepository),
          contentBlocklistRepositoryProvider.overrideWithValue(
            blocklistRepository,
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: UnavailableProfileActions(userIdHex: _userIdHex),
          ),
        ),
      );
    }

    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byType(UnavailableProfileActions));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'unfollow calls unfollow, not toggleFollow, and reports success',
      (tester) async {
        when(
          () => followRepository.unfollow(_userIdHex),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(
          buildSubject(isFollowing: true, isBlocked: false),
        );
        await openSheet(tester);

        await tester.tap(
          find.text(l10n.profileUnfollowDisplayName(l10n.profileUserFallback)),
        );
        await tester.pumpAndSettle();

        verify(() => followRepository.unfollow(_userIdHex)).called(1);
        verifyNever(() => followRepository.toggleFollow(_userIdHex));
        expect(
          find.text(l10n.profileUnfollowedUser(l10n.profileUserFallback)),
          findsOneWidget,
        );
      },
    );

    testWidgets('block confirmation blocks and reports success', (
      tester,
    ) async {
      when(
        () => blocklistRepository.blockUser(_userIdHex),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(
        buildSubject(isFollowing: false, isBlocked: false),
      );
      await openSheet(tester);

      await tester.tap(
        find.text(l10n.profileBlockDisplayName(l10n.profileUserFallback)),
      );
      await tester.pumpAndSettle();
      final confirm = find.text(
        l10n.profileBlockConfirmButton(l10n.profileUserFallback),
      );
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      verify(() => blocklistRepository.blockUser(_userIdHex)).called(1);
      expect(
        find.text(l10n.profileBlockedUser(l10n.profileUserFallback)),
        findsOneWidget,
      );
    });

    testWidgets('unblock confirmation unblocks and reports success', (
      tester,
    ) async {
      when(
        () => blocklistRepository.unblockUser(_userIdHex),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(
        buildSubject(isFollowing: false, isBlocked: true),
      );
      await openSheet(tester);

      await tester.tap(
        find.text(l10n.profileUnblockDisplayName(l10n.profileUserFallback)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.profileUnblockButton));
      await tester.pumpAndSettle();

      verify(() => blocklistRepository.unblockUser(_userIdHex)).called(1);
      expect(
        find.text(l10n.profileUnblockedUser(l10n.profileUserFallback)),
        findsOneWidget,
      );
    });

    testWidgets('failed unfollow reports an error instead of escaping', (
      tester,
    ) async {
      when(
        () => followRepository.unfollow(_userIdHex),
      ).thenThrow(Exception('network unavailable'));

      await tester.pumpWidget(
        buildSubject(isFollowing: true, isBlocked: false),
      );
      await openSheet(tester);

      await tester.tap(
        find.text(l10n.profileUnfollowDisplayName(l10n.profileUserFallback)),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.shareActionFailed), findsOneWidget);
    });
  });
}
