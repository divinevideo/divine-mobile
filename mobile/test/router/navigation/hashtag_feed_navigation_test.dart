// ABOUTME: Tests for openHashtagFeed: a hashtag feed opens once per frame
// ABOUTME: (#9980), and it opens again even after a feed left through go().

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/navigation/hashtag_feed_navigation.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';

import '../../helpers/go_router.dart';

const _androidAndIos = TargetPlatformVariant({
  TargetPlatform.android,
  TargetPlatform.iOS,
});

void main() {
  group('openHashtagFeed', () {
    late BuildContext homeContext;

    Future<GoRouter> pumpRouter(WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) {
              homeContext = context;
              return const Scaffold(body: Text('home'));
            },
          ),
          GoRoute(
            path: HashtagScreenRouter.path,
            builder: (context, state) =>
                Scaffold(body: Text('feed ${state.pathParameters['tag']}')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
      return router;
    }

    Finder feedPage(String tag) => find.text('feed $tag', skipOffstage: false);

    testWidgets(
      'opens one feed when asked twice before the next frame',
      (tester) async {
        final router = await pumpRouter(tester);

        openHashtagFeed(homeContext, 'funny', logName: 'test');
        openHashtagFeed(homeContext, 'funny', logName: 'test');
        await tester.pumpAndSettle();

        expect(feedPage('funny'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        expect(feedPage('funny'), findsNothing);
        expect(find.text('home'), findsOneWidget);
      },
      variant: _androidAndIos,
    );

    testWidgets(
      'drops a different tag asked for in the same frame',
      (tester) async {
        await pumpRouter(tester);

        openHashtagFeed(homeContext, 'funny', logName: 'test');
        openHashtagFeed(homeContext, 'comedy', logName: 'test');
        await tester.pumpAndSettle();

        expect(feedPage('funny'), findsOneWidget);
        expect(feedPage('comedy'), findsNothing);
      },
      variant: _androidAndIos,
    );

    // A pushed route's future completes only on a pop; a go() drops it.
    testWidgets('opens again after the previous feed left through go()', (
      tester,
    ) async {
      final router = await pumpRouter(tester);
      openHashtagFeed(homeContext, 'funny', logName: 'test');
      await tester.pumpAndSettle();
      expect(feedPage('funny'), findsOneWidget);

      router.go('/');
      await tester.pumpAndSettle();
      expect(feedPage('funny'), findsNothing);

      openHashtagFeed(homeContext, 'comedy', logName: 'test');
      await tester.pumpAndSettle();

      expect(feedPage('comedy'), findsOneWidget);
    });

    // On a still screen nothing else draws a frame, so the gate has to ask
    // for the one that reopens it.
    testWidgets('reopens after one frame even when the push draws nothing', (
      tester,
    ) async {
      final router = MockGoRouter();
      when(
        () => router.push<void>(any()),
      ).thenAnswer((_) => Completer<void>().future);
      await tester.pumpWidget(
        MockGoRouterProvider(
          goRouter: router,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                homeContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      openHashtagFeed(homeContext, 'funny', logName: 'test');
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump();
      openHashtagFeed(homeContext, 'funny', logName: 'test');

      verify(
        () => router.push<void>(HashtagScreenRouter.pathForTag('funny')),
      ).called(2);
    });
  });
}
