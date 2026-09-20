import 'dart:async';
import 'dart:convert';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/global_error_widget.dart';

/// A widget whose build always fails, so the framework has to fall back to
/// [ErrorWidget.builder] for its subtree.
class _ThrowsOnBuild extends StatelessWidget {
  const _ThrowsOnBuild();

  @override
  Widget build(BuildContext context) {
    throw StateError('deliberate build failure');
  }
}

/// Fails its first build and succeeds from the second on, recording each
/// attempt in [attempts] so a test can tell a retry from a stray rebuild.
class _FailsUntilRetried extends StatelessWidget {
  const _FailsUntilRetried(this.attempts);

  final List<int> attempts;

  @override
  Widget build(BuildContext context) {
    attempts.add(attempts.length + 1);
    if (attempts.length == 1) throw StateError('first build fails');
    return const Text('recovered');
  }
}

/// The font family [copy] resolves to once its style has been merged with
/// whatever the tree above it provides.
String? _resolvedFontFamily(WidgetTester tester, String copy) => tester
    .widget<RichText>(
      find.descendant(of: find.text(copy), matching: find.byType(RichText)),
    )
    .text
    .style
    ?.fontFamily;

/// The surface's own background, found from the headline upwards so a
/// `ColoredBox` the app shell paints above it is never mistaken for it.
Finder _surface() => find
    .ancestor(
      of: find.text('got a bit tangled'),
      matching: find.byType(ColoredBox),
    )
    .first;

