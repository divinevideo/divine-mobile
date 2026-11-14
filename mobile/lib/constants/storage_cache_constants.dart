// ABOUTME: Shared cache byte-budget constants for the storage feature.
// ABOUTME: Neutral home so both the service layer and the settings UI can read
// ABOUTME: them without the UI importing the service layer (layering ratchet).

/// Smallest selectable video-cache byte budget (0.5 GB).
const int kCacheLimitMinBytes = 512 * 1024 * 1024;

/// Largest selectable video-cache byte budget (10 GB).
const int kCacheLimitMaxBytes = 10 * 1024 * 1024 * 1024;

/// Default video-cache byte budget when the user hasn't chosen one (2 GB).
const int kCacheLimitDefaultBytes = 2 * 1024 * 1024 * 1024;

/// SharedPreferences key holding the user-chosen video-cache byte budget.
const String kCacheLimitPrefKey = 'video_cache_max_bytes';

/// Directory containing downloaded feed videos in the platform temp root.
const String kVideoCacheDirectoryName = 'openvine_video_cache';

/// Rough average size of one cached short video, used to translate a byte
/// budget into an approximate video count in the UI.
const int kApproxVideoBytes = 4 * 1024 * 1024;

/// Default upper bound on persisted transition-seam previews (200 MB).
const int kSeamCacheLimitBytes = 200 * 1024 * 1024;

/// Share of the disk automatic sizing tries to keep free. The caches shrink
/// as the disk fills, but stop at their floors (the `k*CacheFloorBytes`
/// below), and caches outside automatic sizing are not counted.
const double kAutoCacheReservedDiskFraction = 0.15;

/// Smallest video-cache budget automatic sizing shrinks to (64 MB): the
/// feed's eight-video prefetch window plus as many behind for scrolling back.
const int kVideoCacheFloorBytes = 64 * 1024 * 1024;

/// Smallest image-cache budget automatic sizing shrinks to (32 MB).
const int kImageCacheFloorBytes = 32 * 1024 * 1024;

/// Smallest Android player-cache budget automatic sizing shrinks to (32 MB).
const int kPlayerCacheFloorBytes = 32 * 1024 * 1024;
