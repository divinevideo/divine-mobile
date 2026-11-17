import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/find_people_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/find_people_routes.dart';
import 'package:profile_repository/profile_repository.dart';

class _Follows extends Mock implements FollowRepository {}

void main() {
  GoRouter router() => GoRouter(
    initialLocation: RoutePaths.findPeople,
    routes: [
      GoRoute(path: RoutePaths.root, builder: (_, _) => const Text('Home')),
      ...findPeopleRoutes(),
    ],
  );

  testWidgets('direct links cannot bypass the disabled experiment', (
    tester,
  ) async {
    final navigation = router();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isFeatureEnabledProvider(FeatureFlag.findPeople)
              .overrideWithValue(false),
        ],
        child: MaterialApp.router(routerConfig: navigation),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    navigation.dispose();
  });

  testWidgets(
    'signed out discovery never requests another account suggestions',
    (tester) async {
      final repository = FindPeopleRepository(
        apiClient: FunnelcakeApiClient(
          baseUrl: 'https://example.test',
          httpClient: MockClient(
            (_) => throw StateError('No signed-in account'),
          ),
        ),
        accountPubkey: null,
        currentPubkey: () => null,
        isExcluded: (_) => false,
        readDismissed: () => [],
        writeDismissed: (_) async {},
      );
      final navigation = router();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isFeatureEnabledProvider(FeatureFlag.findPeople)
                .overrideWithValue(true),
            findPeopleRepositoryProvider.overrideWithValue(repository),
            followRepositoryProvider.overrideWithValue(_Follows()),
            findPeopleActionRecorderProvider.overrideWithValue(
              (_) => (_, _, _) {},
            ),
          ],
          child: MaterialApp.router(
            routerConfig: navigation,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Find people'), findsOneWidget);
      expect(
        find.text('No more suggestions right now. Try searching for someone.'),
        findsOneWidget,
      );
      final semantics = tester.ensureSemantics();
      await tester.tap(find.bySemanticsIdentifier('back_button'));
      semantics.dispose();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await repository.dispose();
      navigation.dispose();
    },
  );
}
