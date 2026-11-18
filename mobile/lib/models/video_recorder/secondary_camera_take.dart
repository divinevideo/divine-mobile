// ABOUTME: The second camera's file of a dual-camera take, carried on its clip
// ABOUTME: until the editor turns it into a picture-in-picture layer

import 'package:flutter/widgets.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;

/// The second camera's recording of a dual-camera take.
///
/// While dual-camera capture is on, every take records the front and the back
/// camera. The camera that filled the viewfinder becomes the clip; the other
/// one travels on it as this take, a clip of its own with its own proof, and
/// becomes a picture-in-picture layer over that clip when the editor opens.
@immutable
class SecondaryCameraTake {
  /// Creates the second camera's take.
  const SecondaryCameraTake({
    required this.clip,
    this.pipCenter = defaultPipCenter,
    this.compositeThumbnailPath,
  });

  /// The second camera's recording. Silent, and it starts at the same moment
  /// as the clip it belongs to.
  final DivineVideoClip clip;

  /// Where the viewfinder showed the second camera's window: the window's
  /// center as fractions of the width and height of the picture the post
  /// keeps, the whole frame for a vertical take and its middle square for a
  /// square one. The viewfinder, the editor and the library picture all
  /// measure against that part, so the window lands where it was shown.
  final Offset pipCenter;

  /// The take's picture with the second camera's window drawn over it where
  /// the viewfinder showed it, for the places that show a take as one
  /// picture: the clip library, the drafts and the recorder's library button.
  /// Null until both cameras' thumbnails exist.
  final String? compositeThumbnailPath;

  /// Where the viewfinder starts the window: the top-left corner, below the
  /// close button and clear of the next button and the tool rail on the
  /// right. Far enough in that a phone taller than 9:16, whose viewfinder
  /// cuts the sides off a vertical frame, still shows it whole.
  static const defaultPipCenter = Offset(0.28, 0.3);

  /// The window's width as a fraction of the width of the picture the post
  /// keeps, in the viewfinder and as the editor places the layer.
  static const pipWidthFraction = 0.3;

  /// How round the window's corners are, as a fraction of half its width
  /// (how a rectangle `LayerMask` measures it). The viewfinder rounds the
  /// window by it and the editor masks the layer by it, so the take looks
  /// the same in both.
  static const pipCornerRadius = 0.2;

  /// Every local file the take holds a reference to.
  Iterable<String?> get ownedFilePaths sync* {
    yield* clip.ownedFilePaths;
    yield compositeThumbnailPath;
  }

  /// Returns a copy with the given fields replaced.
  SecondaryCameraTake copyWith({
    DivineVideoClip? clip,
    Offset? pipCenter,
    String? compositeThumbnailPath,
  }) {
    return SecondaryCameraTake(
      clip: clip ?? this.clip,
      pipCenter: pipCenter ?? this.pipCenter,
      compositeThumbnailPath:
          compositeThumbnailPath ?? this.compositeThumbnailPath,
    );
  }

  /// Serializes the take; file paths are stored as basenames like every
  /// clip's.
  Map<String, dynamic> toJson() => {
    'clip': clip.toJson(),
    'pipCenterX': pipCenter.dx,
    'pipCenterY': pipCenter.dy,
    if (compositeThumbnailPath case final path?)
      'compositeThumbnailPath': p.basename(path),
  };

  /// Restores a take written by [toJson]. Returns null for anything else, so
  /// a damaged entry costs the picture-in-picture, never its clip.
  static SecondaryCameraTake? fromJson(
    Object? json,
    String documentsPath, {
    bool useOriginalPath = false,
  }) {
    if (json is! Map) return null;
    final clipJson = json['clip'];
    if (clipJson is! Map) return null;
    final DivineVideoClip clip;
    try {
      clip = DivineVideoClip.fromJson(
        Map<String, dynamic>.from(clipJson),
        documentsPath,
        useOriginalPath: useOriginalPath,
      );
    } on FormatException {
      return null;
    }
    final x = json['pipCenterX'];
    final y = json['pipCenterY'];
    final composite = json['compositeThumbnailPath'];
    return SecondaryCameraTake(
      clip: clip,
      pipCenter: x is num && y is num
          ? Offset(x.toDouble(), y.toDouble())
          : defaultPipCenter,
      compositeThumbnailPath: composite is String
          ? resolvePath(
              composite,
              documentsPath,
              useOriginalPath: useOriginalPath,
            )
          : null,
    );
  }
}
