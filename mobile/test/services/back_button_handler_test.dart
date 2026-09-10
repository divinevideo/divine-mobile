// ABOUTME: Drives the real org.openvine/navigation channel Android calls into
// ABOUTME: Regression for #3337 - back from the Inbox tab used to close the app

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/router/providers/providers.dart';
import 'package:openvine/services/back_button_handler.dart';

const _navChannel = MethodChannel('org.openvine/navigation');

void main() {
  tearDown(() {
    // The handler BackButtonHandler.initialize installs outlives the test, and
    // holds a disposed GoRouter. Clear both sides so no later suite inherits it.
    _navChannel.setMethodCallHandler(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_navChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  /// Visits [visitedPaths], then delivers a real `onBackPressed` call over the
  /// platform channel and reports what the native side would receive.
  Future<({bool? handled, String location})> pressBackAfterVisiting(
    WidgetTester tester,
    List<String> visitedPaths, {
    String? pushAfter,
  }) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final locations = StreamController<String>.broadcast();
    addTearDown(locations.close);

    final router = GoRouter(
      initialLocation: '/home/0',
      routes: [
        GoRoute(path: '/home/:i', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/explore', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/explore/:i', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/notifications/:i', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/inbox', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/hashtag/:tag', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/video-editor', builder: (_, _) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);

    late WidgetRef capturedRef;
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routerLocationStreamProvider.overrideWithValue(locations.stream),
        ],
        // Mount the router for real: GoRouter.canPop() reads live
        // NavigatorStates, so a router that is never attached to a widget
        // tree always reports false and the pop arms go untested.
        child: Consumer(
          builder: (context, ref, _) {
            capturedRef = ref;
            container = ProviderScope.containerOf(context);
            return MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            );
          },
        ),
      ),
    );
    await tester.pump();
    // Both are lazy Notifiers whose ref.listen only arms on first read. The
    // running app reads them early (the home feed and the bottom nav do), so
    // arm them here too or the harness silently records nothing.
    container.read(tabHistoryProvider);
    container.read(lastTabPositionProvider);
    container.listen(pageContextProvider, (_, _) {});

    for (final path in visitedPaths) {
      locations.add(path);
      await tester.pump(Duration.zero);
      await tester.pump(Duration.zero);
    }

    if (pushAfter != null) {
      // Push on the real router *and* feed the mocked location stream, so the
      // page context the handler reads matches the route that is on top.
      router.push(pushAfter);
      locations.add(pushAfter);
      await tester.pumpAndSettle();
    }

    BackButtonHandler.initialize(router, capturedRef);

    bool? handled;
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      _navChannel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('onBackPressed'),
      ),
      (ByteData? reply) {
        if (reply == null) return;
        handled = const StandardMethodCodec().decodeEnvelope(reply) as bool?;
      },
    );
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);

    final location = router.routeInformationProvider.value.uri.toString();
    // Must be cleared inside the test body: flutter_test asserts every
    // foundation debug variable is unset before tearDown runs.
    debugDefaultTargetPlatformOverride = null;

    return (handled: handled, location: location);
  }

  group(BackButtonHandler, () {
    group('onBackPressed', () {
      // #3337: this returned false, and MainActivity turns false into
      // finish() / super.onBackPressed() — the app closed from a primary tab.
      testWidgets('consumes the press on the Inbox tab and goes home', (
        tester,
      ) async {
        final result = await pressBackAfterVisiting(tester, [
          '/home/0',
          '/inbox',
        ]);

        expect(
          result.handled,
          isTrue,
          reason: 'false lets Android finish the activity, closing the app',
        );
        expect(result.location, equals('/home/0'));
      });

      testWidgets('consumes the press on the notifications feed', (
        tester,
      ) async {
        final result = await pressBackAfterVisiting(tester, [
          '/home/0',
          '/notifications/0',
        ]);

        expect(result.handled, isTrue);
        expect(result.location, equals('/home/0'));
      });

      // #8084: this used to land on '/explore/0' — the video feed —
      // because LastTabPosition recorded `ctx.videoIndex ?? 0` and merely
      // opening the grid stored index 0.
      testWidgets('returns to the previously visited tab', (tester) async {
        final result = await pressBackAfterVisiting(tester, [
          '/home/0',
          '/explore',
          '/inbox',
        ]);

        expect(result.handled, isTrue);
        expect(
          result.location,
          equals('/explore'),
          reason: 'the user was on the grid, so the tab restores the grid',
        );
      });

      testWidgets('resumes the explore video the user actually opened', (
        tester,
      ) async {
        final result = await pressBackAfterVisiting(tester, [
          '/home/0',
          '/explore',
          '/explore/4',
          '/inbox',
        ]);

        expect(result.handled, isTrue);
        expect(result.location, equals('/explore/4'));
      });

      // Regression for #3337: tab 2 hosts /inbox and /notifications/:index.
      // The handler read lastTabPosition.getPosition, which defaults
      // notifications to 0, so backing to the Inbox tab dropped the user into
      // a notification video feed they had never opened. Only reachable once
      // the inbox started being recorded in tab history.
      testWidgets(
        'returns to the inbox, not a notification feed never opened',
        (tester) async {
          final result = await pressBackAfterVisiting(tester, [
            '/home/0',
            '/inbox',
            '/explore',
          ]);

          expect(result.handled, isTrue);
          expect(result.location, equals('/inbox'));
        },
      );

      testWidgets('resumes the notification feed the user actually opened', (
        tester,
      ) async {
        final result = await pressBackAfterVisiting(tester, [
          '/home/0',
          '/notifications/3',
          '/explore',
        ]);

        expect(result.handled, isTrue);
        expect(result.location, equals('/notifications/3'));
      });

      testWidgets('returns to inbox after leaving a notification feed', (
        tester,
      ) async {
        final result = await pressBackAfterVisiting(tester, [
          '/home/0',
          '/notifications/3',
          '/inbox',
          '/explore',
        ]);

        expect(result.handled, isTrue);
        expect(result.location, equals('/inbox'));
      });

      // Proves the pop arm is reachable: GoRouter.canPop() is false at a
      // branch root and true once a route is pushed, so a pushed hashtag grid
      // pops back where it came from instead of replacing the stack with
      // /explore (#3337 P2).
      testWidgets('pops a pushed hashtag grid instead of jumping to explore', (
        tester,
      ) async {
        final result = await pressBackAfterVisiting(
          tester,
          ['/home/0', '/explore'],
          pushAfter: '/hashtag/dart',
        );

        expect(result.handled, isTrue);
        // Popped back to whatever the router had underneath, rather than
        // replacing the stack with /explore the way the pre-#3337 Android
        // copy did.
        expect(result.location, equals('/home/0'));
        expect(result.location, isNot(equals('/explore')));
      });

      // Raised in review on #8083: an editor reached with nothing beneath it
      // used to report the press unhandled, which on Android finishes the
      // activity. Unreachable via any deep link the parser emits, but the
      // whole point of this policy is that "unhandled" must mean "genuinely
      // nowhere to go".
      testWidgets('consumes the press in an editor with nothing to pop', (
        tester,
      ) async {
        final result = await pressBackAfterVisiting(tester, [
          '/home/0',
          '/video-editor',
        ]);

        expect(
          result.handled,
          isTrue,
          reason: 'false would let Android close the app from the editor',
        );
        expect(result.location, equals('/home/0'));
      });

      // The one case where reporting the press unhandled is correct: home,
      // nothing pushed, no tab to go back to.
      testWidgets('leaves home with no history to the platform', (
        tester,
      ) async {
        final result = await pressBackAfterVisiting(tester, ['/home/0']);

        expect(result.handled, isFalse);
      });
    });
  });
}
