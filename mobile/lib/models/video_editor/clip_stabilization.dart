// ABOUTME: What a stabilized timeline clip was before its shake was baked out,
// ABOUTME: so turning stabilization off restores the clip exactly.

import 'package:flutter/foundation.dart';
import 'package:openvine/models/c2pa_edit_source.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;

/// Marks a clip whose file is a stabilized render and records what it was
/// rendered from.
///
/// Stabilization is baked into the clip's video like a green screen, so the
/// preview and the export show the same steadied picture. It always works on
/// raw footage — a baked chroma key is applied again on top — so this keeps
/// the raw, unstabilized file rather than whatever the clip showed before.
///
/// The render covers the visible part of the clip plus a margin on both
/// sides, so its file starts [windowStart] into [rawSourcePath]. The clip's
/// trims are re-anchored to the render; turning stabilization off maps them
/// back and restores the duration and split floors recorded here.
@immutable
class ClipStabilization {
  const ClipStabilization({
    required this.rawSourcePath,
    required this.windowStart,
    required this.sourceDuration,
    this.sourceMinTrimStart = Duration.zero,
    this.sourceStartOffset = Duration.zero,
    this.sourceDerivedFrom,
  });

  /// Rebuilds the record from persisted JSON, re-anchoring file paths under
  /// [documentsPath]. Returns `null` when the JSON does not describe one.
  static ClipStabilization? fromJson(
    Object? json,
    String documentsPath, {
    bool useOriginalPath = false,
  }) {
    if (json is! Map<String, dynamic>) return null;
    final rawSourcePath = resolvePath(
      json['rawSourcePath'] as String?,
      documentsPath,
      useOriginalPath: useOriginalPath,
    );
    if (rawSourcePath == null) return null;
    final derivedFrom = json['sourceDerivedFrom'];
    List<C2paEditSource>? sourceDerivedFrom;
    if (derivedFrom is List) {
      try {
        sourceDerivedFrom = [
          for (final source in derivedFrom.whereType<Map<String, dynamic>>())
            C2paEditSource.fromJson(
              source,
              documentsPath,
              useOriginalPath: useOriginalPath,
            ),
        ];
      } on FormatException {
        // An unreadable source list degrades to "the footage is its own
        // source", as the clip's own derivedFrom does.
        sourceDerivedFrom = null;
      }
    }
    return ClipStabilization(
      rawSourcePath: rawSourcePath,
      windowStart: _duration(json['windowStartUs']),
      sourceDuration: _duration(json['sourceDurationUs']),
      sourceMinTrimStart: _duration(json['sourceMinTrimStartUs']),
      sourceStartOffset: _duration(json['sourceStartOffsetUs']),
      sourceDerivedFrom: sourceDerivedFrom,
    );
  }

  /// The unstabilized footage: the clip's file before stabilization, or the
  /// footage under its green screen when it had one baked in.
  final String rawSourcePath;

  /// Where the stabilized render starts within [rawSourcePath].
  final Duration windowStart;

  /// The clip's duration before stabilization.
  final Duration sourceDuration;

  /// The clip's trim floor before stabilization; see
  /// `DivineVideoClip.minTrimStart`.
  final Duration sourceMinTrimStart;

  /// The clip's offset within its recording before stabilization; see
  /// `DivineVideoClip.sourceStartOffset`.
  final Duration sourceStartOffset;

  /// The C2PA sources the clip named before stabilization, `null` when its
  /// video was its own source.
  final List<C2paEditSource>? sourceDerivedFrom;

  /// Serializes the record for persisted editor state. Paths are stored as
  /// basenames: iOS rewrites the container path on app update.
  Map<String, dynamic> toJson() => {
    'rawSourcePath': p.basename(rawSourcePath),
    'windowStartUs': windowStart.inMicroseconds,
    'sourceDurationUs': sourceDuration.inMicroseconds,
    if (sourceMinTrimStart > Duration.zero)
      'sourceMinTrimStartUs': sourceMinTrimStart.inMicroseconds,
    if (sourceStartOffset > Duration.zero)
      'sourceStartOffsetUs': sourceStartOffset.inMicroseconds,
    if (sourceDerivedFrom case final sources?)
      'sourceDerivedFrom': [for (final source in sources) source.toJson()],
  };

  static Duration _duration(Object? value) =>
      Duration(microseconds: value is num ? value.toInt() : 0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClipStabilization &&
          other.rawSourcePath == rawSourcePath &&
          other.windowStart == windowStart &&
          other.sourceDuration == sourceDuration &&
          other.sourceMinTrimStart == sourceMinTrimStart &&
          other.sourceStartOffset == sourceStartOffset &&
          listEquals(other.sourceDerivedFrom, sourceDerivedFrom);

  @override
  int get hashCode => Object.hash(
    rawSourcePath,
    windowStart,
    sourceDuration,
    sourceMinTrimStart,
    sourceStartOffset,
    sourceDerivedFrom == null ? null : Object.hashAll(sourceDerivedFrom!),
  );

  @override
  String toString() =>
      'ClipStabilization(rawSourcePath: $rawSourcePath, '
      'windowStart: $windowStart, sourceDuration: $sourceDuration)';
}
