import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'transition_boundary_state.dart';

/// Small offset back from the trim-end so the seek lands on a real frame rather
/// than just past the last visible one.
const _boundaryFrameEpsilon = Duration(milliseconds: 50);

/// Extracts the exact boundary frame for [clip]'s tail or head, returning its
/// path or `null` when it can't be produced. Injectable so the emit-on-extract
/// and keep-placeholder-on-null paths can be tested without the real thumbnail
/// pipeline / file system.
typedef BoundaryFrameExtractor = Future<String?> Function(
  DivineVideoClip clip, {
  required bool tail,
});

/// Resolves the two frames a transition preview shows either side of the
/// boundary: the outgoing clip's last visible frame and the incoming clip's
/// first.
///
/// Starts from the caller-supplied placeholders (ghost frame / thumbnail) and
/// swaps in freshly-extracted exact boundary frames as they resolve. Owning the
/// extraction here keeps the picker UI free of any direct
/// `package:openvine/services/` dependency (UI → Cubit → service).
class TransitionBoundaryCubit extends Cubit<TransitionBoundaryState> {
  TransitionBoundaryCubit({
    required DivineVideoClip fromClip,
    required DivineVideoClip toClip,
    String? fromPlaceholder,
    String? toPlaceholder,
    BoundaryFrameExtractor? frameExtractor,
  }) : _frameExtractor = frameExtractor ?? _extractBoundaryFrame,
       super(
         TransitionBoundaryState(
           fromFramePath: fromPlaceholder,
           toFramePath: toPlaceholder,
         ),
       ) {
    _resolve(fromClip, toClip);
  }

  /// Produces the exact boundary frames. Defaults to [_extractBoundaryFrame];
  /// tests inject a fake to drive [_resolve] without the thumbnail pipeline.
  final BoundaryFrameExtractor _frameExtractor;

  Future<void> _resolve(
    DivineVideoClip fromClip,
    DivineVideoClip toClip,
  ) async {
    final from = await _frameExtractor(fromClip, tail: true);
    if (!isClosed && from != null) {
      emit(state.copyWith(fromFramePath: from));
    }
    final to = await _frameExtractor(toClip, tail: false);
    if (!isClosed && to != null) {
      emit(state.copyWith(toFramePath: to));
    }
  }

  /// Extracts the exact boundary frame: [clip]'s last visible frame
  /// ([tail] = true, at `duration - trimEnd`) or its first visible frame
  /// ([tail] = false, at `trimStart`).
  ///
  /// The frame is copied to a deterministic path keyed by clip identity + the
  /// resolved video file + trim + side. That path doubles as the cache
  /// (re-extraction is skipped when it already exists) and keeps the two
  /// boundary extractions from colliding on [VideoThumbnailService]'s
  /// timestamp-named output file. The video path is part of the key because
  /// reversing a clip swaps in a physically-reversed file while leaving the
  /// trims symmetric — without it the picker would show a stale forward frame.
  ///
  /// Returns `null` (so the caller keeps its placeholder) when the video path is
  /// unavailable or extraction fails.
  static Future<String?> _extractBoundaryFrame(
    DivineVideoClip clip, {
    required bool tail,
  }) async {
    try {
      final videoPath = await clip.requireVideo.safeFilePath();
      if (videoPath.isEmpty) return null;

      final side = tail ? 'tail' : 'head';
      final pathHash = sha256
          .convert(utf8.encode(videoPath))
          .toString()
          .substring(0, 16);
      final dir = Directory(
        p.join(
          (await getApplicationDocumentsDirectory()).path,
          'transition_frames',
        ),
      );
      final destPath = p.join(
        dir.path,
        '${clip.id}_${pathHash}_${clip.trimStart.inMicroseconds}_'
        '${clip.trimEnd.inMicroseconds}_$side.jpg',
      );
      if (File(destPath).existsSync()) return destPath;

      var position = tail
          ? clip.duration - clip.trimEnd - _boundaryFrameEpsilon
          : clip.trimStart;
      if (position < clip.trimStart) position = clip.trimStart;
      if (position < Duration.zero) position = Duration.zero;

      final result = await VideoThumbnailService.extractThumbnail(
        videoPath: videoPath,
        targetTimestamp: position,
      );
      final src = result?.path;
      if (src == null) return null;

      await dir.create(recursive: true);
      final out = await File(src).copy(destPath);
      try {
        await File(src).delete();
      } catch (_) {
        // Best effort: a lingering temp file is harmless.
      }
      return out.path;
    } catch (_) {
      return null;
    }
  }
}
