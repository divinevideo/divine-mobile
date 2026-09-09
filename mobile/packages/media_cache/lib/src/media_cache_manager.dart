import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/io_client.dart';
import 'package:media_cache/src/cancellable_cache_operation.dart';
import 'package:media_cache/src/cancellable_downloader.dart';
import 'package:media_cache/src/platform_downloader_factory.dart';
import 'package:media_cache/src/safe_cache_info_repository.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:unified_logger/unified_logger.dart';

/// Filenames written by [MediaCacheManager] end with
/// `_<microseconds>_<seq><ext>` (see `_relativePathFor`). Reclamation only
/// deletes *untracked* files matching this shape,
/// [_hasLegacyUrlTailName] or [_webHelperCacheFilePattern], so
/// externally-managed files that share the cache directory — e.g. the alias
/// manifest or caller-owned sidecar files — are never removed.
final RegExp _managedCacheFilePattern = RegExp(
  r'_\d{13,19}_\d+\.[A-Za-z0-9]+$',
);

/// Splits the `_<microseconds>_<seq>.<tail>` suffix this package writes,
/// capturing `<tail>` so [_hasLegacyUrlTailName] can judge it.
///
/// The timestamp run is pinned to the width of a microsecond epoch (13–19
/// digits; every write has carried 16 since 2001) rather than `\d+`, so an
/// externally-owned name that happens to carry a short `_<digits>_<digits>.`
/// infix — `report_2024_01.csv.gz` — is never a reclamation candidate.
final RegExp _timestampedCacheFilePattern = RegExp(
  r'_\d{13,19}_\d+\.([^/\\]*)$',
);

/// Filenames written by `flutter_cache_manager`'s WebHelper — the path behind
/// the inherited [CacheManager.downloadFile] / [CacheManager.getSingleFile] —
/// are `<uuid-v1><ext>` (and `<uuid-v1>.file` for not-modified responses).
/// Its eviction never deletes these files for this on-disk layout (it resolves
/// the relative path against the process CWD), so they orphan just like the
/// cancellable path's files. Cannot collide with seed media (raw hex event
/// ids have no dashes) or the alias manifest.
final RegExp _webHelperCacheFilePattern = RegExp(
  '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}'
  r'-[0-9a-fA-F]{12}\.[A-Za-z0-9]+$',
);

/// Longest sanitized cache key kept as the readable head of a cache
/// filename. `NAME_MAX` — the byte limit for a single path component — is
/// 255 on APFS, ext4 and f2fs, and `File.openWrite` fails with
/// `ENAMETOOLONG` past it. Proxied image URLs routinely run past 230
/// characters, and the image cache keys on the raw URL, so the sanitized key
/// has to be capped rather than trusted. The cap leaves room for the
/// `_<microseconds>_<seq><ext>` suffix under every value those three parts
/// can take.
const int _maxSanitizedKeyLength = 160;

/// Hex characters of the key digest appended when a sanitized key is
/// shortened, so two keys sharing a long prefix still land on distinct
/// filenames.
const int _keyDigestLength = 16;

/// Matches an extension [MediaCacheManager] will carry over from a URL.
/// Percent-encoded origin URLs embedded in image-proxy paths decode to
/// segments whose "extension" is an arbitrarily long tail (`.png?v=2`), which
/// neither describes a container nor matches [_managedCacheFilePattern].
/// Anything outside this shape falls back to
/// [MediaCacheConfig.defaultExtension]. Files already written under the
/// pre-cap behaviour are reclaimed via [_hasLegacyUrlTailName].
final RegExp _usableExtensionPattern = RegExp(r'^\.[A-Za-z0-9]{1,10}$');

/// Whether [name] is a file this package wrote before `_extensionFor` gained
/// [_usableExtensionPattern] — the same `_<microseconds>_<seq>.` infix, but a
/// tail carried over verbatim from a percent-decoded URL segment rather than
/// a container extension: `…_1723600000000000_4.png?v=2`, `…_4.jpg (1)`, or
/// the bare `…_4.` a segment ending in a dot produced.
///
/// Reclamation has to recognise these or their bytes are stranded for the
/// life of the install. Such a file stops being tracked the moment a
/// re-download writes today's clean name, and it never matched
/// [_managedCacheFilePattern], whose extension class is `[A-Za-z0-9]+`
/// anchored at end-of-string. Untracked *and* unmatched means neither
/// reclamation nor byte eviction could see it, so it sat on top of the
/// configured budget until `clearCache()`.
///
/// The tail is judged with [_usableExtensionPattern] itself rather than a
/// hand-written negation of it, so the two cannot drift apart: this accepts
/// exactly the tails today's `_extensionFor` would refuse to write.
bool _hasLegacyUrlTailName(String name) {
  final tail = _timestampedCacheFilePattern.firstMatch(name)?.group(1);
  if (tail == null) return false;
  return !_usableExtensionPattern.hasMatch('.$tail');
}

/// Untracked files younger than this are never reclaimed. Covers the window
/// where a download settled after the sweep's snapshots were taken (its store
/// row and manifest entry land after the snapshot but before the walk reaches
/// the file), and WebHelper's in-flight writes, which carry no in-flight
/// shield at all. A real orphan is simply picked up by a later sweep once it
/// has aged past the window.
const Duration _reclamationFreshnessWindow = Duration(minutes: 5);

/// Number of successful downloads between throttled in-session
/// [MediaCacheManager.enforceCacheLimits] passes.
const int _downloadsPerSweep = 25;

/// Minimum wall-clock gap between throttled in-session
/// [MediaCacheManager.enforceCacheLimits] passes, so heavy scrolling cannot
/// trigger back-to-back directory scans.
const Duration _minSweepInterval = Duration(seconds: 60);

/// {@template media_cache_config}
/// Configuration for [MediaCacheManager].
///
/// Provides sensible defaults that can be overridden for specific use cases.
/// {@endtemplate}
class MediaCacheConfig {
  /// {@macro media_cache_config}
  const MediaCacheConfig({
    required this.cacheKey,
    this.stalePeriod = const Duration(days: 14),
    this.maxNrOfCacheObjects = 200,
    this.maxCacheSizeBytes,
    this.connectionTimeout = const Duration(seconds: 15),
    this.idleTimeout = const Duration(seconds: 30),
    this.maxConnectionsPerHost = 6,
    this.enableSyncManifest = false,
    this.allowBadCertificatesInDebug = true,
    this.defaultExtension = '.bin',
  });

  /// Creates a configuration optimized for video caching.
  ///
  /// - Longer stale period (30 days)
  /// - More cache objects (1000)
  /// - Total on-disk budget of 2 GB, enforced by
  ///   [MediaCacheManager.enforceCacheLimits]
  /// - Longer timeouts for large downloads
  /// - Sync manifest enabled for instant playback
  const MediaCacheConfig.video({required String cacheKey})
    : this(
        cacheKey: cacheKey,
        stalePeriod: const Duration(days: 30),
        maxNrOfCacheObjects: 1000,
        maxCacheSizeBytes: 2 * 1024 * 1024 * 1024,
        connectionTimeout: const Duration(seconds: 30),
        idleTimeout: const Duration(minutes: 2),
        maxConnectionsPerHost: 4,
        enableSyncManifest: true,
        // AVURLAsset / ExoPlayer probe the container from the file
        // extension first. URLs that hash to a path with no extension
        // (e.g. `https://media.divine.video/<sha>` for original
        // uploads) would otherwise be cached as `.bin` and fail to
        // open with `Cannot Open`.
        defaultExtension: '.mp4',
      );

  /// Creates a configuration optimized for image caching.
  ///
  /// - Shorter stale period (7 days)
  /// - Fewer cache objects (200)
  /// - Total on-disk budget of 256 MB, enforced by
  ///   [MediaCacheManager.enforceCacheLimits]
  /// - Shorter timeouts for smaller downloads
  /// - No sync manifest needed
  const MediaCacheConfig.image({required String cacheKey})
    : this(
        cacheKey: cacheKey,
        stalePeriod: const Duration(days: 7),
        maxNrOfCacheObjects: 200,
        maxCacheSizeBytes: 256 * 1024 * 1024,
        connectionTimeout: const Duration(seconds: 10),
        idleTimeout: const Duration(seconds: 30),
        // Tuning choice (not a measured optimum): raised from 6 → 20 to
        // unblock surfaces like the profile grid that issue ~20 concurrent
        // thumbnail requests to the same CDN host. 6 was observed too low
        // under #4330; 20 leaves headroom over the typical grid column
        // count. Revisit if socket/memory pressure shows up in profiling.
        maxConnectionsPerHost: 20,
        enableSyncManifest: false,
        defaultExtension: '.jpg',
      );

