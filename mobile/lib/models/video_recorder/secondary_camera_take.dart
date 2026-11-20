// ABOUTME: The second camera's file of a dual-camera take, carried on its clip
// ABOUTME: for good and placed as a picture-in-picture layer over it

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;

/// The second camera's recording of a dual-camera take.
///
/// While dual-camera capture is on, every take records the front and the back
/// camera. The camera that filled the viewfinder becomes the clip; the other
/// one travels on it as this take, a clip of its own with its own proof but
/// no library entry, and becomes a picture-in-picture layer over that clip.
/// The take stays on the clip after that, so a draft opened again or posted
/// from the library places the layer once more if its history lost it.
@immutable
class SecondaryCameraTake {
  /// Creates the second camera's take.
  const SecondaryCameraTake({
    required this.clip,
    this.pipCenter = defaultPipCenter,
    this.pipScale = 1,
    this.pipRotation = 0,
    this.pipAspectRatio = model.AspectRatio.vertical,
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

  /// How much the creator pinched the window larger or smaller: its width is
  /// [pipWidthFraction] of the kept picture times this. A pinch keeps it
  /// between [pipMinScale] and [pipMaxScale]; [fittingPipScale] can take it
  /// below the smallest to keep a turned window whole.
  final double pipScale;

  /// How far the creator turned the window, in radians clockwise around its
  /// center, between -pi and pi.
  final double pipRotation;

  /// The window's shape: the whole portrait picture of the second camera, or
  /// the square from its middle, as a long press in the viewfinder chose.
  final model.AspectRatio pipAspectRatio;

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

  /// The smallest [pipScale] a pinch reaches.
  static const pipMinScale = 0.5;

  /// The largest [pipScale] a pinch reaches. The window is kept whole inside
  /// the kept picture on top of that, so a turned window or a square take can
  /// stop below it.
  static const pipMaxScale = 2.0;

  /// How round the window's corners are, as a fraction of half its shorter
  /// side (how a rectangle `LayerMask` measures it). The viewfinder rounds the
  /// window by it and the editor masks the layer by it, so the take looks
  /// the same in both.
  static const pipCornerRadius = 0.2;

  /// The size of the box a window of [size] covers once turned by
  /// [rotation] radians around its center.
  static Size turnedPipBounds(Size size, double rotation) {
    final cos = math.cos(rotation).abs();
    final sin = math.sin(rotation).abs();
    return Size(
      size.width * cos + size.height * sin,
      size.width * sin + size.height * cos,
    );
  }

  /// [scale] limited to [pipMinScale]..[pipMaxScale] and to what keeps a
  /// window of [unscaledSize] at scale 1, turned by [rotation], whole inside
  /// [area]. The viewfinder, the editor and the library picture all limit it
  /// this way, so the window keeps its size in each.
  static double fittingPipScale({
    required double scale,
    required Size unscaledSize,
    required double rotation,
    required Size area,
  }) {
    final bounds = turnedPipBounds(unscaledSize, rotation);
    var largest = pipMaxScale;
    if (bounds.width > 0) {
      largest = math.min(largest, area.width / bounds.width);
    }
    if (bounds.height > 0) {
      largest = math.min(largest, area.height / bounds.height);
    }
    if (largest <= pipMinScale) return largest;
    return scale.clamp(pipMinScale, largest);
  }

  /// Every local file the take holds a reference to.
  Iterable<String?> get ownedFilePaths sync* {
    yield* clip.ownedFilePaths;
    yield compositeThumbnailPath;
  }

  /// Returns a copy with the given fields replaced.
  SecondaryCameraTake copyWith({
    DivineVideoClip? clip,
    Offset? pipCenter,
    double? pipScale,
    double? pipRotation,
    model.AspectRatio? pipAspectRatio,
    String? compositeThumbnailPath,
  }) {
    return SecondaryCameraTake(
      clip: clip ?? this.clip,
      pipCenter: pipCenter ?? this.pipCenter,
      pipScale: pipScale ?? this.pipScale,
      pipRotation: pipRotation ?? this.pipRotation,
      pipAspectRatio: pipAspectRatio ?? this.pipAspectRatio,
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
    'pipScale': pipScale,
    'pipRotation': pipRotation,
    'pipAspectRatio': pipAspectRatio.name,
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
    final scale = json['pipScale'];
    final rotation = json['pipRotation'];
    final shape = json['pipAspectRatio'];
    final composite = json['compositeThumbnailPath'];
    return SecondaryCameraTake(
      clip: clip,
      pipCenter: x is num && y is num
          ? Offset(x.toDouble(), y.toDouble())
          : defaultPipCenter,
      // Takes from before the window could be pinched have neither.
      pipScale: scale is num ? scale.toDouble() : 1,
      pipRotation: rotation is num ? rotation.toDouble() : 0,
      pipAspectRatio: model.AspectRatio.values.firstWhere(
        (ratio) => ratio.name == shape,
        orElse: () => model.AspectRatio.vertical,
      ),
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
