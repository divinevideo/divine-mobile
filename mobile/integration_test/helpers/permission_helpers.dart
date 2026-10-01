// ABOUTME: Answers Android's runtime permission dialogs for Patrol suites:
// ABOUTME: camera and microphone, and the post-sign-in notifications prompt.

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

Future<void> _acceptPermissionDialogIfShown(
  PatrolIntegrationTester $, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  if (await $.platformAutomator.mobile.isPermissionDialogVisible(
    timeout: timeout,
  )) {
    await $.platformAutomator.mobile.grantPermissionWhenInUse();
  }
}

/// Accepts Android's notification permission dialog if it is showing.
///
/// After authentication the app requests POST_NOTIFICATIONS. The system
/// dialog sits in front of the app and blocks Flutter widget interaction
/// until it is answered. It is matched by its button id rather than by the
/// text "Allow", which its title ("Allow `<app>` to send you notifications?")
/// also contains.
Future<void> dismissNotificationPermission(PatrolIntegrationTester $) =>
    _acceptPermissionDialogIfShown($, timeout: const Duration(seconds: 3));
