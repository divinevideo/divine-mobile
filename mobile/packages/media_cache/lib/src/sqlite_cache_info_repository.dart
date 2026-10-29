import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:media_cache/src/safe_cache_info_repository.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqlite;

/// A shared SQLite cache index with narrowly classified corrupt-open recovery.
///
/// Only cache metadata is recreated, never the media files. Busy/locked, I/O,
/// permission and unknown errors propagate without deleting a healthy index.
class SqliteCacheInfoRepository implements CacheInfoRepository {
  /// Creates an index under the application's support directory.
  SqliteCacheInfoRepository({
    required String databaseName,
    @visibleForTesting DirectoryProvider? directoryProvider,
    @visibleForTesting CacheInfoRepository Function(String)? repositoryFactory,
    @visibleForTesting Future<void> Function(String)? deleteDatabase,
  }) : _databaseName = databaseName,
       _directoryProvider = directoryProvider ?? getApplicationSupportDirectory,
       _repositoryFactory =
           repositoryFactory ??
           ((filePath) =>
               CacheObjectProvider(path: filePath, databaseName: databaseName)),
       _deleteDatabase = deleteDatabase ?? sqlite.deleteDatabase;

  final String _databaseName;
  final DirectoryProvider _directoryProvider;
  final CacheInfoRepository Function(String) _repositoryFactory;
  final Future<void> Function(String) _deleteDatabase;
  Future<String>? _path;
  Future<void> _lifecycle = Future<void>.value();
  bool _isOpen = false;
  late CacheInfoRepository _repository;

  /// Callers holding the index open after a successful [open] call.
  ///
  /// The cache store holds the index for its whole life while each cache sweep
  /// opens and closes its own connection. The database is shared, so it may
  /// only close with the last connection: closing it on a sweep's [close] left
  /// every later lookup failing with `database_closed`.
  int _connections = 0;

  Future<String> get _databasePath => _path ??= () async {
    final directory = await _directoryProvider();
    return path.join(directory.path, '$_databaseName.db');
  }();

  /// Acquires one lease on the index, which needs its own [close].
  ///
  /// Lifecycle operations run in invocation order. Failed or refused opens
  /// acquire no lease and a later call can retry with a fresh provider.
  @override
  Future<bool> open() => _scheduleLifecycle(() async {
    if (!_isOpen) {
      _isOpen = await _open();
      if (!_isOpen) return false;
    }
    _connections++;
    return true;
  });

  Future<bool> _scheduleLifecycle(Future<bool> Function() operation) {
    final result = _lifecycle.then((_) => operation());
    // The caller receives the error; subsequent operations must still run.
    _lifecycle = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<bool> _open() async {
    final filePath = await _databasePath;
    _repository = _repositoryFactory(filePath);
    try {
      return await _repository.open();
    } on sqlite.DatabaseException catch (error) {
      final code = error.getResultCode();
      // Mask extended codes to SQLite's primary result code. Never infer
      // corruption from exception text, which can describe unrelated failures.
      final primaryCode = code == null ? null : code & 0xff;
      if (primaryCode != 11 && primaryCode != 26) rethrow;
      // The native deleteDatabase operation handles SQLite's companion files.
      // CacheObjectProvider retains a failed open completer, so retry through a
      // fresh instance, exactly once, rather than reopening the failed one.
      await _deleteDatabase(filePath);
      _repository = _repositoryFactory(filePath);
      return _repository.open();
    }
  }

  /// Closes one connection, and the database with the last one.
  ///
  /// Returns false while other connections keep the database open.
  @override
  Future<bool> close() => _scheduleLifecycle(() async {
    if (_connections > 0) {
      _connections--;
      if (_connections > 0) return false;
    }
    if (!_isOpen) return true;
    // Retain the provider if close fails or is refused, allowing a retry.
    final closed = await _repository.close();
    if (closed) _isOpen = false;
    return closed;
  });

  @override
  Future<bool> exists() async => File(await _databasePath).existsSync();

  @override
  Future<void> deleteDataFile() async => _deleteDatabase(await _databasePath);

  @override
  Future<CacheObject?> get(String key) => _repository.get(key);

  @override
  Future<CacheObject> insert(
    CacheObject cacheObject, {
    bool setTouchedToNow = true,
  }) => _repository.insert(cacheObject, setTouchedToNow: setTouchedToNow);

  @override
  Future<int> update(CacheObject cacheObject, {bool setTouchedToNow = true}) =>
      _repository.update(cacheObject, setTouchedToNow: setTouchedToNow);

  @override
  Future<dynamic> updateOrInsert(CacheObject cacheObject) =>
      _repository.updateOrInsert(cacheObject);

  @override
  Future<int> delete(int id) => _repository.delete(id);

  @override
  Future<int> deleteAll(Iterable<int> ids) => _repository.deleteAll(ids);

  @override
  Future<List<CacheObject>> getAllObjects() => _repository.getAllObjects();

  @override
  Future<List<CacheObject>> getObjectsOverCapacity(int capacity) =>
      _repository.getObjectsOverCapacity(capacity);

  @override
  Future<List<CacheObject>> getOldObjects(Duration maxAge) =>
      _repository.getOldObjects(maxAge);
}
