// ABOUTME: Shared source readers for native implementation contract tests.
// ABOUTME: Keeps declaration-scoped assertions consistent across platforms.

import 'dart:io';

String readIosNativeSource(String fileName) {
  final file = [
    File('ios/Classes/$fileName'),
    File('packages/divine_camera/ios/Classes/$fileName'),
  ].firstWhere((file) => file.existsSync());

  return file.readAsStringSync();
}

String readMacosNativeSource(String fileName) {
  final file = [
    File('macos/Classes/$fileName'),
    File('packages/divine_camera/macos/Classes/$fileName'),
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
