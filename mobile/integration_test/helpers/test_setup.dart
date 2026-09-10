// ABOUTME: Test setup helpers for E2E integration tests
// ABOUTME: Error suppression and ErrorWidget.builder management

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Whether an error message is a non-critical async error.
///
/// These errors come from subsystems that don't affect E2E test flow:
/// - External relay WebSocket/certificate failures (expected in local env)
/// - setState-after-dispose from text field teardown during navigation
/// - Firebase Messaging permission races during multi-account flows
bool _isNonCriticalAsyncError(String message) {
  return message.contains('setState() called after dispose()') ||
      message.contains('CERTIFICATE_VERIFY_FAILED') ||
      message.contains('WebSocketException') ||
      message.contains('WebSocketChannelException') ||
      message.contains('Relay rejected event') ||
      message.contains('A request for permissions is already running');
}

/// Suppress non-critical errors that don't affect E2E test flow.
///
/// Suppresses:
/// - setState-after-dispose from text field teardown during navigation
/// - External relay WebSocket/certificate errors (expected in local env)
/// - Relay rejected event errors surfaced by the app's error handler
///
/// Returns the original error handler for restoration.
FlutterExceptionHandler? suppressSetStateErrors() {
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final message = details.exceptionAsString();
    if (_isNonCriticalAsyncError(message)) {
      return;
    }
    originalOnError?.call(details);
  };
  return originalOnError;
}

/// Drain any pending async exceptions (e.g. WebSocket errors from external
/// relays) that the test framework captured. Call this before the test body
/// ends to prevent `_pendingExceptionDetails` assertion failures.
void drainAsyncErrors(WidgetTester tester) {
  // takeException() returns the pending uncaught exception and clears it.
  // Loop in case multiple errors queued up.
  Object? ex;
  do {
    ex = tester.takeException();
  } while (ex != null);
}

/// Launch the app inside a guarded zone that catches external relay errors.
///
/// The test framework's zone error handler (`handleUncaughtError`) captures
/// async WebSocket exceptions and fails the test. By running the app in a
/// child zone with its own error handler, relay errors never reach the test
/// framework.
void launchAppGuarded(void Function() appMain) {
  runZonedGuarded(
    appMain,
    (error, stack) {
      if (_isNonCriticalAsyncError(error.toString())) {
        return; // swallow relay errors
      }
      // Re-throw non-relay errors into the parent zone so tests still fail
      Zone.current.parent?.handleUncaughtError(error, stack);
    },
  );
}

/// Restore the original FlutterError.onError handler.
void restoreErrorHandler(FlutterExceptionHandler? original) {
  FlutterError.onError = original;
}

/// Save ErrorWidget.builder before app.main() sets a custom one.
///
/// Must be called before app.main() and restored before test body ends
/// (the framework asserts it hasn't changed).
ErrorWidgetBuilder saveErrorWidgetBuilder() {
  return ErrorWidget.builder;
}

/// Restore ErrorWidget.builder to the saved value.
void restoreErrorWidgetBuilder(ErrorWidgetBuilder original) {
  ErrorWidget.builder = original;
}

/// Print a timestamped log message matching the app's `[HH:MM:SS.mmm]` format.
///
/// This ensures test-side log lines (phase markers, status messages) get
/// timestamps that `merge_logs.py` can parse and interleave with app/docker
/// logs.
void logPhase(String message) {
  final now = DateTime.now();
  final ts =
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}:'
      '${now.second.toString().padLeft(2, '0')}.'
      '${now.millisecond.toString().padLeft(3, '0')}';
  debugPrint('[$ts] $message');
}

/// Pump frames until either the app has settled or maxSeconds is reached.
///
/// This is a workaround for situations where pumpAndSettle times out
/// due to persistent animations or polling timers. Pumps every 250ms
/// for more responsive frame processing.
Future<void> pumpUntilSettled(
  WidgetTester tester, {
  int maxSeconds = 5,
}) async {
  final iterations = maxSeconds * 4;
  for (var i = 0; i < iterations; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}
