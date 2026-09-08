// ABOUTME: Service for extracting thumbnails from video files
// ABOUTME: Generates preview frames for video posts to include in NIP-71 events

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service for extracting thumbnail images from video files
class VideoThumbnailService {
  /// Crash reporting for this static utility.
  ///
  /// [VideoThumbnailService] has no instances, so there is no constructor to inject through.
  /// Bootstrap assigns this once from `crashReportingServiceProvider`; tests
  /// assign a recording fake. This is a deliberately-confined residual of the
  /// #4743 conversion — every instantiable service takes a [CrashReporter]
  /// through its constructor instead.
  static CrashReporter crashReporter = const SilentCrashReporter();

  static const int _thumbnailQuality = 75;
  static const Size _thumbnailSize = Size.square(640);

  static ProVideoEditor get _proVideoEditor => ProVideoEditor.instance;

  /// Serial queue for strip thumbnail extraction batches.
  ///
  /// This keeps only one native decode call active at a time, but allows
  /// multiple clip streams to interleave batch-by-batch for faster
  /// perceived timeline fill across clips.
  static Future<void> _stripBatchQueue = Future<void>.value();

  /// Resets the strip-batch serial queue between tests.
  ///
  /// A widget test that tears down while a strip generator is awaiting the
  /// queue strands a forever-pending future in that test's dead FakeAsync
  /// zone; the next test would inherit it and deadlock before its first
  /// batch.
  ///
  /// Call this from inside the `testWidgets` body, not from `setUp`: the
  /// replacement future must be created in the test's FakeAsync zone or its
  /// completion lands on the real event loop, which a widget test never
  /// reaches until it ends.
  @visibleForTesting
  static void resetStripBatchQueueForTesting() {
    _stripBatchQueue = Future<void>.value();
  }

