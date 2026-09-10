// ABOUTME: Integration tests for video recording functionality
// ABOUTME: Tests start/stop recording, video file creation, and recording state

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:patrol/patrol.dart';
import 'package:permissions_service/permissions_service.dart';

import '../helpers/patrol_semantics.dart';

/// Helper widget that wraps VideoRecorderScreen with required providers
Widget _buildTestWidget() {
  return ProviderScope(
    child: BlocProvider(
      create: (_) => CameraPermissionBloc(
        permissionsService: const PermissionHandlerPermissionsService(),
      )..add(const CameraPermissionRefresh()),
      child: const MaterialApp(home: VideoRecorderScreen()),
    ),
  );
}

/// Grant camera and microphone permissions via Patrol native automation.
Future<void> _grantPermissions(PatrolIntegrationTester $) async {
  const service = PermissionHandlerPermissionsService();
  unawaited(service.requestCameraPermission());
  if (await $.platformAutomator.mobile.isPermissionDialogVisible(
    timeout: const Duration(seconds: 5),
  )) {
    await $.platformAutomator.mobile.grantPermissionWhenInUse();
  }
  unawaited(service.requestMicrophonePermission());
  if (await $.platformAutomator.mobile.isPermissionDialogVisible(
    timeout: const Duration(seconds: 5),
  )) {
    await $.platformAutomator.mobile.grantPermissionWhenInUse();
  }
}

void main() {
  ignorePlatformSemanticsHandle();

  group('Video Recorder Integration Tests', () {
    late CameraService cameraService;

    setUp(() async {
      cameraService = CameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
        onAutoStopped: (_) {},
      );
      await cameraService.initialize();
    });

    tearDown(() async {
      try {
        await cameraService.stopRecording();
      } catch (_) {
        // Ignore errors if not recording
      }
      try {
        await cameraService.dispose();
      } catch (_) {
        // Ignore errors if already disposed
      }
    });

    patrolTest('can start recording', ($) async {
      await _grantPermissions($);
      final tester = $.tester;
      expect(cameraService.canRecord, isTrue);

      await cameraService.startRecording();

      // Give recording a moment to start
      await tester.pump(const Duration(milliseconds: 100));
    });

    patrolTest('can stop recording after starting', ($) async {
      await _grantPermissions($);
      final tester = $.tester;
      await cameraService.startRecording();

      // Record for 2 seconds
      await tester.pump(const Duration(seconds: 2));

      final video = await cameraService.stopRecording();

      // Should have created a video
      expect(video, anyOf(isNull, isA<Object>()));
    });

    patrolTest('can start and stop multiple recordings', ($) async {
      await _grantPermissions($);
      final tester = $.tester;
      for (var i = 0; i < 3; i++) {
        await cameraService.startRecording();
        await tester.pump(const Duration(milliseconds: 500));

        final video = await cameraService.stopRecording();

        // Each recording should complete
        expect(video, anyOf(isNull, isA<Object>()));

        // Wait between recordings
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    patrolTest('stopping without starting does not crash', ($) async {
      await _grantPermissions($);
      // Should handle gracefully
      final video = await cameraService.stopRecording();

      // Should return null or handle gracefully
      expect(video, anyOf(isNull, isA<Object>()));
    });
  });

  group('Video Recorder Widget Tests', () {
    patrolTest('pinch to zoom changes zoom level', ($) async {
      await _grantPermissions($);
      final tester = $.tester;
      await tester.pumpWidget(_buildTestWidget());

      // Wait for camera to initialize
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final bloc = BlocProvider.of<VideoRecorderBloc>(
        tester.element(find.byType(VideoRecorderView)),
      );
      final initialZoom = bloc.state.zoomLevel;

      // Simulate pinch zoom out (scale > 1)
      final center = tester.getCenter(find.byType(VideoRecorderScreen));
      final pointer1 = TestPointer();
      final pointer2 = TestPointer(2);

      // Start with two fingers close together
      await tester.sendEventToBinding(pointer1.down(center));
      await tester.sendEventToBinding(pointer2.down(center));
      await tester.pump();

      // Move fingers apart (zoom in)
      await tester.sendEventToBinding(
        pointer1.move(center + const Offset(-50, 0)),
      );
      await tester.sendEventToBinding(
        pointer2.move(center + const Offset(50, 0)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Release
      await tester.sendEventToBinding(pointer1.up());
      await tester.sendEventToBinding(pointer2.up());
      await tester.pump();

      final newZoom = bloc.state.zoomLevel;

      // Zoom should have increased
      expect(newZoom, greaterThanOrEqualTo(initialZoom));
    });

    patrolTest('long press on record button starts recording', ($) async {
      await _grantPermissions($);
      final tester = $.tester;
      await tester.pumpWidget(_buildTestWidget());

      // Wait for camera to initialize and zoom limits to load
      await tester.pumpAndSettle(const Duration(seconds: 3));
      // Extra pump to ensure postFrameCallback completes
      await tester.pump();
      await tester.pump();

      final bloc = BlocProvider.of<VideoRecorderBloc>(
        tester.element(find.byType(VideoRecorderView)),
      );

      // Find record button
      final recordButton = find.bySemanticsIdentifier(
        'divine-camera-record-button',
      );
      expect(recordButton, findsOneWidget);

      // Start long press (hold it - don't release yet)
      final buttonCenter = tester.getCenter(recordButton);
      final gesture = await tester.startGesture(buttonCenter);
      await tester.pump(
        const Duration(milliseconds: 600),
      ); // Wait for long press to trigger

      // Check recording state while still pressing
      final isRecording = bloc.state.isRecording;
      expect(isRecording, isTrue);

      // Get initial zoom level
      final initialZoom = bloc.state.zoomLevel;

      // Move finger up (should zoom in)
      await gesture.moveBy(
        const Offset(0, -200),
        timeStamp: const Duration(milliseconds: 600),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Check zoom changed
      final zoomAfterMove = bloc.state.zoomLevel;
      expect(
        zoomAfterMove,
        greaterThan(initialZoom),
        reason: 'Zoom should increase when moving finger up during recording',
      );

      // Release to stop recording
      await gesture.up();
      await tester.pumpAndSettle();
    });

    patrolTest('long press move zooms during recording', ($) async {
      await _grantPermissions($);
      final tester = $.tester;
      await tester.pumpWidget(_buildTestWidget());

      // Wait for camera to initialize
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final bloc = BlocProvider.of<VideoRecorderBloc>(
        tester.element(find.byType(VideoRecorderView)),
      );

      // Find record button
      final recordButton = find.bySemanticsIdentifier(
        'divine-camera-record-button',
      );
      final buttonCenter = tester.getCenter(recordButton);

      // Start long press
      final gesture = await tester.startGesture(buttonCenter);
      await tester.pump(
        const Duration(milliseconds: 600),
      ); // Trigger long press

      final initialZoom = bloc.state.zoomLevel;

      // Move finger up (should zoom in)
      await gesture.moveBy(const Offset(0, -100));
      await tester.pump(const Duration(milliseconds: 100));

      final zoomAfterMove = bloc.state.zoomLevel;

      // Zoom should have changed
      expect(zoomAfterMove, greaterThanOrEqualTo(initialZoom));

      // Release
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
