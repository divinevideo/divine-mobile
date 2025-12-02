// ABOUTME: Mock implementation of PathProviderPlatform for testing
// ABOUTME: Allows tests to control file system paths without accessing real directories

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPathProviderPlatform
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  String? _temporaryPath;
  String? _applicationDocumentsPath;
  String? _applicationSupportPath;

  void setTemporaryPath(String path) {
    _temporaryPath = path;
  }

  void setApplicationDocumentsPath(String path) {
    _applicationDocumentsPath = path;
  }

  void setApplicationSupportPath(String path) {
    _applicationSupportPath = path;
  }

  @override
  Future<String?> getTemporaryPath() async {
    return _temporaryPath;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return _applicationDocumentsPath;
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    return _applicationSupportPath;
  }

  @override
  Future<String?> getApplicationCachePath() async {
    return null;
  }

  @override
  Future<String?> getDownloadsPath() async {
    return null;
  }

  @override
  Future<List<String>?> getExternalCachePaths() async {
    return null;
  }

  @override
  Future<String?> getExternalStoragePath() async {
    return null;
  }

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async {
    return null;
  }

  @override
  Future<String?> getLibraryPath() async {
    return null;
  }
}
