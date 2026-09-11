// ABOUTME: Pins the transition-free shell page on the root navigator
// ABOUTME: Regression test for the startup/login sign-in-page glimpse (#5242)

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/router/routes/shell.dart';
import 'package:openvine/screens/feed/home_feed_retap_cubit.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/startup/app_side_effects.dart';

class _FakeGoRouterState extends Fake implements GoRouterState {
  @override
  ValueKey<String> get pageKey => const ValueKey('shell');

  @override
  String? get name => null;

  @override
  String? get path => null;

  @override
  GoRoute? get topRoute => GoRoute(
    path: VideoFeedPage.path,
    name: VideoFeedPage.routeName,
    builder: (_, _) => const SizedBox.shrink(),
  );

  @override
  Map<String, String> get pathParameters => const {'tab': 'feed'};

  @override
  Uri get uri => Uri.parse('/home?source=startup');
}

class _FakeNavigationShell extends Fake
    with Diagnosticable
    implements StatefulNavigationShell {
  @override
  int get currentIndex => 0;
}

void main() {
  group('bottom-nav shell route', () {
    testWidgets('builds a zero-duration page on the root navigator', (
      tester,
    ) async {
      final shellRoute = shellRoutes().single as StatefulShellRoute;

      expect(
        shellRoute.notifyRootObserver,
        isFalse,
        reason:
            'Branch navigation must not notify the root analytics observers '
            'until the event model in #9079 is decided.',
      );

      // The shell replaces /welcome on the root navigator when the
      // authenticated redirect lands (startup restore, login), and the
      // startup splash lifts at the start of that navigation. A `builder:`
      // here would fall back to a default MaterialPage whose ~400ms slide
      // shows the welcome screen exiting — the sign-in glimpse of #5242.
      expect(
        shellRoute.pageBuilder,
        isNotNull,
        reason:
            'The shell StatefulShellRoute must use pageBuilder (not '
            'builder) so the welcome→home startup redirect swaps without '
            'a visible transition.',
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      final context = tester.element(find.byType(SizedBox));

      final page = shellRoute.pageBuilder!(
        context,
        _FakeGoRouterState(),
        _FakeNavigationShell(),
      );

      expect(page, isA<NoTransitionPage<void>>());
      final transitionPage = page as NoTransitionPage<void>;
      expect(transitionPage.transitionDuration, Duration.zero);
      expect(transitionPage.reverseTransitionDuration, Duration.zero);
      expect(transitionPage.key, const ValueKey('shell'));
      // Page metadata feeds PageLoadObserver; without it the shell route
      // reports as an unnamed page and startup navigations go untracked.
      expect(transitionPage.name, VideoFeedPage.routeName);
      expect(transitionPage.restorationId, 'shell');
      expect(transitionPage.arguments, <String, String>{
        'tab': 'feed',
        'source': 'startup',
      });
      // The shell-tier app-wide side effects are activated above the page's
      // content so AppShell itself stays pure chrome (see app_side_effects.dart).
      expect(transitionPage.child, isA<AppShellSideEffects>());
      final sideEffects = transitionPage.child as AppShellSideEffects;
      // The retap cubit wraps AppShell so the bottom nav and the home
      // branch's feed share one instance (see shell.dart).
      expect(sideEffects.child, isA<BlocProvider<HomeFeedRetapCubit>>());
      final retapProvider =
          sideEffects.child as BlocProvider<HomeFeedRetapCubit>;
      expect(retapProvider.child, isA<AppShell>());
    });
  });
}
