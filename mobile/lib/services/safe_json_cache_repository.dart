// ABOUTME: Safe wrapper around JsonCacheInfoRepository that handles corrupted cache files
// ABOUTME: Prevents app crashes when cache JSON is empty or malformed by catching FormatException

import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// A safe wrapper around JsonCacheInfoRepository that handles corrupted JSON files.
///
/// The standard JsonCacheInfoRepository crashes with FormatException when the
/// cache JSON file is empty or corrupted (e.g., due to app crash during write).
/// This wrapper catches those errors and deletes the corrupted file so a fresh
/// cache can be created.
class SafeJsonCacheInfoRepository extends JsonCacheInfoRepository {
  SafeJsonCacheInfoRepository({required String databaseName})
    : _databaseName = databaseName,
      super(databaseName: databaseName);

  final String _databaseName;

  @override
  Future<bool> open() async {
    try {
      return await super.open();
    } on FormatException catch (e) {
      // JSON file is corrupted - delete it and retry
      Log.warning(
        '⚠️ Cache JSON corrupted for $_databaseName, clearing cache: $e',
        name: 'SafeJsonCacheRepository',
        category: LogCategory.system,
      );
      await _deleteCacheFile();
      return await super.open();
    } catch (e) {
      // Handle other errors (null content, type errors, etc.)
      if (e.toString().contains('Unexpected end of input') ||
          e.toString().contains('type \'Null\'')) {
        Log.warning(
          '⚠️ Cache JSON empty/null for $_databaseName, clearing cache: $e',
          name: 'SafeJsonCacheRepository',
          category: LogCategory.system,
        );
        await _deleteCacheFile();
        return await super.open();
      }
      rethrow;
    }
  }

  /// Delete the corrupted cache JSON file
  /// Note: JsonCacheInfoRepository stores its JSON in getApplicationSupportDirectory()
  Future<void> _deleteCacheFile() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final filePath = path.join(directory.path, '$_databaseName.json');
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        Log.info(
          '🗑️ Deleted corrupted cache file: $filePath',
          name: 'SafeJsonCacheRepository',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.error(
        '❌ Failed to delete corrupted cache file: $e',
        name: 'SafeJsonCacheRepository',
        category: LogCategory.system,
      );
    }
  }
}
