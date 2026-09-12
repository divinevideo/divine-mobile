// ABOUTME: Tests camera permission denial flow using Patrol native automation
// ABOUTME: Verifies fallback UI renders when user denies camera permission

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:patrol/patrol.dart';
import 'package:permissions_service/permissions_service.dart';

import '../helpers/patrol_semantics.dart';

void main() {
  ignorePlatformSemanticsHandle();

  group('Camera Permission Denied', () {
    patrolTest(
      'shows fallback UI when camera permission is denied',
      ($) async {
        final tester = $.tester;

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider(
              create: (_) => CameraPermissionBloc(
                permissionsService: const PermissionHandlerPermissionsService(),
              )..add(const CameraPermissionRefresh()),
              child: const VideoRecorderScreen(),
            ),
          ),
        );

        // Wait for the permission dialog to appear
        if (await $.platformAutomator.mobile.isPermissionDialogVisible(
          timeout: const Duration(seconds: 5),
        )) {
          // Deny the permission
          await $.platformAutomator.mobile.denyPermission();
        }

        // Pump to let BLoC react to denial
        await tester.pump(const Duration(seconds: 2));

        // Verify fallback UI is shown (permission denied state)
        // The CameraPermissionBloc should emit denied state,
        // which renders a "Camera access required" or similar message
        final hasPermissionMessage =
            find.textContaining('camera').evaluate().isNotEmpty ||
            find.textContaining('Camera').evaluate().isNotEmpty ||
            find.textContaining('permission').evaluate().isNotEmpty;

        expect(
          hasPermissionMessage,
          isTrue,
          reason:
              'Should show camera permission message when permission denied',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