  /// Unique key for this cache. Used as the cache directory name.
  final String cacheKey;

  /// Duration before cached files are considered stale.
  final Duration stalePeriod;

  /// Maximum number of objects to keep in cache.
  final int maxNrOfCacheObjects;

  /// Maximum total size of the on-disk cache directory, in bytes.
  ///
  /// `flutter_cache_manager` only bounds the cache by *object count*
  /// ([maxNrOfCacheObjects]); for media where individual files span
  /// kilobytes to tens of megabytes, a count limit lets the directory grow
  /// to many gigabytes. When set, [MediaCacheManager.enforceCacheLimits]
  /// evicts the oldest files first — ordered by the store's last-touch time,
  /// falling back to file mtime when it is unset — until the directory is back
  /// under this budget. `null` disables byte-based eviction (count limit only).
  final int? maxCacheSizeBytes;

  /// Timeout for establishing HTTP connections.
  ///
  /// Applied on Apple (`cupertino_http`) and dart:io fallback clients.
  /// Android Cronet currently ignores this value because `cronet_http` does
  /// not expose a matching configuration API.
  final Duration connectionTimeout;

  /// Timeout for idle HTTP connections.
  ///
  /// Applied on dart:io fallback clients.
  /// Android Cronet currently ignores this value because `cronet_http` does
  /// not expose a matching configuration API.
  final Duration idleTimeout;

  /// Maximum concurrent connections per host.
  final int maxConnectionsPerHost;

  /// Whether to maintain an in-memory manifest for synchronous lookups.
  ///
  /// When enabled, [MediaCacheManager.getCachedFileSync] can return cached
  /// files instantly without async overhead. Useful for video players that
  /// need immediate file access.
  final bool enableSyncManifest;

  /// Whether to allow bad certificates in debug mode on desktop platforms.
  ///
  /// Useful for local development with self-signed certificates.
  final bool allowBadCertificatesInDebug;

  /// Extension applied to cached files when the source URL has none.
  ///
  /// Native media frameworks (`AVURLAsset`, ExoPlayer) probe the
  /// container format from the file extension first. Hash-style URLs
  /// such as `https://media.divine.video/<sha>` (used for original
  /// uploads) would otherwise be cached as `.bin`, which AVFoundation
  /// rejects with `Cannot Open`. Set to `.mp4` for video caches and
  /// `.jpg` for image caches via the named factories.
  final String defaultExtension;
}

/// Tracks cache hit/miss statistics for observability.
///
/// Records hits, misses, and prefetch effectiveness. Use [toMap] to export
/// metrics for analytics reporting.
class CacheMetrics {
  /// Number of synchronous cache lookups that found a cached file.
  int hits = 0;

  /// Number of synchronous cache lookups that did not find a cached file.
  int misses = 0;

  /// Files that were prefetched AND later accessed via getCachedFileSync.
  int prefetchedUsed = 0;

  /// Total files that were prefetched (downloaded via preCacheFiles).
  int prefetchedTotal = 0;

  /// Cache hit rate as a ratio (0.0 to 1.0).
  double get hitRate {
    final total = hits + misses;
    if (total == 0) return 0;
    return hits / total;
  }

  /// Export metrics as a map for analytics reporting.
  Map<String, dynamic> toMap() => {
    'cache_hits': hits,
    'cache_misses': misses,
    'cache_hit_rate': hitRate,
    'prefetched_used': prefetchedUsed,
    'prefetched_total': prefetchedTotal,
  };

  /// Reset all counters to zero.
  void reset() {
    hits = 0;
    misses = 0;
    prefetchedUsed = 0;
    prefetchedTotal = 0;
  }
}

/// {@template media_cache_manager}
/// A configurable media cache manager built on `flutter_cache_manager`.
///
/// Features:
/// - Configurable cache size, stale period, and timeouts
/// - Corrupt cache file recovery via `SafeCacheInfoRepository`
/// - Optional in-memory manifest for synchronous file lookups
/// - Preset configurations for videos and images
/// - Cache hit/miss metrics via `metrics`
///
/// Example:
/// ```dart
/// // Create a video cache with sync manifest
/// final videoCache = MediaCacheManager(
///   config: MediaCacheConfig.video(cacheKey: 'my_video_cache'),
/// );
///
/// // Initialize manifest for sync lookups (call on app startup)
/// await videoCache.initialize();
///
/// // Get cached file synchronously (instant, no async overhead)
/// final file = videoCache.getCachedFileSync('video_123');
///
/// // Or cache a new file
/// final cachedFile = await videoCache.cacheFile(
///   'https://example.com/video.mp4',
///   key: 'video_123',
/// );
///
/// // Check cache performance
/// print('Hit rate: ${videoCache.metrics.hitRate}');
/// ```
/// {@endtemplate}

/// {@macro media_cache_manager}
class MediaCacheManager extends CacheManager {
  /// {@macro media_cache_manager}
  MediaCacheManager({
    required MediaCacheConfig config,
    @visibleForTesting DirectoryProvider? tempDirectoryProvider,
    @visibleForTesting CacheInfoRepository? repoOverride,
    @visibleForTesting CancellableDownloader? downloaderOverride,
    @visibleForTesting IOClient? fileServiceClientOverride,
    @visibleForTesting Duration? sweepThrottleOverride,
  }) : this._(
         config: config,
         tempDirectoryProvider: tempDirectoryProvider ?? getTemporaryDirectory,
         repoOverride: repoOverride,
         downloader: downloaderOverride ?? _createDefaultDownloader(config),
         // Built up-front and retained on the instance so close() can
         // dispose it. Without this the legacy non-cancellable cacheFile
         // path leaks an HttpClient on every MediaCacheManager.close().
         fileServiceClient: kIsWeb
             ? null
             : (fileServiceClientOverride ?? _buildFileServiceClient(config)),
         sweepThrottle: sweepThrottleOverride ?? _minSweepInterval,
       );

  MediaCacheManager._({
    required MediaCacheConfig config,
    required DirectoryProvider tempDirectoryProvider,
    required CacheInfoRepository? repoOverride,
    required CancellableDownloader downloader,
    required IOClient? fileServiceClient,
    required Duration sweepThrottle,
  }) : _config = config,
       _tempDirectoryProvider = tempDirectoryProvider,
       _repoOverride = repoOverride,
       _downloader = downloader,
       _fileServiceClient = fileServiceClient,
       _sweepThrottle = sweepThrottle,
       super(
         kIsWeb
             // coverage:ignore-start
             ? Config(
                 config.cacheKey,
                 stalePeriod: config.stalePeriod,
                 maxNrOfCacheObjects: config.maxNrOfCacheObjects,
               )
             // coverage:ignore-end
             : Config(
                 config.cacheKey,
                 stalePeriod: config.stalePeriod,
                 maxNrOfCacheObjects: config.maxNrOfCacheObjects,
                 repo:
                     repoOverride ??
                     SafeCacheInfoRepository(databaseName: config.cacheKey),
                 // Non-null on the non-web branch (kIsWeb == false here);
                 // the public ctor only nulls fileServiceClient on web.
                 // ignore: unnecessary_null_checks
                 fileService: HttpFileService(httpClient: fileServiceClient!),
               ),
       );

  static CancellableDownloader _createDefaultDownloader(
    MediaCacheConfig config,
  ) {
    return createPlatformDownloader(
      connectionTimeout: config.connectionTimeout,
      idleTimeout: config.idleTimeout,
      maxConnectionsPerHost: config.maxConnectionsPerHost,
      allowBadCertificatesInDebug: config.allowBadCertificatesInDebug,
      isDebugMode: kDebugMode,
      isWeb: kIsWeb,
    );
  }

  final MediaCacheConfig _config;
  final DirectoryProvider _tempDirectoryProvider;
  final CacheInfoRepository? _repoOverride;
  final CancellableDownloader _downloader;

