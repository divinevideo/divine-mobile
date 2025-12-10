// ABOUTME: Platform stub for web compatibility to avoid dart:io imports
// ABOUTME: Fake Platform class for web builds to prevent Platform errors

/// Stub Platform class for web.
///
/// Provides a fake Platform class to prevent dart:io errors on web builds.
class Platform {
  /// Returns false as web is not iOS.
  static bool get isIOS => false;

  /// Returns false as web is not Android.
  static bool get isAndroid => false;

  /// Returns false as web is not macOS.
  static bool get isMacOS => false;

  /// Returns false as web is not Windows.
  static bool get isWindows => false;

  /// Returns false as web is not Linux.
  static bool get isLinux => false;

  /// Returns 'web' as the operating system.
  static String get operatingSystem => 'web';
}
