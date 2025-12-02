// ABOUTME: Integration test for camera preview initialization race condition
// ABOUTME: Tests the complete flow from screen load to recording, catching preview widget crashes

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/screens/pure/universal_camera_screen_pure.dart';
import 'package:openvine/providers/vine_recording_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Camera Preview Initialization Integration Tests', () {
    testWidgets(
      'FAILING TEST: Opening camera screen should not crash on preview access',
      (WidgetTester tester) async {
        // This test reproduces the exact crash from the logs:
        // LateInitializationError: Field '_previewWidget@1465126971' has not been initialized

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: UniversalCameraScreenPure()),
          ),
        );

        // Pump once to build widget tree
        await tester.pump();

        // At this point, the screen tries to access previewWidget
        // This WILL throw LateInitializationError if bug exists
        expect(
          tester.takeException(),
          isNull,
          reason:
              'Should not crash when accessing preview widget during initialization',
        );

        // Wait for initialization to complete
        await tester.pump(const Duration(seconds: 1));

        // Verify no exceptions occurred during initialization
        expect(tester.takeException(), isNull);

        // Verify screen is visible
        expect(find.byType(UniversalCameraScreenPure), findsOneWidget);
      },
    );

    testWidgets(
      'FAILING TEST: Complete recording flow should not crash at any point',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: UniversalCameraScreenPure()),
          ),
        );

        // Initial render
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Initial render should not crash',
        );

        // Wait for camera initialization
        await tester.pump(const Duration(seconds: 1));
        expect(
          tester.takeException(),
          isNull,
          reason: 'Camera initialization should not crash',
        );

        // Find and tap record button (if visible)
        final recordButton = find.byIcon(Icons.circle);
        if (recordButton.evaluate().isNotEmpty) {
          await tester.tap(recordButton);
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Starting recording should not crash',
          );

          // Record for a few seconds
          await tester.pump(const Duration(seconds: 2));
          expect(
            tester.takeException(),
            isNull,
            reason: 'During recording should not crash',
          );

          // Stop recording
          await tester.tap(recordButton);
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Stopping recording should not crash',
          );

          // Wait for processing
          await tester.pump(const Duration(seconds: 1));
          expect(
            tester.takeException(),
            isNull,
            reason: 'Processing recording should not crash',
          );
        }
      },
    );

    testWidgets(
      'FAILING TEST: Rapid screen transitions should not cause preview widget crash',
      (WidgetTester tester) async {
        // Test the scenario: navigate to camera → navigate away quickly
        // This often triggers initialization race conditions

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              routes: {
                '/': (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const UniversalCameraScreenPure(),
                        ),
                      );
                    },
                    child: const Text('Open Camera'),
                  ),
                ),
              },
            ),
          ),
        );

        await tester.pump();

        // Navigate to camera
        await tester.tap(find.text('Open Camera'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Navigate back immediately (during initialization)
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pump();

        // Should not crash during cleanup
        expect(
          tester.takeException(),
          isNull,
          reason:
              'Rapid navigation should not cause preview widget initialization crash',
        );

        // Navigate to camera again
        await tester.tap(find.text('Open Camera'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Wait for full initialization
        await tester.pump(const Duration(seconds: 1));

        // Should be stable now
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'FAILING TEST: Preview widget should be available when isInitialized becomes true',
      (WidgetTester tester) async {
        // This test ensures atomicity: when isInitialized=true, preview MUST be ready

        late WidgetRef testRef;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, child) {
                  testRef = ref;
                  final state = ref.watch(vineRecordingProvider);

                  return Scaffold(
                    body: Column(
                      children: [
                        Text('Init: ${state.isInitialized}'),
                        if (state.isInitialized)
                          // Access preview immediately when initialized
                          Expanded(
                            child: ref
                                .read(vineRecordingProvider.notifier)
                                .previewWidget,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );

        await tester.pump();

        // Initialize camera
        await testRef.read(vineRecordingProvider.notifier).initialize();
        await tester.pump();

        // Wait for initialization
        await tester.pump(const Duration(milliseconds: 500));

        // When isInitialized is true, accessing previewWidget MUST NOT crash
        final state = testRef.read(vineRecordingProvider);
        if (state.isInitialized) {
          expect(
            tester.takeException(),
            isNull,
            reason:
                'Preview widget must be available immediately when isInitialized=true',
          );
        }
      },
    );
  });
}
