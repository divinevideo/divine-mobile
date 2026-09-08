// ABOUTME: Tests for reactive router location provider
// ABOUTME: Verifies location stream emits when router navigates

import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/services/auth_service.dart';

import '../helpers/test_provider_overrides.dart';
import '../helpers/test_pubkeys.dart';

void main() {
  Future<ProviderContainer> createContainer() async {
    final container = ProviderContainer(
      overrides: [
        ...getStandardTestOverrides(
          mockAuthService: createMockAuthService(
            authState: AuthState.authenticated,
            currentPublicKeyHex: syntheticTestPubkey,
          ),
        ).cast(),
        currentMinorAccountReviewStatusProvider.overrideWith(
          (ref) async => MinorAccountReviewStatus.active(),
        ),
        currentAccountDeletionAttemptProvider.overrideWith((ref) async => null),
      ],
    );
    await container.read(currentMinorAccountReviewStatusProvider.future);
    await container.read(currentAccountDeletionAttemptProvider.future);
    return container;
  }

  group('Router Location Provider', () {
    testWidgets('emits initial location immediately', (tester) async {
      final container = await createContainer();
      addTearDown(container.dispose);
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

      final stream = container.read(routerLocationStreamProvider);
      final queue = StreamQueue(stream);

      // Get initial location
      final initial = await queue.next;
      expect(initial, WelcomeScreen.path);

      await queue.cancel();
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    });

    testWidgets('emits new location when router navigates', (tester) async {
      final container = await createContainer();
      addTearDown(container.dispose);
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

      // Listen to the raw stream for deterministic events
      final stream = container.read(routerLocationStreamProvider);
      final queue = StreamQueue(stream);

      // 1) Initial location
      final initial = await queue.next;
      expect(initial, WelcomeScreen.path);

      // Use error routes so this provider test does not initialize unrelated
      // app-shell side effects.
      container.read(goRouterProvider).go('/unknown-one');
      await tester.pump();

      final next1 = await queue.next;
      expect(next1, '/unknown-one');

      container.read(goRouterProvider).go('/unknown-two');
      await tester.pump();

      final next2 = await queue.next;
      expect(next2, '/unknown-two');

      await queue.cancel();
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    });

    test('removes its listener and closes the stream on dispose', () async {
      registerFallbackValue(() {});
      final router = _MockGoRouter();
      final delegate = _MockGoRouterDelegate();
      final routeInformation = GoRouteInformationProvider(
        initialLocation: WelcomeScreen.path,
        initialExtra: null,
      );
      addTearDown(routeInformation.dispose);
      when(() => router.routerDelegate).thenReturn(delegate);
      when(() => router.routeInformationProvider).thenReturn(routeInformation);
      final container = ProviderContainer(
        overrides: [goRouterProvider.overrideWithValue(router)],
      );
      addTearDown(container.dispose);

      final stream = container.read(routerLocationStreamProvider);
      final queue = StreamQueue(stream);
      addTearDown(queue.cancel);
      final listener =
          verify(
                () => delegate.addListener(captureAny()),
              ).captured.single
              as VoidCallback;

      final initial = await queue.next;
      expect(initial, WelcomeScreen.path);

      // Keep the subscription active so cancellation cannot hide a leaked
      // controller. The router remains alive independently of this container.
      container.dispose();
      verify(() => delegate.removeListener(listener)).called(1);
      expect(await queue.hasNext, isFalse);
    });
  });
}

class _MockGoRouter extends Mock implements GoRouter {}

class _MockGoRouterDelegate extends Mock implements GoRouterDelegate {}
