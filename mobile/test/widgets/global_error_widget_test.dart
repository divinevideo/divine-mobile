import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
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

    testWidgets('renders tangled vine headline', (tester) async {
      await tester.pumpWidget(buildGlobalErrorWidget(details));

      expect(find.text('got a bit tangled'), findsOneWidget);
    });

    testWidgets('renders friendly explanation text', (tester) async {
      await tester.pumpWidget(buildGlobalErrorWidget(details));

      expect(
        find.text("something tripped up here.\nit's not you, it's us."),
        findsOneWidget,
      );
    });

    testWidgets('renders navigation hint', (tester) async {
      await tester.pumpWidget(buildGlobalErrorWidget(details));

      expect(find.text('try navigating away and coming back'), findsOneWidget);
    });

    testWidgets('renders tangled vine illustration', (tester) async {
      await tester.pumpWidget(buildGlobalErrorWidget(details));

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('shows debug info in debug mode', (tester) async {
      // kDebugMode is true during tests
      await tester.pumpWidget(buildGlobalErrorWidget(details));

      expect(find.text('debug info'), findsOneWidget);
      expect(
        find.textContaining('Test error: widget build failed'),
        findsOneWidget,
      );
    });

    testWidgets('shows library name in debug mode', (tester) async {
      await tester.pumpWidget(buildGlobalErrorWidget(details));

      expect(find.text('library: widgets library'), findsOneWidget);
    });

    testWidgets('shows error context in debug mode', (tester) async {
      await tester.pumpWidget(buildGlobalErrorWidget(details));

      expect(find.text('building TestWidget'), findsOneWidget);
    });

    testWidgets('handles error details without context gracefully', (
      tester,
    ) async {
      final minimalDetails = FlutterErrorDetails(
        exception: Exception('Minimal error'),
      );

      await tester.pumpWidget(buildGlobalErrorWidget(minimalDetails));

      expect(find.text('got a bit tangled'), findsOneWidget);
    });

    testWidgets('uses the dark background when no theme exists yet', (
      tester,
    ) async {
      // Pumped as the root widget: no MaterialApp, no Theme, no Directionality,
      // which is the shape of a failure before the app shell is up.
      await tester.pumpWidget(buildGlobalErrorWidget(details));

      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.color, equals(VineTheme.darkColors.background));
    });

    testWidgets('is scrollable for long error messages', (tester) async {
      await tester.pumpWidget(buildGlobalErrorWidget(details));

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });

  group('installed as ErrorWidget.builder', () {
    Widget themedApp({required ThemeData theme}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme,
      home: const _ThrowsOnBuild(),
    );

    testWidgets('replaces a widget that throws during build', (tester) async {
      final originalBuilder = ErrorWidget.builder;
      addTearDown(() => ErrorWidget.builder = originalBuilder);
      ErrorWidget.builder = buildGlobalErrorWidget;

      await tester.pumpWidget(themedApp(theme: VineTheme.theme));

      // The framework reports the failure before it asks the builder for a
      // replacement; the report is what the test binding hands back here.
      expect(tester.takeException(), isA<StateError>());
      expect(find.text('got a bit tangled'), findsOneWidget);
      expect(find.textContaining('deliberate build failure'), findsOneWidget);

      // Inline restore: the framework verifies the builder is unchanged at
      // end-of-body, before addTearDown runs.
      ErrorWidget.builder = originalBuilder;
    });

    testWidgets('follows the light appearance inside a light-themed app', (
      tester,
    ) async {
      final originalBuilder = ErrorWidget.builder;
      addTearDown(() => ErrorWidget.builder = originalBuilder);
      ErrorWidget.builder = buildGlobalErrorWidget;

      await tester.pumpWidget(themedApp(theme: VineTheme.lightTheme));
      expect(tester.takeException(), isA<StateError>());

      final surface = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('got a bit tangled'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(surface.color, equals(VineTheme.lightColors.background));
      expect(surface.color, isNot(equals(VineTheme.darkColors.background)));

      ErrorWidget.builder = originalBuilder;
    });
  });
}
