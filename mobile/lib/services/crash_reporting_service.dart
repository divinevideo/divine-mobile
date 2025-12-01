// ABOUTME: Crash reporting service for production error tracking
// ABOUTME: Uses Firebase Crashlytics to capture and report crashes from TestFlight/production

import 'dart:async';
import 'dart:isolate';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:openvine/firebase_options.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Crash reporting service for production error tracking
class CrashReportingService {
  static CrashReportingService? _instance;
  static CrashReportingService get instance =>
      _instance ??= CrashReportingService._();

  CrashReportingService._();

  bool _initialized = false;

  /// Initialize crash reporting (Firebase Crashlytics)
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize Firebase with platform-specific options
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Pass all uncaught errors from the framework to Crashlytics
      FlutterError.onError = (errorDetails) {
        // Log locally first
        Log.error(
          'Flutter framework error: ${errorDetails.exception}',
          name: 'CrashReporting',
        );

        // Send to Crashlytics
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };

      // Pass all uncaught asynchronous errors to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        // Log locally first
        Log.error('Async error: $error', name: 'CrashReporting');

        // Send to Crashlytics
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      // Catch errors in other isolates
      Isolate.current.addErrorListener(
        RawReceivePort((pair) async {
          final List<dynamic> errorAndStacktrace = pair;
          await FirebaseCrashlytics.instance.recordError(
            errorAndStacktrace.first,
            errorAndStacktrace.last,
            fatal: true,
          );
        }).sendPort,
      );

      // Set custom keys for debugging
      await FirebaseCrashlytics.instance.setCustomKey(
        'environment',
        const String.fromEnvironment('ENVIRONMENT', defaultValue: 'production'),
      );
      await FirebaseCrashlytics.instance.setCustomKey(
        'build_mode',
        kDebugMode ? 'debug' : 'release',
      );

      // Enable crash collection for all environments (including TestFlight/production)
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        !kDebugMode,
      );

      _initialized = true;
      Log.info(
        'Crash reporting initialized successfully',
        name: 'CrashReporting',
      );
    } catch (e) {
      Log.error(
        'Failed to initialize crash reporting: $e',
        name: 'CrashReporting',
      );
      // Don't throw - app should continue even if crash reporting fails
    }
  }

  /// Log a non-fatal error to Crashlytics
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
  }) async {
    if (!_initialized) return;

    try {
      await FirebaseCrashlytics.instance.recordError(
        exception,
        stack,
        reason: reason,
        fatal: false,
      );
    } catch (e) {
      Log.error(
        'Failed to record error to Crashlytics: $e',
        name: 'CrashReporting',
      );
    }
  }

  /// Log a custom message to Crashlytics
  void log(String message) {
    if (!_initialized) return;

    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (e) {
      Log.error(
        'Failed to log message to Crashlytics: $e',
        name: 'CrashReporting',
      );
    }
  }

  /// Set user identifier for crash reports
  Future<void> setUserId(String userId) async {
    if (!_initialized) return;

    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(userId);
    } catch (e) {
      Log.error(
        'Failed to set user ID in Crashlytics: $e',
        name: 'CrashReporting',
      );
    }
  }

  /// Add custom key-value pair to crash reports
  Future<void> setCustomKey(String key, dynamic value) async {
    if (!_initialized) return;

    try {
      await FirebaseCrashlytics.instance.setCustomKey(key, value);
    } catch (e) {
      Log.error(
        'Failed to set custom key in Crashlytics: $e',
        name: 'CrashReporting',
      );
    }
  }

  /// Log initialization step for debugging startup crashes
  void logInitializationStep(String step) {
    log('[INIT] $step');
    Log.info('Initialization: $step', name: 'CrashReporting');
  }
}
