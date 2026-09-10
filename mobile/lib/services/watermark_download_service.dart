// ABOUTME: Orchestrates downloading a video, applying a watermark overlay, and saving to gallery
// ABOUTME: Emits progress updates for UI feedback during the multi-step process

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_cache/media_cache.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/services/c2pa_signing_service.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/services/temp_render_janitor.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/services/watermark_image_generator.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Progress stages for watermark download.
enum WatermarkDownloadStage {
  /// Downloading/caching the video file.
  downloading,

  /// Generating watermark and rendering onto video.
  watermarking,

  /// Saving the watermarked video to gallery.
  saving,
}

/// Progress stages for saving original video (no watermark).
enum OriginalSaveStage {
  /// Downloading/caching the video file.
  downloading,

  /// Saving the video to gallery.
  saving,
}

/// Result of a watermark download operation.
sealed class WatermarkDownloadResult {
  const WatermarkDownloadResult();
}

/// Watermarked video was successfully saved to the gallery.
class WatermarkDownloadSuccess extends WatermarkDownloadResult {
  /// Creates a [WatermarkDownloadSuccess] with the output [filePath].
  const WatermarkDownloadSuccess(this.filePath);

  /// Path to the watermarked video file.
  final String filePath;
}

/// Watermark download failed.
class WatermarkDownloadFailure extends WatermarkDownloadResult {
  /// Creates a [WatermarkDownloadFailure] with the given [reason].
  const WatermarkDownloadFailure(this.reason);

  /// Human-readable failure reason.
  final String reason;
}

/// Gallery permission was denied — UI should offer to open Settings.
class WatermarkDownloadPermissionDenied extends WatermarkDownloadResult {
  /// Creates a [WatermarkDownloadPermissionDenied].
  const WatermarkDownloadPermissionDenied();
}

/// File extensions recognised as playable video files when validating a
/// previously cached download. Anything else (e.g. a `.bin` file from an
/// interrupted download) is evicted and re-fetched.
const _videoExtensions = <String>{'.mp4', '.mov', '.webm', '.mkv', '.m4v'};

/// Frame-rate ceiling for the watermark render.
///
/// iOS Photos tags an import above ~60 fps as high-frame-rate and plays it back
/// as slow motion, so a 120 fps rendition reaches the camera roll as a Slo-Mo
/// clip. 60 is the highest rate Photos still treats as an ordinary video, which
/// keeps a genuine 60 fps source intact instead of dropping real frames.
///
/// This is a cap, not a target: a source already at or below it is untouched.
/// It only reaches the watermark render — `downloadOriginal` copies the file
/// without re-encoding, so there is nothing to cap there.
const _maxWatermarkFrameRate = 60;

String _redownloadCacheKey(String videoId) =>
    '$videoId-redownload-${DateTime.now().microsecondsSinceEpoch}';

/// Service that downloads a video, applies a Divine watermark, and saves
/// the result to the device gallery.
class WatermarkDownloadService {
  /// Creates a [WatermarkDownloadService] with required dependencies.
  ///
  /// [c2paSigningService] carries an embedded C2PA manifest forward onto the
  /// watermarked output, which the render step would otherwise strip.
  const WatermarkDownloadService({
    required MediaCacheManager mediaCache,
    required GallerySaveService gallerySaveService,
    required C2paSigningService c2paSigningService,
  }) : _mediaCache = mediaCache,
       _gallerySaveService = gallerySaveService,
       _c2paSigningService = c2paSigningService;

  final MediaCacheManager _mediaCache;
  final GallerySaveService _gallerySaveService;
  final C2paSigningService _c2paSigningService;

  static const _logName = 'WatermarkDownloadService';

