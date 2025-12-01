// Stub for web platform where dart:io is not available.
// This file provides dummy implementations for Directory and File
// to allow code to compile on web, but these will not have
// any functional file system capabilities.

class Directory {
  final String path;
  Directory(this.path);
  Future<bool> exists() async => false;
  Future<Directory> create({bool recursive = false}) async => this;
}

class File {
  final String path;
  File(this.path);
  bool existsSync() => false;
  int lengthSync() => 0;
  // Add other methods that are used in the codebase if needed,
  // returning dummy values or throwing UnsupportedError.
}

// Add a Platform class with operatingSystem as a stub for web
class Platform {
  static String get operatingSystem => 'web';
}
