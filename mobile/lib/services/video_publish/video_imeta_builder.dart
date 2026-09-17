// ABOUTME: Builds the NIP-92 imeta tag for a direct video upload
// ABOUTME: Selects publishable URLs and derives size, hash, dimensions and blurhash

import 'dart:io';

import 'package:blurhash_service/blurhash_service.dart';
import 'package:models/models.dart' show VideoUrlResolver;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_publish/publish_timeline.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Builds the `imeta` tag of a NIP-71 video event from a [PendingUpload].
///
/// Only HTTP(S) URLs on live media hosts are minted — a local file path or a
/// known dead delivery host must never leak into a Nostr event — and the
/// file-derived fields degrade independently: `size` needs the file on disk,
/// `x` does not, and a missing blurhash is optional metadata.
class VideoImetaBuilder {
  const VideoImetaBuilder();

  static const String _logName = 'VideoImetaBuilder';

  /// Whether [upload] carries at least one video URL that may be published.
  static bool hasPublishableVideoUrl(PendingUpload upload) =>
      isPublishableMediaUrl(upload.streamingMp4Url) ||
      isPublishableMediaUrl(upload.fallbackUrl) ||
      isPublishableMediaUrl(upload.streamingHlsUrl) ||
      isPublishableMediaUrl(upload.cdnUrl);

  /// Whether [url] is an HTTP(S) URL on a media host that still serves.
  static bool isPublishableMediaUrl(String? url) =>
      isHttpUrl(url) && !VideoUrlResolver.isKnownDeadMediaUrl(url!);