  /// HTTP client backing the legacy non-cancellable
  /// [CacheManager.getFileStream] / [CacheManager.getSingleFile] path.
  /// Retained so it can be closed symmetrically in [close]. `null` on
  /// web (no `dart:io` HttpClient there).
  final IOClient? _fileServiceClient;

  /// Resolved `<tempDir>/<cacheKey>` path. Populated by [initialize] and
  /// reused by [cacheFileCancellable] to compute target file paths
  /// synchronously.
  String? _baseCacheDir;

  /// Monotonic counter to disambiguate filenames written within the same
  /// millisecond when the same key is downloaded repeatedly.
  int _downloadSeq = 0;

  /// Relative filenames currently being written by an in-flight download.
  ///
  /// [enforceCacheLimits] skips these so a reclamation pass never deletes a
  /// file mid-download (the file exists on disk before its cache-store row
  /// is written).
  final Set<String> _inFlightRelativePaths = {};

  /// Successful downloads since the last [enforceCacheLimits] pass. Drives
  /// the throttled in-session sweep so the directory stays bounded without
  /// running a full reconciliation after every single download.
  int _downloadsSinceSweep = 0;

  /// Guards against overlapping [enforceCacheLimits] runs.
  bool _sweepInProgress = false;

  /// Completes after the active sweep and any queued forced follow-up settle.
  Completer<void>? _activeSweepCompletion;

  /// A forced sweep requested while another pass is running.
  ///
  /// Ordinary background sweeps may still be coalesced, but callers that lower
  /// a user-configured budget must be able to await a pass that observes the
  /// new value instead of silently returning behind an older sweep.
  Completer<void>? _queuedForceSweep;

  /// When the last [enforceCacheLimits] pass started. Drives the time-based
  /// throttle so back-to-back sweeps cannot pile up during heavy scrolling.
  /// Seeded to the epoch so the first pass is never throttled.
  DateTime _lastSweepAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Minimum gap between sweeps — [_minSweepInterval] in production,
  /// shortenable in tests so trailing-sweep timing stays fast to exercise.
  final Duration _sweepThrottle;

  /// Running estimate of the cache directory's on-disk bytes. Incremented as
  /// downloads settle and re-synced to the walked total on every
  /// byte-eviction pass (which is also when deletions happen) — so drift
  /// only ever costs one extra window-gated sweep, never a missed budget.
  int _knownCacheBytes = 0;

  /// One-shot sweep armed when a download crosses the byte budget inside the
  /// throttle window, so the directory converges back under budget even if
  /// no further download ever lands (#8242). Cancelled by [close] and
  /// whenever a byte-eviction pass re-syncs the total.
  Timer? _pendingByteSweepTimer;

  /// Whether a download settled after the current sweep began. Its file may
  /// have missed the sweep's directory snapshot, so the total needs one
  /// follow-up resync after the throttle window.
  bool _directoryTotalNeedsResync = false;

  /// Runtime override for [MediaCacheConfig.maxCacheSizeBytes], set from a
  /// user preference. `null` falls back to the config default.
  int? _maxCacheSizeBytesOverride;

  /// In-memory manifest for synchronous lookups.
  /// Maps cache key to file path.
  final Map<String, String> _cacheManifest = {};

  /// Persistent alias → actual cache key mapping.
  ///
  /// Survives app restarts so that successful fallback downloads
  /// (cached under e.g. `<videoId>__fb1`) remain reachable via the
  /// stable `aliasKey` (e.g. `<videoId>`) on the next launch instead
  /// of forcing the prefetcher to retry the failing first-attempt URL.
  final Map<String, String> _aliasMap = {};

  /// Serialises writes to the on-disk alias map.
  Future<void> _aliasWriteQueue = Future<void>.value();

  /// Tracks keys currently being cached to prevent duplicate requests.
  final Map<String, _PendingCacheOperation> _pendingCacheOperations = {};

  /// Tracks cancellable operations currently in-flight.
  final Set<CancellableCacheOperation> _activeCancellableOperations = {};

  /// Tracks keys that were downloaded via [preCacheFiles] (prefetched).
  final Set<String> _prefetchedKeys = {};

  /// Cache hit/miss metrics for observability.
  final CacheMetrics metrics = CacheMetrics();

  /// Whether the cache manifest has been initialized.
  bool _manifestInitialized = false;

  bool _isClosed = false;

  /// Latched by [cancelInFlightDownloads], cleared by [resumeDownloads].
  /// While set, cancellable downloads complete with `null` instead of
  /// reaching the network, so autonomous prefetch loops (disk prefetcher
  /// cycles, [preCacheFiles] batches) cannot re-arm fresh native requests
  /// after a background cancellation.
  bool _downloadsSuspended = false;

  bool _isProcessingResponse(FileInfo fileInfo) =>
      fileInfo.statusCode == HttpStatus.accepted;

  /// Whether this cache manager has been initialized.
  bool get isInitialized => _manifestInitialized;

  /// The configuration used by this cache manager.
  MediaCacheConfig get mediaConfig => _config;

  /// The effective on-disk byte budget: the runtime override when set,
  /// otherwise [MediaCacheConfig.maxCacheSizeBytes].
  int? get maxCacheSizeBytes =>
      _maxCacheSizeBytesOverride ?? _config.maxCacheSizeBytes;

  /// Overrides the on-disk byte budget at runtime (e.g. from a user setting).
  /// Pass `null` to fall back to the configured default. Does not itself
  /// evict — call [enforceCacheLimits] afterwards to apply the new budget.
  set maxCacheSizeBytes(int? bytes) => _maxCacheSizeBytesOverride = bytes;

