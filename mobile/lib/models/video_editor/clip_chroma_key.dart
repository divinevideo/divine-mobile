// ABOUTME: Chroma-key settings used by baked timeline clips and live layers.
// ABOUTME: Wraps pro_video_editor's ChromaKey and adds the video-background
// ABOUTME: mode, which a single-track render cannot express on its own.

import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:openvine/models/c2pa_edit_source.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart';

/// What fills the area the key removed.
enum ClipChromaKeyBackgroundType {
  /// Nothing is put behind the subject.
  ///
  /// The render is H.264, which carries no alpha, so this flattens to black.
  /// It is still a distinct choice from [color]: the user is saying "no
  /// backdrop", not "a black backdrop", and a later composition path can
  /// honour it literally.
  transparent,

  /// A solid color fills it.
  color,

  /// A still image fills it, stretched to the frame.
  image,

  /// A video from the clip library plays behind the subject.
  ///
  /// Unlike the others this cannot be expressed by [ChromaKey] alone — it needs
  /// a two-layer [VideoComposition] (see [ChromaKeyBakeService]).
  video,
}

/// A clip's chroma-key settings.
///
/// For a timeline clip these settings drive the preview and are then recorded
/// alongside the key baked into the clip file, so the screen can restore the
/// user's choices. For a detached clip they remain live layer state: the canvas
/// preview and export composition both apply the persisted settings directly.
@immutable
class ClipChromaKey {
  const ClipChromaKey({required this.key, this.backgroundVideoPath})
    : assert(
        backgroundVideoPath == null || backgroundVideoPath.length > 0,
        '[backgroundVideoPath] must be a real path when set',
      );

  /// The key itself: screen color, tolerances, and — for the
  /// [ClipChromaKeyBackgroundType.color] and
  /// [ClipChromaKeyBackgroundType.image] background types — the fill.
  ///
  /// For [ClipChromaKeyBackgroundType.video] this stays transparent so the
  /// layer below shows through; the backdrop comes from [backgroundVideoPath].
  final ChromaKey key;

  /// Absolute path of the library video that plays behind the subject, or
  /// `null` for every other background type.
  final String? backgroundVideoPath;

  /// Path of the background image, or `null` when there is none.
  String? get backgroundImagePath => key.backgroundImage?.file?.path;

  /// The backdrop media this key composites behind the subject, as sources
  /// of the keyed video.
  List<C2paEditSource> get backdropSources => [
    if (backgroundVideoPath case final path?) C2paEditSource(path: path),
    if (backgroundImagePath case final path?)
      C2paEditSource(path: path, kind: C2paSourceKind.image),
  ];

  /// Which background this key fills the removed area with.
  ClipChromaKeyBackgroundType get backgroundType {
    if (backgroundVideoPath != null) return ClipChromaKeyBackgroundType.video;
    if (key.backgroundColor != null) return ClipChromaKeyBackgroundType.color;
    if (key.backgroundImage != null) return ClipChromaKeyBackgroundType.image;
    return ClipChromaKeyBackgroundType.transparent;
  }

  /// Whether baking this key needs a [VideoComposition] rather than a single
  /// keyed segment.
  bool get needsComposition =>
      backgroundType == ClipChromaKeyBackgroundType.video ||
      backgroundType == ClipChromaKeyBackgroundType.transparent;

  /// A copy with the background replaced by [videoPath].
  ///
  /// Clears any color/image fill: the four background types are mutually
  /// exclusive, and the composition needs the key itself transparent so the
  /// layer below shows through.
  ClipChromaKey withVideoBackground(String videoPath) => ClipChromaKey(
    key: key.copyWith(removeBackground: true),
    backgroundVideoPath: videoPath,
  );

  /// A copy carrying [key], dropping any video background.
  ///
  /// Use for the transparent / color / image types, whose fill lives entirely
  /// inside [ChromaKey].
  ClipChromaKey withKey(ChromaKey key) => ClipChromaKey(key: key);

