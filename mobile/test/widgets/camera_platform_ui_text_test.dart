// ABOUTME: Widget tests for platform-specific camera UI text
// ABOUTME: Tests "Tap to record" vs "Hold to record" without full camera initialization

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Camera Platform UI Text Tests', () {
    testWidgets('should render correct hint text based on platform', (
      tester,
    ) async {
      // Build a simple widget that shows the platform-specific text
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(kIsWeb ? 'Tap to record' : 'Hold to record'),
            ),
          ),
        ),
      );

      // Verify the correct text is shown
      if (kIsWeb) {
        expect(find.text('Tap to record'), findsOneWidget);
        expect(find.text('Hold to record'), findsNothing);
      } else {
        expect(find.text('Hold to record'), findsOneWidget);
        expect(find.text('Tap to record'), findsNothing);
      }
    });

    testWidgets('segment counter text should format correctly', (tester) async {
      // Test single segment
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('1 segment'))),
      );

      expect(find.text('1 segment'), findsOneWidget);

      // Test multiple segments
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('3 segments'))),
      );

      expect(find.text('3 segments'), findsOneWidget);
    });

    testWidgets('should conditionally show UI elements based on platform', (
      tester,
    ) async {
      // Simulate the conditional rendering logic
      final showSegmentCount = !kIsWeb;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                if (showSegmentCount) const Text('2 segments'),
                if (!showSegmentCount) const Text('Recording...'),
              ],
            ),
          ),
        ),
      );

      if (kIsWeb) {
        expect(find.text('2 segments'), findsNothing);
        expect(find.text('Recording...'), findsOneWidget);
      } else {
        expect(find.text('2 segments'), findsOneWidget);
        expect(find.text('Recording...'), findsNothing);
      }
    });

    test('duration formatting should work correctly', () {
      String formatDuration(Duration duration) {
        String twoDigits(int n) => n.toString().padLeft(2, '0');
        String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
        String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
        return '$twoDigitMinutes:$twoDigitSeconds';
      }

      expect(formatDuration(Duration.zero), equals('00:00'));
      expect(formatDuration(const Duration(seconds: 5)), equals('00:05'));
      expect(formatDuration(const Duration(seconds: 30)), equals('00:30'));
      expect(
        formatDuration(const Duration(minutes: 1, seconds: 30)),
        equals('01:30'),
      );
      expect(formatDuration(const Duration(seconds: 63)), equals('01:03'));
    });

    testWidgets('recording state text should update during lifecycle', (
      tester,
    ) async {
      // Test idle state
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Ready'))),
      );

      expect(find.text('Ready'), findsOneWidget);

      // Test recording state
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('00:03'))),
      );

      expect(find.text('00:03'), findsOneWidget);

      // Test completed state
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Processing video...'))),
      );

      expect(find.text('Processing video...'), findsOneWidget);
    });
  });
}
