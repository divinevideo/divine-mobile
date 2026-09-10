import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('PartialCircleSpinner', () {
    Widget buildTestWidget({
      double progress = 0.0,
      double size = 24,
      Color backgroundColor = const Color(0xFF737778),
      Color progressColor = Colors.white,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: PartialCircleSpinner(
            progress: progress,
            size: size,
            backgroundColor: backgroundColor,
            progressColor: progressColor,
          ),
        ),
      );
    }

    testWidgets('renders with default values', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(PartialCircleSpinner), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PartialCircleSpinner),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders with correct default size', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.width, 24);
      expect(sizedBox.height, 24);
    });

    testWidgets('renders with custom size', (tester) async {
      await tester.pumpWidget(buildTestWidget(size: 48));

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.width, 48);
      expect(sizedBox.height, 48);
    });

    testWidgets('animates when progress changes', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Change progress
      await tester.pumpWidget(buildTestWidget(progress: 0.5));

      // Pump through the animation
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(PartialCircleSpinner), findsOneWidget);
    });

    testWidgets('completes animation to final progress value', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpWidget(buildTestWidget(progress: 1));

      // Complete the animation
      await tester.pumpAndSettle();

      expect(find.byType(PartialCircleSpinner), findsOneWidget);
    });

    testWidgets('renders with custom background color', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(backgroundColor: Colors.red),
      );

      expect(find.byType(PartialCircleSpinner), findsOneWidget);
    });

    testWidgets('renders with custom progress color', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(progressColor: Colors.blue),
      );

      expect(find.byType(PartialCircleSpinner), findsOneWidget);
    });

    testWidgets('disposes animation controller without error', (tester) async {
      await tester.pumpWidget(buildTestWidget(progress: 0.5));

      // Remove widget to trigger dispose
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      // No error should occur
      expect(find.byType(PartialCircleSpinner), findsNothing);
    });

    testWidgets('does not animate when progress stays the same', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(progress: 0.5));
      await tester.pumpAndSettle();

      // Rebuild with same progress
      await tester.pumpWidget(buildTestWidget(progress: 0.5));

      expect(find.byType(PartialCircleSpinner), findsOneWidget);
    });
  });
}
