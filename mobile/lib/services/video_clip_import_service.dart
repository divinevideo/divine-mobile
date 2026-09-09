// ABOUTME: Imports videos into the local clip library.
// ABOUTME: Copies cached media into documents so saved clip paths survive app restarts.

import 'dart:io';

import 'package:characters/characters.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/subtitle_service.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:text_sanitizer/text_sanitizer.dart';
import 'package:unified_logger/unified_logger.dart';

typedef VideoClipDownloader = Future<File?> Function({
  required String url,
  required String cacheKey,
});

typedef VideoClipThumbnailExtractor = Future<VideoClipThumbnail?> Function({
  required String videoPath,
  required Duration targetTimestamp,
});

typedef VideoClipLastFrameExtractor = Future<String?> Function({
  required String videoPath,
  required Duration videoDuration,
});

typedef DocumentsPathProvider = Future<String> Function();
typedef Clock = DateTime Function();

typedef VideoMetadataReader = Future<VideoMetadata> Function(EditorVideo video);

class VideoClipThumbnail {
  const VideoClipThumbnail({required this.path, required this.timestamp});

  final String path;
  final Duration timestamp;
}

sealed class VideoClipImportResult {
  const VideoClipImportResult();
}

final class VideoClipImportSuccess extends VideoClipImportResult {
  const VideoClipImportSuccess(this.clip);

  final DivineVideoClip clip;
}

final class VideoClipImportFailure extends VideoClipImportResult {
  const VideoClipImportFailure(this.reason);

  final VideoClipImportFailureReason reason;
}

enum VideoClipImportFailureReason {
  missingVideoUrl,
  unsupportedPlatform,
  downloadFailed,
  copyFailed,
  saveFailed,
}

class VideoClipImportService {
  VideoClipImportService({
    required ClipLibraryService clipLibraryService,
    required DocumentsPathProvider getDocumentsPath,
    required VideoClipDownloader downloadVideo,
    required VideoClipThumbnailExtractor extractThumbnail,
    required VideoClipLastFrameExtractor extractLastFrame,
    Clock? now,
    VideoMetadataReader? readVideoMetadata,
  }) : _clipLibraryService = clipLibraryService,
       _getDocumentsPath = getDocumentsPath,
       _downloadVideo = downloadVideo,
       _extractThumbnail = extractThumbnail,
       _extractLastFrame = extractLastFrame,
       _now = now ?? DateTime.now,
       _readVideoMetadata =
           readVideoMetadata ?? ProVideoEditor.instance.getMetadata;

  static const _logName = 'VideoClipImportService';

  /// Aspect-ratio threshold at or above which an own video is square-cropped.
  /// Videos meeting this threshold — including landscape videos wider than 1:1
  /// — are intentionally mapped to [models.AspectRatio.square].
  static const double _squareishMinAspectRatio = 0.9;

  final ClipLibraryService _clipLibraryService;
  final DocumentsPathProvider _getDocumentsPath;
  final VideoClipDownloader _downloadVideo;
  final VideoClipThumbnailExtractor _extractThumbnail;
  final VideoClipLastFrameExtractor _extractLastFrame;
  final Clock _now;
  final VideoMetadataReader _readVideoMetadata;

