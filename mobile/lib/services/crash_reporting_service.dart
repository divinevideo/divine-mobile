// ABOUTME: Crash reporting service for production error tracking
// ABOUTME: Uses Firebase Crashlytics to capture and report crashes from TestFlight/production

import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/firebase_initialization.dart';
import 'package:openvine/utils/platform_support.dart';
import 'package:unified_logger/unified_logger.dart';

/// One call against Crashlytics, held until [CrashReportingService.initialize]
/// has decided whether Crashlytics exists.
typedef _CrashlyticsCall = Future<void> Function(
  FirebaseCrashlytics crashlytics,
);

/// Whether Crashlytics can take a call right now.
enum _Readiness {
  /// [CrashReportingService.initialize] has not resolved; calls are held.
  pending,

  /// Crashlytics is up; calls are forwarded as they arrive.
  ready,

  /// Firebase is unsupported here or failed to initialize; nothing is
  /// forwarded, and non-fatal errors fall back to the unified log.
  unavailable,
}

/// Crash reporting service for production error tracking.
///
/// Nothing handed to this service is discarded silently (#8616). Until
/// [initialize] resolves, every call is held in order — the first
/// [pendingReportCapacity] of them — and replayed once Crashlytics is up, so
/// the breadcrumbs and non-fatal errors from the pre-init startup window still
/// reach the dashboard. A non-fatal error is also written to the unified log
/// at once, because that log is what a bug report carries and the process may
/// never reach [initialize]: a launch that fails closed before it, or an
/// isolate that never calls it. If Crashlytics turns out to be unavailable the
/// held calls are dropped with a count; from then on non-fatal errors go to
/// the unified log, while breadcrumbs and keys — which only mean anything
/// attached to a Crashlytics report — are dropped.
class CrashReportingService implements CrashReporter {
  /// [initializeFirebase] and [crashlytics] default to the real Firebase; tests
  /// inject stand-ins so the replay can be observed without a Firebase app.
  CrashReportingService({
    Future<void> Function() initializeFirebase =
        ensureDefaultFirebaseInitialized,
    FirebaseCrashlytics Function() crashlytics = _defaultCrashlytics,
  }) : _initializeFirebase = initializeFirebase,
       _crashlytics = crashlytics;

  /// How many calls are held before [initialize] resolves. The earliest are
  /// kept: in a startup error storm the first report is the root cause and the
  /// rest are its cascade.
  static const int pendingReportCapacity = 32;

  static FirebaseCrashlytics _defaultCrashlytics() =>
      FirebaseCrashlytics.instance;

  final Future<void> Function() _initializeFirebase;
  final FirebaseCrashlytics Function() _crashlytics;

  _Readiness _readiness = _Readiness.pending;
  final List<_CrashlyticsCall> _pending = [];
  int _overflowed = 0;