void main() {
  group('buildGlobalErrorWidget', () {
    late FlutterErrorDetails details;

    setUp(() {
      details = FlutterErrorDetails(
        exception: Exception('Test error: widget build failed'),
        library: 'widgets library',
        context: ErrorDescription('building TestWidget'),
        stack: StackTrace.current,
      );
    });

    group('renders', () {
      testWidgets('the headline', (tester) async {
        await tester.pumpWidget(buildGlobalErrorWidget(details));

        expect(find.text('got a bit tangled'), findsOneWidget);
      });

      testWidgets('the friendly explanation', (tester) async {
        await tester.pumpWidget(buildGlobalErrorWidget(details));

        expect(
          find.text("something tripped up here.\nit's not you, it's us."),
          findsOneWidget,
        );
      });

      testWidgets('the navigation hint', (tester) async {
        await tester.pumpWidget(buildGlobalErrorWidget(details));

        expect(
          find.text('try navigating away and coming back'),
          findsOneWidget,
        );
      });

      testWidgets('the tangled mascot illustration', (tester) async {
        await tester.pumpWidget(buildGlobalErrorWidget(details));

        final image = tester.widget<Image>(find.byType(Image));
        expect(
          image.image,
          isA<AssetImage>().having(
            (asset) => asset.assetName,
            'assetName',
            equals(globalErrorMascotAsset),
          ),
        );
      });

      testWidgets('debug info in debug mode', (tester) async {
        // kDebugMode is true during tests
        await tester.pumpWidget(buildGlobalErrorWidget(details));

        expect(find.text('debug info'), findsOneWidget);
        expect(
          find.textContaining('Test error: widget build failed'),
          findsOneWidget,
        );
      });

      testWidgets('the library name in debug mode', (tester) async {
        await tester.pumpWidget(buildGlobalErrorWidget(details));

        expect(find.text('library: widgets library'), findsOneWidget);
      });

      testWidgets('the error context in debug mode', (tester) async {
        await tester.pumpWidget(buildGlobalErrorWidget(details));

        expect(find.text('building TestWidget'), findsOneWidget);
      });

      testWidgets('error details without a context', (tester) async {
        final minimalDetails = FlutterErrorDetails(
          exception: Exception('Minimal error'),
        );

        await tester.pumpWidget(buildGlobalErrorWidget(minimalDetails));

        expect(find.text('got a bit tangled'), findsOneWidget);
      });

      testWidgets('inside a scroll view for long error messages', (
        tester,
      ) async {
        await tester.pumpWidget(buildGlobalErrorWidget(details));

        expect(find.byType(SingleChildScrollView), findsOneWidget);
      });
    });

    group('before any app shell exists', () {
      // Pumped as the root widget: no MaterialApp, no Theme, no MediaQuery and
      // no Navigator, which is the shape of a failure during startup.
      testWidgets('uses the dark background', (tester) async {
        await tester.pumpWidget(buildGlobalErrorWidget(details));

        expect(
          tester.widget<ColoredBox>(_surface()).color,
          equals(VineTheme.darkColors.background),
        );
      });

      testWidgets('offers Reload and no Back, and builds without throwing', (
        tester,
      ) async {
        await tester.pumpWidget(buildGlobalErrorWidget(details));

        expect(find.text('Reload'), findsOneWidget);
        expect(find.byType(DivineIconButton), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });

    group('bundled assets', () {
      testWidgets('ships the mascot illustration', (tester) async {
        final data = await tester.runAsync(
          () => rootBundle.load(globalErrorMascotAsset),
        );

        expect(data!.lengthInBytes, greaterThan(0));
      });

      testWidgets('declares the families the copy is set in', (tester) async {
        final manifest = await tester.runAsync(
          () => rootBundle.loadString('FontManifest.json'),
        );

        final families = [
          for (final entry in jsonDecode(manifest!) as List<dynamic>)
            (entry as Map<String, dynamic>)['family'],
        ];
        expect(
          families,
          containsAll([VineTheme.fontFamilyBricolage, 'Inter']),
        );
      });

      testWidgets('ships the Reload label font, so it is never fetched', (
        tester,
      ) async {
        final data = await tester.runAsync(
          () =>
              rootBundle.load('assets/fonts/BricolageGrotesque-ExtraBold.ttf'),
        );

        expect(data!.lengthInBytes, greaterThan(0));
      });
    });
  });

  group('installed as ErrorWidget.builder', () {
    /// Runs [body] with the branded builder installed.
    ///
    /// Installed inside the test body, not in `setUp`: the framework records
    /// the builder when the body starts and fails the test if it differs at the
    /// end, before any `addTearDown` runs. So the restore is inline, and the
    /// tear-down only covers a body that throws first.
    Future<void> withBrandedBuilder(Future<void> Function() body) async {
      final originalBuilder = ErrorWidget.builder;
      addTearDown(() => ErrorWidget.builder = originalBuilder);
      ErrorWidget.builder = buildGlobalErrorWidget;
      await body();
      ErrorWidget.builder = originalBuilder;
    }

    Widget app({
      required Widget home,
      ThemeData? theme,
      GlobalKey<NavigatorState>? navigatorKey,
    }) => MaterialApp(
      navigatorKey: navigatorKey,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme ?? VineTheme.theme,
      home: home,
    );

    /// Pushes [page] over a first route, so the failing route can be popped.
    Future<void> pushOverPreviousPage(WidgetTester tester, Widget page) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        app(navigatorKey: navigatorKey, home: const Text('previous page')),
      );
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => page),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isA<StateError>());
    }

    /// The production shape: the app under go_router, with a first route at
    /// `/` and the failing page at `/broken`, or at `/shell/broken` inside a
    /// shell that has a navigator of its own.
    Future<GoRouter> pumpRouterApp(
      WidgetTester tester, {
      required String initialLocation,
    }) async {
      final router = GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Text('previous page')),
          GoRoute(path: '/broken', builder: (_, _) => const _ThrowsOnBuild()),
          ShellRoute(
            builder: (_, _, child) => child,
            routes: [
              GoRoute(
                path: '/shell/broken',
                builder: (_, _) => const _ThrowsOnBuild(),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          routerConfig: router,
        ),
      );
      return router;
    }

    group('renders', () {
      testWidgets(
        'in place of a widget that throws during build',
        (tester) => withBrandedBuilder(() async {
          await tester.pumpWidget(app(home: const _ThrowsOnBuild()));

          // The framework reports the failure before it asks the builder for
          // a replacement; the report is what the test binding hands back.
          expect(tester.takeException(), isA<StateError>());
          expect(find.text('got a bit tangled'), findsOneWidget);
          expect(
            find.textContaining('deliberate build failure'),
            findsOneWidget,
          );
        }),
      );

      testWidgets(
        'in its own bundled fonts where it would inherit a monospace fallback',
        (tester) => withBrandedBuilder(() async {
          // A whole page failed, so nothing between MaterialApp and the
          // surface provides a Material, and the inherited style is
          // MaterialApp's monospace "missing Material" fallback.
          await tester.pumpWidget(app(home: const _ThrowsOnBuild()));
          expect(tester.takeException(), isA<StateError>());
          final inherited = DefaultTextStyle.of(
            tester.element(find.text('got a bit tangled')),
          ).style;
          expect(inherited.fontFamily, equals('monospace'));

          expect(
            _resolvedFontFamily(tester, 'got a bit tangled'),
            equals(VineTheme.fontFamilyBricolage),
          );
          expect(
            _resolvedFontFamily(
              tester,
              "something tripped up here.\nit's not you, it's us.",
            ),
            equals('Inter'),
          );
          expect(
            _resolvedFontFamily(tester, 'try navigating away and coming back'),
            equals('Inter'),
          );
        }),
      );

      testWidgets(
        'in the light appearance inside a light-themed app',
        (tester) => withBrandedBuilder(() async {
          await tester.pumpWidget(
            app(home: const _ThrowsOnBuild(), theme: VineTheme.lightTheme),
          );
          expect(tester.takeException(), isA<StateError>());

          final color = tester.widget<ColoredBox>(_surface()).color;
          expect(color, equals(VineTheme.lightColors.background));
          expect(color, isNot(equals(VineTheme.darkColors.background)));
        }),
      );
    });

    group('Reload', () {
      testWidgets(
        're-runs the failed build and restores the widget',
        (tester) => withBrandedBuilder(() async {
          final attempts = <int>[];
          await tester.pumpWidget(app(home: _FailsUntilRetried(attempts)));
          expect(tester.takeException(), isA<StateError>());
          expect(find.text('got a bit tangled'), findsOneWidget);
          // Nothing but Reload may have caused the second build.
          expect(attempts, equals([1]));

          await tester.tap(find.text('Reload'));
          await tester.pumpAndSettle();

          expect(attempts, equals([1, 2]));
          expect(find.text('recovered'), findsOneWidget);
          expect(find.text('got a bit tangled'), findsNothing);
        }),
      );
    });

    group('Back', () {
      testWidgets(
        'is absent when the failing route has nothing to pop',
        (tester) => withBrandedBuilder(() async {
          await tester.pumpWidget(app(home: const _ThrowsOnBuild()));
          expect(tester.takeException(), isA<StateError>());

          expect(find.text('got a bit tangled'), findsOneWidget);
          expect(find.byType(DivineIconButton), findsNothing);
        }),
      );

      testWidgets(
        'pops the failing route',
        (tester) => withBrandedBuilder(() async {
          await pushOverPreviousPage(tester, const _ThrowsOnBuild());
          expect(find.text('got a bit tangled'), findsOneWidget);

          await tester.tap(find.byType(DivineIconButton));
          await tester.pumpAndSettle();

          expect(find.text('previous page'), findsOneWidget);
          expect(find.text('got a bit tangled'), findsNothing);
        }),
      );

      testWidgets(
        'pops a go_router route',
        (tester) => withBrandedBuilder(() async {
          final router = await pumpRouterApp(tester, initialLocation: '/');
          unawaited(router.push('/broken'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isA<StateError>());
          expect(find.text('got a bit tangled'), findsOneWidget);

          await tester.tap(find.byType(DivineIconButton));
          await tester.pumpAndSettle();

          expect(find.text('previous page'), findsOneWidget);
          expect(find.text('got a bit tangled'), findsNothing);
        }),
      );

      testWidgets(
        'pops out of a nested navigator that has nothing to pop itself',
        (tester) => withBrandedBuilder(() async {
          final router = await pumpRouterApp(tester, initialLocation: '/');
          unawaited(router.push('/shell/broken'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isA<StateError>());

          // The shell's own navigator holds one page; only the router knows
          // the root stack can pop.
          final surface = tester.element(find.text('got a bit tangled'));
          expect(Navigator.of(surface).canPop(), isFalse);

          await tester.tap(find.byType(DivineIconButton));
          await tester.pumpAndSettle();

          expect(find.text('previous page'), findsOneWidget);
          expect(find.text('got a bit tangled'), findsNothing);
        }),
      );

      testWidgets(
        'is absent on a go_router route with nothing to pop',
        (tester) => withBrandedBuilder(() async {
          await pumpRouterApp(tester, initialLocation: '/broken');
          expect(tester.takeException(), isA<StateError>());

          expect(find.text('got a bit tangled'), findsOneWidget);
          expect(find.byType(DivineIconButton), findsNothing);
        }),
      );

      testWidgets(
        'is announced as Back',
        (tester) => withBrandedBuilder(() async {
          final semantics = tester.ensureSemantics();
          await pushOverPreviousPage(tester, const _ThrowsOnBuild());

          expect(find.bySemanticsLabel('Back'), findsOneWidget);

          semantics.dispose();
        }),
      );

      testWidgets(
        'is offered when the failed page sat inside the safe area',
        (tester) => withBrandedBuilder(() async {
          const notch = FakeViewPadding(top: 141, bottom: 102);
          tester.view.padding = notch;
          tester.view.viewPadding = notch;
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.view.resetViewPadding);
          await pushOverPreviousPage(
            tester,
            const SafeArea(child: _ThrowsOnBuild()),
          );

          // Smaller than the navigator by exactly the system insets.
          expect(tester.getSize(_surface()).height, lessThan(600));
          expect(find.byType(DivineIconButton).hitTestable(), findsOneWidget);
        }),
      );

      testWidgets(
        'stays out of reach on a failed item of a list',
        (tester) => withBrandedBuilder(() async {
          final semantics = tester.ensureSemantics();
          await pushOverPreviousPage(
            tester,
            Scaffold(
              body: ListView.builder(
                itemCount: 3,
                itemBuilder: (_, index) => index == 1
                    ? const _ThrowsOnBuild()
                    : const SizedBox(height: 40, child: Text('a healthy row')),
              ),
            ),
          );

          // A list does not bound its items, so the failed one grows to the
          // height of its content, which is taller than many whole screens.
          expect(tester.getSize(_surface()).height, greaterThan(360));
          expect(find.byType(DivineIconButton), findsOneWidget);
          expect(find.byType(DivineIconButton).hitTestable(), findsNothing);
          expect(find.bySemanticsLabel('Back'), findsNothing);

          semantics.dispose();
        }),
      );

      testWidgets(
        'stays out of reach under an app bar that still works',
        (tester) => withBrandedBuilder(() async {
          await pushOverPreviousPage(
            tester,
            Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                title: const Text('a live app bar'),
              ),
              body: const _ThrowsOnBuild(),
            ),
          );

          expect(find.text('a live app bar'), findsOneWidget);
          expect(find.byType(DivineIconButton), findsOneWidget);
          expect(find.byType(DivineIconButton).hitTestable(), findsNothing);
        }),
      );

      testWidgets(
        'stays out of reach when only a fragment of the page failed',
        (tester) => withBrandedBuilder(() async {
          final semantics = tester.ensureSemantics();
          await pushOverPreviousPage(
            tester,
            const Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: _ThrowsOnBuild(),
              ),
            ),
          );

          // Built, because the route can pop — only the size of the surface
          // keeps it from the user.
          expect(find.byType(DivineIconButton), findsOneWidget);
          expect(find.byType(DivineIconButton).hitTestable(), findsNothing);
          expect(find.bySemanticsLabel('Back'), findsNothing);

          semantics.dispose();
        }),
      );
    });
  });
}
