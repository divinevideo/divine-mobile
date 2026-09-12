import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/global_error_widget.dart';

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

    testWidgets('uses dark background', (tester) async {
      await tester.pumpWidget(buildGlobalErrorWidget(details));

      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.color, equals(const Color(0xFF000000)));
    });

    testWidgets('is scrollable for long error messages', (tester) async {
      await tester.pumpWidget(buildGlobalErrorWidget(details));

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}
