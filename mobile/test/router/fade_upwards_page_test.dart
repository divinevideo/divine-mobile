// ABOUTME: Pins that fadeUpwardsPage carries go_router page metadata
// ABOUTME: Regression test for PageLoadObserver reporting unknown_route

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/fade_upwards_page.dart';
import 'package:openvine/ui/adaptive_layout.dart';

class _FakeGoRouterState extends Fake implements GoRouterState {
  _FakeGoRouterState({
    required this.pageKey,
    this.name,
    this.path,
    this.pathParameters = const {},
    Uri? uri,
  }) : uri = uri ?? Uri.parse('/');

  @override
  final ValueKey<String> pageKey;

  @override
  final String? name;

  @override
  final String? path;

  @override
  GoRoute? get topRoute => null;

  @override
  String? get fullPath => null;

  @override
  final Map<String, String> pathParameters;

  @override
  final Uri uri;
}

void main() {
  group('fadeUpwardsPage', () {
    test('is a CustomTransitionPage (keeps the fade-upwards transition)', () {
      final page = fadeUpwardsPage(
        state: _FakeGoRouterState(
          pageKey: const ValueKey('video-recorder'),
          name: 'video-recorder',
          path: '/video-recorder',
        ),
        child: const SizedBox.shrink(),
      );

      expect(page, isA<CustomTransitionPage<void>>());
      expect(page.key, const ValueKey('video-recorder'));
    });

    test('carries the route name and restorationId so root-navigator '
        'observers resolve a real surface, not unknown_route', () {
      // A nameless CustomTransitionPage makes route.settings.name null,
      // which PageLoadObserver maps to `unknown_route` — the regression
      // this pins. See #5983.
      final page = fadeUpwardsPage(
        state: _FakeGoRouterState(
          pageKey: const ValueKey('video-recorder'),
          name: 'video-recorder',
          path: '/video-recorder',
        ),
        child: const SizedBox.shrink(),
      );

      expect(page.name, 'video-recorder');
      expect(page.restorationId, 'video-recorder');
    });

    test('falls back to the route path when the route has no name', () {
      final page = fadeUpwardsPage(
        state: _FakeGoRouterState(
          pageKey: const ValueKey('/drafts'),
          path: '/drafts',
        ),
        child: const SizedBox.shrink(),
      );

      expect(page.name, '/drafts');
    });

    test('merges path and query parameters into arguments', () {
      final page = fadeUpwardsPage(
        state: _FakeGoRouterState(
          pageKey: const ValueKey('clips'),
          name: 'clips',
          path: '/clips',
          pathParameters: const {'id': '42'},
          uri: Uri.parse('/clips?tab=recent'),
        ),
        child: const SizedBox.shrink(),
      );

      expect(page.arguments, {'id': '42', 'tab': 'recent'});
    });

    testWidgets('ends the page before a status bar column, reached through a '
        'named route', (tester) async {
      const pageKey = Key('library');
      const padding = FakeViewPadding(right: 84, bottom: 34);
      tester.view.physicalSize = const Size(951, 669);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = padding;
      tester.view.viewPadding = padding;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const SizedBox.expand(),
            routes: [
              GoRoute(
                path: 'library',
                name: 'library',
                pageBuilder: (_, state) => fadeUpwardsPage(
                  state: state,
                  child: const SizedBox.expand(key: pageKey),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isFeatureEnabledProvider(
              FeatureFlag.largeScreenLayout,
            ).overrideWithValue(true),
          ],
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            routerConfig: router,
            builder: (context, child) => AdaptiveLayoutScope(child: child!),
          ),
        ),
      );

      router.goNamed('library');
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.byKey(pageKey)),
        equals(const Rect.fromLTRB(0, 0, 867, 669)),
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ColoredBox &&
              widget.color == VineTheme.darkColors.nav &&
              widget.child is SizedBox &&
              (widget.child! as SizedBox).width == 84,
        ),
        findsOneWidget,
      );
    });
  });
}