  Future<VideoClipImportResult> importToLibrary(
    models.VideoEvent video, {
    String? libraryTitle,
  }) async {
    final playableUrl = await video.getPlayableUrl();
    if (playableUrl == null || playableUrl.isEmpty) {
      return const VideoClipImportFailure(
        VideoClipImportFailureReason.missingVideoUrl,
      );
    }

    final documentsPath = await _getDocumentsPath();
    if (documentsPath.isEmpty) {
      return const VideoClipImportFailure(
        VideoClipImportFailureReason.unsupportedPlatform,
      );
    }

    final downloaded = await _downloadVideo(
      url: playableUrl,
      cacheKey: video.id,
    );
    if (downloaded == null || !downloaded.existsSync()) {
      return const VideoClipImportFailure(
        VideoClipImportFailureReason.downloadFailed,
      );
    }

    final importedAt = _now();
    final clipId = _clipIdFor(video, importedAt);

    try {
      await Directory(documentsPath).create(recursive: true);
      final copiedVideo = await _copyVideoIntoDocuments(
        downloaded,
        documentsPath,
        clipId,
      );

      final metadata = await _probeMetadata(copiedVideo);
      final duration = _durationFor(video, metadata);

      final thumbnail = await _extractThumbnail(
        videoPath: copiedVideo.path,
        targetTimestamp: _thumbnailTimestampFor(duration),
      );
      final ghostFramePath = await _extractLastFrame(
        videoPath: copiedVideo.path,
        videoDuration: duration,
      );

      final actualRatio = _resolveAspectRatio(video, metadata);

      final clip = DivineVideoClip(
        id: clipId,
        video: EditorVideo.file(copiedVideo.path),
        libraryTitle: defaultLibraryTitleFor(
          video,
          libraryTitle: libraryTitle,
          fallbackTime: importedAt,
        ),
        duration: duration,
        recordedAt: importedAt,
        thumbnailPath: thumbnail?.path,
        thumbnailTimestamp: thumbnail?.timestamp,
        originalAspectRatio: actualRatio ?? 1,
        targetAspectRatio: _targetAspectRatioFor(video, actualRatio),
        ghostFramePath: ghostFramePath,
        sourceAuthorPubkey: video.pubkey,
        sourceEventId: video.id,
        sourceAddressableId: video.addressableId,
        sourceRelayHint: video.sourceRelay,
      );

      await _clipLibraryService.saveClip(clip);
      return VideoClipImportSuccess(clip);
    } on FileSystemException catch (e) {
      Log.warning(
        'Failed to copy video into documents: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return const VideoClipImportFailure(
        VideoClipImportFailureReason.copyFailed,
      );
    } catch (e) {
      Log.warning(
        'Failed to save video clip: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return const VideoClipImportFailure(
        VideoClipImportFailureReason.saveFailed,
      );
    }
  }

  static String defaultLibraryTitleFor(
    models.VideoEvent video, {
    String? libraryTitle,
    DateTime? fallbackTime,
  }) {
    final explicit = _normalizedTitle(libraryTitle);
    if (explicit != null) return explicit;

    final title = _normalizedTitle(video.displayTitle);
    if (title != null) return title;

    final description = _normalizedTitle(video.displayContent);
    if (description != null) return description;

    final subtitle = _subtitleTitle(video.textTrackContent);
    if (subtitle != null) return subtitle;

    return _fallbackTitle(fallbackTime ?? DateTime.now());
  }

  static String? _subtitleTitle(String? textTrackContent) {
    if (textTrackContent == null || textTrackContent.trim().isEmpty) {
      return null;
    }
    final cues = SubtitleService.parseVtt(textTrackContent);
    for (final cue in cues) {
      final text = _normalizedTitle(cue.text);
      if (text != null) return text;
    }
    return null;
  }

  /// Caps an imported clip title, counting grapheme clusters rather than
  /// UTF-16 code units.
  ///
  /// Cutting by code unit splits a surrogate pair whenever the limit lands
  /// mid-emoji, leaving a lone surrogate that later throws
  /// `Invalid argument(s): string is not well-formed UTF-16` out of the text
  /// renderer — i.e. it makes us the source of the malformed text rather than
  /// the relay. Grapheme-cluster truncation also keeps combining marks
  /// attached to their base character.
  ///
  /// The incoming value is sanitized as well, because `_subtitleTitle` feeds
  /// this from `VideoEvent.textTrackContent` — the one source here that no
  /// model-level display boundary covers, since `SubtitleService.parseVtt`
  /// carries a relay-served cue through verbatim.
  static String? _normalizedTitle(String? value) {
    final trimmed = sanitizeUtf16OrNull(
      value,
    )?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final graphemes = trimmed.characters;
    if (graphemes.length <= 80) return trimmed;
    return '${graphemes.take(77).toString().trimRight()}...';
  }

