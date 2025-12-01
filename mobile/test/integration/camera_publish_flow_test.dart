// ABOUTME: Integration test for camera recording and publishing flow
// ABOUTME: Tests the complete flow from recording a video to navigating to profile after publish

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/screens/pure/universal_camera_screen_pure.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Camera Publish Flow Integration Tests', () {
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];

      // Mock native camera channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('openvine/native_camera'),
            (MethodCall methodCall) async {
              methodCalls.add(methodCall);

              switch (methodCall.method) {
                case 'hasPermission':
                  return true;
                case 'initialize':
                  await Future.delayed(const Duration(milliseconds: 100));
                  return true;
                case 'startPreview':
                  await Future.delayed(const Duration(milliseconds: 50));
                  return true;
                case 'stopPreview':
                  return true;
                case 'startRecording':
                  return true;
                case 'stopRecording':
                  // Return a mock file path
                  return '/tmp/openvine_test_recording.mov';
                default:
                  return null;
              }
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('openvine/native_camera'),
            null,
          );
    });

    testWidgets(
      'FAILING TEST: Recording and pressing publish should navigate to metadata screen',
      (WidgetTester tester) async {
        // Skip on non-macOS for now
        if (kIsWeb || !Platform.isMacOS) {
          return;
        }

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: UniversalCameraScreenPure()),
          ),
        );

        // Wait for initialization
        await tester.pump(const Duration(milliseconds: 200));

        // On macOS, we need to start AND stop recording to create a segment
        // Find the record button (large circular button)
        final recordButtonFinder = find.byType(GestureDetector);
        expect(recordButtonFinder, findsWidgets);

        // For macOS/web: tap to start recording
        if (!kIsWeb && !Platform.isMacOS) {
          // Mobile: press and hold
          await tester.press(
            recordButtonFinder.at(1),
          ); // The main record button
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();
        } else {
          // macOS/web: tap to toggle
          await tester.tap(recordButtonFinder.at(1));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          // Tap again to stop
          await tester.tap(recordButtonFinder.at(1));
          await tester.pump();
        }

        // After stopping, should have segments and show publish button
        await tester.pumpAndSettle();

        // Find and verify publish button (check icon) appears
        final publishButton = find.byIcon(Icons.check_circle);
        expect(
          publishButton,
          findsOneWidget,
          reason:
              'Publish button should appear after recording stops and creates segment',
        );

        // Tap publish button
        await tester.tap(publishButton);
        await tester.pump();

        // Wait for processing to start
        await tester.pump(const Duration(milliseconds: 100));

        // Should show "Processing video..." overlay
        expect(
          find.text('Processing video...'),
          findsOneWidget,
          reason: 'Processing overlay should appear',
        );

        // Wait for navigation to metadata screen
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Should navigate to VideoMetadataScreenPure
        // This WILL FAIL if processing hangs
        expect(
          find.text('Add Metadata'),
          findsOneWidget,
          reason: 'Should navigate to metadata screen after processing',
        );
      },
    );

    testWidgets(
      'FAILING TEST: Publishing video should eventually navigate to profile',
      (WidgetTester tester) async {
        if (kIsWeb || !Platform.isMacOS) {
          return;
        }

        // Create a mock navigation key for testing
        final testNavigationKey = GlobalKey<NavigatorState>();

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              navigatorKey: testNavigationKey,
              home: const UniversalCameraScreenPure(),
            ),
          ),
        );

        // Wait for initialization
        await tester.pump(const Duration(milliseconds: 200));

        // Start recording
        final recordButton = find.byType(GestureDetector).first;
        await tester.tap(recordButton);
        await tester.pump(const Duration(milliseconds: 500));

        // Tap publish
        final publishButton = find.byIcon(Icons.check_circle);
        await tester.tap(publishButton);
        await tester.pump();

        // Wait for processing and navigation to metadata screen
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Should be on metadata screen now
        expect(find.text('Add Metadata'), findsOneWidget);

        // Simulate publishing from metadata screen
        final publishMetadataButton = find.text('Publish');
        await tester.tap(publishMetadataButton);
        await tester.pump();

        // Wait for publish to complete (simulated 2 second delay)
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        // This WILL FAIL if navigation to profile doesn't work correctly
        // We should be back at a main screen, not stuck on camera or metadata
        expect(
          find.text('Add Metadata'),
          findsNothing,
          reason: 'Should have left metadata screen',
        );
        expect(
          find.byType(UniversalCameraScreenPure),
          findsNothing,
          reason: 'Should have left camera screen',
        );
      },
    );

    testWidgets(
      'FAILING TEST: _isProcessing flag should prevent double-processing',
      (WidgetTester tester) async {
        if (kIsWeb || !Platform.isMacOS) {
          return;
        }

        int processCallCount = 0;

        // Mock that tracks how many times stopRecording is called
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('openvine/native_camera'),
              (MethodCall methodCall) async {
                methodCalls.add(methodCall);

                switch (methodCall.method) {
                  case 'hasPermission':
                    return true;
                  case 'initialize':
                    await Future.delayed(const Duration(milliseconds: 100));
                    return true;
                  case 'startPreview':
                    await Future.delayed(const Duration(milliseconds: 50));
                    return true;
                  case 'stopPreview':
                    return true;
                  case 'startRecording':
                    return true;
                  case 'stopRecording':
                    processCallCount++;
                    return '/tmp/openvine_test_recording.mov';
                  default:
                    return null;
                }
              },
            );

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: UniversalCameraScreenPure()),
          ),
        );

        await tester.pump(const Duration(milliseconds: 200));

        // Start recording
        final recordButton = find.byType(GestureDetector).first;
        await tester.tap(recordButton);
        await tester.pump(const Duration(milliseconds: 500));

        // Tap publish multiple times rapidly
        final publishButton = find.byIcon(Icons.check_circle);
        await tester.tap(publishButton);
        await tester.tap(publishButton);
        await tester.tap(publishButton);
        await tester.pump();

        // Wait a bit
        await tester.pump(const Duration(milliseconds: 500));

        // Should only process once despite multiple taps
        expect(
          processCallCount,
          equals(1),
          reason:
              '_isProcessing flag should prevent multiple simultaneous processing calls',
        );
      },
    );
  });
}
