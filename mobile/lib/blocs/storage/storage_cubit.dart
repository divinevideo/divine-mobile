import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/constants/storage_cache_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/storage_footprint.dart';
import 'package:openvine/services/cache_recovery_service.dart';
import 'package:openvine/services/storage_management_service.dart';

part 'storage_state.dart';

/// Drives the settings "Storage" screen: reports the clearable cache size,
/// clears it on demand, audits the clip library for broken entries, and runs
/// the last-resort repair wipe for a corrupted install.
class StorageCubit extends Cubit<StorageState> {
  /// Creates a cubit backed by [service] and loads the current cache size.
  ///
  /// [recoverAllCaches] must be injected by a screen that exposes repair so
  /// every disposable database table participates. When it is absent, repair
  /// fails closed instead of running an incomplete static wipe.
  StorageCubit({
    required StorageManagementService service,
    Future<bool> Function()? recoverAllCaches,
    Future<int> Function() measureRecoveryFootprint =
        CacheRecoveryService.cacheSizeBytes,
  }) : _service = service,
       _recoverAllCaches = recoverAllCaches,
       _measureRecoveryFootprint = measureRecoveryFootprint,
       super(const StorageState());

  final StorageManagementService _service;
  final Future<bool> Function()? _recoverAllCaches;
  final Future<int> Function() _measureRecoveryFootprint;

