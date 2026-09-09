// ABOUTME: Streams filmstrip thumbnails for a published video's subtitle
// ABOUTME: timeline, caching the remote file before extracting frames.

import 'dart:io';
import 'dart:ui';

import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/subtitle_editor/timeline_frame.dart';
import 'package:openvine/services/video_editor/clip_thumbnail_manager.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Downloads a video and hands back a local file, or `null` when it could not
/// be fetched.
typedef TimelineVideoDownloader = Future<File?> Function({
  required String url,
  required String cacheKey,
});

/// Resolves the event URL into a single file that can be cached and decoded.
typedef TimelineVideoUrlResolver = Future<String?> Function(String? videoUrl);

/// Produces the frames shown under the subtitle editor's timeline.
///
/// The editor works on an already-published video, so unlike the video
/// editor's clip strip there is no local source file to read: the video is
/// pulled through the media cache first, then handed to the same frame
/// extractor the clip strip uses.
class SubtitleTimelineThumbnailService {
  /// Creates the service.
  ///
  /// [stripThumbnailStreamFactory] defaults to the production extractor and is
  /// injectable so tests never touch the native decoder.
  SubtitleTimelineThumbnailService({
    required TimelineVideoDownloader downloadVideo,
    StripThumbnailStreamFactory? stripThumbnailStreamFactory,
    TimelineVideoUrlResolver? resolveVideoUrl,
  }) : _downloadVideo = downloadVideo,
       _resolveVideoUrl = resolveVideoUrl ?? _identityResolver,
       _generateStripThumbnails =
           stripThumbnailStreamFactory ??
           VideoThumbnailService.generateStripThumbnails;

  final TimelineVideoDownloader _downloadVideo;
  final TimelineVideoUrlResolver _resolveVideoUrl;
  final StripThumbnailStreamFactory _generateStripThumbnails;

  static Future<String?> _identityResolver(String? videoUrl) async => videoUrl;

  static bool _isHlsManifestUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.m3u8') || lower.contains('/hls/');
  }

  /// Frames per second of video to extract.
  ///
  /// Matches the clip strip: enough to fill every slot at maximum zoom.
  static int get _thumbsPerSecond =>
      (TimelineConstants.maxPixelsPerSecond / TimelineConstants.thumbnailWidth)
          .ceil();

  /// Streams progressively denser filmstrips for [videoUrl].
  ///
  /// Each event is the full set extracted so far, so a listener can render the
  /// latest batch and drop the previous one. Never emits an error: a video
  /// that cannot be cached, an unknown [duration], and a decoder that gives up
  /// partway all end the stream normally, leaving the timeline with whatever
  /// frames arrived.
  ///
  /// [devicePixelRatio] sizes the extracted frames for the screen they land
  /// on; pass `MediaQuery.devicePixelRatioOf(context)`.
  Stream<List<TimelineFrame>> thumbnailsFor({
    required String videoUrl,
    required String videoId,
    required Duration duration,
    required double devicePixelRatio,
  }) async* {
    if (duration <= Duration.zero) return;

    final String? resolvedUrl;
    try {
      resolvedUrl = await _resolveVideoUrl(videoUrl);
    } catch (e) {
      Log.warning(
        'Could not resolve video for the subtitle timeline: $e',
        name: 'SubtitleTimelineThumbnailService',
      );
      return;
    }
    if (resolvedUrl == null ||
        resolvedUrl.isEmpty ||
        _isHlsManifestUrl(resolvedUrl)) {
      return;
    }

    final File? file;
    try {
      file = await _downloadVideo(url: resolvedUrl, cacheKey: videoId);
    } catch (e) {
      // Frames are decoration: a failed fetch leaves the timeline usable, so
      // it is logged rather than surfaced.
      Log.warning(
        'Could not cache video for the subtitle timeline: $e',
        name: 'SubtitleTimelineThumbnailService',
      );
      return;
    }
    if (file == null || !file.existsSync()) return;

    final batches = _generateStripThumbnails(
      videoPath: file.path,
      clipId: videoId,
      duration: duration,
      outputSize: Size(
        TimelineConstants.thumbnailWidth * devicePixelRatio,
        TimelineConstants.thumbnailStripHeight * devicePixelRatio,
      ),
      thumbsPerSecond: _thumbsPerSecond,
    );
    // The extractor reports a mid-stream native failure as a stream error, so
    // callers that care can tell a truncated strip from a complete one. This
    // one cannot: the frames that arrived stay on screen either way, and an
    // escaping error would file a crash report for a decode failure.
    try {
      await for (final batch in batches) {
        yield [
          for (final frame in batch)
            TimelineFrame(path: frame.path, timestamp: frame.timestamp),
        ];
      }
    } catch (e) {
      Log.warning(
        'Stopped extracting frames for the subtitle timeline: $e',
        name: 'SubtitleTimelineThumbnailService',
      );
    }
  }
}
