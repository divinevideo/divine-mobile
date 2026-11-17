// ABOUTME: The thumbnail leg of an upload: extracts a frame from the local
// ABOUTME: video, derives its blurhash, and puts the image on Blossom.

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:unified_logger/unified_logger.dart';

import 'package:upload_repository/src/pending_upload.dart';
import 'package:upload_repository/src/upload_config.dart';
import 'package:upload_repository/src/upload_ports.dart';
import 'package:upload_repository/src/upload_session_errors.dart';

/// What the thumbnail leg produces: the CDN URL of the uploaded frame, the
/// blurhash derived from that same frame, and why there is no URL when
/// [cdnUrl] is null.
typedef ThumbnailLegResult = ({
  String? cdnUrl,
  String? blurhash,
  ThumbnailUploadException? failure,
});

/// Makes an upload's thumbnail and puts it on Blossom.
///
/// Holds no upload state: the repository decides when to run it, persists
/// what it returns, and retries it.
class ThumbnailLegUploader {
  ThumbnailLegUploader({
    required BlossomUploadService blossomService,
    required ThumbnailExtractor thumbnailExtractor,
    required UploadBlurhashGenerator blurhashGenerator,
    required UploadTelemetry telemetry,
    required Duration defaultThumbnailTimestamp,
  }) : _blossomService = blossomService,
       _extractThumbnail = thumbnailExtractor,
       _blurhashGenerator = blurhashGenerator,
       _telemetry = telemetry,
       _defaultThumbnailTimestamp = defaultThumbnailTimestamp;

  final BlossomUploadService _blossomService;

  /// Pulls the thumbnail frame out of the local video. Injectable so the
  /// thumbnail leg can be exercised without a decodable video and the native
  /// plugin behind the app's thumbnail service.
  final ThumbnailExtractor _extractThumbnail;
  final UploadBlurhashGenerator _blurhashGenerator;
  final UploadTelemetry _telemetry;
  final Duration _defaultThumbnailTimestamp;

  /// Extracts a thumbnail from [videoFile], uploads it to Blossom, and derives
  /// the blurhash from the same decoded frame.
  ///
  /// Never throws: when there is no CDN URL, the result's `failure` says
  /// why. Reports no progress: it runs in parallel with the video transfer,
  /// which owns the bar alone. See [videoProgressShare].
  Future<ThumbnailLegResult> run({
    required File videoFile,
    required String nostrPubkey,
    required PendingUpload upload,
  }) async {
    var stage = ThumbnailUploadFailureStage.extraction;
    try {
      Log.info(
        '📸 Extracting thumbnail from video: ${videoFile.path}',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      // Generate thumbnail at optimal timestamp
      final extractWatch = Stopwatch()..start();
      final thumbnailExtraction = await _extractThumbnail(
        videoPath: videoFile.path,
        quality: 85,
        targetTimestamp:
            upload.thumbnailTimestamp ?? _defaultThumbnailTimestamp,
      );
      extractWatch.stop();
      _telemetry(UploadPhases.uploadThumbnailExtract, extractWatch.elapsed);

      if (thumbnailExtraction == null) {
        Log.warning(
          '❌ Failed to extract thumbnail from video',
          name: 'UploadManager',
          category: LogCategory.video,
        );
        return (
          cdnUrl: null,
          blurhash: null,
          failure: const ThumbnailUploadException(
            ThumbnailUploadFailureStage.extraction,
            'no frame could be extracted from the video',
          ),
        );
      }

      final thumbnailFile = File(thumbnailExtraction.path);
      if (!thumbnailFile.existsSync()) {
        Log.warning(
          '❌ Thumbnail file not found after extraction',
          name: 'UploadManager',
          category: LogCategory.video,
        );
        return (
          cdnUrl: null,
          blurhash: null,
          failure: const ThumbnailUploadException(
            ThumbnailUploadFailureStage.extraction,
            'the extracted thumbnail file is missing',
          ),
        );
      }

      Log.info(
        '✅ Thumbnail extracted, uploading to Blossom server',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      // Derive the blurhash from the frame we just decoded. Publishing used to
      // decode the video a second time for this, on the critical path.
      final blurhashWatch = Stopwatch()..start();
      final blurhash = await _blurhashGenerator(
        thumbnailFile.readAsBytesSync(),
      );
      blurhashWatch.stop();
      _telemetry(UploadPhases.uploadThumbnailBlurhash, blurhashWatch.elapsed);

      // Upload thumbnail to Blossom server. Divine relay publishing requires
      // a CDN thumbnail, so keep the image upload's own retry enabled here.
      // UploadRepository retries a transient failure after that on its own;
      // the outer retry policy never re-uploads the whole video for it.
      final thumbnailBytes = thumbnailFile.lengthSync();
      stage = ThumbnailUploadFailureStage.upload;
      final putWatch = Stopwatch()..start();
      final uploadResult = await _blossomService.uploadImage(
        imageFile: thumbnailFile,
        nostrPubkey: nostrPubkey,
        // A thumbnail is a few KB — a single PUT avoids the resumable
        // init/chunk/complete handshake (two extra round-trips plus extra auth
        // signings) that otherwise dominated short-clip publish time.
        allowResumable: false,
      );
      putWatch.stop();
      _telemetry(
        UploadPhases.uploadThumbnailPut,
        putWatch.elapsed,
        bytes: thumbnailBytes,
      );

      // Clean up local thumbnail file
      try {
        await thumbnailFile.delete();
        Log.debug(
          '🧹 Cleaned up local thumbnail file',
          name: 'UploadManager',
          category: LogCategory.video,
        );
      } catch (e) {
        Log.warning(
          'Failed to clean up thumbnail file: $e',
          name: 'UploadManager',
          category: LogCategory.video,
        );
      }

      if (uploadResult.success && uploadResult.cdnUrl != null) {
        return (cdnUrl: uploadResult.cdnUrl, blurhash: blurhash, failure: null);
      }

      return (
        cdnUrl: null,
        blurhash: blurhash,
        failure: ThumbnailUploadException.fromUploadResult(uploadResult),
      );
    } catch (e) {
      Log.error(
        'Error generating/uploading thumbnail: $e',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return (
        cdnUrl: null,
        blurhash: null,
        failure: ThumbnailUploadException(stage, '$e'),
      );
    }
  }
}