  static String _fallbackTitle(DateTime time) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = time.toLocal();
    final month = months[local.month - 1];
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final marker = local.hour >= 12 ? 'PM' : 'AM';
    return 'Clip $month ${local.day}, $hour12:$minute $marker';
  }

  Future<File> _copyVideoIntoDocuments(
    File source,
    String documentsPath,
    String clipId,
  ) {
    final sourceExtension = p.extension(source.path);
    final extension = sourceExtension.isEmpty ? '.mp4' : sourceExtension;
    final targetPath = p.join(documentsPath, '$clipId$extension');
    return source.copy(targetPath);
  }

  String _clipIdFor(models.VideoEvent video, DateTime importedAt) {
    final safeStableId = video.stableId.replaceAll(
      RegExp('[^a-zA-Z0-9_-]'),
      '_',
    );
    final prefix = video.isOriginalVine ? 'classic_vine' : 'own_video';
    return '${prefix}_${safeStableId}_${importedAt.microsecondsSinceEpoch}';
  }

  /// Resolves the clip's duration, preferring the measured file over the
  /// event's `duration` tag.
  ///
  /// The tag cannot be trusted: every Vine archive import advertises a
  /// hardcoded `duration 6` regardless of the real length, which measures
  /// anywhere from 5.201s to 6.548s. The value becomes the export's segment
  /// end, so a wrong one truncates the clip, and on Android — which has no
  /// track-end trim — leaves custom audio playing past the last video frame,
  /// freezing it until the loop restarts (#7920).
  Duration _durationFor(models.VideoEvent video, VideoMetadata? metadata) {
    final measured = metadata?.duration;
    if (measured != null && measured > Duration.zero) return measured;

    final seconds = video.duration;
    if (seconds != null && seconds > 0) {
      return Duration(seconds: seconds);
    }
    return const Duration(seconds: 6);
  }

  /// Probes the copied file once for the duration and resolution the import
  /// needs.
  ///
  /// Returns `null` when the probe fails, leaving both to the event's own
  /// `duration` and `dim` tags — and to their defaults when it carries
  /// neither.
  Future<VideoMetadata?> _probeMetadata(File copiedVideo) async {
    try {
      return await _readVideoMetadata(EditorVideo.file(copiedVideo.path));
    } catch (e) {
      Log.warning(
        'Failed to read video metadata for ${copiedVideo.path}: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }
  }

  Duration _thumbnailTimestampFor(Duration duration) {
    const preferred = Duration(milliseconds: 210);
    final half = Duration(milliseconds: duration.inMilliseconds ~/ 2);
    return half < preferred ? half : preferred;
  }

  double? _aspectRatioFor(models.VideoEvent video) {
    final dimensions = video.dimensions;
    if (dimensions == null || dimensions.isEmpty) return null;

    final match = RegExp(r'^(\d+)x(\d+)$').firstMatch(dimensions);
    if (match == null) return null;

    final width = int.tryParse(match.group(1)!);
    final height = int.tryParse(match.group(2)!);
    if (width == null || height == null || height == 0) return null;

    return width / height;
  }

  /// Resolves the real aspect ratio of the source video.
  ///
  /// Prefers the dimensions advertised in the Nostr event, falling back to the
  /// probed [metadata] when the event has no usable `dim` tag (common for own
  /// uploads that bypass the transcoding pipeline).
  double? _resolveAspectRatio(
    models.VideoEvent video,
    VideoMetadata? metadata,
  ) {
    final fromEvent = _aspectRatioFor(video);
    if (fromEvent != null) return fromEvent;
    if (metadata == null) return null;

    final width = metadata.resolution.width;
    final height = metadata.resolution.height;
    if (width <= 0 || height <= 0) return null;
    // ProVideoEditor reports display dimensions with rotation applied.
    return width / height;
  }

  /// Determines the target crop aspect ratio for the editor.
  ///
  /// Classic Vines are always 1:1 square originals.
  /// Own videos use [actualRatio]: ratios >= [_squareishMinAspectRatio]
  /// (including landscape videos wider than 1:1) intentionally map to square.
  /// Everything narrower maps to 9:16. Falls back to 9:16 when the ratio is
  /// unknown, matching the default capture orientation.
  models.AspectRatio _targetAspectRatioFor(
    models.VideoEvent video,
    double? actualRatio,
  ) {
    if (video.isOriginalVine) return models.AspectRatio.square;
    if (actualRatio != null && actualRatio >= _squareishMinAspectRatio) {
      return models.AspectRatio.square;
    }
    return models.AspectRatio.vertical;
  }
}
