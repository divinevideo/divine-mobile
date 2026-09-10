// ABOUTME: Widget tests for RouteErrorScreen — message, always-escapable home
// ABOUTME: button, and safePop back handling so no route can strand the user.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_error_screen.dart';

import '../helpers/finders.dart';

void main() {
  final strings = AppLocalizationsEn();

  Future<void> pumpErrorScreen(
    WidgetTester tester, {
    required Widget errorScreen,
    String initialLocation = '/err',
  }) async {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/home/:index',
          builder: (_, _) => const _HomeMarker(),
        ),
        GoRoute(path: '/err', builder: (_, _) => errorScreen),
        GoRoute(
          path: '/first',
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push('/err'),
                child: const Text('open error'),
              ),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
  }

  group(RouteErrorScreen, () {
    testWidgets('renders the message and a home button by default', (
      tester,
    ) async {
      await pumpErrorScreen(
        tester,
        errorScreen: const RouteErrorScreen(message: 'boom'),
      );

      expect(find.text('boom'), findsOneWidget);
      expect(
        find.widgetWithText(DivineButton, strings.routeGoHome),
        findsOneWidget,
      );
    });

    testWidgets('home button navigates to the home feed', (tester) async {
      await pumpErrorScreen(
        tester,
        errorScreen: const RouteErrorScreen(message: 'boom'),
      );

      await tester.tap(find.widgetWithText(DivineButton, strings.routeGoHome));
      await tester.pumpAndSettle();

      expect(find.byType(_HomeMarker), findsOneWidget);
    });

    testWidgets('showHomeButton: false hides the home button', (tester) async {
      await pumpErrorScreen(
        tester,
        errorScreen: const RouteErrorScreen(
          message: 'boom',
          showHomeButton: false,
        ),
      );

      expect(find.text('boom'), findsOneWidget);
      expect(
        find.widgetWithText(DivineButton, strings.routeGoHome),
        findsNothing,
      );
    });

    testWidgets('shows no back button by default', (tester) async {
      await pumpErrorScreen(
        tester,
        errorScreen: const RouteErrorScreen(message: 'boom'),
      );

      expect(findByTooltip('Back'), findsNothing);
    });

    testWidgets(
      'back control falls back to the home feed when the stack is empty',
      (tester) async {
        await pumpErrorScreen(
          tester,
          errorScreen: const RouteErrorScreen(
            message: 'boom',
            showBackButton: true,
          ),
        );

        // Reached via `go` (single-entry stack) → nothing to pop → safePop
        // lands on the home feed instead of throwing GoError.
        await tester.tap(findByTooltip('Back'));
        await tester.pumpAndSettle();

        expect(find.byType(_HomeMarker), findsOneWidget);
      },
    );

    testWidgets('back control pops when there is a route to pop to', (
      tester,
    ) async {
      await pumpErrorScreen(
        tester,
        errorScreen: const RouteErrorScreen(
          message: 'boom',
          showBackButton: true,
        ),
        initialLocation: '/first',
      );

      await tester.tap(find.text('open error'));
      await tester.pumpAndSettle();
      expect(find.text('boom'), findsOneWidget);

      await tester.tap(findByTooltip('Back'));
      await tester.pumpAndSettle();

      // Popped back to the pushing screen rather than being forced home.
      expect(find.text('open error'), findsOneWidget);
      expect(find.byType(_HomeMarker), findsNothing);
    });
  });
}

class _HomeMarker extends StatelessWidget {
  const _HomeMarker();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('home-marker')));
}