  static IOClient _buildFileServiceClient(MediaCacheConfig config) {
    final httpClient = HttpClient()
      ..connectionTimeout = config.connectionTimeout
      ..idleTimeout = config.idleTimeout
      ..maxConnectionsPerHost = config.maxConnectionsPerHost;

    // In debug mode on desktop, allow self-signed certificates
    if (config.allowBadCertificatesInDebug &&
        kDebugMode &&
        !kIsWeb &&
        (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      httpClient.badCertificateCallback = (cert, host, port) => true;
    }

    return IOClient(httpClient);
  }

  /// Initializes the cache manifest by loading all cached files from database.
  ///
  /// Should be called on app startup if [MediaCacheConfig.enableSyncManifest]
  /// is `true`. This enables [getCachedFileSync] to return files instantly.
  ///
  /// Safe to call multiple times - subsequent calls are no-ops.
  Future<void> initialize() async {
    // coverage:ignore-start
    if (kIsWeb) {
      _manifestInitialized = true;
      return;
    }
    // coverage:ignore-end

    if (!_config.enableSyncManifest || _manifestInitialized) {
      _manifestInitialized = true;
      return;
    }

    final repo = _repoOverride ?? config.repo;
    var repoOpened = false;
    try {
      // Read cache metadata via the Config's CacheInfoRepository
      // (JsonCacheInfoRepository wrapped by SafeCacheInfoRepository).
      // In tests a repo override may be injected to pre-populate the manifest
      // without needing a real JSON file on disk.
      if (!await repo.open()) {
        _manifestInitialized = true;
        return;
      }
      repoOpened = true;

      final objects = await repo.getAllObjects();
      final tempDir = await _tempDirectoryProvider();
      final baseCacheDir = path.join(tempDir.path, _config.cacheKey);
      _baseCacheDir = baseCacheDir;

      for (final obj in objects) {
        final fullPath = path.join(baseCacheDir, obj.relativePath);
        final file = File(fullPath);

        if (file.existsSync()) {
          _cacheManifest[obj.key] = fullPath;
        }
      }

      // Restore persisted alias → actualKey mappings so successful
      // fallback downloads from previous sessions remain reachable
      // via the stable alias on this launch.
      final aliasFile = File(path.join(baseCacheDir, 'aliases.json'));
      if (aliasFile.existsSync()) {
        try {
          final decoded = jsonDecode(await aliasFile.readAsString());
          if (decoded is Map<String, dynamic>) {
            var hadStaleEntries = false;
            for (final entry in decoded.entries) {
              final actualKey = entry.value;
              if (actualKey is! String) continue;
              final actualPath = _cacheManifest[actualKey];
              if (actualPath != null) {
                _aliasMap[entry.key] = actualKey;
                _cacheManifest[entry.key] = actualPath;
              } else {
                // Target was evicted by flutter_cache_manager's LRU; drop
                // the stale entry rather than letting aliases.json grow
                // unbounded across sessions.
                hadStaleEntries = true;
              }
            }
            if (hadStaleEntries) {
              unawaited(_persistAliasMap());
            }
          }
        } on Exception catch (_) {
          // Corrupt alias file → ignore, will be overwritten on next write.
        }
      }

      _manifestInitialized = true;
    } on Exception catch (_) {
      // Don't throw - degraded functionality is better than crash
      _manifestInitialized = true;
    } finally {
      if (repoOpened) {
        try {
          await repo.close();
        } on Object {
          // Best-effort lease release; initialization already completed.
        }
      }
    }
  }

  /// Persists the current [_aliasMap] to disk. Calls are serialised so
  /// concurrent fallback successes never interleave writes.
  Future<void> _persistAliasMap() {
    // coverage:ignore-start
    if (kIsWeb) return Future<void>.value();
    // coverage:ignore-end
    final snapshot = Map<String, String>.from(_aliasMap);
    final next = _aliasWriteQueue.then((_) async {
      try {
        final tempDir = await _tempDirectoryProvider();
        final baseCacheDir = Directory(
          path.join(tempDir.path, _config.cacheKey),
        );
        if (!baseCacheDir.existsSync()) {
          baseCacheDir.createSync(recursive: true);
        }
        final aliasFile = File(path.join(baseCacheDir.path, 'aliases.json'));
        final tmpFile = File('${aliasFile.path}.tmp');
        await tmpFile.writeAsString(jsonEncode(snapshot), flush: true);
        await tmpFile.rename(aliasFile.path);
      } on Exception catch (_) {
        // Best-effort; in-memory alias map still works for this session.
      }
    });
    _aliasWriteQueue = next;
    return next;
  }

  /// Gets a cached file synchronously using the in-memory manifest.
  ///
  /// Returns `null` if:
  /// - The file is not in the manifest
  /// - The file no longer exists on disk
  /// - [MediaCacheConfig.enableSyncManifest] is `false`
  /// - [initialize] has not been called
  ///
  /// This method has zero async overhead, making it ideal for video players
  /// that need to decide immediately whether to use a cached file or network.
  File? getCachedFileSync(String key) {
    if (!_config.enableSyncManifest) {
      return null;
    }

    final cachedPath = _cacheManifest[key];
    if (cachedPath == null) {
      metrics.misses++;
      return null;
    }

    // Verify file still exists
    final file = File(cachedPath);
    if (!file.existsSync()) {
      // Remove stale entry from manifest and any aliases pointing at it.
      _cacheManifest.remove(key);
      final orphanedAliases = _aliasMap.entries
          .where((e) => e.value == key)
          .map((e) => e.key)
          .toList(growable: false);
      if (orphanedAliases.isNotEmpty) {
        for (final alias in orphanedAliases) {
          _aliasMap.remove(alias);
          _cacheManifest.remove(alias);
        }
        unawaited(_persistAliasMap());
      }
      metrics.misses++;
      return null;
    }

    metrics.hits++;

    // Track prefetch effectiveness
    if (_prefetchedKeys.contains(key)) {
      metrics.prefetchedUsed++;
    }

    return file;
  }

  /// Downloads and caches a file, returning the cached [File].
  ///
  /// If the file is already being cached (duplicate request), waits for and
  /// returns the result of the existing operation.
  ///
  /// Parameters:
  /// - [url]: The URL to download from
  /// - [key]: Unique key for this cached item (used for lookups)
  /// - [authHeaders]: Optional HTTP headers (e.g., for authenticated requests)
  ///
  /// Returns the cached [File], or `null` if caching failed.
  Future<File?> cacheFile(
    String url, {
    required String key,
    Map<String, String>? authHeaders,
  }) async {
    if (_isClosed) return null;

    // Check if already cached
    final existingFile = await getFileFromCache(key);
    if (existingFile != null && existingFile.file.existsSync()) {
      // Update manifest
      if (_config.enableSyncManifest) {
        _cacheManifest[key] = existingFile.file.path;
      }
      return existingFile.file;
    }

    // Check if already being cached
    if (_pendingCacheOperations.containsKey(key)) {
      return _pendingCacheOperations[key]!.completer.future.then(
        (result) => result.file,
      );
    }

    // Start caching
    final pendingOperation = _PendingCacheOperation();
    final completer = pendingOperation.completer;
    _pendingCacheOperations[key] = pendingOperation;

    final settlement = () async {
      try {
        final fileInfo = await downloadFile(
          url,
          key: key,
          authHeaders: authHeaders ?? {},
        );

        if (_isProcessingResponse(fileInfo)) {
          await removeCachedFile(key);
          try {
            if (fileInfo.file.existsSync()) {
              await fileInfo.file.delete();
            }
          } on Object {
            // Best-effort cleanup; the cache metadata has already been
            // removed so the processing response cannot be replayed.
          }
          if (!completer.isCompleted) {
            completer.complete(const CancellableDownloadResult(file: null));
          }
          return;
        }

        // Update manifest
        if (_config.enableSyncManifest && !_isClosed) {
          _cacheManifest[key] = fileInfo.file.path;
        }

        _recordSuccessfulDownload(fileInfo.file);

        if (!completer.isCompleted) {
          completer.complete(
            CancellableDownloadResult(file: _isClosed ? null : fileInfo.file),
          );
        }
      } on Exception {
        if (!completer.isCompleted) {
          completer.complete(const CancellableDownloadResult(file: null));
        }
      } finally {
        _pendingCacheOperations.remove(key);
      }
    }();
    pendingOperation.settlement = settlement;
    unawaited(settlement);

    return completer.future.then((result) => result.file);
  }

  /// Downloads and caches a file with the ability to cancel mid-download.
  ///
  /// Unlike [cacheFile], this returns a [CancellableCacheOperation] whose
  /// underlying HTTP stream can be torn down immediately via
  /// `CancellableCacheOperation.cancel()`, freeing bandwidth for
  /// higher-priority downloads.
  ///
  /// Returns a completed operation instantly if the file is already cached.
  ///
  /// When [aliasKey] is provided, the manifest also records the resulting
  /// file path under [aliasKey] on success, and the fast-path lookup
  /// considers both keys. This lets callers retry the same logical asset
  /// under multiple cache keys (e.g. one per fallback URL) without
  /// inheriting partially-cached or otherwise broken data from a previous
  /// attempt, while still letting consumers look the file up by the
  /// stable [aliasKey].
  CancellableCacheOperation cacheFileCancellable(
    String url, {
    required String key,
    String? aliasKey,
    Map<String, String>? authHeaders,
  }) {
    return _cacheFileCancellable(
      url,
      key: key,
      aliasKey: aliasKey,
      authHeaders: authHeaders,
    );
  }

  CancellableCacheOperation _cacheFileCancellable(
    String url, {
    required String key,
    String? aliasKey,
    Map<String, String>? authHeaders,
    bool trackPrefetchMetrics = true,
  }) {
    if (_isClosed) {
      return CancellableCacheOperation.fromDownload(_CompletedNullDownload());
    }

    // Fast path: already cached on disk.
    if (_config.enableSyncManifest) {
      final cached =
          getCachedFileSync(key) ??
          (aliasKey != null ? getCachedFileSync(aliasKey) : null);
      if (cached != null) return CancellableCacheOperation.completed(cached);
    }

    // Suspended (app backgrounded): refuse to start anything new. Prefetch
    // loops keep requesting the next item after their current download is
    // cancelled; without this gate they would re-arm fresh native requests
    // right in the suspension window [cancelInFlightDownloads] just cleared.
    if (_downloadsSuspended) {
      return CancellableCacheOperation.fromDownload(_CompletedNullDownload());
    }

    // Join an in-flight download for the same key (started by either
    // cacheFile or a prior cacheFileCancellable call) instead of launching
    // a second concurrent download that would orphan the first file on disk.
    if (_pendingCacheOperations.containsKey(key)) {
      final pendingOperation = _pendingCacheOperations[key]!;
      final sharedFuture = pendingOperation.completer.future;
      var localCancelled = false;
      final localCompleter = Completer<CancellableDownloadResult>();
      unawaited(
        sharedFuture.then((result) {
          if (!localCompleter.isCompleted) {
            localCompleter.complete(
              localCancelled
                  ? const CancellableDownloadResult(file: null)
                  : result,
            );
          }
        }),
      );
      final joinOp = CancellableCacheOperation.fromDownload(
        _DeferredDownload(
          future: localCompleter.future,
          progressBytes: pendingOperation.progressBytes,
          cancel: () {
            if (localCancelled) return;
            localCancelled = true;
            if (!localCompleter.isCompleted) {
              localCompleter.complete(
                const CancellableDownloadResult(file: null),
              );
            }
          },
          // coverage:ignore-start
          isCancelledGetter: () => localCancelled,
          // coverage:ignore-end
        ),
        cacheKey: key,
      );
      _activeCancellableOperations.add(joinOp);
      unawaited(
        joinOp.file.whenComplete(() {
          _activeCancellableOperations.remove(joinOp);
        }),
      );
      return joinOp;
    }

    if (trackPrefetchMetrics) {
      _prefetchedKeys.add(key);
      metrics.prefetchedTotal++;
    }

    final relativePath = _relativePathFor(key, url);
    // Shield the not-yet-registered file from a concurrent reclamation pass
    // (added before the file exists, removed once the download settles).
    _inFlightRelativePaths.add(relativePath);
    final pendingOperation = _PendingCacheOperation.withProgress();
    final completer = pendingOperation.completer;
    // Register before the async download starts so any concurrent caller
    // (cacheFile or another cacheFileCancellable) for the same key joins
    // this operation instead of issuing a second download.
    _pendingCacheOperations[key] = pendingOperation;
    CancellableDownload? activeDownload;
    StreamSubscription<int>? progressSubscription;
    var cancelledBeforeStart = false;
    File? completedFile;

    Future<void> startDownload() async {
      try {
        final baseDir = await _resolveBaseCacheDir();
        if (cancelledBeforeStart) {
          if (!completer.isCompleted) {
            completer.complete(const CancellableDownloadResult(file: null));
          }
          return;
        }
        final targetFile = File(path.join(baseDir, relativePath));
        final download = _downloader.download(
          url: url,
          targetFile: targetFile,
          headers: authHeaders,
        );
        activeDownload = download;
        progressSubscription = download.progressBytes.listen(
          pendingOperation.addProgress,
        );
        final downloadResult = await download.result;
        final file = downloadResult.file;
        if (file != null && !download.isCancelled) {
          // Register in flutter_cache_manager's store so the file survives
          // app restart and shows up in [getAllObjects] on next launch.
          try {
            await store.putFile(
              CacheObject(
                url,
                key: key,
                relativePath: relativePath,
                validTill: DateTime.now().add(_config.stalePeriod),
              ),
            );
          } on Object catch (_) {
            // Best-effort persistence; in-memory manifest still works.
          }
          if (_config.enableSyncManifest) {
            _cacheManifest[key] = file.path;
            if (aliasKey != null) {
              _cacheManifest[aliasKey] = file.path;
              if (_aliasMap[aliasKey] != key) {
                _aliasMap[aliasKey] = key;
                unawaited(_persistAliasMap());
              }
            }
          }
          completedFile = file;
        }
        if (!completer.isCompleted) completer.complete(downloadResult);
      } on Object catch (error) {
        Log.warning(
          'MediaCacheManager: download setup failed (${error.runtimeType})',
          name: 'MediaCache',
          category: LogCategory.video,
        );
        if (!completer.isCompleted) {
          completer.complete(const CancellableDownloadResult(file: null));
        }
      } finally {
        await progressSubscription?.cancel();
        await pendingOperation.closeProgress();
        _pendingCacheOperations.remove(key);
        _inFlightRelativePaths.remove(relativePath);
        final settledFile = completedFile;
        if (settledFile != null) _recordSuccessfulDownload(settledFile);
      }
    }

    final settlement = startDownload();
    pendingOperation.settlement = settlement;
    unawaited(settlement);

    final operation = CancellableCacheOperation.fromDownload(
      _DeferredDownload(
        future: completer.future,
        progressBytes: pendingOperation.progressBytes,
        cancel: () {
          cancelledBeforeStart = true;
          activeDownload?.cancel();
        },
        // coverage:ignore-start
        isCancelledGetter: () =>
            activeDownload?.isCancelled ?? cancelledBeforeStart,
        // coverage:ignore-end
      ),
      cacheKey: key,
    );

    _activeCancellableOperations.add(operation);
    unawaited(
      operation.file.whenComplete(() {
        _activeCancellableOperations.remove(operation);
      }),
    );

    return operation;
  }

  /// Returns the base cache directory, resolving and caching it on first use.
  Future<String> _resolveBaseCacheDir() async {
    final cached = _baseCacheDir;
    if (cached != null) return cached;
    final tempDir = await _tempDirectoryProvider();
    final base = path.join(tempDir.path, _config.cacheKey);
    final dir = Directory(base);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    _baseCacheDir = base;
    return base;
  }

  /// Generates a unique relative filename for [key]. The filename embeds the
  /// cache key plus a monotonic counter and timestamp so concurrent
  /// downloads of the same key cannot collide on disk.
  ///
  /// The result always fits within `NAME_MAX`: the sanitizer emits nothing
  /// outside `[A-Za-z0-9._-]`, so the key's [_maxSanitizedKeyLength]
  /// characters are [_maxSanitizedKeyLength] bytes, and the extension adds at
  /// most 11. Even at the 19-digit ceiling for both the timestamp and the
  /// counter the name stops at 211 bytes, short of 255.
  String _relativePathFor(String key, String url) {
    final safeKey = _sanitizedKeyFor(key);
    final ext = _extensionFor(url);
    final seq = ++_downloadSeq;
    final ts = DateTime.now().microsecondsSinceEpoch;
    return '${safeKey}_${ts}_$seq$ext';
  }

  /// Renders [key] as the readable head of a cache filename.
  ///
  /// Non-filesystem-safe characters (slashes, colons, `?`, Unicode, etc.) are
  /// replaced with `_` so the path never creates unintended sub-directories.
  /// A key past [_maxSanitizedKeyLength] — every image cached under a long
  /// proxied URL — keeps as much of its head as fits and ends in a digest of
  /// the full key, so distinct keys cannot be shortened onto the same name.
  ///
  /// Only the filename changes: cache lookups resolve through the stored
  /// `CacheObject.relativePath`, never by recomputing this from the key, so
  /// entries written before the cap stay reachable.
  String _sanitizedKeyFor(String key) {
    final safeKey = key.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
    if (safeKey.length <= _maxSanitizedKeyLength) return safeKey;
    final digest = sha256
        .convert(utf8.encode(key))
        .toString()
        .substring(0, _keyDigestLength);
    final head = safeKey.substring(
      0,
      _maxSanitizedKeyLength - _keyDigestLength - 1,
    );
    return '${head}_$digest';
  }

  String _extensionFor(String url) {
    try {
      final uri = Uri.parse(url);
      final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
      final ext = path.extension(last);
      if (_usableExtensionPattern.hasMatch(ext)) return ext;
    } on Object catch (_) {
      // Fall through to default.
    }
    final fallback = _config.defaultExtension;
    return _usableExtensionPattern.hasMatch(fallback) ? fallback : '.bin';
  }

  /// Runs a throttled [enforceCacheLimits] pass once enough downloads have
  /// accumulated since the last run — or as soon as the running byte total
  /// crosses the budget — keeping the directory bounded during a long
  /// session without sweeping after every single download.
  void _maybeEnforceCacheLimits() {
    final budget = maxCacheSizeBytes;
    final overBudget = budget != null && _knownCacheBytes > budget;
    if (_downloadsSinceSweep < _downloadsPerSweep && !overBudget) return;
    // Keep the counter while a sweep would be skipped anyway (one is already
    // running, or the throttle window is still open) so these downloads count
    // toward the next eligible pass instead of being consumed silently.
    if (_sweepInProgress ||
        clock.now().difference(_lastSweepAt) < _sweepThrottle) {
      // A budget crossing must not wait for a future download that may never
      // land: arm a one-shot pass at window expiry (#8242). A download that
      // settles during the active sweep is handled by its completion path.
      if (overBudget && !_sweepInProgress) _armTrailingSweep();
      return;
    }
    if (_downloadsSinceSweep >= _downloadsPerSweep) _downloadsSinceSweep = 0;
    unawaited(enforceCacheLimits());
  }

  /// Schedules the over-budget follow-up sweep for when the throttle window
  /// reopens. On firing it re-checks every gate: the manager may have closed,
  /// a sweep may have run (re-syncing the total), or a forced sweep may have
  /// restarted the window — in which case it re-arms rather than running
  /// inside the window.
  void _armTrailingSweep() {
    if (_pendingByteSweepTimer != null || _isClosed) return;
    final remaining = _sweepThrottle - clock.now().difference(_lastSweepAt);
    final delay = remaining.isNegative
        ? Duration.zero
        : remaining + const Duration(milliseconds: 100);
    _pendingByteSweepTimer = Timer(delay, () {
      _pendingByteSweepTimer = null;
      if (_isClosed || _sweepInProgress) return;
      final budget = maxCacheSizeBytes;
      if (budget == null ||
          (_knownCacheBytes <= budget && !_directoryTotalNeedsResync)) {
        return;
      }
      if (clock.now().difference(_lastSweepAt) < _sweepThrottle) {
        _armTrailingSweep();
        return;
      }
      unawaited(enforceCacheLimits());
    });
  }

  void _cancelTrailingSweep() {
    _pendingByteSweepTimer?.cancel();
    _pendingByteSweepTimer = null;
  }

  void _recordSuccessfulDownload(File file) {
    _downloadsSinceSweep++;
    try {
      // statSync reports a vanished file as notFound with size -1 rather
      // than throwing; either way the estimate runs low until the next
      // sweep re-syncs it. The catch covers platforms without dart:io.
      final size = file.statSync().size;
      if (size > 0) _knownCacheBytes += size;
    } on Object {
      // See above: the next sweep re-syncs the estimate.
    }
    if (_sweepInProgress) {
      _directoryTotalNeedsResync = true;
      return;
    }
    _maybeEnforceCacheLimits();
  }

  /// Reclaims leaked cache files and enforces
  /// [MediaCacheConfig.maxCacheSizeBytes].
  ///
  /// Two passes, both safe to run at any time and never throwing:
  ///
  /// 1. **Reclamation** — deletes top-level files in the cache directory that
  ///    neither the cache store nor the sync manifest still tracks and match
  ///    [_managedCacheFilePattern], [_hasLegacyUrlTailName] or
  ///    [_webHelperCacheFilePattern].
  ///    `flutter_cache_manager` drops database rows on eviction without
  ///    reliably deleting the underlying file for this on-disk layout, so
  ///    evicted and superseded downloads pile up as untracked orphans; this
  ///    pass removes them. Files still referenced by the manifest (live
  ///    entries the store's object cap has demoted), files that match neither
  ///    pattern (the alias manifest and caller-owned sidecars), caller-owned
  ///    subdirectories, in-flight downloads, and files written within
  ///    [_reclamationFreshnessWindow] are left untouched.
  /// 2. **Byte eviction** — when [MediaCacheConfig.maxCacheSizeBytes] is set,
  ///    totals every file in the directory (so the enforced number matches
  ///    what callers measure on disk) and deletes the oldest deletable files
  ///    first — tracked store rows plus files kept alive only by the sync
  ///    manifest — until the directory is back under budget or no candidates
  ///    remain. Undeletable bytes (the alias manifest, in-flight partials,
  ///    unmanaged files) count towards the total but are never removed.
  ///    Store touch time is preferred when available, with file mtime as the
  ///    fallback. The sync-manifest read path does not refresh `touched`, so
  ///    in practice this trims by download age rather than true last-access.
  ///
  /// Safe to call at startup and repeatedly; overlapping background calls are
  /// ignored, while an overlapping forced call queues one follow-up pass.
  /// Unforced calls within the sweep throttle ([_minSweepInterval] in
  /// production) of the previous pass are skipped.
  ///
  /// I/O is intentionally asynchronous: the directory is walked with a
  /// `Directory.list()` stream and files are removed with `File.delete()` so
  /// the event loop yields between entries instead of the whole sweep blocking
  /// the isolate. Cheap metadata reads stay synchronous (`statSync`) per
  /// `avoid_slow_async_io` — the async variants of those add more overhead
  /// than they save.
  Future<void> enforceCacheLimits({bool force = false}) async {
    if (_isClosed) return;
    if (_sweepInProgress) {
      if (!force) return;
      final queued = _queuedForceSweep ??= Completer<void>();
      return queued.future;
    }
    if (!force && clock.now().difference(_lastSweepAt) < _sweepThrottle) {
      return;
    }
    _sweepInProgress = true;
    // A download settling after this point sets the flag again. Clearing it
    // synchronously here makes this pass the owner of the next clean snapshot.
    _directoryTotalNeedsResync = false;
    final sweepCompletion = Completer<void>();
    _activeSweepCompletion = sweepCompletion;
    var repoOpened = false;
    final started = clock.now();
    final repo = _repoOverride ?? config.repo;
    try {
      if (!await repo.open()) return;
      repoOpened = true;
      final objects = await repo.getAllObjects();
      final baseDir = await _resolveBaseCacheDir();

      final trackedNames = {for (final object in objects) object.relativePath};
      final reclaimed = await _reclaimOrphanedFiles(baseDir, trackedNames);

      final budget = maxCacheSizeBytes;
      var evictedCount = 0;
      var evictedBytes = 0;
      int? directoryBytes;
      if (budget != null) {
        final evicted = await _evictToByteBudget(
          baseDir,
          objects,
          budget,
          repo,
        );
        evictedCount = evicted.deletedCount;
        evictedBytes = evicted.deletedBytes;
        directoryBytes = evicted.directoryBytes;
      }
      final elapsed = clock.now().difference(started);
      Log.info(
        'MediaCacheManager(${_config.cacheKey}): sweep reclaimed $reclaimed '
        'orphans, evicted $evictedCount files ($evictedBytes bytes)'
        '${directoryBytes == null ? '' : '; directory $directoryBytes bytes '
                  'of $budget budget'}'
        '; took ${elapsed.inMilliseconds}ms',
        name: 'MediaCache',
        category: LogCategory.video,
      );
    } on Object catch (error) {
      Log.warning(
        'MediaCacheManager: enforceCacheLimits failed: $error',
        name: 'MediaCache',
        category: LogCategory.video,
      );
    } finally {
      if (repoOpened) {
        try {
          await repo.close();
        } on Object {
          // The sweep is best-effort; a later pass can retry persistence.
        }
      }
      _sweepInProgress = false;
      // Measure the throttle window from completion, not start, so a slow
      // sweep can't immediately re-trigger back-to-back and monopolise I/O.
      // Only stamped for passes that got past open(): a failed repository
      // open (e.g. cold start) must not throttle out the retry.
      if (repoOpened) _lastSweepAt = clock.now();

      try {
        final queued = _queuedForceSweep;
        _queuedForceSweep = null;
        if (queued != null) {
          await enforceCacheLimits(force: true);
          if (!queued.isCompleted) queued.complete();
        }
      } finally {
        if (!sweepCompletion.isCompleted) sweepCompletion.complete();
        if (identical(_activeSweepCompletion, sweepCompletion)) {
          _activeSweepCompletion = null;
        }
      }
      if (_directoryTotalNeedsResync) _armTrailingSweep();
    }
  }

