import 'dart:async';
import 'dart:convert';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/find_people_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/screens/feed/feed_people_suggestions_host.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _FollowRepository extends Mock implements FollowRepository {}

const _ownerPubkey =
    '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
const _creatorPubkey =
    'c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5';

void main() {
  group('Feed people suggestions renders', () {
    for (final dark in [false, true]) {
      testWidgets(
        'ready recommendations arm an inactive card in ${dark ? 'dark' : 'light'} appearance',
        (tester) async {
          VisibilityDetectorController.instance.updateInterval = Duration.zero;
          final response = Completer<http.Response>();
          final repository = FindPeopleRepository(
            apiClient: FunnelcakeApiClient(
              baseUrl: 'https://example.test',
              httpClient: MockClient((_) => response.future),
            ),
            accountPubkey: _ownerPubkey,
            currentPubkey: () => _ownerPubkey,
            isExcluded: (_) => false,
            readDismissed: () => [],
            writeDismissed: (_) async {},
          );
          final actions = <String>[];
          FeedPeopleSlot? slot;
          var continued = false;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                findPeopleActionRecorderProvider.overrideWithValue(
                  (_) =>
                      (action, suggestion, position) => actions.add(action),
                ),
                findPeopleRepositoryProvider.overrideWithValue(repository),
                followRepositoryProvider.overrideWithValue(_FollowRepository()),
                isFeatureEnabledProvider(FeatureFlag.findPeople)
                    .overrideWithValue(true),
                isFeatureEnabledProvider(FeatureFlag.feedPeopleSuggestions)
                    .overrideWithValue(true),
              ],
              child: MaterialApp(
                theme: dark ? VineTheme.theme : VineTheme.lightTheme,
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: FeedPeopleSuggestionsHost(
                    sessionKey: 0,
                    currentVideoIndex: () => 0,
                    isFeedActive: false,
                    onContinue: () {
                      continued = true;
                    },
                    builder: (context, value) {
                      slot = value;
                      return value.builder?.call(context) ??
                          const Text('Videos only');
                    },
                  ),
                ),
              ),
            ),
          );
          expect(find.text('Videos only'), findsOneWidget);
          expect(slot!.index, isNull);
          response.complete(
            http.Response(
              jsonEncode({
                'suggestions': [
                  {
                    'pubkey': _creatorPubkey,
                    'profile': {'display_name': 'Classic creator'},
                    'reason': 'classic',
                    'is_classic': true,
                  },
                ],
              }),
              200,
            ),
          );
          await tester.pumpAndSettle();
          expect(slot!.index, 10);
          expect(find.text('Find people'), findsOneWidget);
          expect(find.text('Restored Vine archive'), findsOneWidget);
          expect(find.text('Classic creator'), findsOneWidget);
          expect(actions, isEmpty);
          await tester.tap(find.text('Keep watching'));
          expect(continued, isTrue);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await repository.dispose();
          VisibilityDetectorController.instance.updateInterval = const Duration(
            milliseconds: 500,
          );
        },
      );
    }

    testWidgets(
      'policy refusal immediately disarms an already armed Home card',
      (tester) async {
        VisibilityDetectorController.instance.updateInterval = Duration.zero;
        var refuse = false;
        final repository = FindPeopleRepository(
          apiClient: FunnelcakeApiClient(
            baseUrl: 'https://example.test',
            retryBaseDelay: Duration.zero,
            httpClient: MockClient(
              (_) async => refuse
                  ? http.Response('{}', 503)
                  : http.Response(
                      jsonEncode({
                        'suggestions': [
                          {
                            'pubkey': _creatorPubkey,
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
          accountPubkey: _ownerPubkey,
          currentPubkey: () => _ownerPubkey,
          isExcluded: (_) => false,
          readDismissed: () => [],
          writeDismissed: (_) async {},
        );
        FeedPeopleSlot? slot;
        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                findPeopleActionRecorderProvider.overrideWithValue(
                  (_) => (_, _, _) {},
                ),
                findPeopleRepositoryProvider.overrideWithValue(repository),
                followRepositoryProvider.overrideWithValue(_FollowRepository()),
                isFeatureEnabledProvider(FeatureFlag.findPeople)
                    .overrideWithValue(true),
                isFeatureEnabledProvider(FeatureFlag.feedPeopleSuggestions)
                    .overrideWithValue(true),
              ],
              child: MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: FeedPeopleSuggestionsHost(
                    sessionKey: 0,
                    currentVideoIndex: () => 0,
                    isFeedActive: true,
                    onContinue: () {},
                    builder: (context, value) {
                      slot = value;
                      return value.builder?.call(context) ??
                          const Text('Videos only');
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(slot!.index, 10);
          slot!.onVisibilityChanged?.call(true);

          refuse = true;
          await expectLater(
            repository.load(),
            throwsA(isA<FindPeopleUnavailableException>()),
          );
          await tester.pumpAndSettle();
          expect(slot!.index, isNull);
          expect(find.text('Videos only'), findsOneWidget);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await repository.dispose();
          VisibilityDetectorController.instance.updateInterval = const Duration(
            milliseconds: 500,
          );
        }
      },
    );

    testWidgets(
      'rebuilt session reads the live video index and never inserts behind the viewer',
      (tester) async {
        VisibilityDetectorController.instance.updateInterval = Duration.zero;
        const liveIndex = 15;
        final repository = FindPeopleRepository(
          apiClient: FunnelcakeApiClient(
            baseUrl: 'https://example.test',
            httpClient: MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'suggestions': [
                    {
                      'pubkey': _creatorPubkey,
                      'profile': {'display_name': 'Creator'},
                      'reason': 'popular',
                      'is_classic': false,
                    },
                  ],
                }),
                200,
              ),
            ),
          ),
          accountPubkey: _ownerPubkey,
          currentPubkey: () => _ownerPubkey,
          isExcluded: (_) => false,
          readDismissed: () => [],
          writeDismissed: (_) async {},
        );
        FeedPeopleSlot? slot;
        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                findPeopleActionRecorderProvider.overrideWithValue(
                  (_) => (_, _, _) {},
                ),
                findPeopleRepositoryProvider.overrideWithValue(repository),
                followRepositoryProvider.overrideWithValue(_FollowRepository()),
                isFeatureEnabledProvider(FeatureFlag.findPeople)
                    .overrideWithValue(true),
                isFeatureEnabledProvider(FeatureFlag.feedPeopleSuggestions)
                    .overrideWithValue(true),
              ],
              child: MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: FeedPeopleSuggestionsHost(
                    sessionKey: 0,
                    currentVideoIndex: () => liveIndex,
                    isFeedActive: true,
                    onContinue: () {},
                    builder: (context, value) {
                      slot = value;
                      return value.builder?.call(context) ??
                          const Text('Videos only');
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(slot!.index, isNull);
          expect(find.text('Videos only'), findsOneWidget);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await repository.dispose();
          VisibilityDetectorController.instance.updateInterval = const Duration(
            milliseconds: 500,
          );
        }
      },
    );

    testWidgets(
      'small phone with large text renders the card without a nested vertical scrollable',
      (tester) async {
        VisibilityDetectorController.instance.updateInterval = Duration.zero;
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = FindPeopleRepository(
          apiClient: FunnelcakeApiClient(
            baseUrl: 'https://example.test',
            httpClient: MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'suggestions': [
                    {
                      'pubkey': _creatorPubkey,
                      'profile': {
                        'display_name': 'Classic creator',
                        'about': 'Longer creator bio for large text test',
                      },
                      'reason': 'classic',
                      'is_classic': true,
                    },
                  ],
                }),
                200,
              ),
            ),
          ),
          accountPubkey: _ownerPubkey,
          currentPubkey: () => _ownerPubkey,
          isExcluded: (_) => false,
          readDismissed: () => [],
          writeDismissed: (_) async {},
        );
        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                findPeopleActionRecorderProvider.overrideWithValue(
                  (_) => (_, _, _) {},
                ),
                findPeopleRepositoryProvider.overrideWithValue(repository),
                followRepositoryProvider.overrideWithValue(_FollowRepository()),
                isFeatureEnabledProvider(FeatureFlag.findPeople)
                    .overrideWithValue(true),
                isFeatureEnabledProvider(FeatureFlag.feedPeopleSuggestions)
                    .overrideWithValue(true),
              ],
              child: MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2),
                  ),
                  child: child!,
                ),
                home: Scaffold(
                  body: FeedPeopleSuggestionsHost(
                    sessionKey: 0,
                    currentVideoIndex: () => 0,
                    isFeedActive: true,
                    onContinue: () {},
                    builder: (context, value) =>
                        value.builder?.call(context) ??
                        const Text('Videos only'),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            ),
            findsNothing,
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await repository.dispose();
          VisibilityDetectorController.instance.updateInterval = const Duration(
            milliseconds: 500,
          );
        }
      },
    );

    testWidgets('disabled card does not load recommendation dependencies', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isFeatureEnabledProvider(FeatureFlag.findPeople)
                .overrideWithValue(false),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FeedPeopleSuggestionsHost(
              sessionKey: 0,
              currentVideoIndex: () => 0,
              isFeedActive: true,
              onContinue: () {},
              builder: (_, slot) {
                expect(slot.index, isNull);
                return const Text('Videos only');
              },
            ),
          ),
        ),
      );
      expect(find.text('Videos only'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
