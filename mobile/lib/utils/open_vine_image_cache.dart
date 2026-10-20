import 'package:flutter/foundation.dart';
import 'package:media_cache/media_cache.dart';
import 'package:openvine/utils/decoded_image_cache.dart';

/// Global image cache singleton backed by [MediaCacheManager].
final openVineImageCache = MediaCacheManager(
  config: const MediaCacheConfig.image(cacheKey: 'openvine_image_cache'),
);

/// Clears Flutter's in-memory image caches and the shared thumbnail disk cache.
///
/// [diskCache] replaces [openVineImageCache] in tests, which keep the real
/// on-disk cache out of the shared test isolate.
Future<void> clearOpenVineImageCache({
  @visibleForTesting MediaCacheManager? diskCache,
}) async {
  // Clear all image entries, not only thumbnails, so revoked adult-media auth
  // cannot survive in live ImageProviders or shared cache-manager files.
  clearDecodedImageCache(includeLiveImages: true);
  await (diskCache ?? openVineImageCache).clearCache();
}
