// ABOUTME: Widget coverage for unavailable pinned-video recovery.
// ABOUTME: Verifies the owner sees the stored coordinate and can remove it.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/profile_unavailable_pins_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

import '../helpers/test_provider_overrides.dart';

class _MockProfileFeedCubit extends MockBloc<ProfileFeedEvent, ProfileFeedState>
    implements ProfileFeedCubit {}

void main() {
  const coordinate =
      '34236:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:stale';

  setUpAll(() {
    registerFallbackValue(
      const ProfileFeedPinnedCoordinateRemoveRequested(coordinate),
    );
  });

  group('renders / interactions', () {
    testWidgets('renders an unavailable coordinate and dispatches removal', (
      tester,
    ) async {
      final bloc = _MockProfileFeedCubit();
      when(() => bloc.state).thenReturn(
        const ProfileFeedState(unavailablePinnedCoordinates: [coordinate]),
      );
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => bloc.add(any())).thenReturn(null);

      await tester.pumpWidget(
        testMaterialApp(
          home: BlocProvider<ProfileFeedCubit>.value(
            value: bloc,
            child: const ProfileUnavailablePinsView(),
          ),
        ),
      );
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ProfileUnavailablePinsView)),
      );
      expect(find.text(l10n.profilePinUnavailableLabel), findsOneWidget);
      expect(find.text(coordinate), findsOneWidget);
      expect(find.text(l10n.profilePinRemoveUnavailable), findsOneWidget);

      await tester.tap(find.text(l10n.profilePinRemoveUnavailable));

      verify(
        () => bloc.add(
          const ProfileFeedPinnedCoordinateRemoveRequested(coordinate),
        ),
      ).called(1);
    });
  });

  group('navigation', () {
    testWidgets('blocks recovery access from another profile', (tester) async {
      final authService = createMockAuthService(
        currentPublicKeyHex: 'b' * 64,
      );
      final ownerNpub = NostrKeyUtils.encodePubKey('a' * 64);

      await tester.pumpWidget(
        testMaterialApp(
          home: ProfileUnavailablePinsPage(npub: ownerNpub),
          mockAuthService: authService,
        ),
      );
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ProfileUnavailablePinsPage)),
      );
      expect(find.text(l10n.profilePinRecoveryOwnerOnly), findsOneWidget);
      expect(find.byType(ProfileUnavailablePinsView), findsNothing);
    });
  });
}
