// ABOUTME: Always-on memory gauge sampler for OOM instrumentation
// ABOUTME: Reads injected gauges on an interval and emits a MemorySnapshot

import 'dart:async';
import 'dart:math' as math;

/// An immutable point-in-time reading of the app's memory-relevant gauges.
class MemorySnapshot {
  const MemorySnapshot({
    required this.rssBytes,
    required this.peakRssBytes,
    required this.nativeControllers,
    required this.queueDepth,
    required this.imageCacheBytes,
    required this.peakImageCacheBytes,
    required this.imageCacheLiveCount,
  });

  /// Sentinel used when a gauge could not be read.
  static const int unavailableGauge = -1;

  /// Resident set size at sample time, in bytes.
  final int rssBytes;

  /// Highest resident set size this process has reached, in bytes.
  ///
  /// Sourced from the OS high-water mark, so it covers spikes that occur
  /// between samples. Falls back to the highest sampled [rssBytes] where no
  /// OS gauge is available (web).
  final int peakRssBytes;

  /// Live `divine_video_player` native controllers.
  final int nativeControllers;

  /// Events queued for ingestion across all priorities.
  final int queueDepth;

  /// Decoded image bytes retained by Flutter's keep-alive image cache.
  ///
  /// This is [unavailableGauge] when the cache could not be read.
  final int imageCacheBytes;

  /// Highest decoded-image cache occupancy observed during this process.
  ///
  /// Flutter clears [imageCacheBytes] before notifying memory-pressure
  /// observers. This high-water mark preserves the last meaningful occupancy
  /// across that framework clear. It is [unavailableGauge] until the first
  /// successful reading.
  final int peakImageCacheBytes;

  /// Decoded images with at least one live listener.
  ///
  /// Live images are tracked separately from [imageCacheBytes], so this is a
  /// count rather than an estimate of their memory footprint. This is
  /// [unavailableGauge] when the cache could not be read.
  final int imageCacheLiveCount;

  @override
  String toString() =>
      'MemorySnapshot(rssBytes: $rssBytes, peakRssBytes: $peakRssBytes, '
      'nativeControllers: $nativeControllers, queueDepth: $queueDepth, '
      'imageCacheBytes: $imageCacheBytes, '
      'peakImageCacheBytes: $peakImageCacheBytes, '
      'imageCacheLiveCount: $imageCacheLiveCount)';
}

/// Samples memory-relevant gauges and emits a [MemorySnapshot].
///
/// All inputs are injected as callbacks so the service stays Flutter-free and
/// trivially testable. Production wiring supplies a `readRssBytes` backed by
/// `ProcessInfo.currentRss`, a `readPeakRssBytes` backed by
/// `ProcessInfo.maxRss`, and an `emit` that logs and annotates Crashlytics.
///
/// The peak must come from the OS rather than from this sampler's own
/// readings. Sampling on an interval can only ever report a peak it happened
/// to land on, and the allocation that gets an app jetsammed is over long
/// before the next tick: a 1.0.20 report measured 229.3 MB of sampled peak in
/// a process whose OS high-water mark was 2266.0 MB (#8300).
class MemoryTelemetryService {
  MemoryTelemetryService({
    required int Function() readRssBytes,
    required int Function() readPeakRssBytes,
    required int Function() nativeControllerCount,
    required int Function() queueDepth,
    required int Function() imageCacheBytes,
    required int Function() imageCacheLiveCount,
    required void Function(MemorySnapshot snapshot, String trigger) emit,
    this.interval = const Duration(seconds: 30),
  }) : _readRssBytes = readRssBytes,
       _readPeakRssBytes = readPeakRssBytes,
       _nativeControllerCount = nativeControllerCount,
       _queueDepth = queueDepth,
       _imageCacheBytes = imageCacheBytes,
       _imageCacheLiveCount = imageCacheLiveCount,
       _emit = emit;

  final int Function() _readRssBytes;
  final int Function() _readPeakRssBytes;
  final int Function() _nativeControllerCount;
  final int Function() _queueDepth;
  final int Function() _imageCacheBytes;
  final int Function() _imageCacheLiveCount;
  final void Function(MemorySnapshot snapshot, String trigger) _emit;

  /// How often [start] samples the gauges.
  final Duration interval;

  Timer? _timer;
  int _peakRssBytes = 0;
  int _peakImageCacheBytes = MemorySnapshot.unavailableGauge;

  /// Reads every gauge once, updates the running peak, and emits a snapshot.
  ///
  /// The peak is the OS high-water mark, floored by the highest sampled RSS
  /// so a platform without an OS gauge still reports something monotonic.
  void sampleOnce({String trigger = 'periodic'}) {
    final rss = _readGauge(_readRssBytes);
    final imageCacheBytes = _readGauge(
      _imageCacheBytes,
      unavailable: MemorySnapshot.unavailableGauge,
    );
    if (imageCacheBytes != MemorySnapshot.unavailableGauge) {
      _peakImageCacheBytes = math.max(_peakImageCacheBytes, imageCacheBytes);
    }
    _peakRssBytes = math.max(
      math.max(_peakRssBytes, rss),
      _readGauge(_readPeakRssBytes),
    );
    _emit(
      MemorySnapshot(
        rssBytes: rss,
        peakRssBytes: _peakRssBytes,
        nativeControllers: _readGauge(_nativeControllerCount),
        queueDepth: _readGauge(_queueDepth),
        imageCacheBytes: imageCacheBytes,
        peakImageCacheBytes: _peakImageCacheBytes,
        imageCacheLiveCount: _readGauge(
          _imageCacheLiveCount,
          unavailable: MemorySnapshot.unavailableGauge,
        ),
      ),
      trigger,
    );
  }

  /// Isolates gauge failures so telemetry cannot prevent memory shedding.
  ///
  /// Some platforms do not implement every gauge, and cache access must stay
  /// distinguishable from a genuinely empty cache.
  static int _readGauge(int Function() read, {int unavailable = 0}) {
    try {
      final value = read();
      return value < 0 ? unavailable : value;
    } on Object catch (_) {
      return unavailable;
    }
  }

  /// Begins periodic sampling on [interval]. Safe to call after [stop].
  void start() {
    _timer ??= Timer.periodic(interval, (_) => sampleOnce());
  }

  /// Stops periodic sampling. Idempotent.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
