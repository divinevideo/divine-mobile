// ABOUTME: Widget tests for camera preview initialization and rendering
// ABOUTME: Tests the race condition between camera initialization and preview widget access

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/screens/pure/universal_camera_screen_pure.dart';
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/widgets/macos_camera_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Camera Preview Widget Tests', () {
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
                  // Simulate native initialization delay
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
                  return '/tmp/test_video.mov';
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
      'FAILING TEST: Camera preview widget should handle initialization race condition',
      (WidgetTester tester) async {
        // This test currently FAILS with LateInitializationError
        // because previewWidget is accessed before _previewWidget is initialized

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: UniversalCameraScreenPure()),
          ),
        );

        // Allow first frame to build
        await tester.pump();

        // The screen should attempt to show preview
        // This WILL throw LateInitializationError if bug exists
        expect(find.byType(UniversalCameraScreenPure), findsOneWidget);

        // Wait for initialization to complete
        await tester.pump(const Duration(milliseconds: 200));

        // Should now show preview without error
        expect(
          tester.takeException(),
          isNull,
          reason: 'Preview widget should not throw during initialization',
        );
      },
    );

    testWidgets(
      'FAILING TEST: Camera preview should be accessible immediately after isInitialized=true',
      (WidgetTester tester) async {
        // This test verifies that when isInitialized becomes true,
        // the preview widget is ALREADY available

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  return Consumer(
                    builder: (context, ref, child) {
                      final recordingNotifier = ref.read(
                        vineRecordingProvider.notifier,
                      );
                      final recordingState = ref.watch(vineRecordingProvider);

                      return Column(
                        children: [
                          Text('Initialized: ${recordingState.isInitialized}'),
                          if (recordingState.isInitialized)
                            // This WILL crash if previewWidget not ready
                            SizedBox(
                              width: 400,
                              height: 300,
                              child: recordingNotifier.previewWidget,
                            ),
                          ElevatedButton(
                            onPressed: () async {
                              await recordingNotifier.initialize();
                            },
                            child: const Text('Initialize'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );

        await tester.pump();

        // Tap initialize button
        await tester.tap(find.text('Initialize'));
        await tester.pump();

        // Wait for native initialization
        await tester.pump(const Duration(milliseconds: 200));

        // Should show initialized without crash
        expect(find.text('Initialized: true'), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'Should not crash when accessing preview after init',
        );
      },
    );

    testWidgets(
      'FAILING TEST: Camera preview should show placeholder before initialization completes',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: UniversalCameraScreenPure()),
          ),
        );

        // First frame - should show placeholder
        await tester.pump();

        // Should find placeholder (before initialization)
        expect(find.byType(CameraPreviewPlaceholder), findsOneWidget);

        // No exceptions should occur
        expect(tester.takeException(), isNull);

        // Wait for initialization
        await tester.pump(const Duration(milliseconds: 200));

        // After init, should either show preview or still have placeholder
        // but MUST NOT crash
        expect(
          tester.takeException(),
          isNull,
          reason: 'No crash during transition from placeholder to preview',
        );
      },
    );

    testWidgets(
      'FAILING TEST: macOS camera preview texture should be created',
      (WidgetTester tester) async {
        // Skip on non-macOS
        if (!Platform.isMacOS) {
          return;
        }

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: UniversalCameraScreenPure()),
          ),
        );

        await tester.pump();

        // Wait for full initialization
        await tester.pump(const Duration(milliseconds: 300));

        // Should have created texture widget for macOS
        // This test will fail if preview widget is not properly initialized
        expect(tester.takeException(), isNull);

        // Verify camera was initialized
        expect(
          methodCalls.where((call) => call.method == 'initialize').length,
          greaterThan(0),
        );
      },
    );
  });
}
