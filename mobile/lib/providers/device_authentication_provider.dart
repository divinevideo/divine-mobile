// ABOUTME: Provides fail-closed device-local authentication for sensitive app actions
// ABOUTME: Wraps local_auth behind an injectable result-based interface

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:unified_logger/unified_logger.dart';

enum DeviceAuthenticationResult { authenticated, denied, unavailable }

abstract interface class DeviceAuthentication {
  Future<DeviceAuthenticationResult> authenticate({required String reason});
}

class LocalDeviceAuthentication implements DeviceAuthentication {
  LocalDeviceAuthentication({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  @override
  Future<DeviceAuthenticationResult> authenticate({
    required String reason,
  }) async {
    try {
      if (!await _localAuthentication.isDeviceSupported()) {
        return DeviceAuthenticationResult.unavailable;
      }

      final authenticated = await _localAuthentication.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
      return authenticated
          ? DeviceAuthenticationResult.authenticated
          : DeviceAuthenticationResult.denied;
    } on LocalAuthException catch (error, stackTrace) {
      final result = switch (error.code) {
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout ||
        LocalAuthExceptionCode.authInProgress ||
        LocalAuthExceptionCode.uiUnavailable ||
        LocalAuthExceptionCode.deviceError ||
        LocalAuthExceptionCode.unknownError =>
          DeviceAuthenticationResult.unavailable,
        _ => DeviceAuthenticationResult.denied,
      };
      if (error.code == LocalAuthExceptionCode.deviceError ||
          error.code == LocalAuthExceptionCode.unknownError) {
        Log.warning(
          'Device authentication failed unexpectedly',
          name: 'LocalDeviceAuthentication',
          category: LogCategory.auth,
          error: error,
          stackTrace: stackTrace,
        );
      }
      return result;
    } on Object catch (error, stackTrace) {
      Log.warning(
        'Device authentication threw an unexpected error',
        name: 'LocalDeviceAuthentication',
        category: LogCategory.auth,
        error: error,
        stackTrace: stackTrace,
      );
      return DeviceAuthenticationResult.unavailable;
    }
  }
}

final deviceAuthenticationProvider = Provider<DeviceAuthentication>(
  (ref) => LocalDeviceAuthentication(),
);