  /// Initialize crash reporting (Firebase Crashlytics)
  Future<void> initialize() async {
    if (_readiness != _Readiness.pending) return;

    // Firebase only supports Android, iOS, macOS, and web.
    // DefaultFirebaseOptions.currentPlatform throws UnsupportedError for
    // Linux and Windows — skip initialization on those platforms.
    if (!isFirebaseSupported) {
      _giveUp('Firebase is not supported on this platform');
      return;
    }

    try {
      await _initializeFirebase();
      final crashlytics = _crashlytics();

      // Pass all uncaught errors from the framework to Crashlytics
      FlutterError.onError = (errorDetails) {
        // Log locally first
        Log.error(
          'Flutter framework error: ${errorDetails.exception}',
          name: 'CrashReporting',
        );

        // Send to Crashlytics
        crashlytics.recordFlutterFatalError(errorDetails);
      };

      // Pass all uncaught asynchronous errors to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        // Log locally first
        Log.error('Async error: $error', name: 'CrashReporting');

        // Send to Crashlytics
        crashlytics.recordError(error, stack, fatal: true);
        return true;
      };

      // Set custom keys for debugging
      await crashlytics.setCustomKey(
        'environment',
        const String.fromEnvironment('ENVIRONMENT', defaultValue: 'production'),
      );
      await crashlytics.setCustomKey(
        'build_mode',
        kDebugMode ? 'debug' : 'release',
      );

      // Enable crash collection for release builds only (TestFlight, production)
      // Disabled in debug mode to avoid flooding dashboard with dev errors
      const enableCollection = !kDebugMode;
      Log.debug(
        '🔥 CRASHLYTICS: kDebugMode=$kDebugMode, enabling collection=$enableCollection',
        name: 'CrashReportingService',
        category: LogCategory.system,
      );
      await crashlytics.setCrashlyticsCollectionEnabled(enableCollection);

      // Verify it's actually enabled
      final isEnabled = crashlytics.isCrashlyticsCollectionEnabled;
      Log.debug(
        '🔥 CRASHLYTICS: Collection enabled check = $isEnabled',
        name: 'CrashReportingService',
        category: LogCategory.system,
      );

      _readiness = _Readiness.ready;
      await _replayPending();

      // Log a breadcrumb to prove connection works (visible in Crashlytics logs)
      if (isEnabled) {
        crashlytics.log(
          'App started: kDebugMode=$kDebugMode, collection=$isEnabled',
        );
      }

      Log.info(
        'Crash reporting initialized: kDebugMode=$kDebugMode, enabled=$isEnabled',
        name: 'CrashReporting',
      );
    } catch (e) {
      final becameReady = _readiness == _Readiness.ready;
      Log.error(
        becameReady
            ? 'Crash reporting initialized, but completion logging failed: $e'
            : 'Failed to initialize crash reporting: $e',
        name: 'CrashReporting',
      );
      // Don't throw - app should continue even if crash reporting fails
      if (!becameReady) {
        _giveUp('Crashlytics failed to initialize');
      }
    }
  }

  /// Marks Crashlytics unusable for the rest of the process and drops what was
  /// held for it. Non-fatal errors among the held calls are already in the
  /// unified log, so only the count is worth a line.
  void _giveUp(String why) {
    _readiness = _Readiness.unavailable;
    final held = _pending.length + _overflowed;
    _pending.clear();
    _overflowed = 0;
    if (held == 0) return;
    Log.warning(
      '$why; $held Crashlytics call(s) made before initialization were not '
      'forwarded',
      name: 'CrashReporting',
    );
  }

  /// Replays the held calls now that Crashlytics is up.
  Future<void> _replayPending() async {
    final held = List<_CrashlyticsCall>.of(_pending);
    _pending.clear();
    // Started in one synchronous pass so the platform-channel messages keep
    // their original order ahead of any call that arrives while they settle.
    await Future.wait([
      for (final call in held) _forward(call, what: 'replay a held call'),
    ]);
    if (_overflowed == 0) return;
    Log.warning(
      'Startup buffer overflowed: $_overflowed Crashlytics call(s) made before '
      'initialization were not forwarded',
      name: 'CrashReporting',
    );
    _overflowed = 0;
  }

  /// Forwards, holds, or drops [call] depending on readiness.
  Future<void> _dispatch(_CrashlyticsCall call, {required String what}) async {
    switch (_readiness) {
      case _Readiness.ready:
        await _forward(call, what: what);
      case _Readiness.pending:
        _hold(call);
      case _Readiness.unavailable:
        // Crashlytics is unavailable; recordError has already used its local
        // fallback, while calls that only annotate Crashlytics can be dropped.
        break;
    }
  }

  void _hold(_CrashlyticsCall call) {
    if (_pending.length >= pendingReportCapacity) {
      _overflowed++;
      return;
    }
    _pending.add(call);
  }

  Future<void> _forward(_CrashlyticsCall call, {required String what}) async {
    try {
      await call(_crashlytics());
    } catch (e) {
      Log.error('Failed to $what in Crashlytics: $e', name: 'CrashReporting');
    }
  }

  /// Log a non-fatal error to Crashlytics.
  ///
  /// Written to the unified log as well whenever Crashlytics cannot take it
  /// right now, so a bug report carries it even if the process never gets to
  /// [initialize].
  @override
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
  }) {
    if (_readiness != _Readiness.ready) {
      final fate = _readiness == _Readiness.pending
          ? 'held until Crashlytics initializes'
          : 'not forwarded because Crashlytics is unavailable';
      Log.error(
        'Non-fatal error $fate${reason == null ? '' : ': $reason'}',
        name: 'CrashReporting',
        error: exception,
        stackTrace: stack,
      );
    }
    return _dispatch(
      (crashlytics) =>
          crashlytics.recordError(exception, stack, reason: reason),
      what: 'record error',
    );
  }

  /// Log a custom message to Crashlytics
  @override
  void log(String message) {
    unawaited(
      _dispatch((crashlytics) => crashlytics.log(message), what: 'log message'),
    );
  }

  /// Set user identifier for crash reports
  Future<void> setUserId(String? userId) => _dispatch(
    (crashlytics) => crashlytics.setUserIdentifier(userId ?? ''),
    what: 'set user ID',
  );

  /// Add custom key-value pair to crash reports
  @override
  Future<void> setCustomKey(String key, dynamic value) => _dispatch(
    (crashlytics) => crashlytics.setCustomKey(key, value as Object),
    what: 'set custom key',
  );

  /// Log initialization step for debugging startup crashes
  void logInitializationStep(String step) {
    log('[INIT] $step');
    Log.info('Initialization: $step', name: 'CrashReporting');
  }
}
