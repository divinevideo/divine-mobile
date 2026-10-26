import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'package:media_cache/src/safe_cache_info_repository.dart';

/// Creates an index shared by foreground and notification background engines.
///
/// On native mobile platforms SQLite persists each row before returning and
/// coordinates independent connections. JSON repositories keep an isolate-local
/// snapshot and debounce whole-index writes, so cannot safely share that index.
/// Other platforms retain their existing cache behavior; they do not run the
/// mobile notification background engine.
CacheInfoRepository createSharedCacheInfoRepository(String databaseName) {
  if (!kIsWeb &&
      const {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      }.contains(defaultTargetPlatform)) {
    return CacheObjectProvider(databaseName: databaseName);
  }
  return SafeCacheInfoRepository(databaseName: databaseName);
}