  /// Loads the current clearable cache size and configured limit.
  Future<void> loadCacheSize() async {
    // Read the persisted limit up front — a cheap in-memory prefs read that
    // can't fail — so a size-measurement failure below still leaves the slider
    // on the user's saved budget instead of resetting it to the default.
    emit(
      state.copyWith(
        cacheStatus: StorageCacheStatus.loading,
        videoCacheLimitBytes: _service.videoCacheLimitBytes(),
      ),
    );
    try {
      final usage = await _service.cacheUsage();
      emit(
        state.copyWith(
          cacheStatus: StorageCacheStatus.ready,
          cacheSizeBytes: usage.totalBytes,
          cacheUsage: usage,
          videoCacheLimitBytes: _service.videoCacheLimitBytes(),
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(cacheStatus: StorageCacheStatus.failure));
    }
  }

  /// Reflects a slider drag without persisting — keeps the label live while
  /// the user is still choosing.
  void previewVideoCacheLimit(int bytes) =>
      emit(state.copyWith(videoCacheLimitBytes: bytes));

  /// Persists the chosen [bytes] limit, applies it, and refreshes the size
  /// (the cache may have been trimmed). Surfaces a busy status while the
  /// forced trim + re-measure runs so the stale size can't be acted on.
  Future<void> commitVideoCacheLimit(int bytes) async {
    emit(
      state.copyWith(
        cacheStatus: StorageCacheStatus.loading,
        videoCacheLimitBytes: bytes,
      ),
    );
    try {
      await _service.setVideoCacheLimit(bytes);
      final usage = await _service.cacheUsage();
      emit(
        state.copyWith(
          cacheStatus: StorageCacheStatus.ready,
          cacheSizeBytes: usage.totalBytes,
          cacheUsage: usage,
          videoCacheLimitBytes: _service.videoCacheLimitBytes(),
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(cacheStatus: StorageCacheStatus.failure));
    }
  }

  /// Clears the caches, then refreshes the reported size.
  Future<void> clearCaches() async {
    emit(state.copyWith(cacheStatus: StorageCacheStatus.clearing));
    try {
      await _service.clearCaches();
      final usage = await _service.cacheUsage();
      emit(
        state.copyWith(
          cacheStatus: StorageCacheStatus.cleared,
          cacheSizeBytes: usage.totalBytes,
          cacheUsage: usage,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(cacheStatus: StorageCacheStatus.failure));
    }
  }

  /// Scans the clip library for clips whose backing file is missing.
  Future<void> scanLibrary() async {
    emit(state.copyWith(libraryStatus: StorageLibraryStatus.scanning));
    try {
      final broken = await _service.findBrokenClips();
      emit(
        state.copyWith(
          libraryStatus: StorageLibraryStatus.scanned,
          brokenClips: broken,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(libraryStatus: StorageLibraryStatus.failure));
    }
  }

  /// Measures everything a repair wipe would clear — Hive boxes, Application
  /// Support, temp and cache directories — which is a superset of the media
  /// cache [loadCacheSize] reports.
  ///
  /// A measurement failure falls back to [StorageRecoveryStatus.idle] rather
  /// than `failure`: the size is decoration on the confirmation sheet, and
  /// `failure` is what the UI renders when the wipe itself went wrong.
  ///
  /// The screen fires this unawaited alongside the confirmation sheet, so a
  /// slow walk can land after the page popped or after the user already
  /// confirmed. Both results are discarded rather than emitted over a wipe
  /// that has since started.
  Future<void> loadRecoveryFootprint() async {
    emit(state.copyWith(recoveryStatus: StorageRecoveryStatus.measuring));
    try {
      final footprint = await _measureRecoveryFootprint();
      if (_measurementSuperseded) return;
      emit(
        state.copyWith(
          recoveryStatus: StorageRecoveryStatus.measured,
          recoveryFootprintBytes: footprint,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (_measurementSuperseded) return;
      emit(state.copyWith(recoveryStatus: StorageRecoveryStatus.idle));
    }
  }

  /// Whether an in-flight measurement has been outlived by its screen or
  /// overtaken by the wipe it was measuring for.
  bool get _measurementSuperseded =>
      isClosed || state.recoveryStatus != StorageRecoveryStatus.measuring;

  /// Wipes the app's caches and databases to recover from corruption. The
  /// durable database directory is preserved by [CacheRecoveryService]; the
  /// user still has to restart the app afterwards.
  ///
  /// The wipe takes seconds and the user can navigate back while it runs, so
  /// the outcome is dropped if the screen closed the cubit first.
  Future<void> recoverFromCorruptedCache() async {
    emit(state.copyWith(recoveryStatus: StorageRecoveryStatus.recovering));
    try {
      final recoverAllCaches = _recoverAllCaches;
      if (recoverAllCaches == null) {
        throw StateError('Cache recovery was not configured for this screen');
      }
      final succeeded = await recoverAllCaches();
      if (isClosed) return;
      emit(
        state.copyWith(
          recoveryStatus: succeeded
              ? StorageRecoveryStatus.recovered
              : StorageRecoveryStatus.failure,
          recoveryFootprintBytes: 0,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (isClosed) return;
      emit(state.copyWith(recoveryStatus: StorageRecoveryStatus.failure));
    }
  }

  /// Measures every directory the app writes to for the developer diagnostic.
  ///
  /// Unlike [loadCacheSize], this includes what no in-app action can reclaim —
  /// the documents directory and the durable database — which is the whole
  /// point: it answers where an unexplained OS-reported footprint sits.
  ///
  /// The walk takes seconds on a large install and the user can navigate away
  /// while it runs, so the result is dropped if the cubit closed first.
  Future<void> measureFootprint() async {
    emit(state.copyWith(footprintStatus: StorageFootprintStatus.measuring));
    try {
      final footprint = await _service.measureFootprint();
      if (isClosed) return;
      emit(
        state.copyWith(
          footprintStatus: StorageFootprintStatus.measured,
          footprint: footprint,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (isClosed) return;
      emit(state.copyWith(footprintStatus: StorageFootprintStatus.failure));
    }
  }

  /// Removes the broken clips found by [scanLibrary].
  Future<void> removeBrokenClips() async {
    if (state.brokenClips.isEmpty) return;
    emit(state.copyWith(libraryStatus: StorageLibraryStatus.cleaning));
    try {
      await _service.removeBrokenClips(state.brokenClips);
      emit(
        state.copyWith(
          libraryStatus: StorageLibraryStatus.cleaned,
          brokenClips: const [],
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(libraryStatus: StorageLibraryStatus.failure));
    }
  }
}
