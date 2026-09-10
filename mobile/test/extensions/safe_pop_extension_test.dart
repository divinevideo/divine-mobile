import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';

import '../helpers/go_router.dart';

class _BackButtonScreen extends StatelessWidget {
  const _BackButtonScreen({this.fallback});
  final String? fallback;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TextButton(
        onPressed: fallback == null
            ? context.safePop
            : () => context.safePop(fallback: fallback),
        child: const Text('back'),
      ),
    );
  }
}

void main() {
  group('SafePopExtension', () {
    Widget homeScreen() => const Scaffold(body: Text('home'));

    testWidgets(
      'pops the current route when canPop is true',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/home',
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => homeScreen(),
              routes: [
                GoRoute(
                  path: 'detail',
                  builder: (_, _) => const _BackButtonScreen(),
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        router.go('/home/detail');
        await tester.pumpAndSettle();

        expect(find.text('back'), findsOneWidget);

        await tester.tap(find.text('back'));
        await tester.pumpAndSettle();

        expect(find.text('home'), findsOneWidget);
        expect(find.text('back'), findsNothing);
      },
    );

    test('default fallback is /home/0', () {
      expect(defaultSafePopFallback, equals('/home/0'));
    });

    testWidgets(
      'navigates to defaultSafePopFallback when canPop is false',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/key-management',
          routes: [
            GoRoute(
              path: defaultSafePopFallback,
              builder: (_, _) => homeScreen(),
            ),
            GoRoute(
              path: '/key-management',
              builder: (_, _) => const _BackButtonScreen(),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(find.text('back'), findsOneWidget);

        await tester.tap(find.text('back'));
        await tester.pumpAndSettle();

        expect(find.text('home'), findsOneWidget);
        expect(
          router.routerDelegate.currentConfiguration.uri.toString(),
          equals(defaultSafePopFallback),
        );
      },
    );

    testWidgets(
      'navigates to custom fallback when provided',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/key-management',
          routes: [
            GoRoute(
              path: '/settings',
              builder: (_, _) => const Scaffold(body: Text('settings')),
            ),
            GoRoute(
              path: '/key-management',
              builder: (_, _) => const _BackButtonScreen(fallback: '/settings'),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        await tester.tap(find.text('back'));
        await tester.pumpAndSettle();

        expect(find.text('settings'), findsOneWidget);
      },
    );

    testWidgets(
      'tearoff is assignable to VoidCallback (e.g. onBackPressed)',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/key-management',
          routes: [
            GoRoute(
              path: '/home/0',
              builder: (_, _) => homeScreen(),
            ),
            GoRoute(
              path: '/key-management',
              builder: (context, _) => Scaffold(
                appBar: AppBar(
                  leading: BackButton(onPressed: context.safePop),
                ),
                body: const Text('key-management'),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.text('home'), findsOneWidget);
      },
    );

    testWidgets(
      'pops with no arguments when no result was asked for',
      (tester) async {
        final router = MockGoRouter();
        when(router.canPop).thenReturn(true);
        when(router.pop).thenReturn(null);

        await tester.pumpWidget(
          MockGoRouterProvider(
            goRouter: router,
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: context.safePop,
                    child: const Text('back'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('back'));
        await tester.pumpAndSettle();

        // Not pop(null): call sites that never asked for a result are
        // verified against the no-argument shape all over the app.
        verify(router.pop).called(1);
      },
    );

    testWidgets(
      'hands the result to the awaiting caller when it can pop',
      (tester) async {
        Object? received = 'untouched';
        final router = GoRouter(
          initialLocation: '/home',
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    received = await context.push<bool>('/home/detail');
                  },
                  child: const Text('open'),
                ),
              ),
              routes: [
                GoRoute(
                  path: 'detail',
                  builder: (context, _) => Scaffold(
                    body: TextButton(
                      onPressed: () => context.safePop(result: true),
                      child: const Text('done'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('done'));
        await tester.pumpAndSettle();

        expect(received, isTrue);
      },
    );

    testWidgets(
      'drops the result and navigates when there is nothing to pop',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/key-management',
          routes: [
            GoRoute(
              path: '/home/0',
              builder: (_, _) => homeScreen(),
            ),
            GoRoute(
              path: '/key-management',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => context.safePop(result: true),
                  child: const Text('done'),
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        await tester.tap(find.text('done'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('home'), findsOneWidget);
      },
    );

    testWidgets(
      'does not throw GoError when stack is empty',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/key-management',
          routes: [
            GoRoute(
              path: '/home/0',
              builder: (_, _) => homeScreen(),
            ),
            GoRoute(
              path: '/key-management',
              builder: (_, _) => const _BackButtonScreen(),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        await tester.tap(find.text('back'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