  /// Returns the number of orphaned files it deleted.
  Future<int> _reclaimOrphanedFiles(
    String baseDir,
    Set<String> trackedNames,
  ) async {
    final dir = Directory(baseDir);
    if (!dir.existsSync()) return 0;
    // Files the sync manifest still points at are live cache entries — even
    // when flutter_cache_manager has dropped their row from its capped store
    // (its object cap is far smaller than the manifest can grow). Treating
    // those as orphans deletes files getCachedFileSync is actively serving,
    // which forces an immediate re-download that re-populates the manifest and
    // triggers the next sweep — a churn storm that reads as constant jank.
    // Protect anything the manifest references.
    final manifestNames = {
      for (final filePath in _cacheManifest.values) path.basename(filePath),
    };
    final freshnessCutoff = clock.now().subtract(_reclamationFreshnessWindow);
    var reclaimed = 0;
    // `Directory.list()` yields between entries, so a large reclamation pass
    // does not block the isolate the way a `listSync()` loop would.
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = path.basename(entity.path);
      if (trackedNames.contains(name)) continue;
      if (manifestNames.contains(name)) continue;
      if (_inFlightRelativePaths.contains(name)) continue;
      if (!_managedCacheFilePattern.hasMatch(name) &&
          !_hasLegacyUrlTailName(name) &&
          !_webHelperCacheFilePattern.hasMatch(name)) {
        continue;
      }
      // Freshness guard (see [_reclamationFreshnessWindow]): a download that
      // settled after the snapshots above were taken is untracked here yet
      // fully live, and WebHelper's in-flight writes have no shield entry.
      // Both carry a fresh mtime, so recently-written files stay untouched.
      if (entity.statSync().modified.isAfter(freshnessCutoff)) continue;
      if (await _deleteFile(entity)) reclaimed++;
    }
    return reclaimed;
  }

  /// Returns what it deleted plus the directory's post-eviction byte total,
  /// which also re-syncs [_knownCacheBytes] and disarms any pending trailing
  /// sweep — after this pass, only a fresh download can arm one again, so an
  /// over-budget residue of undeletable bytes cannot spin sweeps in a loop.
  Future<({int deletedCount, int deletedBytes, int directoryBytes})>
  _evictToByteBudget(
    String baseDir,
    List<CacheObject> objects,
    int budget,
    CacheInfoRepository repo,
  ) async {
    // The budget governs the whole directory, matching what callers measure
    // when they size the cache on disk. Undeletable bytes — the alias
    // manifest, in-flight partial downloads, files matching neither managed
    // pattern — count towards the total but are never eviction candidates,
    // so the loop below simply stops once the candidates run out.
    final sizesByRelativePath = <String, int>{};
    final modifiedByRelativePath = <String, DateTime>{};
    var total = 0;
    final pendingDirectories = <Directory>[Directory(baseDir)];
    while (pendingDirectories.isNotEmpty) {
      final directory = pendingDirectories.removeLast();
      try {
        await for (final entity in directory.list(followLinks: false)) {
          if (entity is Directory) {
            pendingDirectories.add(entity);
            continue;
          }
          if (entity is! File) continue;
          final stat = entity.statSync();
          if (stat.type == FileSystemEntityType.notFound) continue;
          final relativePath = path.relative(entity.path, from: baseDir);
          sizesByRelativePath[relativePath] = stat.size;
          modifiedByRelativePath[relativePath] = stat.modified;
          total += stat.size;
        }
      } on Object catch (error) {
        // Match StorageManagementService's measurement: one unreadable
        // subtree must not discard bytes already counted from its siblings.
        Log.warning(
          'MediaCacheManager: sizing ${directory.path} failed: $error',
          name: 'MediaCache',
          category: LogCategory.video,
        );
      }
    }
    if (total <= budget) {
      _knownCacheBytes = total;
      _cancelTrailingSweep();
      return (
        deletedCount: 0,
        deletedBytes: 0,
        directoryBytes: total,
      );
    }

    final entriesByRelativePath = <String, _BudgetedCacheFile>{};
    for (final object in objects) {
      final size = sizesByRelativePath[object.relativePath];
      if (size == null) continue;
      entriesByRelativePath[object.relativePath] = _BudgetedCacheFile(
        object: object,
        file: File(path.join(baseDir, object.relativePath)),
        size: size,
        lastUsed:
            object.touched ?? modifiedByRelativePath[object.relativePath]!,
      );
    }

    // The sync manifest can keep a cache file live after
    // flutter_cache_manager has demoted its row past the object-count limit.
    // Those files are protected from orphan reclamation, so they must stay
    // eligible for byte eviction.
    for (final filePath in _cacheManifest.values) {
      final relativePath = path.relative(filePath, from: baseDir);
      if (entriesByRelativePath.containsKey(relativePath) ||
          _inFlightRelativePaths.contains(relativePath)) {
        continue;
      }
      final size = sizesByRelativePath[relativePath];
      if (size == null) continue;
      entriesByRelativePath[relativePath] = _BudgetedCacheFile(
        file: File(path.join(baseDir, relativePath)),
        size: size,
        lastUsed: modifiedByRelativePath[relativePath]!,
      );
    }

    // Oldest first (last-touch time, else file mtime) so newer items survive.
    final entries = entriesByRelativePath.values.toList()
      ..sort((a, b) => a.lastUsed.compareTo(b.lastUsed));
    final removedIds = <int>[];
    var aliasMapChanged = false;
    var deletedCount = 0;
    var deletedBytes = 0;
    for (final entry in entries) {
      if (total <= budget) break;
      if (!await _deleteFile(entry.file)) continue;
      total -= entry.size;
      deletedCount++;
      deletedBytes += entry.size;
      final object = entry.object;
      final id = object?.id;
      if (id != null) removedIds.add(id);
      final removedManifestKeys = <String>{
        if (object != null) object.key,
        for (final manifestEntry in _cacheManifest.entries)
          if (manifestEntry.value == entry.file.path) manifestEntry.key,
      };
      _cacheManifest.removeWhere(
        (key, value) =>
            removedManifestKeys.contains(key) || value == entry.file.path,
      );
      final aliasesToRemove = _aliasMap.entries
          .where(
            (alias) =>
                removedManifestKeys.contains(alias.key) ||
                removedManifestKeys.contains(alias.value),
          )
          .map((alias) => alias.key)
          .toList(growable: false);
      if (aliasesToRemove.isNotEmpty) {
        aliasMapChanged = true;
        aliasesToRemove.forEach(_aliasMap.remove);
      }
    }
    if (removedIds.isNotEmpty) {
      await repo.deleteAll(removedIds);
    }
    if (aliasMapChanged) await _persistAliasMap();
    _knownCacheBytes = total;
    _cancelTrailingSweep();
    return (
      deletedCount: deletedCount,
      deletedBytes: deletedBytes,
      directoryBytes: total,
    );
  }

  /// Deletes [file] asynchronously and reports whether it was removed. The
  /// surrounding loop yields between deletions. No existence pre-check: a
  /// missing file throws [PathNotFoundException] and is treated like any other
  /// failed unlink.
  Future<bool> _deleteFile(File file) async {
    try {
      await file.delete();
      return true;
    } on Object catch (_) {
      // Best-effort; anything left behind is retried on the next pass.
      return false;
    }
  }

  /// Checks if a file is cached (async version).
  ///
  /// For synchronous checks, use [getCachedFileSync] instead.
  Future<bool> isFileCached(String key) async {
    try {
      final fileInfo = await getFileFromCache(key);
      final isCached = fileInfo != null && fileInfo.file.existsSync();

      // Update manifest if cached
      if (isCached && _config.enableSyncManifest) {
        _cacheManifest[key] = fileInfo.file.path;
      }

      return isCached;
    } on Exception {
      return false;
    }
  }

  /// Pre-caches multiple files in batches.
  ///
  /// Parameters:
  /// - [items]: List of (url, key) pairs to cache
  /// - [batchSize]: Maximum concurrent downloads (default: 3)
  /// - [authHeadersProvider]: Optional function to provide auth headers per key
  Future<void> preCacheFiles(
    List<({String url, String key})> items, {
    int batchSize = 3,
    Map<String, String>? Function(String key)? authHeadersProvider,
  }) async {
    if (items.isEmpty) return;

    // Track all items as prefetched for metrics
    for (final item in items) {
      _prefetchedKeys.add(item.key);
    }
    metrics.prefetchedTotal += items.length;

    final inFlightByKey = <String, Future<File?>>{};

    // Process in batches
    for (var i = 0; i < items.length; i += batchSize) {
      // Backgrounded mid-run: stop opening new batches. The downloads would
      // be refused by the suspension gate anyway; bailing here also skips
      // the per-item cache probes. Callers re-trigger prefetch on the next
      // interaction after resume.
      if (_downloadsSuspended) return;
      final batch = <Future<File?>>[];
      final end = (i + batchSize > items.length) ? items.length : i + batchSize;

      for (var j = i; j < end; j++) {
        final item = items[j];

        // Skip if already cached
        if (await isFileCached(item.key)) {
          continue;
        }

        final existingDownload = inFlightByKey[item.key];
        if (existingDownload != null) {
          batch.add(existingDownload);
          continue;
        }

        final downloadFuture =
            _cacheFileCancellable(
              item.url,
              key: item.key,
              authHeaders: authHeadersProvider?.call(item.key),
              trackPrefetchMetrics: false,
            ).file.whenComplete(() {
              inFlightByKey.removeWhere((key, _) => key == item.key);
            });
        inFlightByKey[item.key] = downloadFuture;
        batch.add(downloadFuture);
      }

      // Wait for batch to complete
      await Future.wait(batch);
    }
  }

  /// Removes a cached file by key.
  ///
  /// Useful for removing corrupted files so they can be re-downloaded.
  Future<void> removeCachedFile(String key) async {
    await removeFile(key);

    final aliasKeysToRemove = _aliasMap.entries
        .where((entry) => entry.value == key)
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final aliasKey in aliasKeysToRemove) {
      _aliasMap.remove(aliasKey);
      _cacheManifest.remove(aliasKey);
    }
    if (aliasKeysToRemove.isNotEmpty) {
      await _persistAliasMap();
    }

    // Remove from manifest
    _cacheManifest.remove(key);
    unawaited(Future(() => _pendingCacheOperations.remove(key)));
  }

  /// Clears all cached files.
  Future<void> clearCache() async {
    await emptyCache();

    // Clear manifest
    _cacheManifest.clear();
    if (_aliasMap.isNotEmpty) {
      _aliasMap.clear();
      await _persistAliasMap();
    }
    _pendingCacheOperations.clear();
    _knownCacheBytes = 0;
    _cancelTrailingSweep();
  }

  /// Returns basic cache statistics including hit/miss metrics.
  Map<String, dynamic> getCacheStats() {
    return {
      'cacheKey': _config.cacheKey,
      'manifestSize': _cacheManifest.length,
      'manifestInitialized': _manifestInitialized,
      'maxObjects': _config.maxNrOfCacheObjects,
      'maxCacheSizeBytes': maxCacheSizeBytes,
      'stalePeriodDays': _config.stalePeriod.inDays,
      'syncManifestEnabled': _config.enableSyncManifest,
      ...metrics.toMap(),
    };
  }

  /// Resets internal state for testing purposes.
  @visibleForTesting
  void resetForTesting() {
    _cancelTrailingSweep();
    _knownCacheBytes = 0;
    _directoryTotalNeedsResync = false;
    _manifestInitialized = false;
    _cacheManifest.clear();
    _activeCancellableOperations.clear();
    _pendingCacheOperations.clear();
    _prefetchedKeys.clear();
    metrics.reset();
  }

  /// Waits for all pending alias-map writes to complete.
  ///
  /// Use this in tests instead of `pumpEventQueue` whenever a
  /// [getCachedFileSync] eviction or an [initialize] stale-entry prune
  /// triggers [_persistAliasMap] and you need the file on disk to reflect
  /// the updated map before making assertions.
  @visibleForTesting
  Future<void> waitForPendingAliasWrites() => _aliasWriteQueue;

  /// Cancels in-flight cancellable downloads and suspends new ones without
  /// closing the manager.
  ///
  /// Unlike [close], the manager stays usable — cached files still resolve,
  /// and downloads work again after [resumeDownloads]. Wire this to
  /// app-background transitions so in-flight NSURLSession (`cupertino_http`)
  /// requests are torn down before the OS suspends the Dart isolate; a late
  /// delegate callback into a suspended isolate aborts the process in the
  /// FFI trampoline.
  ///
  /// The suspension latch is required on top of the one-shot cancellation:
  /// prefetch loops (disk prefetcher cycles, [preCacheFiles] batches) react
  /// to a cancelled download by advancing to their next item, which would
  /// otherwise start a fresh native request inside the same suspension
  /// window.
  void cancelInFlightDownloads() {
    if (_isClosed) return;
    _downloadsSuspended = true;
    // Cancel manager-level operations first, mirroring [close]. An operation
    // still awaiting _resolveBaseCacheDir() has not started its download yet,
    // so it is absent from the downloader's active set; cancelling it here
    // sets cancelledBeforeStart so startDownload() bails instead of issuing a
    // fresh NSURLSession request after the isolate is already suspended.
    for (final operation in _activeCancellableOperations.toList(
      growable: false,
    )) {
      operation.cancel();
    }
    _downloader.cancelActiveDownloads();
  }

  /// Lifts the download suspension latched by [cancelInFlightDownloads].
  ///
  /// Wire this to the app returning to the foreground
  /// (`AppLifecycleState.resumed`) so prefetch and on-demand downloads work
  /// again.
  void resumeDownloads() {
    _downloadsSuspended = false;
  }

  /// Closes this manager and releases owned downloader resources.
  ///
  /// Cancels active cancellable downloads, drains their persistence work, and
  /// completes pending cache operations with `null` so callers do not hang.
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    _cancelTrailingSweep();
    final activeSweep = _activeSweepCompletion?.future;

    final activeOps = _activeCancellableOperations.toList(growable: false);
    for (final operation in activeOps) {
      operation.cancel();
    }
    _activeCancellableOperations.clear();

    final pending = _pendingCacheOperations.values.toList(growable: false);
    for (final operation in pending) {
      if (!operation.completer.isCompleted) {
        operation.completer.complete(
          const CancellableDownloadResult(file: null),
        );
      }
      await operation.closeProgress();
    }
    _pendingCacheOperations.clear();

    try {
      // Abort the legacy WebHelper request before waiting for its settlement;
      // it does not share the cancellable downloader closed below.
      _fileServiceClient?.close();
      await _downloader.close();
      await Future.wait([
        for (final operation in pending)
          if (operation.settlement != null) operation.settlement!,
      ]);
    } finally {
      try {
        if (activeSweep != null) await activeSweep;
        await _aliasWriteQueue;
      } finally {
        // CacheManager.dispose() closes the repository directly, which can
        // race CacheStore's constructor-started open. CacheStore.dispose()
        // waits for that open before releasing the same lifetime connection.
        try {
          await store.dispose();
        } on Object catch (error) {
          // Teardown must still complete if the repository never opened or
          // its final flush fails; every other owned resource is closed above.
          Log.warning(
            'MediaCacheManager: store dispose failed: $error',
            name: 'MediaCache',
            category: LogCategory.video,
          );
        }
      }
    }
  }
}

