// ABOUTME: Tests for DraggableTextOverlay widget which renders draggable text on videos
// ABOUTME: Validates positioning, drag behavior, style application, and normalized coordinates

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/text_overlay.dart';
import 'package:openvine/widgets/text_overlay/draggable_text_overlay.dart';

void main() {
  group('DraggableTextOverlay', () {
    testWidgets('displays text with correct style', (tester) async {
      final overlay = TextOverlay(
        id: 'test-id',
        text: 'Hello World',
        fontSize: 32.0,
        color: Colors.yellow,
        normalizedPosition: const Offset(0.5, 0.5),
        fontFamily: 'Roboto',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: DraggableTextOverlay(
                overlay: overlay,
                videoSize: const Size(400, 600),
                onPositionChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Hello World'), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text('Hello World'));
      expect(textWidget.style?.fontSize, 32.0);
      expect(textWidget.style?.color, Colors.yellow);
      expect(textWidget.style?.fontFamily, 'Roboto');
    });

    testWidgets('positions text based on normalized coordinates', (tester) async {
      final overlay = TextOverlay(
        id: 'test-id',
        text: 'Centered',
        fontSize: 24.0,
        color: Colors.white,
        normalizedPosition: const Offset(0.5, 0.5), // Center
        fontFamily: 'Roboto',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: DraggableTextOverlay(
                overlay: overlay,
                videoSize: const Size(400, 600),
                onPositionChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Text should be near center (200, 300)
      final positioned = tester.widget<Positioned>(
        find.ancestor(
          of: find.text('Centered'),
          matching: find.byType(Positioned),
        ),
      );

      // Normalized 0.5, 0.5 on 400x600 should be around (200, 300)
      expect(positioned.left, closeTo(200, 50));
      expect(positioned.top, closeTo(300, 50));
    });

    testWidgets('can be dragged to new position', (tester) async {
      Offset? newPosition;

      final overlay = TextOverlay(
        id: 'test-id',
        text: 'Drag Me',
        fontSize: 24.0,
        color: Colors.white,
        normalizedPosition: const Offset(0.5, 0.5),
        fontFamily: 'Roboto',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: DraggableTextOverlay(
                overlay: overlay,
                videoSize: const Size(400, 600),
                onPositionChanged: (position) {
                  newPosition = position;
                },
              ),
            ),
          ),
        ),
      );

      // Drag the text
      await tester.drag(find.text('Drag Me'), const Offset(50, 100));
      await tester.pumpAndSettle();

      expect(newPosition, isNotNull);
    });

    testWidgets('returns normalized position on drag', (tester) async {
      Offset? normalizedPosition;

      final overlay = TextOverlay(
        id: 'test-id',
        text: 'Drag Test',
        fontSize: 24.0,
        color: Colors.white,
        normalizedPosition: const Offset(0.0, 0.0), // Top left
        fontFamily: 'Roboto',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: DraggableTextOverlay(
                overlay: overlay,
                videoSize: const Size(400, 600),
                onPositionChanged: (position) {
                  normalizedPosition = position;
                },
              ),
            ),
          ),
        ),
      );

      // Drag to approximately center (200, 300 on 400x600 canvas)
      await tester.drag(find.text('Drag Test'), const Offset(200, 300));
      await tester.pumpAndSettle();

      expect(normalizedPosition, isNotNull);
      // Should be close to 0.5, 0.5 after normalizing
      expect(normalizedPosition!.dx, greaterThan(0.3));
      expect(normalizedPosition!.dx, lessThan(0.7));
      expect(normalizedPosition!.dy, greaterThan(0.3));
      expect(normalizedPosition!.dy, lessThan(0.7));
    });

    testWidgets('respects text alignment', (tester) async {
      final overlay = TextOverlay(
        id: 'test-id',
        text: 'Left Aligned',
        fontSize: 24.0,
        color: Colors.white,
        normalizedPosition: const Offset(0.5, 0.5),
        fontFamily: 'Roboto',
        alignment: TextAlign.left,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: DraggableTextOverlay(
                overlay: overlay,
                videoSize: const Size(400, 600),
                onPositionChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('Left Aligned'));
      expect(textWidget.textAlign, TextAlign.left);
    });

    testWidgets('applies text shadow for readability', (tester) async {
      final overlay = TextOverlay(
        id: 'test-id',
        text: 'Shadowed',
        fontSize: 24.0,
        color: Colors.white,
        normalizedPosition: const Offset(0.5, 0.5),
        fontFamily: 'Roboto',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: DraggableTextOverlay(
                overlay: overlay,
                videoSize: const Size(400, 600),
                onPositionChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('Shadowed'));
      expect(textWidget.style?.shadows, isNotNull);
      expect(textWidget.style?.shadows?.isNotEmpty, isTrue);
    });

    testWidgets('clamps normalized position to 0.0-1.0', (tester) async {
      Offset? normalizedPosition;

      final overlay = TextOverlay(
        id: 'test-id',
        text: 'Edge Test',
        fontSize: 24.0,
        color: Colors.white,
        normalizedPosition: const Offset(0.5, 0.5),
        fontFamily: 'Roboto',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: DraggableTextOverlay(
                overlay: overlay,
                videoSize: const Size(400, 600),
                onPositionChanged: (position) {
                  normalizedPosition = position;
                },
              ),
            ),
          ),
        ),
      );

      // Drag far beyond bounds
      await tester.drag(find.text('Edge Test'), const Offset(1000, 1000));
      await tester.pumpAndSettle();

      expect(normalizedPosition, isNotNull);
      expect(normalizedPosition!.dx, lessThanOrEqualTo(1.0));
      expect(normalizedPosition!.dy, lessThanOrEqualTo(1.0));
      expect(normalizedPosition!.dx, greaterThanOrEqualTo(0.0));
      expect(normalizedPosition!.dy, greaterThanOrEqualTo(0.0));
    });

    testWidgets('updates position on multiple drags', (tester) async {
      final positions = <Offset>[];

      final overlay = TextOverlay(
        id: 'test-id',
        text: 'Multi Drag',
        fontSize: 24.0,
        color: Colors.white,
        normalizedPosition: const Offset(0.5, 0.5),
        fontFamily: 'Roboto',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: DraggableTextOverlay(
                overlay: overlay,
                videoSize: const Size(400, 600),
                onPositionChanged: (position) {
                  positions.add(position);
                },
              ),
            ),
          ),
        ),
      );

      // First drag
      await tester.drag(find.text('Multi Drag'), const Offset(50, 50));
      await tester.pumpAndSettle();

      // Second drag
      await tester.drag(find.text('Multi Drag'), const Offset(-30, 20));
      await tester.pumpAndSettle();

      expect(positions.length, greaterThanOrEqualTo(2));
    });

    testWidgets('maintains text visibility during drag', (tester) async {
      final overlay = TextOverlay(
        id: 'test-id',
        text: 'Always Visible',
        fontSize: 24.0,
        color: Colors.white,
        normalizedPosition: const Offset(0.5, 0.5),
        fontFamily: 'Roboto',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: DraggableTextOverlay(
                overlay: overlay,
                videoSize: const Size(400, 600),
                onPositionChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Always Visible'), findsOneWidget);

      await tester.drag(find.text('Always Visible'), const Offset(100, 100));
      await tester.pump();

      expect(find.text('Always Visible'), findsOneWidget);
    });
  });
}
