/// A reusable media caching package built on flutter_cache_manager.
///
/// Provides configurable caching for videos, images, and other media files
/// with corrupt cache recovery and optional synchronous file lookups.
///
/// ## Features
///
/// - **Configurable cache**: Size, stale period, timeouts, and connection
///   limits
/// - **Corrupt cache recovery**: Automatically handles corrupted cache files
/// - **Sync manifest**: Optional in-memory manifest for instant file lookups
/// - **Preset configurations**: Optimized defaults for videos and images
///
/// ## Quick Start
///
/// ```dart
/// // Create a video cache with sync manifest for instant playback
/// final videoCache = MediaCacheManager(
///   config: MediaCacheConfig.video(cacheKey: 'my_video_cache'),
/// );
///
/// // Initialize on app startup (loads manifest for sync lookups)
/// await videoCache.initialize();
///
/// // Get cached file synchronously (no async overhead)
/// final file = videoCache.getCachedFileSync('video_123');
/// if (file != null) {
///   // Play the cached file immediately (no network round-trip)
///   await controller.setSource(VideoClip.file(file.path));
/// } else {
///   // Fall back to network
///   await controller.setSource(VideoClip.network(url));
///   // Cache in background for next time
///   unawaited(videoCache.cacheFile(url, key: 'video_123'));
/// }
/// ```
///
/// ## Image Caching with MediaCacheImageProvider
///
/// ```dart
/// final imageCache = MediaCacheManager(
///   config: MediaCacheConfig.image(cacheKey: 'my_image_cache'),
/// );
///
/// // Use with Image widget
/// Image(
///   image: MediaCacheImageProvider(
///     'https://example.com/image.jpg',
///     cacheManager: imageCache,
///   ),
/// )
/// ```
library;

export 'src/cancellable_cache_operation.dart' show CancellableCacheOperation;
export 'src/cancellable_downloader.dart'
    show
        CancellableDownload,
        CancellableDownloadResult,
        CancellableDownloader,
        HttpCancellableDownloader;
export 'src/media_cache_image_provider.dart'
    show MediaCacheImageLoadException, MediaCacheImageProvider;
export 'src/media_cache_manager.dart'
    show CacheMetrics, MediaCacheConfig, MediaCacheManager;
export 'src/safe_cache_info_repository.dart'
    show DirectoryProvider, SafeCacheInfoRepository;
export 'src/shared_cache_info_repository.dart'
    show createSharedCacheInfoRepository;
