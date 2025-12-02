// ABOUTME: Test to reproduce and fix camera initialization hang on iOS
// ABOUTME: Verifies camera initializes quickly without hanging in postFrameCallback

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/pure/universal_camera_screen_pure.dart';
import 'package:openvine/providers/vine_recording_provider.dart';

void main() {
  testWidgets(
    'Camera initialization should complete within 2 seconds without hanging',
    (WidgetTester tester) async {
      // This test reproduces the bug where camera initialization hangs indefinitely
      // due to unsafe Riverpod provider access inside postFrameCallback

      // Set a reasonable timeout - camera should initialize in < 2 seconds
      const initializationTimeout = Duration(seconds: 2);

      // Create a provider container to track state
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Build the camera screen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: UniversalCameraScreenPure()),
        ),
      );

      // Initial frame - should show loading state
      await tester.pump();

      // Wait for initialization to complete
      // This will fail if initialization hangs (which is the bug we're fixing)
      await tester.pumpAndSettle(initializationTimeout);

      // After initialization completes, we should see either:
      // 1. Camera preview (if permissions granted)
      // 2. Permission screen (if permissions not granted)
      // 3. Error screen (if camera hardware fails)
      //
      // We should NOT see the indefinite loading spinner

      final recordingState = container.read(vineRecordingProvider);

      // The bug causes isInitialized to stay false forever
      // After fix, it should be true (showing camera or permission screen)
      // OR it should show an error state
      expect(
        recordingState.isInitialized || recordingState.isError,
        isTrue,
        reason:
            'Camera should initialize or show error within $initializationTimeout, '
            'but initialization appears to be hanging. '
            'Current state: ${recordingState.recordingState}',
      );

      // Verify we're not stuck in the loading state
      expect(
        recordingState.recordingState.name,
        isNot(equals('processing')),
        reason:
            'Should not be stuck in processing state after initialization timeout',
      );
    },
  );

  testWidgets('Camera screen should not block UI while initializing', (
    WidgetTester tester,
  ) async {
    // Verify that even if camera takes time to initialize,
    // the UI remains responsive (can navigate back)

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(home: UniversalCameraScreenPure())),
    );

    await tester.pump();

    // Try to tap the back button while initializing
    final backButton = find.byKey(const Key('back-button'));
    expect(backButton, findsOneWidget);

    // This tap should work even if camera hasn't initialized yet
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    // Should have navigated back (camera screen disposed)
    expect(find.byType(UniversalCameraScreenPure), findsNothing);
  });
}
