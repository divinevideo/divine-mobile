// ABOUTME: A file an edited video was made from, as named in its C2PA manifest
// ABOUTME: Kept on clips so an edit is signed against the media it came from

import 'package:flutter/foundation.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:unified_logger/unified_logger.dart';

/// What kind of media an edited video was made from.
enum C2paSourceKind {
  /// Footage. It must carry its own manifest: a video without one cannot be
  /// shown to be a camera capture, so an edit of it is not signed at all.
  video,

  /// A still, such as a chroma-key backdrop or a placeholder fill.
  image,

  /// A sound, such as a track from the sound library or a voice-over.
  audio,
}

/// A file an edited video was made from.
@immutable
class C2paEditSource {
  /// Creates a [C2paEditSource] for the file at [path].
  const C2paEditSource({
    required this.path,
    this.kind = C2paSourceKind.video,
    this.recordingSha256,
  });

  /// Restores a source, resolving [json]'s path against [documentsPath] the
  /// way clip file paths are resolved.
  ///
  /// Throws [FormatException] when the path is missing.
  factory C2paEditSource.fromJson(
    Map<String, dynamic> json,
    String documentsPath, {
    bool useOriginalPath = false,
  }) {
    final rawPath = json['path'];
    if (rawPath is! String || rawPath.isEmpty) {
      throw const FormatException('C2paEditSource JSON has no path');
    }
    return C2paEditSource(
      path: resolvePath(
        rawPath,
        documentsPath,
        useOriginalPath: useOriginalPath,
      )!,
      kind:
          C2paSourceKind.values.asNameMap()[json['kind']] ??
          C2paSourceKind.video,
      recordingSha256: json['recordingSha256'] as String?,
    );
  }

  /// Restores a list of sources written by [toJson], degrading to `null`
  /// when [raw] is not a list or any entry can't be read, so one unreadable
  /// field does not abort a whole draft load.
  ///
  /// The whole list is dropped, never just the bad entry: a partial list would
  /// sign an edit against part of its history. `null` makes the media its own
  /// source, and an editor render has no manifest, so an edit of it stays
  /// unsigned.
  static List<C2paEditSource>? listFromJson(
    Object? raw,
    String documentsPath, {
    bool useOriginalPath = false,
  }) {
    if (raw is! List) return null;
    try {
      return [
        for (final source in raw.cast<Map<String, dynamic>>())
          C2paEditSource.fromJson(
            source,
            documentsPath,
            useOriginalPath: useOriginalPath,
          ),
      ];
    } catch (error, stackTrace) {
      Log.error(
        'Dropping unparseable C2PA sources; the media is its own source',
        name: 'C2paEditSource',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Path of the source file.
  final String path;

  /// What the source is.
  final C2paSourceKind kind;

  /// SHA-256 of [path] as the camera wrote it, when the source is one of this
  /// app's own recordings whose capture signing may still be retried.
  ///
  /// Travels with the source into every clip edited from it, so a merge or a
  /// freeze frame made offline can still have its recordings signed later.
  /// See `DivineVideoClip.recordingSha256`.
  final String? recordingSha256;

  /// Serializes to JSON, storing only the basename like every clip path.
  ///
  /// The key is `path` so the clip library counts the file as referenced and
  /// does not delete it while an edit still points at it.
  Map<String, dynamic> toJson() => {
    'path': p.basename(path),
    'kind': kind.name,
    'recordingSha256': ?recordingSha256,
  };

  @override
  bool operator ==(Object other) =>
      other is C2paEditSource &&
      other.path == path &&
      other.kind == kind &&
      other.recordingSha256 == recordingSha256;

  @override
  int get hashCode => Object.hash(path, kind, recordingSha256);

  @override
  String toString() => 'C2paEditSource(${kind.name}: $path)';
}
