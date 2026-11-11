// ABOUTME: Owns temporary consent recordings and immutable upload snapshots.
// ABOUTME: Removes files abandoned by a previous process before creating new ones.
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// App-private consent files. One instance lives for the app process.
class ConsentFileStore {
  ConsentFileStore(Directory temporaryDirectory)
    : _temporaryDirectory = (() async => temporaryDirectory);

  ConsentFileStore._(this._temporaryDirectory);

  static final instance = ConsentFileStore._(getTemporaryDirectory);
  final Future<Directory> Function() _temporaryDirectory;
  late Directory _root;
  Future<void>? _initialization;

  /// Sweeps the previous process once, before this process creates any files.
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    final temporary = await _temporaryDirectory();
    _root = Directory('${temporary.path}/divine-parent-consent');
    if (_root.existsSync()) _root.deleteSync(recursive: true);
    _root.createSync(recursive: true);
  }

  /// Allocates a private directory after recovery cleanup has completed.
  Future<Directory> createDirectory() async {
    await initialize();
    _root.createSync(recursive: true);
    return _root.createTempSync('session-');
  }

  /// Allocates a recording directory behind the platform boundary.
  Future<String> createRecordingDirectory() async =>
      (await createDirectory()).path;

  /// Discards a recording without logging its private path.
  Future<void> deleteClip(String path) async {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  }
}
