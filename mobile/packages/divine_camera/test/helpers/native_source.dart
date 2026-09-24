// ABOUTME: Shared source readers for native implementation contract tests.
// ABOUTME: Keeps declaration-scoped assertions consistent across platforms.

import 'dart:io';

/// Reads a Swift source shared by the iOS and macOS implementations.
String readDarwinNativeSource(String fileName) {
  final file = [
    File('darwin/divine_camera/Sources/divine_camera/$fileName'),
    File(
      'packages/divine_camera/darwin/divine_camera/Sources/divine_camera/$fileName',
    ),
  ].firstWhere((file) => file.existsSync());

  return file.readAsStringSync();
}

String readAndroidNativeSource(String fileName) {
  const packagePath = 'android/src/main/kotlin/co/openvine/divine_camera';
  final file = [
    File('$packagePath/$fileName'),
    File('packages/divine_camera/$packagePath/$fileName'),
  ].firstWhere((file) => file.existsSync());

  return file.readAsStringSync();
}

/// Returns the declaration or block starting at [signature] up to its closing
/// brace, so assertions cannot match identical text outside the intended scope.
String declarationAt(String source, String signature) {
  final start = source.indexOf(signature);
  if (start < 0) {
    throw StateError('No declaration starting with "$signature".');
  }

  var depth = 0;
  for (var i = source.indexOf('{', start); i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }
  throw StateError('Unbalanced braces after "$signature".');
}
