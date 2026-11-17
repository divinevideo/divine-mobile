// ABOUTME: Verifies video-led creator discovery without starting video players.
// ABOUTME: Covers responsive layout, intentional navigation and real exposure.

import 'dart:convert';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/find_people/find_people_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/find_people/widgets/find_people_recommendations.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../helpers/test_provider_overrides.dart';

class _Follows extends Mock implements FollowRepository {}

class _ContentVersion extends ContentFilterVersion {
  @override
  int build() => 0;
}

void main() {
  final owner = 'a' * 64;
  final firstKey = 'b' * 64;
  final secondKey = 'c' * 64;
  final previewId = 'd' * 64;
  late FindPeopleRepository repository;
  late FindPeopleCubit cubit;
  late _Follows follows;
  late ProviderContainer container;
  late List<String> actions;
  var requests = 0;

  Future<void> prepare() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    follows = _Follows();
    actions = [];
    requests = 0;
    repository = FindPeopleRepository(
      apiClient: FunnelcakeApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((_) async {
          requests++;
          return http.Response(
            jsonEncode({
              'suggestions': [
                for (var i = 0; i < 3; i++)
                  {
                    'pubkey': ['b', 'c', 'e'][i] * 64,
                    'profile': {
                      'name': [
                        'Creator one',
                        'Creator two',
                        'Creator three',
                      ][i],
                    },
                    'reason': 'popular',
                    'is_classic': i == 1,
                    if (i != 2)
                      'video_preview': {
                        'id': previewId,
                        'thumbnail_url':
                            'https://media.divine.video/$previewId.jpg',
                      },
                  },
              ],
            }),
            200,
          );
        }),
      ),
      accountPubkey: owner,
      currentPubkey: () => owner,
      isExcluded: (_) => false,
      readDismissed: () => [],
      writeDismissed: (_) async {},
    );
    cubit = FindPeopleCubit(repository: repository, followRepository: follows);
    await cubit.load();
    container = ProviderContainer(
      overrides: [
        ...getStandardTestOverrides(),
        currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
        contentFilterVersionProvider.overrideWith(_ContentVersion.new),
      ],
    );
  }

  tearDown(() {
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
  });

  Widget subject({
    bool dark = true,
    double scale = 1,
    FindPeopleSuggestionsLayout layout = FindPeopleSuggestionsLayout.grid,
    GoRouter? router,
  }) {
    Widget content() => Scaffold(
      body: SingleChildScrollView(
        child: BlocProvider.value(
          value: cubit,
          child: FindPeopleSuggestionsList(
            layout: layout,
            onAction: (action, suggestion, _) =>
                actions.add('$action:${suggestion.pubkey}'),
          ),
        ),
      ),
    );
    final navigation = router;
    return UncontrolledProviderScope(
      container: container,
      child: navigation == null
          ? MaterialApp(
              theme: dark ? VineTheme.theme : VineTheme.lightTheme,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: content(),
            )
          : MaterialApp.router(
              theme: VineTheme.theme,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: navigation,
            ),
    );
  }

  group('video-led people cards', () {
    for (final dark in [false, true]) {
      testWidgets(
        'phone grid leads with real previews in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
          try {
            await prepare();
            tester.view.physicalSize = const Size(390, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(subject(dark: dark));
            await tester.pumpAndSettle();
            final first = tester.getRect(
              find.byKey(ValueKey('creator-card:$firstKey')),
            );
            final second = tester.getRect(
              find.byKey(ValueKey('creator-card:$secondKey')),
            );
            expect(first.top, second.top);
            expect(second.left, greaterThan(first.right));
            final image = tester.widget<PassiveAuthThumbnailImage>(
              find.byType(PassiveAuthThumbnailImage).first,
            );
            expect(image.videoId, previewId);
            expect(image.url, 'https://media.divine.video/$previewId.jpg');
            expect(find.text('Restored Vine archive'), findsOneWidget);
            expect(find.byType(VideoThumbnailWidget), findsNothing);
            expect(requests, 1);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.runAsync(cubit.close);
            await repository.dispose();
            container.dispose();
          }
        },
      );
    }

    testWidgets(
      'narrow large-text grid remains scrollable with reachable actions',
      (tester) async {
        try {
          await prepare();
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(subject(scale: 2));
          await tester.pumpAndSettle();
          final first = tester.getRect(
            find.byKey(ValueKey('creator-card:$firstKey')),
          );
          final second = tester.getRect(
            find.byKey(ValueKey('creator-card:$secondKey')),
          );
          expect(first.left, second.left);
          expect(second.top, greaterThan(first.bottom));
          expect(tester.takeException(), isNull);
          final follow = find.descendant(
            of: find.byKey(ValueKey('creator-card:$firstKey')),
            matching: find.text('Follow'),
          );
          when(() => follows.followWithResult(firstKey))
              .thenAnswer((_) async => FollowOutcome.published);
          await tester.ensureVisible(follow);
          await tester.pumpAndSettle();
          await tester.tap(follow);
          await tester.pumpAndSettle();
          expect(
            cubit.state.suggestions.any((person) => person.pubkey == firstKey),
            isFalse,
          );
          expect(actions, contains('followed:$firstKey'));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(cubit.close);
          await repository.dispose();
          container.dispose();
        }
      },
    );

    testWidgets(
      'carousel records only foreground cards beyond half visibility',
      (tester) async {
        try {
          await prepare();
          tester.view.physicalSize = const Size(390, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          container.read(appForegroundProvider.notifier).setForeground(false);
          await tester.pumpWidget(
            subject(layout: FindPeopleSuggestionsLayout.carousel),
          );
          await tester.pumpAndSettle();
          expect(actions, isEmpty);
          container.read(appForegroundProvider.notifier).setForeground(true);
          await tester.pumpAndSettle();
          expect(actions, ['exposed:$firstKey']);
          final carousel = find.byKey(const ValueKey('people-carousel'));
          await tester.drag(carousel, const Offset(-310, 0));
          await tester.pumpAndSettle();
          expect(actions, contains('exposed:$secondKey'));
          expect(
            actions.where((action) => action == 'exposed:$firstKey'),
            hasLength(1),
          );
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(cubit.close);
          await repository.dispose();
          container.dispose();
        }
      },
    );

    testWidgets('dismissal removes a card without automatically following', (
      tester,
    ) async {
      try {
        await prepare();

        await tester.pumpWidget(subject());
        await tester.pumpAndSettle();
        expect(find.text('Creator one'), findsOneWidget);
        final dismiss = find.descendant(
          of: find.byKey(ValueKey('creator-card:$firstKey')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DivineIconButton &&
                widget.semanticLabel == 'Dismiss suggestion',
          ),
        );
        expect(dismiss, findsOneWidget);
        await tester.tap(dismiss);
        await tester.pumpAndSettle();
        expect(
          find.text('Creator one'),
          findsNothing,
          reason:
              'actions=$actions pending=${cubit.state.pendingPubkeys} failed=${cubit.state.actionFailed}',
        );
        expect(
          cubit.state.suggestions.any((person) => person.pubkey == firstKey),
          isFalse,
        );
        expect(actions, contains('dismissed:$firstKey'));
        verifyNever(() => follows.followWithResult(any()));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
        await repository.dispose();
        container.dispose();
      }
    });

    testWidgets(
      'preview opens exact video and author while identity opens profile',
      (tester) async {
        try {
          await prepare();
          GoRouterState? videoDestination;
          GoRouterState? profileDestination;
          late GoRouter router;
          router = GoRouter(
            routes: [
              GoRoute(
                path: RoutePaths.root,
                builder: (_, _) => Scaffold(
                  body: SingleChildScrollView(
                    child: BlocProvider.value(
                      value: cubit,
                      child: const FindPeopleSuggestionsList(),
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: '${RoutePaths.videoDetailBase}/:id',
                builder: (_, state) {
                  videoDestination = state;
                  return const Text('Video destination');
                },
              ),
              GoRoute(
                path: '${RoutePaths.otherProfile}/:npub',
                builder: (_, state) {
                  profileDestination = state;
                  return const Text('Profile destination');
                },
              ),
            ],
          );
          try {
            await tester.pumpWidget(subject(router: router));
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(ValueKey('creator-preview:$firstKey')));
            await tester.pumpAndSettle();
            expect(find.text('Video destination'), findsOneWidget);
            expect(videoDestination!.pathParameters['id'], previewId);
            expect(videoDestination!.uri.queryParameters['author'], firstKey);
            router.pop();
            await tester.pumpAndSettle();
            await tester.tap(find.text('Creator one'));
            await tester.pumpAndSettle();
            expect(find.text('Profile destination'), findsOneWidget);
            expect(
              profileDestination!.pathParameters['npub'],
              Nip19.encodePubKey(firstKey),
            );
            expect(requests, 1);
            await tester.pumpWidget(const SizedBox.shrink());
          } finally {
            router.dispose();
          }
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(cubit.close);
          await repository.dispose();
          container.dispose();
        }
      },
    );
  });
}
