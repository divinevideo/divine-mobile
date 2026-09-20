import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
    });

    group('bundled assets', () {
      testWidgets('ships the mascot illustration', (tester) async {
        final data = await tester.runAsync(
          () => rootBundle.load(globalErrorMascotAsset),
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

    Widget app({required Widget home, ThemeData? theme}) => MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme ?? VineTheme.theme,
      home: home,
    );

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
  });
}
