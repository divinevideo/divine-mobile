import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sets up the test environment with necessary platform channel mocks.
void setUpTestEnvironment() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(_setupPathProviderMock);
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });
}

/// Creates a temporary directory for testing and returns its path.
Future<Directory> createTestCacheDirectory(String name) async {
  final tempDir = Directory.systemTemp.createTempSync('media_cache_test_');
  final cacheDir = Directory('${tempDir.path}/$name');
  if (!cacheDir.existsSync()) {
    cacheDir.createSync(recursive: true);
  }
  return cacheDir;
}

/// Cleans up a test directory.
Future<void> cleanupTestDirectory(Directory dir) async {
  if (dir.existsSync()) {
    dir.deleteSync(recursive: true);
  }
}

late Directory _testTempDir;
late Directory _testSupportDir;

/// Gets the test temporary directory path.
String get testTempPath => _testTempDir.path;

/// Gets the test support directory path.
String get testSupportPath => _testSupportDir.path;

/// Sets up test directories that will be used by the mocked path_provider.
Future<void> setUpTestDirectories() async {
  _testTempDir = Directory.systemTemp.createTempSync('media_cache_temp_');
  _testSupportDir = Directory.systemTemp.createTempSync('media_cache_support_');
}

/// Cleans up the contents of the test directories.
///
/// The directories themselves stay alive deliberately: the store behind a
/// manager built here (`JsonCacheInfoRepository`) debounces its JSON save on
/// a 3 s timer, so a test group's last write can land *after* this teardown
/// — under the merged VGV isolate that stray write used to throw
/// [PathNotFoundException] into whichever unrelated test was running by
/// then. Both roots are uniquely-named `systemTemp` children, so leaving the
/// empty shells costs a few KB until the OS cleans them.
Future<void> tearDownTestDirectories() async {
  for (final dir in [_testTempDir, _testSupportDir]) {
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync()) {
      try {
        entity.deleteSync(recursive: true);
      } on Object {
        // Best-effort: a file held by an in-flight write is retried by the
        // OS temp cleaner instead.
      }
    }
  }
}

void _setupPathProviderMock() {
  const pathProviderChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathProviderChannel, (
        methodCall,
      ) async {
        switch (methodCall.method) {
          case 'getTemporaryDirectory':
            return _testTempDir.path;
          case 'getApplicationDocumentsDirectory':
            return '${_testTempDir.path}/documents';
          case 'getApplicationSupportDirectory':
            return _testSupportDir.path;
          default:
            return null;
        }
      });
}

/// Creates a test file with the given content.
Future<File> createTestFile(
  Directory dir,
  String filename, {
  String content = 'test content',
}) async {
  final file = File('${dir.path}/$filename');
  await file.writeAsString(content);
  return file;
}
