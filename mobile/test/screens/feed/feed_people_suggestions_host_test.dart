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

void main() {
  group('Feed people suggestions renders', () {
    for (final dark in [false, true]) {
      testWidgets(
        'ready recommendations arm an inactive card in ${dark ? 'dark' : 'light'} appearance',
        (tester) async {
          VisibilityDetectorController.instance.updateInterval = Duration.zero;
          final response = Completer<http.Response>();
          final owner = 'a' * 64;
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
                    initialVideoIndex: 0,
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
                    'pubkey': 'b' * 64,
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
              initialVideoIndex: 0,
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
