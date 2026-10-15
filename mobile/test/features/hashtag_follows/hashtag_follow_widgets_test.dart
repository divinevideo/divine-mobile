import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hashtag_subscription_repository/hashtag_subscription_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/hashtag_follows/view/followed_hashtags_page.dart';
import 'package:openvine/features/hashtag_follows/view/hashtag_follow_button.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/hashtag_subscription_repository_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';

import 'hashtag_follows_cubit_test.dart' show TestStore;

void main() {
  group('hashtag_follow_widgets_test', () {
    Widget app(HashtagSubscriptionRepository repository, Widget child) =>
        ProviderScope(
          overrides: [
            hashtagSubscriptionRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: child),
          ),
        );

    testWidgets('follow button persists and toggles confirmed membership', (
      tester,
    ) async {
      final repository = HashtagSubscriptionRepository(store: TestStore());
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        app(repository, const HashtagFollowButton(hashtag: 'LNIC')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();
      expect(find.text('Following'), findsOneWidget);
      expect(repository.subscriptions.single.canonicalTag, 'lnic');
      await tester.tap(find.text('Following'));
      await tester.pumpAndSettle();
      expect(repository.subscriptions, isEmpty);
    });
    testWidgets('management shows empty guidance and removes followed tags', (
      tester,
    ) async {
      final repository = HashtagSubscriptionRepository(store: TestStore());
      addTearDown(repository.dispose);
      await repository.follow('LNIC');
      await tester.pumpWidget(app(repository, const FollowedHashtagsPage()));
      await tester.pumpAndSettle();
      expect(find.text('#LNIC'), findsOneWidget);
      await tester.tap(find.text('Unfollow'));
      await tester.pumpAndSettle();
      expect(
        find.text('Follow a hashtag from its page to find it here.'),
        findsOneWidget,
      );
    });
    testWidgets(
      'pending saves disable repeated taps and failed saves retain Follow',
      (tester) async {
        final store = TestStore()..gate = Completer<void>();
        final repository = HashtagSubscriptionRepository(store: store);
        addTearDown(repository.dispose);
        await tester.pumpWidget(
          app(repository, const HashtagFollowButton(hashtag: 'LNIC')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Follow'));
        await tester.pump();
        final button = tester.widget<DivineButton>(find.byType(DivineButton));
        expect(button.onPressed, isNull);
        expect(repository.subscriptions, isEmpty);
        store.fail = true;
        store.gate!.complete();
        await tester.pumpAndSettle();
        expect(find.text('Follow'), findsOneWidget);
        expect(find.text("Couldn't save that. Try again?"), findsOneWidget);
        expect(repository.subscriptions, isEmpty);
      },
    );

    testWidgets(
      'anonymous Follow opens sign in without creating a subscription',
      (tester) async {
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) =>
                  const Scaffold(body: HashtagFollowButton(hashtag: 'LNIC')),
            ),
            GoRoute(
              path: RoutePaths.welcomeLoginOptions,
              builder: (_, _) =>
                  const Scaffold(body: Text('sign in destination')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hashtagSubscriptionRepositoryProvider.overrideWithValue(null),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Follow'));
        await tester.pumpAndSettle();
        expect(find.text('sign in destination'), findsOneWidget);
      },
    );

    for (final theme in [VineTheme.theme, VineTheme.lightTheme]) {
      testWidgets(
        'management scrolls and opens exact Unicode/percent tags in ${theme.brightness}',
        (tester) async {
          final repository = HashtagSubscriptionRepository(store: TestStore());
          addTearDown(repository.dispose);
          for (var i = 0; i < 40; i++) {
            await repository.follow('tag$i');
          }
          await repository.follow('日本語100%fun');
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const FollowedHashtagsPage(),
              ),
              GoRoute(
                path: HashtagScreenRouter.path,
                builder: (_, state) => Scaffold(
                  body: Text('opened:${state.pathParameters['tag']}'),
                ),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                hashtagSubscriptionRepositoryProvider.overrideWithValue(
                  repository,
                ),
              ],
              child: MaterialApp.router(
                theme: theme,
                routerConfig: router,
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(find.text('#日本語100%fun'), 400);
          await tester.pumpAndSettle();
          await tester.tap(find.text('#日本語100%fun'));
          await tester.pumpAndSettle();
          expect(find.text('opened:日本語100%fun'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