  /// Downloads the video, applies a watermark, and saves to gallery.
  ///
  /// [video] is the video event to download and watermark.
  /// [watermarkText] is the identity text to show in the watermark.
  /// [onProgress] is called as the operation moves through stages.
  ///
  /// Returns a [WatermarkDownloadResult] indicating success or failure.
  Future<WatermarkDownloadResult> downloadWithWatermark({
    required VideoEvent video,
    required String watermarkText,
    required ValueChanged<WatermarkDownloadStage> onProgress,
  }) async {
    Log.info(
      'downloadWithWatermark started: videoId=${video.id}',
      name: _logName,
      category: LogCategory.video,
    );

    String? tempOutputPath;

    try {
      // Stage 1: Download / cache the video file
      onProgress(WatermarkDownloadStage.downloading);

      final videoFile = await _getVideoFile(video);
      if (videoFile == null) {
        Log.warning(
          'downloadWithWatermark failed at stage=downloading: '
          '_getVideoFile returned null for videoId=${video.id}',
          name: _logName,
          category: LogCategory.video,
        );
        return const WatermarkDownloadFailure('Could not download video file');
      }
      Log.info(
        'downloadWithWatermark stage=downloading complete: '
        'path=${videoFile.path}',
        name: _logName,
        category: LogCategory.video,
      );

      // Stage 2: Generate watermark and render onto video
      onProgress(WatermarkDownloadStage.watermarking);

      // Read actual video dimensions from the file (not from Nostr metadata,
      // which may be missing or wrong — e.g. a square video defaults to
      // 1080x1920 and causes black letterboxing).
      final metadata = await ProVideoEditor.instance.getMetadata(
        EditorVideo.file(videoFile.path),
      );
      final videoWidth = metadata.resolution.width.round();
      final videoHeight = metadata.resolution.height.round();

      Log.debug(
        'Video dimensions from file: ${videoWidth}x$videoHeight',
        name: _logName,
        category: LogCategory.video,
      );

      final watermarkBytes = await WatermarkImageGenerator.generateWatermark(
        videoWidth: videoWidth,
        videoHeight: videoHeight,
        watermarkText: watermarkText,
      );

      tempOutputPath = await _renderWithWatermark(
        videoFile: videoFile,
        watermarkBytes: watermarkBytes,
        videoId: video.id,
      );

      if (tempOutputPath == null) {
        Log.warning(
          'downloadWithWatermark failed at stage=watermarking: '
          '_renderWithWatermark returned null for videoId=${video.id}',
          name: _logName,
          category: LogCategory.video,
        );
        return const WatermarkDownloadFailure(
          'Failed to render watermarked video',
        );
      }

      // The watermark render re-encodes and strips any embedded C2PA manifest.
      // Carry the source's manifest forward onto the watermarked file — a
      // no-op when the source (e.g. a third-party download) was never signed.
      await _c2paSigningService.resignDerived(
        outputPath: tempOutputPath,
        sourcePath: videoFile.path,
        action: C2paEditActions.edited,
      );

      // Stage 3: Save to gallery
      onProgress(WatermarkDownloadStage.saving);

      final saveResult = await _gallerySaveService.saveVideoToGallery(
        EditorVideo.file(tempOutputPath),
      );

      if (saveResult is GallerySavePermissionDenied) {
        Log.warning(
          'downloadWithWatermark stopped at stage=saving: permission denied',
          name: _logName,
          category: LogCategory.video,
        );
        return const WatermarkDownloadPermissionDenied();
      }
      if (saveResult is GallerySaveFailure) {
        Log.warning(
          'downloadWithWatermark failed at stage=saving: '
          'reason=${saveResult.reason}',
          name: _logName,
          category: LogCategory.video,
        );
        return WatermarkDownloadFailure(
          'Gallery save failed: ${saveResult.reason}',
        );
      }

      Log.info(
        'Watermarked video saved to gallery',
        name: _logName,
        category: LogCategory.video,
      );

      return WatermarkDownloadSuccess(tempOutputPath);
    } on WatermarkGenerationException catch (e) {
      Log.warning(
        'Watermark generation failed: ${e.message}',
        name: _logName,
        category: LogCategory.video,
      );
      return WatermarkDownloadFailure('Watermark error: ${e.message}');
    } catch (e) {
      Log.warning(
        'Watermark download failed: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return WatermarkDownloadFailure('Unexpected error: $e');
    }
  }

  /// Downloads the original video (no watermark) and saves to gallery.
  ///
  /// [video] is the video event to download.
  /// [onProgress] is called as the operation moves through stages.
  ///
  /// Returns a [WatermarkDownloadResult] indicating success or failure.
  Future<WatermarkDownloadResult> downloadOriginal({
    required VideoEvent video,
    required ValueChanged<OriginalSaveStage> onProgress,
  }) async {
    Log.info(
      'downloadOriginal started: videoId=${video.id}',
      name: _logName,
      category: LogCategory.video,
    );

    try {
      // Stage 1: Download / cache the video file
      onProgress(OriginalSaveStage.downloading);

      final videoFile = await _getVideoFile(video);
      if (videoFile == null) {
        Log.warning(
          'downloadOriginal failed at stage=downloading: '
          '_getVideoFile returned null for videoId=${video.id}',
          name: _logName,
          category: LogCategory.video,
        );
        return const WatermarkDownloadFailure('Could not download video file');
      }
      Log.info(
        'downloadOriginal stage=downloading complete: path=${videoFile.path}',
        name: _logName,
        category: LogCategory.video,
      );

      // Stage 2: Save directly to gallery (no watermark)
      onProgress(OriginalSaveStage.saving);

      final saveResult = await _gallerySaveService.saveVideoToGallery(
        EditorVideo.file(videoFile.path),
      );

      if (saveResult is GallerySavePermissionDenied) {
        Log.warning(
          'downloadOriginal stopped at stage=saving: permission denied',
          name: _logName,
          category: LogCategory.video,
        );
        return const WatermarkDownloadPermissionDenied();
      }
      if (saveResult is GallerySaveFailure) {
        Log.warning(
          'downloadOriginal failed at stage=saving: reason=${saveResult.reason}',
          name: _logName,
          category: LogCategory.video,
        );
        return WatermarkDownloadFailure(
          'Gallery save failed: ${saveResult.reason}',
        );
      }

      Log.info(
        'Original video saved to gallery',
        name: _logName,
        category: LogCategory.video,
      );

      return WatermarkDownloadSuccess(videoFile.path);
    } catch (e) {
      Log.warning(
        'Original video save failed: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return WatermarkDownloadFailure('Unexpected error: $e');
    }
  }

  /// Downloads or retrieves the cached video file.
  Future<File?> _getVideoFile(VideoEvent video) async {
    Log.info(
      '_getVideoFile started: videoId=${video.id} videoUrl=${video.videoUrl}',
      name: _logName,
      category: LogCategory.video,
    );
    var cacheKey = video.id;

    // Check cache first — only use it when the file has a recognised video
    // extension.  Stale entries from older app versions (or interrupted
    // downloads) can leave a `.bin` file on disk that ProVideoEditor cannot
    // read.  Evicting the bad entry lets the next cacheFile() call perform a
    // clean network download.
    final cachedFile = _mediaCache.getCachedFileSync(video.id);
    if (cachedFile != null && cachedFile.existsSync()) {
      final ext = p.extension(cachedFile.path).toLowerCase();
      if (_videoExtensions.contains(ext)) {
        Log.debug(
          'Using cached video file',
          name: _logName,
          category: LogCategory.video,
        );
        return cachedFile;
      }

      Log.warning(
        'Cached file has invalid extension "$ext", evicting and re-downloading',
        name: _logName,
        category: LogCategory.video,
      );
      try {
        await _mediaCache.removeCachedFile(video.id);
      } catch (e) {
        Log.warning(
          'Failed to evict invalid cached video file: $e',
          name: _logName,
          category: LogCategory.video,
        );
        cacheKey = _redownloadCacheKey(video.id);
      }
    }

    // Resolve the playable URL and download
    final videoUrl = await video.getPlayableUrl();
    if (videoUrl == null || videoUrl.isEmpty) {
      Log.warning(
        'No video URL available',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }
    Log.info(
      '_getVideoFile resolved playable URL: $videoUrl',
      name: _logName,
      category: LogCategory.video,
    );

    final file = await _mediaCache.cacheFile(videoUrl, key: cacheKey);

    Log.info(
      '_getVideoFile cacheFile returned: '
      '${file == null ? "null" : "${file.path} (exists=${file.existsSync()}, "
                "size=${file.existsSync() ? file.lengthSync() : -1})"}',
      name: _logName,
      category: LogCategory.video,
    );

    return file;
  }

  /// Renders the video with the watermark overlay.
  Future<String?> _renderWithWatermark({
    required File videoFile,
    required Uint8List watermarkBytes,
    required String videoId,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      deleteStaleWatermarkRenders(tempDir);
      final outputPath =
          '${tempDir.path}/watermarked_${DateTime.now().microsecondsSinceEpoch}.mp4';

      final task = VideoRenderData(
        id: '${videoId}_watermark',
        videoSegments: [VideoSegment(video: EditorVideo.file(videoFile))],
        shouldOptimizeForNetworkUse: true,
        maxFrameRate: _maxWatermarkFrameRate,
        imageLayers: [
          ImageLayer(image: EditorLayerImage.memory(watermarkBytes)),
        ],
      );

      await VideoEditorRenderService.renderNativeVideoToFile(outputPath, task);

      Log.debug(
        'Watermarked video rendered to: $outputPath',
        name: _logName,
        category: LogCategory.video,
      );

      return outputPath;
    } catch (e) {
      Log.error(
        'Failed to render watermarked video: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// Deletes leftover `watermarked_*.mp4` renders in [tempDir] from previous
  /// saves that are older than [TempRenderJanitor.staleRenderAge]. Called before each new
  /// render so the temp directory stays bounded to roughly the last hour of
  /// renders instead of leaking one full-size video per save.
  /// Best-effort: never throws.
  @visibleForTesting
  void deleteStaleWatermarkRenders(Directory tempDir) =>
      TempRenderJanitor.deleteStaleTempRenders(
        tempDir,
        patterns: const [TempRenderPatterns.watermarkedVideo],
      );
}
