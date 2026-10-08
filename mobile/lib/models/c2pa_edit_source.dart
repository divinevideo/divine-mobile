// ABOUTME: A file an edited video was made from, as named in its C2PA manifest
// ABOUTME: Kept on clips so an edit is signed against the media it came from

import 'package:flutter/foundation.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;

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
  const C2paEditSource({required this.path, this.kind = C2paSourceKind.video});

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
    );
  }

  /// Path of the source file.
  final String path;

  /// What the source is.
  final C2paSourceKind kind;

  /// Serializes to JSON, storing only the basename like every clip path.
  ///
  /// The key is `path` so the clip library counts the file as referenced and
  /// does not delete it while an edit still points at it.
  Map<String, dynamic> toJson() => {
    'path': p.basename(path),
    'kind': kind.name,
  };

  @override
  bool operator ==(Object other) =>
      other is C2paEditSource && other.path == path && other.kind == kind;

  @override
  int get hashCode => Object.hash(path, kind);

  @override
  String toString() => 'C2paEditSource(${kind.name}: $path)';
}
