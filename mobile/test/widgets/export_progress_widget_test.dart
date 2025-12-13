// ABOUTME: Tests for ExportProgressWidget
// ABOUTME: Validates visual elements, progress display, and stage transitions

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/export_progress.dart';
import 'package:openvine/widgets/export_progress_widget.dart';

void main() {
  group('ExportProgressWidget', () {
    testWidgets('displays correct stage text for concatenating',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportProgressWidget(
              stage: ExportStage.concatenating,
              progress: 0.5,
            ),
          ),
        ),
      );

      expect(find.text('Combining clips...'), findsOneWidget);
    });

    testWidgets('displays correct stage text for applying text overlay',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportProgressWidget(
              stage: ExportStage.applyingTextOverlay,
              progress: 0.5,
            ),
          ),
        ),
      );

      expect(find.text('Adding text overlay...'), findsOneWidget);
    });

    testWidgets('displays correct stage text for mixing audio',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportProgressWidget(
              stage: ExportStage.mixingAudio,
              progress: 0.5,
            ),
          ),
        ),
      );

      expect(find.text('Adding sound...'), findsOneWidget);
    });

    testWidgets('displays correct stage text for generating thumbnail',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportProgressWidget(
              stage: ExportStage.generatingThumbnail,
              progress: 0.5,
            ),
          ),
        ),
      );

      expect(find.text('Generating thumbnail...'), findsOneWidget);
    });

    testWidgets('displays correct stage text for complete',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportProgressWidget(
              stage: ExportStage.complete,
              progress: 1.0,
            ),
          ),
        ),
      );

      expect(find.text('Export complete!'), findsOneWidget);
    });

    testWidgets('displays correct stage text for error',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportProgressWidget(
              stage: ExportStage.error,
              progress: 0.0,
            ),
          ),
        ),
      );

      expect(find.text('Export failed'), findsOneWidget);
    });

    testWidgets('displays progress percentage', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportProgressWidget(
              stage: ExportStage.concatenating,
              progress: 0.75,
            ),
          ),
        ),
      );

      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('displays progress bar with correct value',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportProgressWidget(
              stage: ExportStage.concatenating,
              progress: 0.75,
            ),
          ),
        ),
      );

      final progressIndicator =
          tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(progressIndicator.value, 0.75);
    });

    testWidgets('shows cancel button when onCancel provided',
        (WidgetTester tester) async {
      bool cancelCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportProgressWidget(
              stage: ExportStage.concatenating,
              progress: 0.5,
              onCancel: () {
                cancelCalled = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(cancelCalled, isTrue);
    });

    testWidgets('hides cancel button when onCancel not provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportProgressWidget(
              stage: ExportStage.concatenating,
              progress: 0.5,
            ),
          ),
        ),
      );

      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('shows checkmark icon when complete',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportProgressWidget(
              stage: ExportStage.complete,
              progress: 1.0,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows export icon when not complete',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportProgressWidget(
              stage: ExportStage.concatenating,
              progress: 0.5,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.movie_creation), findsOneWidget);
    });

    testWidgets('shows error icon when error stage',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportProgressWidget(
              stage: ExportStage.error,
              progress: 0.0,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('uses dark theme colors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportProgressWidget(
              stage: ExportStage.concatenating,
              progress: 0.5,
            ),
          ),
        ),
      );

      // Verify dark background overlay exists
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(ExportProgressWidget),
          matching: find.byType(Container),
        ).first,
      );

      expect(container.color?.a, closeTo(0.9, 0.01));
    });
  });
}
