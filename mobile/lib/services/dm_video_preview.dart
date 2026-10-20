// ABOUTME: Reads the display preview sent with an encrypted video DM: a
// ABOUTME: blurhash of an early frame and the displayed size, never a thumbnail.

import 'dart:async';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:blurhash_service/blurhash_service.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Display hints for a video DM, sent inside the gift-wrapped kind 15 rumor as
/// NIP-17's `blurhash` and `dim` tags. Either may be null.
///
/// Not key material, but as private as the video: it travels only inside the
/// gift wrap and is never logged.
///
/// [dimensions] is `<width>x<height>` as the video displays, after rotation.
typedef DmVideoPreview = ({String? blurhash, String? dimensions});

/// Reads the [DmVideoPreview] of a plaintext video file. Never throws: a part
/// it cannot read is null.
typedef DmVideoPreviewReader = Future<DmVideoPreview> Function(File videoFile);

/// How long either part of a preview may take before it is left out.
const Duration dmVideoPreviewTimeout = Duration(seconds: 10);

/// Bounding box of the frame decoded for the blurhash, which is encoded from
/// at most 128 pixels across.
const Size _previewFrameSize = Size.square(256);

/// JPEG quality of that frame; a blurhash keeps only its broad colours.
const int _previewFrameQuality = 75;

/// Reads the [DmVideoPreview] of [videoFile]: a blurhash of the frame Divine
/// thumbnails at, and the size the video displays at.
///
/// A part that fails or takes longer than [timeout] is left null, so a video
/// the platform cannot decode is still sent. Never throws. A programming error
/// is also crash-reported to [reporter], which defaults to the app's reporter
/// for detached work.
Future<DmVideoPreview> readDmVideoPreview(
  File videoFile, {
  Duration timeout = dmVideoPreviewTimeout,
  CrashReporter? reporter,
}) async {
  final crashReporter = reporter ?? detachedFailureReporter;
  // Both parts start now and each settles its own failure, so neither can
  // surface uncaught while the other is awaited.
  final blurhash = _readPart(
    'frame',
    () => _readBlurhash(videoFile.path),
    timeout,
    crashReporter,
  );
  final dimensions = _readPart(
    'size',
    () => _readDimensions(videoFile.path),
    timeout,
    crashReporter,
  );
  return (blurhash: await blurhash, dimensions: await dimensions);
}

/// Reads one part of a preview, or null when it fails or times out.
///
/// The log names only the error's type and platform code: an error about the
/// file can quote its path, and a picked attachment keeps its gallery name.
Future<String?> _readPart(
  String part,
  Future<String?> Function() read,
  Duration timeout,
  CrashReporter reporter,
) async {
  try {
    return await read().timeout(timeout, onTimeout: () => null);
  } on Object catch (error, stackTrace) {
    final code = error is PlatformException ? ' ${error.code}' : '';
    Log.warning(
      'Left the $part out of a video DM preview: ${error.runtimeType}$code',
      name: 'DmVideoPreview',
      category: LogCategory.video,
    );
    final reportable = asReportableError(
      error,
      context: 'readDmVideoPreview $part',
    );
    if (reportable != null) {
      unawaited(
        reporter.recordError(
          reportable,
          stackTrace,
          reason: 'readDmVideoPreview $part',
        ),
      );
    }
    return null;
  }
}

/// One decode at Divine's thumbnail time. Deliberately not the shared
/// thumbnail service: its retries log the file path and crash-report it.
Future<String?> _readBlurhash(String videoPath) async {
  final frames = await ProVideoEditor.instance.getThumbnails(
    ThumbnailConfigs(
      video: EditorVideo.file(videoPath),
      outputSize: _previewFrameSize,
      timestamps: const [VideoEditorConstants.defaultThumbnailExtractTime],
      jpegQuality: _previewFrameQuality,
    ),
  );
  if (frames.isEmpty) return null;
  return BlurhashService.generateBlurhash(frames.first);
}

Future<String?> _readDimensions(String videoPath) async {
  final metadata = await ProVideoEditor.instance.getMetadata(
    EditorVideo.file(videoPath),
  );
  final width = metadata.resolution.width.round();
  final height = metadata.resolution.height.round();
  if (width <= 0 || height <= 0) return null;
  return '${width}x$height';
}
