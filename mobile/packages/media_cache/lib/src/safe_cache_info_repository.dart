import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Function type for getting the application support directory.
typedef DirectoryProvider = Future<Directory> Function();

/// {@template safe_cache_info_repository}
/// A safe wrapper around [CacheInfoRepository] that handles corrupted
/// JSON files.
///
/// Upstream's `JsonCacheInfoRepository._readFile` catches every exception
/// internally (`on Object`) and reports it through [FlutterError.reportError]
/// rather than rethrowing, so a plain try/catch around [open] never sees a
/// corrupt index — the error goes straight to [FlutterError.onError], where
/// Crashlytics files it as a crash and the cache silently comes up empty.
///
/// So this wrapper reads the index itself before delegating, parsing it
/// exactly the way upstream will, and deletes the file when that parse fails.
/// Corruption is then resolved before upstream ever sees it. The direct-throw
/// paths are still caught, for repositories that raise instead of reporting.
///
/// It deliberately does **not** intercept [FlutterError.onError]. That handler
/// is a process-global, and the details upstream reports carry no file or
/// database identity — only `library: 'flutter cache manager'` — so a handler
/// installed by one repository cannot tell its own corruption from another's.
/// Two managers exist in the app and `CacheStore`'s constructor fires
/// `repo.open()` eagerly and unawaited, so those windows overlap: swapping the
/// global and restoring it by assignment dropped one handler whenever they
/// finished out of order and left the other permanently installed, and the
/// captured error could be attributed to the wrong cache and delete a healthy
/// index. Reading the file directly removes the global from the design instead
/// of trying to sequence it.
///
/// Uses composition to wrap a [CacheInfoRepository] (defaults to
/// [JsonCacheInfoRepository]), making it fully testable via dependency
/// injection.
/// {@endtemplate}
class SafeCacheInfoRepository implements CacheInfoRepository {
  /// {@macro safe_cache_info_repository}
  ///
  /// The [repository] and [directoryProvider] parameters are exposed for
  /// testing purposes. In production, they default to
  /// [JsonCacheInfoRepository] and [getApplicationSupportDirectory].
  SafeCacheInfoRepository({
    required String databaseName,
    @visibleForTesting CacheInfoRepository? repository,
    @visibleForTesting DirectoryProvider? directoryProvider,
  }) : _databaseName = databaseName,
       _repository =
           repository ?? JsonCacheInfoRepository(databaseName: databaseName),
       _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final String _databaseName;
  final CacheInfoRepository _repository;
  final DirectoryProvider _directoryProvider;

  /// The wrapped repository instance.
  ///
  /// Exposed for testing purposes only.
  @visibleForTesting
  CacheInfoRepository get repository => _repository;

  /// The index check for the open the wrapped repository reads the file on.
  ///
  /// Upstream reads the index only when its open count goes from 0 to 1, and
  /// `CacheStore` holds its open for the manager's lifetime, so the sweep's
  /// and the manifest's opens never read it. Checking the file on those opens
  /// raced upstream's save, which truncates the file before writing it: a
  /// read in that window parsed an empty or partial index and deleted the
  /// live one. Every open awaits this one check instead, and a close that
  /// fully closes the repository clears it for the next read.
  Future<void>? _indexCheck;

  @override
  Future<bool> open() async {
    await (_indexCheck ??= _deleteCacheFileIfUnreadable());

    // Kept for repositories that raise instead of reporting. The upstream
    // JSON repository is handled above, before it can swallow the error.
    try {
      return await _repository.open();
    } on FormatException {
      await deleteCacheFile();
      return _repository.open();
    } on Exception catch (e) {
      if (e.toString().contains('Unexpected end of input') ||
          e.toString().contains("type 'Null'")) {
        await deleteCacheFile();
        return _repository.open();
      }
      rethrow;
    }
  }

  /// Deletes the cache index when it cannot be parsed.
  ///
  /// Mirrors `JsonCacheInfoRepository._readFile` deliberately: same path
  /// (`<applicationSupport>/<databaseName>.json`, matching upstream's
  /// `_getFile`), same `jsonDecode` to a `List`, same [CacheObject.fromMap]
  /// over each map element, and the same `on Object` reach — so anything that
  /// would leave upstream with an unusable index is caught here first.
  ///
  /// A file that survives this and still fails upstream is no worse off than
  /// before: the app's own handler downgrades `flutter cache manager` reports
  /// to non-fatal and the cache comes up empty, which is what already happened
  /// for every corruption shape the old interception missed.
  Future<void> _deleteCacheFileIfUnreadable() async {
    final File file;
    try {
      final directory = await _directoryProvider();
      file = File(path.join(directory.path, '$_databaseName.json'));
      if (!file.existsSync()) return;
    } on Object {
      // No support directory yet, or it cannot be resolved. There is nothing
      // to validate and nothing to delete; let the repository open normally.
      return;
    }

    try {
      final decoded = jsonDecode(await file.readAsString()) as List<dynamic>;
      for (final element in decoded) {
        if (element is! Map<String, dynamic>) continue;
        CacheObject.fromMap(element);
      }
    } on Object {
      await deleteCacheFile();
    }
  }

  /// Deletes the cache JSON file.
  ///
  /// This is called internally when the cache file is corrupted.
  /// Exposed as a visible method for testing purposes.
  ///
  /// A file that is already gone counts as deleted. `CacheStore`'s
  /// constructor and `MediaCacheManager.initialize` open this repository
  /// concurrently, so both can validate the same corrupt index and both
  /// delete it; an existence check first still leaves the losing delete to
  /// fail. The store keeps that `open()` future without a listener, so the
  /// failure went unhandled and every later store operation rethrew it.
  ///
  /// Throws a [FileSystemException] for any other failure to delete.
  @visibleForTesting
  Future<void> deleteCacheFile() async {
    final directory = await _directoryProvider();
    final file = File(path.join(directory.path, '$_databaseName.json'));
    try {
      await file.delete();
    } on PathNotFoundException {
      // Already deleted, by the other open or by the OS: the intended state.
    }
  }

  // Delegate all CacheInfoRepository methods to the wrapped repository.

  @override
  Future<bool> close() async {
    final closed = await _repository.close();
    if (closed) _indexCheck = null;
    return closed;
  }

  @override
  Future<int> delete(int id) => _repository.delete(id);

  @override
  Future<int> deleteAll(Iterable<int> ids) => _repository.deleteAll(ids);

  @override
  Future<void> deleteDataFile() => _repository.deleteDataFile();

  @override
  Future<bool> exists() => _repository.exists();

  @override
  Future<CacheObject?> get(String key) => _repository.get(key);

  @override
  Future<List<CacheObject>> getAllObjects() => _repository.getAllObjects();

  @override
  Future<List<CacheObject>> getObjectsOverCapacity(int capacity) =>
      _repository.getObjectsOverCapacity(capacity);

  @override
  Future<List<CacheObject>> getOldObjects(Duration maxAge) =>
      _repository.getOldObjects(maxAge);

  @override
  Future<CacheObject> insert(
    CacheObject cacheObject, {
    bool setTouchedToNow = true,
  }) => _repository.insert(cacheObject, setTouchedToNow: setTouchedToNow);

  @override
  Future<int> update(
    CacheObject cacheObject, {
    bool setTouchedToNow = true,
  }) => _repository.update(cacheObject, setTouchedToNow: setTouchedToNow);

  @override
  Future<dynamic> updateOrInsert(CacheObject cacheObject) =>
      _repository.updateOrInsert(cacheObject);
}
