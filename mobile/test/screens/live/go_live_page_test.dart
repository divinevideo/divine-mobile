import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/live_providers.dart';
import 'package:openvine/repositories/live_repository.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/live/go_live_page.dart';
import 'package:openvine/screens/live/live_discovery_page.dart';
import 'package:openvine/services/live_api_service.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockLiveRepository extends Mock implements LiveRepository {}

class _MockLiveApiService extends Mock implements LiveApiService {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

Iterable<String> _flattenPaths(Iterable<RouteBase> routes) sync* {
  for (final route in routes) {
    if (route is GoRoute) {
      yield route.path;
      yield* _flattenPaths(route.routes);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoLivePage', () {
    test(
      'Go Live route is available only when livestreamingBeta is enabled',
      () {
        expect(
          _flattenPaths(buildLiveRoutes(liveEnabled: true)),
          contains(GoLivePage.path),
        );
        expect(
          _flattenPaths(buildLiveRoutes(liveEnabled: false)),
          isNot(contains(GoLivePage.path)),
        );
      },
    );

    testWidgets('renders room setup fields and start action', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      final mockLiveRepository = _MockLiveRepository();
      final mockLiveApiService = _MockLiveApiService();
      final mockProfileRepository = _MockProfileRepository();
      final mockAuthService = createMockAuthService();
      when(() => mockAuthService.currentPublicKeyHex).thenReturn('host-pubkey');
      when(
        () => mockProfileRepository.getCachedProfile(pubkey: 'host-pubkey'),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(
        testMaterialApp(
          mockSharedPreferences: sharedPreferences,
          mockAuthService: mockAuthService,
          mockProfileRepository: mockProfileRepository,
          additionalOverrides: [
            liveRepositoryProvider.overrideWithValue(mockLiveRepository),
            liveApiServiceProvider.overrideWithValue(mockLiveApiService),
          ],
          home: const GoLivePage(),
        ),
      );
      await tester.pump();

      expect(find.text('Go live'), findsOneWidget);
      expect(find.text('Start live now'), findsOneWidget);
      expect(find.text('Room title'), findsOneWidget);
    });

    testWidgets('prefills room setup from the cached host profile', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      final mockLiveRepository = _MockLiveRepository();
      final mockLiveApiService = _MockLiveApiService();
      final mockProfileRepository = _MockProfileRepository();
      final mockAuthService = createMockAuthService();
      const hostPubkey = 'host-pubkey';
      const pictureUrl = 'https://example.com/tet.png';
      const displayName = 'Tet';
      const expectedTitle = 'Tet is live';
      const expectedSummary = 'Come hang out with Tet live on Divine.';

      when(() => mockAuthService.currentPublicKeyHex).thenReturn(hostPubkey);
      when(
        () => mockProfileRepository.getCachedProfile(pubkey: hostPubkey),
      ).thenAnswer(
        (_) async => UserProfile(
          pubkey: hostPubkey,
          rawData: const <String, dynamic>{},
          createdAt: DateTime.utc(2026, 4, 9),
          eventId: 'profile-event',
          displayName: displayName,
          picture: pictureUrl,
        ),
      );

      await tester.pumpWidget(
        testMaterialApp(
          mockSharedPreferences: sharedPreferences,
          mockAuthService: mockAuthService,
          mockProfileRepository: mockProfileRepository,
          additionalOverrides: [
            liveRepositoryProvider.overrideWithValue(mockLiveRepository),
            liveApiServiceProvider.overrideWithValue(mockLiveApiService),
          ],
          home: const GoLivePage(),
        ),
      );
      await tester.pumpAndSettle();

      final editableTexts = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .map((widget) => widget.controller.text)
          .toList();

      expect(editableTexts, contains(expectedTitle));
      expect(editableTexts, contains(expectedSummary));
      expect(editableTexts, contains(pictureUrl));

      final preview = tester.widget<UserAvatar>(
        find.byType(UserAvatar),
      );
      expect(preview.imageUrl, pictureUrl);
    });

    testWidgets('keeps the form blank when no cached host profile exists', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      final mockLiveRepository = _MockLiveRepository();
      final mockLiveApiService = _MockLiveApiService();
      final mockProfileRepository = _MockProfileRepository();
      final mockAuthService = createMockAuthService();
      const hostPubkey = 'host-pubkey';

      when(() => mockAuthService.currentPublicKeyHex).thenReturn(hostPubkey);
      when(
        () => mockProfileRepository.getCachedProfile(pubkey: hostPubkey),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(
        testMaterialApp(
          mockSharedPreferences: sharedPreferences,
          mockAuthService: mockAuthService,
          mockProfileRepository: mockProfileRepository,
          additionalOverrides: [
            liveRepositoryProvider.overrideWithValue(mockLiveRepository),
            liveApiServiceProvider.overrideWithValue(mockLiveApiService),
          ],
          home: const GoLivePage(),
        ),
      );
      await tester.pumpAndSettle();

      final editableTexts = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .map((widget) => widget.controller.text)
          .toList();

      expect(editableTexts, everyElement(isEmpty));
      expect(find.byType(UserAvatar), findsNothing);
    });

    testWidgets(
      'shows a back button that falls back to live discovery when opened directly',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final sharedPreferences = await SharedPreferences.getInstance();
        final mockLiveRepository = _MockLiveRepository();
        final mockLiveApiService = _MockLiveApiService();
        final mockProfileRepository = _MockProfileRepository();
        final mockAuthService = createMockAuthService();
        when(() => mockAuthService.currentPublicKeyHex).thenReturn(
          'host-pubkey',
        );
        when(
          () => mockProfileRepository.getCachedProfile(pubkey: 'host-pubkey'),
        ).thenAnswer((_) async => null);

        final router = GoRouter(
          initialLocation: GoLivePage.path,
          routes: <RouteBase>[
            GoRoute(
              path: LiveDiscoveryPage.path,
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('live discovery')),
              ),
            ),
            GoRoute(
              path: GoLivePage.path,
              builder: (context, state) => const GoLivePage(),
            ),
          ],
        );

        await tester.pumpWidget(
          testProviderScope(
            mockSharedPreferences: sharedPreferences,
            mockAuthService: mockAuthService,
            mockProfileRepository: mockProfileRepository,
            additionalOverrides: [
              liveRepositoryProvider.overrideWithValue(mockLiveRepository),
              liveApiServiceProvider.overrideWithValue(mockLiveApiService),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(BackButton), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.text('live discovery'), findsOneWidget);
      },
    );
  });
}
