// ABOUTME: Source mapping for a baked loop correction, retained by drafts and
// ABOUTME: history independently of the stabilization toggle.

import 'package:flutter/foundation.dart';
import 'package:openvine/models/c2pa_edit_source.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;

/// The displayed footage before a loop correction was baked into a new file.
/// The current file remains authoritative when this optional record is absent.
@immutable
class ClipLoopAlignment {
  const ClipLoopAlignment({
    required this.sourcePath,
    required this.windowStart,
    required this.sourceDuration,
    required this.operationId,
    this.sourceMinTrimStart = Duration.zero,
    this.sourceStartOffset = Duration.zero,
    this.sourceDerivedFrom,
  });

  final String sourcePath;
  final Duration windowStart;
  final Duration sourceDuration;
  final Duration sourceMinTrimStart;
  final Duration sourceStartOffset;
  final String operationId;
  final List<C2paEditSource>? sourceDerivedFrom;

  static ClipLoopAlignment? fromJson(
    Object? raw,
    String documentsPath, {
    bool useOriginalPath = false,
  }) {
    if (raw is! Map<String, dynamic>) return null;
    final path = raw['sourcePath'];
    final operation = raw['operationId'];
    final duration = raw['sourceDurationUs'];
    final window = raw['windowStartUs'];
    final floor = raw['sourceMinTrimStartUs'] ?? 0;
    final offset = raw['sourceStartOffsetUs'] ?? 0;
    if (path is! String ||
        path.isEmpty ||
        operation is! String ||
        operation.isEmpty ||
        duration is! int ||
        duration <= 0 ||
        window is! int ||
        window < 0 ||
        window >= duration ||
        floor is! int ||
        floor < 0 ||
        floor > window ||
        offset is! int ||
        offset < 0) {
      return null;
    }
    return ClipLoopAlignment(
      sourcePath: resolvePath(
        path,
        documentsPath,
        useOriginalPath: useOriginalPath,
      )!,
      windowStart: Duration(microseconds: window),
      sourceDuration: Duration(microseconds: duration),
      sourceMinTrimStart: Duration(microseconds: floor),
      sourceStartOffset: Duration(microseconds: offset),
      operationId: operation,
      sourceDerivedFrom: C2paEditSource.listFromJson(
        raw['sourceDerivedFrom'],
        documentsPath,
        useOriginalPath: useOriginalPath,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'sourcePath': p.basename(sourcePath),
    'windowStartUs': windowStart.inMicroseconds,
    'sourceDurationUs': sourceDuration.inMicroseconds,
    'sourceMinTrimStartUs': sourceMinTrimStart.inMicroseconds,
    'sourceStartOffsetUs': sourceStartOffset.inMicroseconds,
    'operationId': operationId,
    if (sourceDerivedFrom case final sources?)
      'sourceDerivedFrom': [for (final source in sources) source.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is ClipLoopAlignment &&
      sourcePath == other.sourcePath &&
      windowStart == other.windowStart &&
      sourceDuration == other.sourceDuration &&
      sourceMinTrimStart == other.sourceMinTrimStart &&
      sourceStartOffset == other.sourceStartOffset &&
      operationId == other.operationId &&
      listEquals(sourceDerivedFrom, other.sourceDerivedFrom);

  @override
  int get hashCode => Object.hash(
    sourcePath,
    windowStart,
    sourceDuration,
    sourceMinTrimStart,
    sourceStartOffset,
    operationId,
    sourceDerivedFrom == null ? null : Object.hashAll(sourceDerivedFrom!),
  );
}
