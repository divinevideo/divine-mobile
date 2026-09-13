// ABOUTME: Narrow crash-reporting port injected into services (#4743)
// ABOUTME: Keeps deep services off the concrete Firebase-backed service

/// What a service needs from crash reporting, and nothing more.
///
/// Deep services take this instead of the concrete [CrashReportingService] so
/// they neither import Firebase nor reach a process global, and so a test can
/// hand them a recording fake. `CrashReportingService` implements it; the
/// app layer supplies the instance through `crashReportingServiceProvider`.
///
/// This is the same shape the upload pipeline already carved out as
/// `UploadCrashReporter` (since #8301 in `package:upload_repository`), promoted
/// here so the rest of the services layer can share one port rather than
/// growing a per-feature copy. See `.claude/rules/error_handling.md` →
/// "Reporter port pattern".
abstract interface class CrashReporter {
  /// Attach a custom key/value to subsequent crash reports.
  Future<void> setCustomKey(String key, Object value);

  /// Log a breadcrumb message to the crash reporter.
  void log(String message);

  /// Record a non-fatal error with an optional [reason].
  Future<void> recordError(Object error, StackTrace? stack, {String? reason});
}

/// A [CrashReporter] that discards everything.
///
/// The default for the two static utility classes that cannot take a
/// constructor-injected reporter, so an unwired test never NPEs and never
/// reaches Firebase. Bootstrap replaces it with the real service.
class SilentCrashReporter implements CrashReporter {
  const SilentCrashReporter();

  @override
  Future<void> setCustomKey(String key, Object value) async {}

  @override
  void log(String message) {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async {}
}