  /// A copy with the screen colour or tolerances changed and the backdrop —
  /// fill or clip — kept as it is.
  ClipChromaKey withKeySettings({
    Color? color,
    double? similarity,
    double? smoothness,
    double? spill,
  }) => ClipChromaKey(
    key: key.copyWith(
      color: color,
      similarity: similarity,
      smoothness: smoothness,
      spill: spill,
    ),
    backgroundVideoPath: backgroundVideoPath,
  );

  /// A copy switched to [preset]'s screen colour and tolerances, keeping the
  /// chosen backdrop.
  ///
  /// A preset describes the screen, never what replaces it, so switching from
  /// green to blue must not throw away a backdrop the user already picked.
  ClipChromaKey withPreset(ChromaKey preset) => ClipChromaKey(
    key: preset.copyWith(
      backgroundColor: key.backgroundColor,
      backgroundImage: key.backgroundColor == null ? key.backgroundImage : null,
    ),
    backgroundVideoPath: backgroundVideoPath,
  );

  /// A copy that leaves the keyed area unfilled.
  ClipChromaKey withTransparentBackground() =>
      withKey(key.copyWith(removeBackground: true));

  /// A copy that fills the keyed area with [color].
  ClipChromaKey withColorBackground(Color color) =>
      withKey(key.copyWith(backgroundColor: color));

  /// A copy that fills the keyed area with the image at [path], stretched to
  /// the frame.
  ClipChromaKey withImageBackground(String path) =>
      withKey(key.copyWith(backgroundImage: EditorLayerImage.file(path)));

  /// Serializes the settings for persisted editor state.
  ///
  /// A timeline clip stores them to restore the screen choices associated with
  /// its baked key. A detached clip stores them as the live key applied by the
  /// canvas preview and export composition.
  Map<String, dynamic> toJson() {
    // Paths are stored as basenames: iOS rewrites the container path on app
    // update, so an absolute path in a persisted draft goes stale.
    final imagePath = backgroundImagePath;
    final videoPath = backgroundVideoPath;
    return {
      ...key.toMap(),
      'backgroundImage': imagePath != null ? p.basename(imagePath) : null,
      if (videoPath != null) 'backgroundVideo': p.basename(videoPath),
    };
  }

  /// Rebuilds settings from persisted JSON, re-anchoring file paths under
  /// [documentsPath].
  factory ClipChromaKey.fromJson(
    Map<String, dynamic> json,
    String documentsPath, {
    bool useOriginalPath = false,
  }) {
    final imagePath = resolvePath(
      json['backgroundImage'] as String?,
      documentsPath,
      useOriginalPath: useOriginalPath,
    );
    return ClipChromaKey(
      key: ChromaKey.fromMap({
        ...json,
        'backgroundImage': imagePath != null ? {'file': imagePath} : null,
      }),
      backgroundVideoPath: resolvePath(
        json['backgroundVideo'] as String?,
        documentsPath,
        useOriginalPath: useOriginalPath,
      ),
    );
  }

  @override
  String toString() =>
      'ClipChromaKey(key: $key, backgroundVideoPath: $backgroundVideoPath)';

  /// Value equality, compared field by field rather than through
  /// [ChromaKey]'s own `==`.
  ///
  /// `ChromaKey` compares its [EditorLayerImage] by identity — that class has
  /// no value equality — so two keys built from the same image path would
  /// compare unequal. The cubit's state is `Equatable` over this type, so an
  /// identity compare would emit a "changed" state for an unchanged key and
  /// rebuild the preview shader on every emit. Comparing the image by path
  /// keeps equality stable.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClipChromaKey &&
          other.key.color == key.color &&
          other.key.similarity == key.similarity &&
          other.key.smoothness == key.smoothness &&
          other.key.spill == key.spill &&
          other.key.backgroundColor == key.backgroundColor &&
          other.backgroundImagePath == backgroundImagePath &&
          other.backgroundVideoPath == backgroundVideoPath;

  @override
  int get hashCode => Object.hash(
    key.color,
    key.similarity,
    key.smoothness,
    key.spill,
    key.backgroundColor,
    backgroundImagePath,
    backgroundVideoPath,
  );
}
