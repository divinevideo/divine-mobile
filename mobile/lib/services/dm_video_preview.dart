// ABOUTME: Reads the display preview sent with an encrypted video DM: a
// ABOUTME: blurhash of an early frame and the displayed size, never a thumbnail.

import 'dart:io';

import 'package:blurhash_service/blurhash_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Non-secret display hints for a video DM, sent inside the gift-wrapped
/// kind 15 rumor as NIP-17's `blurhash` and `dim` tags. Either may be null.
///
/// [dimensions] is `<width>x<height>` as the video displays, after rotation.
typedef DmVideoPreview = ({String? blurhash, String? dimensions});

/// Reads the [DmVideoPreview] of a plaintext video file.
typedef DmVideoPreviewReader = Future<DmVideoPreview> Function(File videoFile);

/// How long either half of a preview may take before it is left out.
const Duration dmVideoPreviewTimeout = Duration(seconds: 10);

/// Reads the [DmVideoPreview] of [videoFile]: a blurhash of the frame Divine
/// thumbnails at, and the size the video displays at.
///
/// Each half that fails or takes longer than [timeout] is left null, so a
/// video the platform cannot decode is still sent. Never throws.
Future<DmVideoPreview> readDmVideoPreview(
  File videoFile, {
  Duration timeout = dmVideoPreviewTimeout,
}) async {
  final (blurhash, dimensions) = await (
    _readBlurhash(videoFile.path).timeout(timeout, onTimeout: () => null),
    _readDimensions(videoFile.path).timeout(timeout, onTimeout: () => null),
  ).wait;
  return (blurhash: blurhash, dimensions: dimensions);
}

Future<String?> _readBlurhash(String videoPath) async {
  final frame = await VideoThumbnailService.extractThumbnailBytes(
    videoPath: videoPath,
  );
  if (frame == null) return null;
  return BlurhashService.generateBlurhash(frame.bytes);
}

Future<String?> _readDimensions(String videoPath) async {
  try {
    final metadata = await ProVideoEditor.instance.getMetadata(
      EditorVideo.file(videoPath),
    );
    final width = metadata.resolution.width.round();
    final height = metadata.resolution.height.round();
    if (width <= 0 || height <= 0) return null;
    return '${width}x$height';
  } on Exception catch (error) {
    Log.warning(
      'Could not read the size of a video DM: $error',
      name: 'DmVideoPreview',
      category: LogCategory.video,
    );
    return null;
  }
}
