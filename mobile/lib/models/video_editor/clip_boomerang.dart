// ABOUTME: What a boomerang timeline clip was before it was rendered to play
// ABOUTME: forward and then backward, so turning it off restores the clip.

import 'package:flutter/foundation.dart';
import 'package:openvine/models/c2pa_edit_source.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart'
    show VideoSpeedRamp, VideoSpeedRampPoint;

/// Marks a clip whose file plays its footage forward and then backward, and
/// records what it was rendered from.
///
/// The bounce is baked into the clip's video like a reverse, so the preview
/// and the export play the same frames. The render covers only the part of
/// [sourcePath] the clip showed, and the boomerang clip starts untrimmed;
/// turning it off puts that file back with the trims, duration and split
/// floor recorded here.
@immutable
class ClipBoomerang {
  const ClipBoomerang({
    required this.sourcePath,
    required this.sourceDuration,
    this.sourceTrimStart = Duration.zero,
    this.sourceTrimEnd = Duration.zero,
    this.sourceMinTrimStart = Duration.zero,
    this.sourceStartOffset = Duration.zero,
    this.sourceDerivedFrom,
  });

  /// Rebuilds the record from persisted JSON, re-anchoring file paths under
  /// [documentsPath]. Returns `null` when the JSON does not describe one.
  static ClipBoomerang? fromJson(
    Object? json,
    String documentsPath, {
    bool useOriginalPath = false,
  }) {
    if (json is! Map<String, dynamic>) return null;
    final sourcePath = resolvePath(
      json['boomerangSourcePath'] as String?,
      documentsPath,
      useOriginalPath: useOriginalPath,
    );
    if (sourcePath == null) return null;
    return ClipBoomerang(
      sourcePath: sourcePath,
      sourceDuration: _duration(json['sourceDurationUs']),
      sourceTrimStart: _duration(json['sourceTrimStartUs']),
      sourceTrimEnd: _duration(json['sourceTrimEndUs']),
      sourceMinTrimStart: _duration(json['sourceMinTrimStartUs']),
      sourceStartOffset: _duration(json['sourceStartOffsetUs']),
      // An unreadable source list degrades to "the footage is its own
      // source", as the clip's own derivedFrom does.
      sourceDerivedFrom: C2paEditSource.listFromJson(
        json['sourceDerivedFrom'],
        documentsPath,
        useOriginalPath: useOriginalPath,
      ),
    );
  }

  /// The clip's file before the boomerang.
  final String sourcePath;

  /// The clip's duration before the boomerang.
  final Duration sourceDuration;

  /// The clip's trims before the boomerang; the part between them is what
  /// the boomerang plays forward and back.
  final Duration sourceTrimStart;
  final Duration sourceTrimEnd;

  /// The clip's trim floor before the boomerang; see
  /// `DivineVideoClip.minTrimStart`.
  final Duration sourceMinTrimStart;

  /// The clip's offset within its recording before the boomerang; see
  /// `DivineVideoClip.sourceStartOffset`.
  final Duration sourceStartOffset;

  /// The C2PA sources the clip named before the boomerang, `null` when its
  /// video was its own source.
  final List<C2paEditSource>? sourceDerivedFrom;

  /// How long the part of [sourcePath] the boomerang bounces lasts.
  Duration get sourceWindow {
    final window = sourceDuration - sourceTrimStart - sourceTrimEnd;
    return window.isNegative ? Duration.zero : window;
  }

  /// Serializes the record for persisted editor state. Paths are stored as
  /// basenames: iOS rewrites the container path on app update.
  ///
  /// The path's key is one `ClipsDao` counts as a file reference, so the
  /// footage survives cleanup while the boomerang can still be turned off.
  Map<String, dynamic> toJson() => {
    'boomerangSourcePath': p.basename(sourcePath),
    'sourceDurationUs': sourceDuration.inMicroseconds,
    if (sourceTrimStart > Duration.zero)
      'sourceTrimStartUs': sourceTrimStart.inMicroseconds,
    if (sourceTrimEnd > Duration.zero)
      'sourceTrimEndUs': sourceTrimEnd.inMicroseconds,
    if (sourceMinTrimStart > Duration.zero)
      'sourceMinTrimStartUs': sourceMinTrimStart.inMicroseconds,
    if (sourceStartOffset > Duration.zero)
      'sourceStartOffsetUs': sourceStartOffset.inMicroseconds,
    if (sourceDerivedFrom case final sources?)
      'sourceDerivedFrom': [for (final source in sources) source.toJson()],
  };

  /// The speed curve of a boomerang made from a clip that played along
  /// [ramp]: the forward part keeps it, the backward part plays it mirrored,
  /// so the slow motion lands on the same moment both ways.
  ///
  /// [forwardShare] is how much of the boomerang's footage the forward part
  /// takes, between 0 and 1. It is a little over a half: the backward part
  /// leaves out the frames the bounce turns on.
  static VideoSpeedRamp bounceSpeedRamp(
    VideoSpeedRamp ramp, {
    required double forwardShare,
  }) {
    final points = [
      for (final point in ramp.points)
        VideoSpeedRampPoint(
          position: point.position * forwardShare,
          speed: point.speed,
        ),
    ];
    for (final point in ramp.reversed.points) {
      final position = forwardShare + point.position * (1 - forwardShare);
      // Where the forward curve ended on the turn, the mirrored one starts
      // at the same speed.
      if (position <= points.last.position) continue;
      points.add(
        VideoSpeedRampPoint(
          position: position > 1 ? 1 : position,
          speed: point.speed,
        ),
      );
    }
    return VideoSpeedRamp(points);
  }

  static Duration _duration(Object? value) =>
      Duration(microseconds: value is num ? value.toInt() : 0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClipBoomerang &&
          other.sourcePath == sourcePath &&
          other.sourceDuration == sourceDuration &&
          other.sourceTrimStart == sourceTrimStart &&
          other.sourceTrimEnd == sourceTrimEnd &&
          other.sourceMinTrimStart == sourceMinTrimStart &&
          other.sourceStartOffset == sourceStartOffset &&
          listEquals(other.sourceDerivedFrom, sourceDerivedFrom);

  @override
  int get hashCode => Object.hash(
    sourcePath,
    sourceDuration,
    sourceTrimStart,
    sourceTrimEnd,
    sourceMinTrimStart,
    sourceStartOffset,
    sourceDerivedFrom == null ? null : Object.hashAll(sourceDerivedFrom!),
  );

  @override
  String toString() =>
      'ClipBoomerang(sourcePath: $sourcePath, '
      'sourceDuration: $sourceDuration, sourceTrimStart: $sourceTrimStart, '
      'sourceTrimEnd: $sourceTrimEnd)';
}