/// A managed cache file paired with its on-disk size and recency signal.
///
/// [object] is absent for a file kept alive only by the sync manifest.
class _BudgetedCacheFile {
  _BudgetedCacheFile({
    required this.file,
    required this.size,
    required this.lastUsed,
    this.object,
  });

  final CacheObject? object;
  final File file;
  final int size;
  final DateTime lastUsed;
}

/// Bridges a deferred [Future] (which performs async setup before the real
/// [CancellableDownload] starts) into the [CancellableDownload] interface
/// expected by [CancellableCacheOperation.fromDownload].
class _DeferredDownload extends CancellableDownload {
  _DeferredDownload({
    required Future<CancellableDownloadResult> future,
    required Stream<int> progressBytes,
    required void Function() cancel,
    required bool Function() isCancelledGetter,
  }) : _future = future,
       _progressBytes = progressBytes,
       _cancel = cancel,
       _isCancelledGetter = isCancelledGetter;

  final Future<CancellableDownloadResult> _future;
  final Stream<int> _progressBytes;
  final void Function() _cancel;
  final bool Function() _isCancelledGetter;

  @override
  Future<CancellableDownloadResult> get result => _future;

  @override
  Stream<int> get progressBytes => _progressBytes;

  // coverage:ignore-start
  @override
  bool get isCancelled => _isCancelledGetter();
  // coverage:ignore-end

  @override
  void cancel() => _cancel();
}

class _CompletedNullDownload extends CancellableDownload {
  @override
  Stream<int> get progressBytes => const Stream.empty();

  @override
  Future<CancellableDownloadResult> get result async =>
      const CancellableDownloadResult(file: null);

  // coverage:ignore-start
  @override
  bool get isCancelled => false;
  // coverage:ignore-end

  @override
  void cancel() {}
}

class _PendingCacheOperation {
  _PendingCacheOperation() : _progressController = null;

  _PendingCacheOperation.withProgress()
    : _progressController = StreamController<int>.broadcast(sync: true);

  final completer = Completer<CancellableDownloadResult>();
  final StreamController<int>? _progressController;
  Future<void>? settlement;

  Stream<int> get progressBytes =>
      _progressController?.stream ?? const Stream.empty();

  void addProgress(int bytes) => _progressController?.add(bytes);

  Future<void> closeProgress() async {
    final controller = _progressController;
    if (controller != null && !controller.isClosed) await controller.close();
  }
}
