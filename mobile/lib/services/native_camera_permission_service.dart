import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum NativeCameraPermissionStatus {
  granted,
  denied,
  requiresSettings,
  promptBlocked,
  unavailable,
}

enum NativeCameraAuthorizationStatus {
  authorized,
  notDetermined,
  denied,
  restricted,
  unavailable,
}

abstract class NativeCameraPermissionService {
  Future<bool> hasPermission();

  Future<NativeCameraAuthorizationStatus> authorizationStatus();

  Future<NativeCameraAuthorizationStatus> microphoneAuthorizationStatus();

  Future<NativeCameraPermissionStatus> requestPermission();

  Future<NativeCameraPermissionStatus> requestMicrophonePermission();

  Future<bool> openSystemSettings();
}

class MethodChannelNativeCameraPermissionService
    implements NativeCameraPermissionService {
  const MethodChannelNativeCameraPermissionService();

  @visibleForTesting
  static const MethodChannel channel = MethodChannel('openvine/native_camera');

  @override
  Future<bool> hasPermission() async {
    return await authorizationStatus() ==
        NativeCameraAuthorizationStatus.authorized;
  }

  @override
  Future<NativeCameraAuthorizationStatus> authorizationStatus() async {
    final status = await channel.invokeMethod<String>('cameraPermissionStatus');
    return switch (status) {
      'authorized' => NativeCameraAuthorizationStatus.authorized,
      'notDetermined' => NativeCameraAuthorizationStatus.notDetermined,
      'denied' => NativeCameraAuthorizationStatus.denied,
      'restricted' => NativeCameraAuthorizationStatus.restricted,
      _ => NativeCameraAuthorizationStatus.unavailable,
    };
  }

  @override
  Future<NativeCameraAuthorizationStatus>
  microphoneAuthorizationStatus() async {
    final status = await channel.invokeMethod<String>(
      'microphonePermissionStatus',
    );
    return switch (status) {
      'authorized' => NativeCameraAuthorizationStatus.authorized,
      'notDetermined' => NativeCameraAuthorizationStatus.notDetermined,
      'denied' => NativeCameraAuthorizationStatus.denied,
      'restricted' => NativeCameraAuthorizationStatus.restricted,
      _ => NativeCameraAuthorizationStatus.unavailable,
    };
  }

  @override
  Future<NativeCameraPermissionStatus> requestPermission() =>
      _request('requestCameraPermission');

  @override
  Future<NativeCameraPermissionStatus> requestMicrophonePermission() =>
      _request('requestMicrophonePermission');

  Future<NativeCameraPermissionStatus> _request(String method) async {
    try {
      final status = await channel.invokeMethod<String>(method);
      return switch (status) {
        'authorized' => NativeCameraPermissionStatus.granted,
        'denied' ||
        'restricted' => NativeCameraPermissionStatus.requiresSettings,
        'notDetermined' => NativeCameraPermissionStatus.promptBlocked,
        _ => NativeCameraPermissionStatus.unavailable,
      };
    } on PlatformException catch (error) {
      if (error.code == 'PERMISSION_DENIED') {
        return NativeCameraPermissionStatus.requiresSettings;
      }
      return NativeCameraPermissionStatus.unavailable;
    }
  }

  @override
  Future<bool> openSystemSettings() async {
    final opened = await channel.invokeMethod<bool>('openSystemSettings');
    return opened ?? false;
  }
}
