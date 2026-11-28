import 'dart:async';
import 'dart:convert';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/find_people/find_people_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/screens/find_people/find_people_view.dart';
import 'package:openvine/screens/find_people/widgets/find_people_recommendations.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _Follows extends Mock implements FollowRepository {}

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });
  tearDown(() {
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
  });
  group('Find people interactions', () {
    testWidgets(
      'desktop failure keeps centered search and compact retry usable',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var requests = 0;
        final owner = 'a' * 64;
        final repository = FindPeopleRepository(
          apiClient: FunnelcakeApiClient(
            baseUrl: 'https://example.test',
            httpClient: MockClient((_) async {
              requests++;
              return http.Response('', 404);
            }),
          ),
          accountPubkey: owner,
          currentPubkey: () => owner,
          isExcluded: (_) => false,
          readDismissed: () => [],
          writeDismissed: (_) async {},
        );
        final cubit = FindPeopleCubit(
          repository: repository,
          followRepository: _Follows(),
        );
        await cubit.load();
        try {
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: VineTheme.theme,
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: BlocProvider.value(
                  value: cubit,
                  child: const FindPeopleView(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final search = tester.getRect(find.byType(DivineSearchBar));
          expect(search.width, lessThanOrEqualTo(1040));
          expect(search.center.dx, closeTo(720, 1));
          final retryFinder = find.widgetWithText(DivineButton, 'Retry');
          final retry = tester.getRect(retryFinder);
          expect(retry.width, lessThanOrEqualTo(240));
          expect(retry.center.dx, closeTo(720, 1));
          expect(find.text('Something went wrong'), findsOneWidget);
          expect(
            tester.widget<DivineSearchBar>(find.byType(DivineSearchBar)).onTap,
            isNotNull,
          );
          await tester.tap(retryFinder);
          await tester.pumpAndSettle();
          expect(requests, 2);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(cubit.close);
          await repository.dispose();
        }
      },
    );

    testWidgets(
      'restored archives stay labeled and onboarding can skip without following',
      (tester) async {
        const owner =
            '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
        const candidate =
            'c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5';
        final repository = FindPeopleRepository(
          apiClient: FunnelcakeApiClient(
            baseUrl: 'https://example.test',
            httpClient: MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'suggestions': [
                    {
                      'pubkey': candidate,
                      'profile': {'display_name': 'Classic creator'},
                      'reason': 'classic',
                      'is_classic': true,
                    },
                  ],
                }),
                200,
              ),
            ),
          ),
          accountPubkey: owner,
          currentPubkey: () => owner,
          isExcluded: (_) => false,
          readDismissed: () => [],
          writeDismissed: (_) async {},
        );
        final cubit = FindPeopleCubit(
          repository: repository,
          followRepository: _Follows(),
        );
        await cubit.load();
        var skipped = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.lightTheme,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider.value(
              value: cubit,
              child: ProviderScope(
                child: FindPeopleView(
                  source: 'onboarding',
                  onSkip: () {
                    skipped = true;
                  },
                  onDone: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Restored Vine archive'), findsOneWidget);
        expect(find.text('Classic creator'), findsOneWidget);
        await tester.tap(find.text('Skip'));
        expect(skipped, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
        await repository.dispose();
      },
    );
    testWidgets(
      'inactive cards record no exposure and activation records once',
      (
        tester,
      ) async {
        const owner =
            '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
        const candidate =
            'c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5';
        final repository = FindPeopleRepository(
          apiClient: FunnelcakeApiClient(
            baseUrl: 'https://example.test',
            httpClient: MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'next_cursor': 'more',
                  'suggestions': [
                    {
                      'pubkey': candidate,
                      'profile': {'name': 'Creator'},
                      'reason': 'follow_graph',
                      'is_classic': false,
                    },
                  ],
                }),
                200,
              ),
            ),
          ),
          accountPubkey: owner,
          currentPubkey: () => owner,
          isExcluded: (_) => false,
          readDismissed: () => [],
          writeDismissed: (_) async {},
        );
        final cubit = FindPeopleCubit(
          repository: repository,
          followRepository: _Follows(),
        );
        await cubit.load();
        final actions = <String>[];
        Widget subject(bool active) => MaterialApp(
          theme: VineTheme.theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProviderScope(
            child: Scaffold(
              body: FindPeopleRecommendations(
                cubit: cubit,
                isActive: active,
                onAction: (action, _, _) => actions.add(action),
              ),
            ),
          ),
        );
        await tester.pumpWidget(subject(false));
        await tester.pumpAndSettle();
        expect(actions, isEmpty);
        expect(find.text('Suggested for you'), findsOneWidget);
        expect(find.text('Load more'), findsNothing);
        await tester.pumpWidget(subject(true));
        await tester.pumpAndSettle();
        expect(actions, ['exposed']);
        await tester.pumpWidget(subject(true));
        await tester.pumpAndSettle();
        expect(actions, ['exposed']);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
        await repository.dispose();
      },
    );
    for (final permanentPage in [true, false]) {
      testWidgets(
        '${permanentPage ? 'permanent page' : 'shared feed card'} exposes pending rows only after foreground resume',
        (tester) async {
          const owner =
              '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
          const candidate =
              'c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5';
          final response = Completer<http.Response>();
          final repository = FindPeopleRepository(
            apiClient: FunnelcakeApiClient(
              baseUrl: 'https://example.test',
              httpClient: MockClient((_) => response.future),
            ),
            accountPubkey: owner,
            currentPubkey: () => owner,
            isExcluded: (_) => false,
            readDismissed: () => [],
            writeDismissed: (_) async {},
          );
          final cubit = FindPeopleCubit(
            repository: repository,
            followRepository: _Follows(),
          );
          final container = ProviderContainer();
          container.read(appForegroundProvider.notifier).setForeground(false);
          final actions = <String>[];
          final pending = cubit.load();
          try {
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  theme: VineTheme.theme,
                  localizationsDelegates: appLocalizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: BlocProvider.value(
                    value: cubit,
                    child: permanentPage
                        ? FindPeopleView(
                            onAction: (action, _, _) => actions.add(action),
                          )
                        : Scaffold(
                            body: FindPeopleRecommendations(
                              cubit: cubit,
                              onAction: (action, _, _) => actions.add(action),
                            ),
                          ),
                  ),
                ),
              ),
            );
            response.complete(
              http.Response(
                jsonEncode({
                  'suggestions': [
                    {
                      'pubkey': candidate,
                      'profile': {'name': 'Foreground creator'},
                      'reason': 'popular',
                      'is_classic': false,
                    },
                  ],
                }),
                200,
              ),
            );
            await tester.runAsync(() => pending);
            await tester.pumpAndSettle();
            expect(find.text('Foreground creator'), findsOneWidget);
            expect(actions, isEmpty);
            container.read(appForegroundProvider.notifier).setForeground(true);
            await tester.pumpAndSettle();
            expect(actions, ['exposed']);
            container.read(appForegroundProvider.notifier).setForeground(false);
            await tester.pumpAndSettle();
            container.read(appForegroundProvider.notifier).setForeground(true);
            await tester.pumpAndSettle();
            expect(actions, ['exposed']);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.runAsync(cubit.close);
            await repository.dispose();
            container.dispose();
          }
        },
      );
    }
  });
}
