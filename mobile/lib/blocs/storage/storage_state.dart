part of 'storage_cubit.dart';

/// Lifecycle of the cache section.
enum StorageCacheStatus {
  /// Not loaded yet.
  initial,

  /// Computing the current cache size.
  loading,

  /// Size known and idle.
  ready,

  /// A clear operation is running.
  clearing,

  /// A clear operation just finished. Idle like [ready], but distinct so the
  /// UI can announce the clear to screen readers without inferring it from a
  /// zero size (which also happens when an already-empty cache is loaded).
  cleared,

  /// The last cache operation failed.
  failure,
}

/// Lifecycle of the "your content" section — the documents directory split
/// into what the user's clips, drafts and sounds own and what nothing
/// references any more.
enum StorageContentStatus {
  /// Not measured yet.
  initial,

  /// Walking the documents directory and checking references.
  loading,

  /// Usage known and idle; see [StorageState.documentsUsage].
  ready,

  /// The orphan sweep is running.
  removing,

  /// The sweep just finished. Idle like [ready], but distinct so the UI can
  /// announce the result to screen readers.
  removed,

  /// The last measurement or sweep failed.
  failure,
}

/// Lifecycle of the clip-library audit section.
enum StorageLibraryStatus {
  /// Not scanned yet.
  idle,

  /// A scan is running.
  scanning,

  /// Scan complete; see [StorageState.brokenClips].
  scanned,

  /// Removing the broken clips.
  cleaning,

  /// Broken clips removed.
  cleaned,

  /// The last library operation failed.
  failure,
}

/// Lifecycle of the repair-install section.
enum StorageRecoveryStatus {
  /// Nothing in flight. Also where a failed measurement lands — the footprint
  /// is decoration on the confirmation sheet, so losing it hides the size line
  /// instead of claiming the reset itself failed.
  idle,

  /// Measuring the total on-disk footprint.
  measuring,

  /// Footprint known and idle; see [StorageState.recoveryFootprintBytes].
  measured,

  /// A full recovery wipe is running.
  recovering,

  /// The wipe finished; the app needs a restart.
  recovered,

  /// The wipe failed.
  failure,
}

/// Lifecycle of the developer footprint diagnostic.
enum StorageFootprintStatus {
  /// Not measured yet.
  idle,

  /// Walking every directory the app writes to.
  measuring,

  /// Footprint known; see [StorageState.footprint].
  measured,

  /// The measurement failed.
  failure,
}

/// State for the settings "Storage" screen.
class StorageState extends Equatable {
  /// Creates a state.
  const StorageState({
    this.cacheStatus = StorageCacheStatus.initial,
    this.cacheSizeBytes = 0,
    this.cacheUsage = CacheUsage.empty,
    this.videoCacheLimitBytes = kCacheLimitDefaultBytes,
    this.contentStatus = StorageContentStatus.initial,
    this.documentsUsage = DocumentsUsage.empty,
    this.libraryStatus = StorageLibraryStatus.idle,
    this.brokenClips = const [],
    this.recoveryStatus = StorageRecoveryStatus.idle,
    this.recoveryFootprintBytes = 0,
    this.footprintStatus = StorageFootprintStatus.idle,
    this.footprint = StorageFootprint.empty,
  });

  /// Lifecycle of the cache section.
  final StorageCacheStatus cacheStatus;

  /// Bytes currently held by the clearable caches.
  final int cacheSizeBytes;

  /// Clearable cache usage split by category and matching budget.
  final CacheUsage cacheUsage;

  /// The configured maximum video-cache size, in bytes.
  final int videoCacheLimitBytes;

  /// Lifecycle of the "your content" section.
  final StorageContentStatus contentStatus;

  /// The documents directory split into the user's content and the files
  /// nothing references any more.
  final DocumentsUsage documentsUsage;

  /// Lifecycle of the clip-library audit section.
  final StorageLibraryStatus libraryStatus;

  /// Library clips whose backing file is missing (populated after a scan).
  final List<DivineVideoClip> brokenClips;

  /// Lifecycle of the repair-install section.
  final StorageRecoveryStatus recoveryStatus;

  /// Total bytes a repair wipe would clear, or zero while unmeasured.
  final int recoveryFootprintBytes;

  /// Lifecycle of the developer footprint diagnostic.
  final StorageFootprintStatus footprintStatus;

  /// Every directory the app writes to, measured on demand.
  final StorageFootprint footprint;

  /// Returns a copy with the given fields replaced.
  StorageState copyWith({
    StorageCacheStatus? cacheStatus,
    int? cacheSizeBytes,
    CacheUsage? cacheUsage,
    int? videoCacheLimitBytes,
    StorageContentStatus? contentStatus,
    DocumentsUsage? documentsUsage,
    StorageLibraryStatus? libraryStatus,
    List<DivineVideoClip>? brokenClips,
    StorageRecoveryStatus? recoveryStatus,
    int? recoveryFootprintBytes,
    StorageFootprintStatus? footprintStatus,
    StorageFootprint? footprint,
  }) {
    return StorageState(
      cacheStatus: cacheStatus ?? this.cacheStatus,
      cacheSizeBytes: cacheSizeBytes ?? this.cacheSizeBytes,
      cacheUsage: cacheUsage ?? this.cacheUsage,
      videoCacheLimitBytes: videoCacheLimitBytes ?? this.videoCacheLimitBytes,
      contentStatus: contentStatus ?? this.contentStatus,
      documentsUsage: documentsUsage ?? this.documentsUsage,
      libraryStatus: libraryStatus ?? this.libraryStatus,
      brokenClips: brokenClips ?? this.brokenClips,
      recoveryStatus: recoveryStatus ?? this.recoveryStatus,
      recoveryFootprintBytes:
          recoveryFootprintBytes ?? this.recoveryFootprintBytes,
      footprintStatus: footprintStatus ?? this.footprintStatus,
      footprint: footprint ?? this.footprint,
    );
  }

  @override
  List<Object?> get props => [
    cacheStatus,
    cacheSizeBytes,
    cacheUsage,
    videoCacheLimitBytes,
    contentStatus,
    documentsUsage,
    libraryStatus,
    brokenClips,
    recoveryStatus,
    recoveryFootprintBytes,
    footprintStatus,
    footprint,
  ];
}
