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
  const owner =
      '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
  const firstKey =
      'c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5';
  const secondKey =
      'f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9';
  const thirdKey =
      'e493dbf1c10d80f3581e4904930b1404cc6c13900ee0758474fa94abe8c4cd13';
  const fourthKey =
      '2f8bde4d1a07209355b4a7250a5c5128e88b84bddc619ab7cba8d569b240efe4';
  const creatorKeys = [firstKey, secondKey, thirdKey, fourthKey];
  const previewId =
      'fff97bd5755eeea420453a14355235d382f6472f8568a18b2f057a1460297556';
  late FindPeopleRepository repository;
  late FindPeopleCubit cubit;
  late _Follows follows;
  late ProviderContainer container;
  late List<String> actions;
  var requests = 0;

  Future<void> prepare({int creatorCount = 3}) async {
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
                for (var i = 0; i < creatorCount; i++)
                  {
                    'pubkey': creatorKeys[i],
                    'profile': {
                      'name': [
                        'Creator one',
                        'Creator two',
                        'Creator three',
                        'Creator four',
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
    for (final width in [800.0, 1440.0]) {
      testWidgets('desktop grid uses compact columns at $width pixels', (
        tester,
      ) async {
        try {
          await prepare(creatorCount: 4);
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(subject());
          await tester.pumpAndSettle();
          final first = tester.getRect(
            find.byKey(const ValueKey('creator-card:$firstKey')),
          );
          final third = tester.getRect(
            find.byKey(const ValueKey('creator-card:$thirdKey')),
          );
          expect(first.width, lessThanOrEqualTo(320));
          expect(third.top, first.top);
          if (width >= 1040) {
            final fourth = tester.getRect(
              find.byKey(const ValueKey('creator-card:$fourthKey')),
            );
            expect(fourth.top, first.top);
            expect(first.left, greaterThan(160));
          }
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(cubit.close);
          await repository.dispose();
          container.dispose();
        }
      });
    }

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
              find.byKey(const ValueKey('creator-card:$firstKey')),
            );
            final second = tester.getRect(
              find.byKey(const ValueKey('creator-card:$secondKey')),
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
            find.byKey(const ValueKey('creator-card:$firstKey')),
          );
          final second = tester.getRect(
            find.byKey(const ValueKey('creator-card:$secondKey')),
          );
          expect(first.left, second.left);
          expect(second.top, greaterThan(first.bottom));
          expect(tester.takeException(), isNull);
          final follow = find.descendant(
            of: find.byKey(const ValueKey('creator-card:$firstKey')),
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
          of: find.byKey(const ValueKey('creator-card:$firstKey')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DivineIconButton &&
                widget.semanticLabel == 'Dismiss suggestion',
          ),
        );
        expect(dismiss, findsOneWidget);
        expect(
          tester.widget<DivineIconButton>(dismiss).type,
          equals(DivineIconButtonType.ghostOverMedia),
        );
        final semantics = tester.ensureSemantics();
        final identityButton = find.descendant(
          of: find.byKey(const ValueKey('creator-card:$firstKey')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.button == true &&
                widget.properties.label == 'Creator one',
          ),
        );
        expect(identityButton, findsOneWidget);
        expect(tester.getSize(identityButton).height, greaterThanOrEqualTo(48));
        semantics.dispose();
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
            await tester.tap(
              find.byKey(const ValueKey('creator-preview:$firstKey')),
            );
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
