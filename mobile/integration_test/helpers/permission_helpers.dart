// ABOUTME: Grants camera and microphone access through the system dialogs,
// ABOUTME: for Patrol suites that record on a fresh install.

import 'dart:async';

import 'package:patrol/patrol.dart';
import 'package:permissions_service/permissions_service.dart';

/// Requests camera and microphone access and accepts each system dialog.
///
/// A fresh install has neither permission, and the recorder refuses to
/// start without the microphone. Each request is left unawaited because it
/// only completes once its dialog is answered.
Future<void> grantCameraAndMicrophone(PatrolIntegrationTester $) async {
  const service = PermissionHandlerPermissionsService();
  unawaited(service.requestCameraPermission());
  await _acceptPermissionDialogIfShown($);
  unawaited(service.requestMicrophonePermission());
  await _acceptPermissionDialogIfShown($);
}

Future<void> _acceptPermissionDialogIfShown(PatrolIntegrationTester $) async {
  if (await $.platformAutomator.mobile.isPermissionDialogVisible(
    timeout: const Duration(seconds: 5),
  )) {
    await $.platformAutomator.mobile.grantPermissionWhenInUse();
  }
}
