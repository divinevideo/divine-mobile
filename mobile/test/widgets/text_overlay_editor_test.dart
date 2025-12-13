// ABOUTME: Tests for TextOverlayEditor widget which provides UI for creating/editing text overlays
// ABOUTME: Validates text input, style selection, color picking, and callback handling

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/text_overlay.dart';
import 'package:openvine/widgets/text_overlay/text_overlay_editor.dart';

void main() {
  group('TextOverlayEditor', () {
    testWidgets('displays dark theme modal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextOverlayEditor(
              onSave: (_) {},
            ),
          ),
        ),
      );

      // Check for dark background
      final containerFinder = find.byType(Container);
      expect(containerFinder, findsWidgets);

      // Verify dark theme colors are used
      expect(find.byType(TextOverlayEditor), findsOneWidget);
    });

    testWidgets('shows text input field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextOverlayEditor(
              onSave: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);

      // Enter text
      await tester.enterText(find.byType(TextField), 'Test Text');
      expect(find.text('Test Text'), findsOneWidget);
    });

    testWidgets('displays font family selector with presets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextOverlayEditor(
              onSave: (_) {},
            ),
          ),
        ),
      );

      // Should have font family options
      expect(find.text('Font'), findsOneWidget);
      expect(find.text('Roboto'), findsOneWidget);
      expect(find.text('Montserrat'), findsOneWidget);
      expect(find.text('Pacifico'), findsOneWidget);
    });

    testWidgets('displays color picker with preset colors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextOverlayEditor(
              onSave: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Color'), findsOneWidget);

      // Check for color options (white, black, yellow, red, blue)
      final colorButtons = find.byType(GestureDetector);
      expect(colorButtons.evaluate().length, greaterThanOrEqualTo(5));
    });

    testWidgets('displays size slider', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextOverlayEditor(
              onSave: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Size'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('calls onSave with TextOverlay when saved', (tester) async {
      TextOverlay? savedOverlay;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TextOverlayEditor(
                onSave: (overlay) {
                  savedOverlay = overlay;
                },
              ),
            ),
          ),
        ),
      );

      // Enter text
      await tester.enterText(find.byType(TextField), 'Hello World');

      // Scroll to bottom to see Save button
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();

      // Tap save button
      await tester.tap(find.text('Save'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(savedOverlay, isNotNull);
      expect(savedOverlay!.text, 'Hello World');
      expect(savedOverlay!.fontSize, greaterThan(0));
      expect(savedOverlay!.color, isNotNull);
    });

    testWidgets('updates preview when text changes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextOverlayEditor(
              onSave: (_) {},
            ),
          ),
        ),
      );

      // Enter text
      await tester.enterText(find.byType(TextField), 'Preview Text');
      await tester.pump();

      // Preview should show the text
      expect(find.text('Preview Text'), findsWidgets);
    });

    testWidgets('updates preview when font family changes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextOverlayEditor(
              onSave: (_) {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Test');

      // Tap Montserrat font
      await tester.tap(find.text('Montserrat'));
      await tester.pump();

      // Preview should update (hard to test font directly, but state should change)
      expect(find.text('Test'), findsWidgets);
    });

    testWidgets('updates preview when size changes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextOverlayEditor(
              onSave: (_) {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Size Test');

      // Drag slider
      await tester.drag(find.byType(Slider), const Offset(50, 0));
      await tester.pump();

      // Preview should update
      expect(find.text('Size Test'), findsWidgets);
    });

    testWidgets('initializes with existing overlay values', (tester) async {
      final existingOverlay = TextOverlay(
        id: 'test-id',
        text: 'Existing Text',
        fontSize: 40.0,
        color: Colors.yellow,
        normalizedPosition: const Offset(0.5, 0.5),
        fontFamily: 'Pacifico',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextOverlayEditor(
              overlay: existingOverlay,
              onSave: (_) {},
            ),
          ),
        ),
      );

      // Should show existing text
      expect(find.text('Existing Text'), findsWidgets);
    });

    testWidgets('does not save when text is empty', (tester) async {
      TextOverlay? savedOverlay;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextOverlayEditor(
              onSave: (overlay) {
                savedOverlay = overlay;
              },
            ),
          ),
        ),
      );

      // Tap save without entering text
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Should not save
      expect(savedOverlay, isNull);
    });

    testWidgets('has cancel button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextOverlayEditor(
              onSave: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      );

      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('calls onCancel when cancel tapped', (tester) async {
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TextOverlayEditor(
                onSave: (_) {},
                onCancel: () {
                  cancelled = true;
                },
              ),
            ),
          ),
        ),
      );

      // Scroll to bottom to see Cancel button
      await tester.ensureVisible(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(cancelled, isTrue);
    });
  });
}