  /// Extract a thumbnail from a video file at a specific timestamp
  ///
  /// [videoPath] - Path to the video file
  /// [targetTimestamp] - Timestamp to extract thumbnail from (default: 210ms)
  /// [quality] - JPEG quality (1-100, default: 75)
  ///
  /// Returns a [ThumbnailFileResult] with the path and actual timestamp used
  static Future<ThumbnailFileResult?> extractThumbnail({
    required String videoPath,
    // Extract frame at 210ms by default
    Duration targetTimestamp = VideoEditorConstants.defaultThumbnailExtractTime,
    int quality = _thumbnailQuality,
  }) async {
    try {
      Log.debug(
        'Extracting thumbnail from video: $videoPath',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
      Log.debug(
        '⏱️ Timestamp: ${targetTimestamp.inMilliseconds}ms',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );

      // Verify video file exists
      final videoFile = File(videoPath);
      if (!videoFile.existsSync()) {
        Log.error(
          'Video file not found: $videoPath',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );
        return null;
      }

      final destPath =
          '${(await getApplicationDocumentsDirectory()).path}/'
          'thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';

      try {
        Log.debug(
          'Trying pro_video_editor plugin',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );

        // The pro_video_editor returns thumbnails only as in-memory Uint8List
        // and does not write files to disk.
        // Therefore, we persist the thumbnails to disk here.
        final thumbnailResult = await extractThumbnailBytes(
          videoPath: videoPath,
          timestamp: targetTimestamp,
          quality: quality,
        );

        if (thumbnailResult == null) {
          throw Exception('Failed to extract thumbnail bytes from video');
        }
        final thumbnailFile = File(destPath);
        await thumbnailFile.writeAsBytes(thumbnailResult.bytes);

        final thumbnailSize = await thumbnailFile.length();
        Log.info(
          'Thumbnail generated with pro_video_editor:',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );
        Log.debug(
          '  📸 Path: $destPath',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );
        Log.debug(
          '  📦 Size: ${(thumbnailSize / 1024).toStringAsFixed(2)}KB',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );
        return ThumbnailFileResult(
          path: destPath,
          timestamp: thumbnailResult.timestamp,
        );
      } catch (e) {
        Log.error(
          'Failed to generate thumbnail: $e',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );
        return null;
      }
    } catch (e, stackTrace) {
      Log.error(
        'Thumbnail extraction error: $e',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
      Log.verbose(
        '📱 Stack trace: $stackTrace',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// Extract thumbnail as bytes (for direct upload without file)
  ///
  /// Includes automatic retry logic with delays to handle "cannot open" errors
  /// that occur when the video file is still being written or locked:
  /// 1. First attempt at the specified timestamp
  /// 2. If failed: Wait 100ms, then retry at the same timestamp
  /// 3. If failed again: Wait 200ms, then attempt at 50ms (fallback position)
  /// 4. If failed again: Wait 300ms, then attempt at video duration / 2
  ///
  /// Returns a [ThumbnailResult] containing the bytes and actual timestamp used.
  static Future<ThumbnailResult?> extractThumbnailBytes({
    required String videoPath,
    Duration timestamp = VideoEditorConstants.defaultThumbnailExtractTime,
    int quality = _thumbnailQuality,
  }) async {
    // Build list of retry attempts with increasing delays and fallback timestamps
    final attempts = <_ThumbnailAttempt>[
      _ThumbnailAttempt(timestamp: timestamp, delay: .zero),
      _ThumbnailAttempt(
        timestamp: timestamp,
        delay: const Duration(milliseconds: 100),
      ),
      const _ThumbnailAttempt(
        timestamp: Duration(milliseconds: 50),
        delay: Duration(milliseconds: 200),
      ),
      const _ThumbnailAttempt(
        timestamp: null, // Will use video duration / 2
        delay: Duration(milliseconds: 300),
        logToCrashlytics: true,
      ),
    ];

    return _extractWithRetry(
      videoPath: videoPath,
      quality: quality,
      attempts: attempts,
    );
  }

  /// Recursively attempts thumbnail extraction with the given list of attempts.
  static Future<ThumbnailResult?> _extractWithRetry({
    required String videoPath,
    required int quality,
    required List<_ThumbnailAttempt> attempts,
  }) async {
    if (attempts.isEmpty) return null;

    final attempt = attempts.first;
    final remainingAttempts = attempts.sublist(1);
    final isLastAttempt = remainingAttempts.isEmpty;

    // Apply delay before this attempt (except for first attempt)
    if (attempt.delay > Duration.zero) {
      await Future<void>.delayed(attempt.delay);
    }

    // Resolve timestamp (null means use video duration / 2)
    Duration timestamp;
    if (attempt.timestamp != null) {
      timestamp = attempt.timestamp!;
    } else {
      try {
        final metadata = await _proVideoEditor.getMetadata(
          EditorVideo.file(videoPath),
        );
        timestamp = Duration(
          milliseconds: metadata.duration.inMilliseconds ~/ 2,
        );
      } catch (e) {
        Log.error(
          'Failed to get video metadata for middle timestamp: $e',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );
        // Skip to next attempt if we can't get metadata
        return _extractWithRetry(
          videoPath: videoPath,
          quality: quality,
          attempts: remainingAttempts,
        );
      }
    }

    if (attempt.delay > Duration.zero) {
      Log.debug(
        'Retrying thumbnail extraction at timestamp: '
        '${timestamp.inMilliseconds}ms',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
    }

    final bytes = await _extractThumbnailBytesInternal(
      videoPath: videoPath,
      timestamp: timestamp,
      quality: quality,
      logToCrashlytics: attempt.logToCrashlytics && isLastAttempt,
    );

    if (bytes != null) {
      return ThumbnailResult(bytes: bytes, timestamp: timestamp);
    }

    // Recurse to next attempt
    return _extractWithRetry(
      videoPath: videoPath,
      quality: quality,
      attempts: remainingAttempts,
    );
  }

  /// Internal method for extracting thumbnail bytes without retry logic.
  static Future<Uint8List?> _extractThumbnailBytesInternal({
    required String videoPath,
    required Duration timestamp,
    required int quality,
    bool logToCrashlytics = false,
  }) async {
    try {
      Log.debug(
        'Extracting thumbnail bytes from video: $videoPath',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );

      // Generate thumbnail file first
      final thumbnails = await _proVideoEditor.getThumbnails(
        ThumbnailConfigs(
          video: EditorVideo.file(videoPath),
          outputSize: _thumbnailSize,
          timestamps: [timestamp],
          jpegQuality: quality,
        ),
      );

      if (thumbnails.isEmpty) {
        Log.error(
          'Failed to generate thumbnail',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );
        if (logToCrashlytics) {
          await crashReporter.recordError(
            Exception('Thumbnail extraction failed - thumbnails list is empty'),
            StackTrace.current,
            reason:
                'VideoThumbnailService: Failed to extract thumbnail from '
                '$videoPath at timestamp: ${timestamp.inMilliseconds}ms',
          );
        }
        return null;
      }

      final thumbnail = thumbnails.first;

      Log.info(
        'Thumbnail bytes generated: '
        '${(thumbnail.lengthInBytes / 1024).toStringAsFixed(2)}KB',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
      return thumbnail;
    } catch (e, stackTrace) {
      Log.error(
        'Thumbnail bytes extraction error: $e',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
      if (logToCrashlytics) {
        await crashReporter.recordError(
          e,
          stackTrace,
          reason:
              'VideoThumbnailService: Failed to extract thumbnail from '
              '$videoPath at timestamp: ${timestamp.inMilliseconds}ms',
        );
      }
      return null;
    }
  }

  /// Generates multiple thumbnails from a video at different timestamps.
  ///
  /// Useful for presenting several candidate frames, such as for preview
  /// selection or cover image picking.
  ///
  /// If [timestamps] is not provided, thumbnails are extracted at **500ms,
  /// 1000ms, and 1500ms** by default. Extraction intentionally does not start
  /// at 0ms because many MP4 videos have no decodable frame at the beginning.
  /// The first keyframe typically appears after ~210ms.
  static Future<List<Uint8List>> extractMultipleThumbnails({
    required String videoPath,
    List<Duration>? timestamps,
    int quality = _thumbnailQuality,
  }) async {
    final timesToExtract =
        timestamps ??
        const [
          Duration(milliseconds: 500),
          Duration(milliseconds: 1000),
          Duration(milliseconds: 1500),
        ];

    final thumbnails = await _proVideoEditor.getThumbnails(
      ThumbnailConfigs(
        video: EditorVideo.file(videoPath),
        outputSize: _thumbnailSize,
        timestamps: timesToExtract,
        jpegQuality: quality,
      ),
    );

    Log.debug(
      '📱 Generated ${thumbnails.length} thumbnails',
      name: 'VideoThumbnailService',
      category: LogCategory.video,
    );
    return thumbnails;
  }

  /// Clean up temporary thumbnail files
  static Future<void> cleanupThumbnails(List<String> thumbnailPaths) async {
    for (final path in thumbnailPaths) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          await file.delete();
          Log.debug(
            '📱️ Deleted thumbnail: $path',
            name: 'VideoThumbnailService',
            category: LogCategory.video,
          );
        }
      } catch (e) {
        Log.error(
          'Failed to delete thumbnail: $e',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );
      }
    }
  }

  /// Extract the last frame of a video.
  ///
  /// Strategy:
  /// 1. Try the native `position: .last` API which resolves the final
  ///    frame without a manual timestamp.
  /// 2. If that fails (e.g. "Cannot Open" on some iOS videos), fall back
  ///    to timestamp-based extraction at `duration − 50 ms`, which
  ///    avoids the seek-past-end issue while still returning a frame
  ///    near the end.
  ///
  /// [videoDuration] can be provided to skip an internal metadata
  /// lookup.
  static Future<String?> extractLastFrame({
    required String videoPath,
    Duration? videoDuration,
    int quality = _thumbnailQuality,
  }) async {
    // --- Attempt 1: native position-based extraction ---
    try {
      final bytes = await _proVideoEditor.getSingleThumbnail(
        SingleThumbnailConfigs(
          video: EditorVideo.file(videoPath),
          outputSize: _thumbnailSize,
          position: ThumbnailPosition.last,
          videoDuration: videoDuration,
          jpegQuality: quality,
        ),
      );

      if (bytes != null && bytes.isNotEmpty) {
        return await _writeGhostFrame(bytes);
      }

      Log.warning(
        '⚠️ getSingleThumbnail(position: .last) returned null/empty',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.warning(
        '⚠️ getSingleThumbnail(position: .last) failed: $e',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
    }

    // --- Attempt 2: timestamp-based fallback near end ---
    try {
      final duration =
          videoDuration ??
          (await _proVideoEditor.getMetadata(
            EditorVideo.file(videoPath),
          )).duration;

      // Offset slightly before the end to avoid the iOS seek-past-end bug.
      const offset = Duration(milliseconds: 50);
      final fallbackTimestamp = duration > offset
          ? duration - offset
          : Duration.zero;

      Log.debug(
        '↩️ Falling back to timestamp extraction at '
        '${fallbackTimestamp.inMilliseconds} ms',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );

      final result = await extractThumbnailBytes(
        videoPath: videoPath,
        timestamp: fallbackTimestamp,
        quality: quality,
      );

      if (result != null) {
        return await _writeGhostFrame(result.bytes);
      }

      Log.warning(
        '⚠️ Timestamp-based last-frame fallback also returned null',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
    } catch (e, stackTrace) {
      Log.error(
        'Last-frame fallback failed: $e',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
      await crashReporter.recordError(
        e,
        stackTrace,
        reason:
            'VideoThumbnailService: Failed to extract last frame from '
            '$videoPath (both strategies failed)',
      );
    }

    return null;
  }

  /// Persist ghost-frame bytes to disk and return the path.
  static Future<String> _writeGhostFrame(Uint8List bytes) async {
    final targetDir = await _resolveGhostFrameDirectory();
    await targetDir.create(recursive: true);
    final destPath =
        '${targetDir.path}/ghost_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(destPath).writeAsBytes(bytes);

    Log.debug(
      '👻 Last frame extracted: $destPath',
      name: 'VideoThumbnailService',
      category: LogCategory.video,
    );
    return destPath;
  }

  static Future<Directory> _resolveGhostFrameDirectory() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (e) {
      Log.warning(
        '⚠️ getApplicationDocumentsDirectory failed for ghost frame: $e',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
    }

    try {
      return await getTemporaryDirectory();
    } catch (e) {
      Log.warning(
        '⚠️ getTemporaryDirectory failed for ghost frame: $e',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
    }

    return Directory.systemTemp;
  }

  /// Generates thumbnails for a timeline strip, yielded in batches so the
  /// UI can update progressively.
  ///
  /// Covers the source range `[startOffset, startOffset + duration]` — the
  /// window a caller actually shows, not necessarily the whole file. A
  /// timeline clip only ever renders its trimmed window, so sizing the
  /// request off the untrimmed source duration extracts frames nothing can
  /// display: a 60 s import trimmed to 6 s asked for the 500-frame cap
  /// instead of ~80.
  ///
  /// Emitted [StripThumbnail.timestamp]s stay absolute positions in the file,
  /// so a caller that later widens its window can merge frames from two
  /// requests without rebasing them.
  ///
  /// [thumbsPerSecond] controls how many frames are extracted per second of
  /// video. Pass `ceil(maxPixelsPerSecond / thumbnailWidth)` to ensure every
  /// visual slot has a distinct frame at maximum zoom.
  ///
  /// Thumbnails are written to temporary cache files to avoid holding
  /// large byte arrays in memory. The caller is responsible for deleting
  /// the files when they are no longer needed (see [StripThumbnail.path]).
  ///
  /// Each yield contains the **accumulated** list so far, allowing the
  /// caller to simply replace its current list on each event.
  ///
  /// If native extraction fails mid-stream, the stream emits the error and
  /// closes. Batches already delivered stay valid, but the set is truncated
  /// — listeners must not treat a stream that errored as having reached full
  /// density.
  static Stream<List<StripThumbnail>> generateStripThumbnails({
    required String videoPath,
    required String clipId,
    required Duration duration,
    required Size outputSize,
    int thumbsPerSecond = 1,
    int quality = _thumbnailQuality,
    int batchSize = 6,
    Duration startOffset = Duration.zero,
    List<Duration>? priorityTimestamps,
  }) async* {
    if (duration <= Duration.zero) return;

    yield* _generateStripThumbnailsBatched(
      videoPath: videoPath,
      clipId: clipId,
      duration: duration,
      outputSize: outputSize,
      thumbsPerSecond: thumbsPerSecond,
      quality: quality,
      batchSize: batchSize,
      startOffset: startOffset,
      priorityTimestamps: priorityTimestamps,
    );
  }

  static Future<T> _runStripBatchExclusive<T>(
    Future<T> Function() action,
  ) async {
    final previous = _stripBatchQueue;
    final release = Completer<void>();
    _stripBatchQueue = release.future;

    await previous;
    try {
      return await action();
    } finally {
      release.complete();
    }
  }

  static Stream<List<StripThumbnail>> _generateStripThumbnailsBatched({
    required String videoPath,
    required String clipId,
    required Duration duration,
    required Size outputSize,
    required int thumbsPerSecond,
    required int quality,
    required int batchSize,
    required Duration startOffset,
    List<Duration>? priorityTimestamps,
  }) async* {
    final durationMs = duration.inMilliseconds;
    // Enough frames to cover every visual slot at the requested density.
    final count = ((durationMs / 1000) * thumbsPerSecond).ceil().clamp(1, 500);

    // Extract center-first so the strip gets useful visual coverage quickly.
    final densityTimestamps = _buildProgressiveStripTimestamps(
      durationMs: durationMs,
      count: count,
      startMs: startOffset.inMilliseconds,
    );

    // Priority timestamps go first (the exact frames the visible slots
    // need at the current zoom), followed by the full-density set with
    // duplicates removed.
    final List<Duration> allTimestamps;
    if (priorityTimestamps != null && priorityTimestamps.isNotEmpty) {
      final seenMs = <int>{};
      final merged = <Duration>[];
      for (final ts in priorityTimestamps) {
        if (seenMs.add(ts.inMilliseconds)) merged.add(ts);
      }
      for (final ts in densityTimestamps) {
        if (seenMs.add(ts.inMilliseconds)) merged.add(ts);
      }
      allTimestamps = merged;
    } else {
      allTimestamps = densityTimestamps;
    }

    final cacheDir = await getTemporaryDirectory();
    final batchId = '${clipId}_${DateTime.now().millisecondsSinceEpoch}';

    final accumulated = <StripThumbnail>[];

    for (
      var batchStart = 0;
      batchStart < allTimestamps.length;
      batchStart += batchSize
    ) {
      final batchEnd = (batchStart + batchSize).clamp(0, allTimestamps.length);
      final batchTimestamps = allTimestamps.sublist(batchStart, batchEnd);

      List<Uint8List> bytes;
      try {
        bytes = await _runStripBatchExclusive(
          () => _proVideoEditor.getThumbnails(
            ThumbnailConfigs(
              video: EditorVideo.file(videoPath),
              outputSize: outputSize,
              timestamps: batchTimestamps,
              jpegQuality: quality,
            ),
            nativeLogLevel: .warning,
          ),
        );
      } catch (error) {
        Log.warning(
          'Failed to generate strip thumbnails for clip $clipId: $error',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );
        // Surface the failure as a stream error instead of closing the
        // stream normally — listeners must be able to tell a truncated set
        // apart from a complete one (a silent close made partial strips
        // look final and dropped their gap-filler frames).
        rethrow;
      }

      for (var i = 0; i < bytes.length && i < batchTimestamps.length; i++) {
        final file = File(
          '${cacheDir.path}/strip_${batchId}_${batchStart + i}.jpg',
        );
        await file.writeAsBytes(bytes[i]);
        accumulated.add(
          StripThumbnail(path: file.path, timestamp: batchTimestamps[i]),
        );
      }

      final sorted = [...accumulated]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      yield List.unmodifiable(sorted);
    }
  }

  /// Builds a center-first timestamp sequence (midpoint refinement) covering
  /// `[startMs, startMs + durationMs]`.
  ///
  /// Example progression for ~10s: 5.0s, 2.5s, 7.5s, 1.25s, 3.75s...
  /// This improves perceived loading because early batches cover the full
  /// requested window instead of only the beginning. The refinement runs in
  /// window-local time and every result is shifted by [startMs], so the
  /// returned timestamps are absolute positions in the source file.
  static List<Duration> _buildProgressiveStripTimestamps({
    required int durationMs,
    required int count,
    int startMs = 0,
  }) {
    final timestamps = <Duration>[];
    final seenMs = <int>{};
    final segments = Queue<(double, double)>()..add((0, durationMs.toDouble()));

    final minMs = durationMs > 1 ? 1 : 0;
    final maxMs = durationMs > 1 ? durationMs - 1 : durationMs;

    while (segments.isNotEmpty && timestamps.length < count) {
      final (start, end) = segments.removeFirst();
      final width = end - start;
      if (width <= 0) {
        continue;
      }

      final midMs = ((start + end) / 2).round().clamp(minMs, maxMs);

      if (seenMs.add(midMs)) {
        timestamps.add(Duration(milliseconds: startMs + midMs));
      }

      if (width > 1) {
        final mid = midMs.toDouble();
        segments
          ..add((start, mid))
          ..add((mid, end));
      }
    }

    if (timestamps.length < count) {
      for (var i = 0; i < count && timestamps.length < count; i++) {
        final fraction = (i + 0.5) / count;
        final ms = (durationMs * fraction).round().clamp(minMs, maxMs);
        timestamps.add(Duration(milliseconds: startMs + ms));
      }
    }

    return timestamps.take(count).toList(growable: false);
  }

  /// Get optimal thumbnail timestamp based on video duration
  static Duration getOptimalTimestamp(Duration videoDuration) {
    // Extract thumbnail from 10% into the video
    // This usually avoids black frames at the start
    final tenPercent = (videoDuration.inMilliseconds * 0.1).round();

    // But ensure it's at least 100ms and not more than 1 second
    return Duration(milliseconds: tenPercent.clamp(100, 1000));
  }
}

/// Configuration for a single thumbnail extraction attempt.
class _ThumbnailAttempt {
  const _ThumbnailAttempt({
    required this.timestamp,
    required this.delay,
    this.logToCrashlytics = false,
  });

  /// The timestamp to extract the thumbnail from.
  /// If null, the middle of the video (duration / 2) will be used.
  final Duration? timestamp;

  /// Delay to wait before this attempt.
  final Duration delay;

  /// Whether to log failures to Crashlytics (typically only for the last attempt).
  final bool logToCrashlytics;
}

/// Result of a thumbnail extraction containing the bytes and actual timestamp used.
class ThumbnailResult {
  const ThumbnailResult({required this.bytes, required this.timestamp});

  /// The thumbnail image bytes.
  final Uint8List bytes;

  /// The actual video timestamp where the thumbnail was extracted from.
  /// May differ from the requested timestamp due to retry logic.
  final Duration timestamp;
}

/// Result of a thumbnail file extraction containing the path and actual timestamp used.
class ThumbnailFileResult {
  const ThumbnailFileResult({required this.path, required this.timestamp});

  /// The path to the generated thumbnail file.
  final String path;

  /// The actual video timestamp where the thumbnail was extracted from.
  /// May differ from the requested timestamp due to retry logic.
  final Duration timestamp;
}

/// A single thumbnail extracted for a timeline strip, persisted to disk.
class StripThumbnail {
  const StripThumbnail({required this.path, required this.timestamp});

  /// Path to the cached thumbnail file.
  final String path;

  /// The video position this thumbnail represents.
  final Duration timestamp;
}
