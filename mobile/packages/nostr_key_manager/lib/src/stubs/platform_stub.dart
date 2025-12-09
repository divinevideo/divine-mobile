// ABOUTME: Platform stub for web compatibility to avoid dart:io imports
// ABOUTME: Provides a fake Platform class for web builds to prevent Platform._version errors

/// Stub Platform class for web
class Platform {
  static bool get isIOS => false;
  static bool get isAndroid => false;
  static bool get isMacOS => false;
  static bool get isWindows => false;
  static bool get isLinux => false;
  static String get operatingSystem => 'web';
}
