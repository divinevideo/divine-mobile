// ABOUTME: Verifies the bookmarks route is registered on the real app router
// ABOUTME: The profile Lists tab pushes this path, so an absent route 404s

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/saved_videos_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_provider_overrides.dart';

void main() {
  group(SavedVideosScreen, () {
    testWidgets('${SavedVideosScreen.path} resolves to $SavedVideosScreen', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'current_user_pubkey_hex': 'f' * 64,
      });
      final sharedPreferences = await SharedPreferences.getInstance();
      final mockAuth = createMockAuthService();
      when(() => mockAuth.isAuthenticated).thenReturn(true);
      when(() => mockAuth.currentPublicKeyHex).thenReturn('f' * 64);
      when(() => mockAuth.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuth.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());

      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(
            mockSharedPreferences: sharedPreferences,
            mockAuthService: mockAuth,
          ),
          currentMinorAccountReviewStatusProvider.overrideWith(
            (ref) async => MinorAccountReviewStatus.active(),
          ),
          currentAccountDeletionAttemptProvider.overrideWith(
            (ref) async => null,
          ),
          videoEventServiceProvider.overrideWithValue(
            createMockVideoEventService(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentMinorAccountReviewStatusProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);
      router.go(SavedVideosScreen.path);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Asserting the screen, not the URI: go_router keeps the location even
      // when no route matches and it falls through to the error page, so a URI
      // assertion passes with the GoRoute deleted.
      expect(find.byType(SavedVideosScreen), findsOneWidget);
    });
  });
}