  /// Whether [url] is an HTTP(S) URL rather than a local file path.
  static bool isHttpUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  /// Returns the complete `imeta` tag for [upload], or `null` when none of
  /// its video URLs can be published.
  ///
  /// [thumbnailTimestamp] picks the frame a freshly computed blurhash is
  /// derived from; an upload that already carries a blurhash reuses it. It
  /// is required, even though it may be null, because no test can observe a
  /// dropped value: the frame is only read through a platform decoder.
  Future<List<String>?> build(
    PendingUpload upload, {
    required Duration? thumbnailTimestamp,
  }) async {
    final components = <String>[];
    final urlsAdded = <String>[];

    void addPublishableUrl({
      required String? url,
      required String fieldName,
      required String label,
    }) {
      if (url == null || url.isEmpty) return;
      if (!isHttpUrl(url)) {
        Log.error(
          '⚠️ Skipping non-HTTP $fieldName (possible local path): $url',
          name: _logName,
          category: LogCategory.video,
        );
        return;
      }
      if (VideoUrlResolver.isKnownDeadMediaUrl(url)) {
        Log.warning(
          '⚠️ Skipping known dead media URL in $fieldName: $url',
          name: _logName,
          category: LogCategory.video,
        );
        return;
      }

      components.add('url $url');
      urlsAdded.add('$label: $url');
    }

    addPublishableUrl(
      url: upload.streamingMp4Url,
      fieldName: 'streamingMp4Url',
      label: 'MP4(streaming)',
    );
    addPublishableUrl(
      url: upload.fallbackUrl,
      fieldName: 'fallbackUrl',
      label: 'MP4(R2 fallback)',
    );
    addPublishableUrl(
      url: upload.streamingHlsUrl,
      fieldName: 'streamingHlsUrl',
      label: 'HLS',
    );

    // Fallback to legacy cdnUrl if no Blossom-specific URLs
    if (urlsAdded.isEmpty) {
      addPublishableUrl(
        url: upload.cdnUrl,
        fieldName: 'cdnUrl',
        label: 'Legacy CDN',
      );
    }

    if (urlsAdded.isEmpty) {
      Log.error(
        '❌ No valid HTTP video URLs available - refusing to publish. '
        'This prevents local file paths from leaking into Nostr events.',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }
    Log.info(
      '✅ Added video URLs to imeta:\n  ${urlsAdded.join("\n  ")}',
      name: _logName,
      category: LogCategory.video,
    );

    components.add('m video/mp4');

    // Use uploaded thumbnail CDN URL from Blossom upload
    final thumbnailPath = upload.thumbnailPath;
    if (thumbnailPath != null && isHttpUrl(thumbnailPath)) {
      components.add('image $thumbnailPath');
      Log.info(
        '✅ Using uploaded thumbnail CDN URL: $thumbnailPath',
        name: _logName,
        category: LogCategory.video,
      );
    }

    if (upload.videoWidth != null && upload.videoHeight != null) {
      components.add('dim ${upload.videoWidth}x${upload.videoHeight}');
    }

    // x: the digest is the upload's videoId, which every upload path sets
    // from the locally streamed HashUtil.sha256File over this same file —
    // _parseUploadResponse takes fileHash as a parameter and never reads a
    // hash off the response body, so this is value-identical to re-hashing
    // the file (which used to cost a measurable slice of the publish and
    // pulled the whole video into memory). Deliberately independent of the
    // local file still existing: funnelcake materializes events_local.sha256
    // from this sub-field and joins moderation labels on it, so a publish
    // landing after local cleanup must still carry it.
    final hash = upload.videoId;
    if (hash != null && hash.isNotEmpty) {
      components.add('x $hash');
    }

    // size genuinely needs the file on disk.
    if (upload.localVideoPath.isNotEmpty) {
      try {
        final videoFile = File(upload.localVideoPath);
        if (videoFile.existsSync()) {
          final fileSize = videoFile.lengthSync();
          components.add('size $fileSize');

          Log.verbose(
            'Added file metadata - size: $fileSize bytes, hash: $hash',
            name: _logName,
            category: LogCategory.video,
          );
        }
      } catch (e) {
        Log.warning(
          'Failed to calculate file metadata: $e',
          name: _logName,
          category: LogCategory.video,
        );
      }
    }

    final blurhash = await _resolveBlurhash(
      upload,
      thumbnailTimestamp: thumbnailTimestamp,
    );
    if (blurhash != null) components.add('blurhash $blurhash');

    return ['imeta', ...components];
  }

  /// Blurhash for progressive image loading. The upload's thumbnail leg
  /// already decoded the frame and derived it there, beside the video
  /// transfer; deriving it again here meant a second video decode on the
  /// critical path (measured at 568ms). Records written before the field
  /// existed, and uploads whose thumbnail was reused from an earlier
  /// attempt, still fall through to computing it.
  Future<String?> _resolveBlurhash(
    PendingUpload upload, {
    required Duration? thumbnailTimestamp,
  }) async {
    final storedBlurhash = upload.blurhash;
    if (storedBlurhash != null && storedBlurhash.isNotEmpty) {
      Log.info(
        '✅ Reused blurhash from upload: $storedBlurhash',
        name: _logName,
        category: LogCategory.video,
      );
      return storedBlurhash;
    }
    if (upload.localVideoPath.isEmpty) return null;

    final blurhashWatch = Stopwatch()..start();
    try {
      Log.debug(
        '🎨 Generating blurhash from video thumbnail',
        name: _logName,
        category: LogCategory.video,
      );

      // Extract thumbnail bytes with 10-second timeout
      final thumbnailBytes =
          await VideoThumbnailService.extractThumbnailBytes(
            videoPath: upload.localVideoPath,
            timestamp:
                thumbnailTimestamp ??
                VideoEditorConstants.defaultThumbnailExtractTime,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              Log.warning(
                '⏱️ Thumbnail extraction timed out after 10 seconds',
                name: _logName,
                category: LogCategory.video,
              );
              return null;
            },
          );

      if (thumbnailBytes == null) {
        Log.warning(
          'Thumbnail extraction returned null',
          name: _logName,
          category: LogCategory.video,
        );
        return null;
      }

      // Generate blurhash with 3-second timeout
      final blurhash =
          await BlurhashService.generateBlurhash(
            thumbnailBytes.bytes,
          ).timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              Log.warning(
                '⏱️ Blurhash generation timed out after 3 seconds',
                name: _logName,
                category: LogCategory.video,
              );
              return null;
            },
          );

      if (blurhash == null || blurhash.isEmpty) {
        Log.warning(
          'Blurhash generation returned null or empty',
          name: _logName,
          category: LogCategory.video,
        );
        return null;
      }
      Log.info(
        '✅ Generated blurhash: $blurhash',
        name: _logName,
        category: LogCategory.video,
      );
      return blurhash;
    } catch (e) {
      // Continue publishing without blurhash - it's optional metadata
      Log.warning(
        'Failed to generate blurhash: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    } finally {
      blurhashWatch.stop();
      logPublishPhase(PublishPhases.nostrBlurhash, blurhashWatch.elapsed);
    }
  }
}
