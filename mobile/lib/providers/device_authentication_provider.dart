// ABOUTME: Provides fail-closed device-local authentication for sensitive app actions
// ABOUTME: Wraps local_auth behind an injectable result-based interface

import 'dart:async';

import 'package:flutter/widgets.dart';
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
    final lifecycle = _AuthenticationLifecycleObserver();
    try {
      if (!await _localAuthentication.isDeviceSupported()) {
        return DeviceAuthenticationResult.unavailable;
      }

      var canRetryAfterBackgrounding = true;
      while (true) {
        try {
          final authenticated = await _localAuthentication.authenticate(
            localizedReason: reason,
            persistAcrossBackgrounding: true,
          );
          if (!authenticated &&
              canRetryAfterBackgrounding &&
              lifecycle.wasBackgrounded) {
            canRetryAfterBackgrounding = false;
            await lifecycle.waitUntilResumed();
            continue;
          }
          return authenticated
              ? DeviceAuthenticationResult.authenticated
              : DeviceAuthenticationResult.denied;
        } on LocalAuthException catch (error, stackTrace) {
          final backgroundedAroundCancellation =
              lifecycle.wasBackgrounded ||
              ((error.code == LocalAuthExceptionCode.systemCanceled ||
                      error.code == LocalAuthExceptionCode.userCanceled) &&
                  await lifecycle.detectPendingBackgroundTransition());
          final canceledWhileBackgrounded =
              canRetryAfterBackgrounding &&
              backgroundedAroundCancellation &&
              (error.code == LocalAuthExceptionCode.systemCanceled ||
                  error.code == LocalAuthExceptionCode.userCanceled);
          if (canceledWhileBackgrounded) {
            canRetryAfterBackgrounding = false;
            await lifecycle.waitUntilResumed();
            continue;
          }
          return _mapLocalAuthException(error, stackTrace);
        }
      }
    } on Object catch (error, stackTrace) {
      Log.warning(
        'Device authentication threw an unexpected error',
        name: 'LocalDeviceAuthentication',
        category: LogCategory.auth,
        error: error,
        stackTrace: stackTrace,
      );
      return DeviceAuthenticationResult.unavailable;
    } finally {
      lifecycle.dispose();
    }
  }

  DeviceAuthenticationResult _mapLocalAuthException(
    LocalAuthException error,
    StackTrace stackTrace,
  ) {
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
  }
}

class _AuthenticationLifecycleObserver extends WidgetsBindingObserver {
  // Android can report BiometricPrompt cancellation just before Flutter
  // receives the matching paused event. Keep the observer alive briefly so
  // that ordering does not turn a background interruption into user denial.
  static const _backgroundTransitionGracePeriod = Duration(milliseconds: 250);

  _AuthenticationLifecycleObserver() {
    WidgetsBinding.instance.addObserver(this);
  }

  bool wasBackgrounded = false;
  Completer<bool>? _backgroundTransition;
  Timer? _backgroundTransitionTimer;
  Completer<void>? _resumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        wasBackgrounded = true;
        _backgroundTransition?.complete(true);
        _clearBackgroundTransitionProbe();
      case AppLifecycleState.resumed:
        _resumed?.complete();
        _resumed = null;
      case AppLifecycleState.inactive:
        break;
    }
  }

  /// Mirrors the states [didChangeAppLifecycleState] counts as backgrounding.
  /// `inactive` is deliberately excluded: a system authentication sheet makes
  /// the app inactive on iOS, so treating it as a background transition turns
  /// an ordinary cancellation into a second prompt.
  static bool _isBackgrounded(AppLifecycleState? state) =>
      state == AppLifecycleState.paused ||
      state == AppLifecycleState.hidden ||
      state == AppLifecycleState.detached;

  Future<void> waitUntilResumed() {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      return Future<void>.value();
    }
    return (_resumed ??= Completer<void>()).future;
  }

  Future<bool> detectPendingBackgroundTransition() {
    if (wasBackgrounded ||
        _isBackgrounded(WidgetsBinding.instance.lifecycleState)) {
      return Future<bool>.value(true);
    }

    final transition = _backgroundTransition ??= Completer<bool>();
    _backgroundTransitionTimer ??= Timer(
      _backgroundTransitionGracePeriod,
      () {
        transition.complete(false);
        _clearBackgroundTransitionProbe();
      },
    );
    return transition.future;
  }

  void _clearBackgroundTransitionProbe() {
    _backgroundTransitionTimer?.cancel();
    _backgroundTransitionTimer = null;
    _backgroundTransition = null;
  }

  void dispose() {
    if (!(_backgroundTransition?.isCompleted ?? true)) {
      _backgroundTransition?.complete(false);
    }
    _clearBackgroundTransitionProbe();
    WidgetsBinding.instance.removeObserver(this);
  }
}

final deviceAuthenticationProvider = Provider<DeviceAuthentication>(
  (ref) => LocalDeviceAuthentication(),
);
