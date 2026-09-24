// ABOUTME: What fills the timeline slot a detached clip left behind — a solid
// ABOUTME: colour or a photographed still — kept on the rendered clip so the
// ABOUTME: backdrop stays editable after the render

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;

/// Key under which the fill's kind is written.
const String _fillTypeKey = 'type';

/// Key under which a colour fill's ARGB value is written.
const String _fillColorKey = 'color';

/// Key under which an image fill's file name is written.
const String _fillImageKey = 'image';

const String _fillTypeColor = 'color';
const String _fillTypeImage = 'image';

/// What fills the timeline slot a clip was detached from.
///
/// Rendered into a still video clip by `ClipPlaceholderRenderService`, and
/// recorded on that clip so the backdrop can be changed later — a colour the
/// user wants a shade darker, or a photo where they first picked a colour.
/// Without it the rendered mp4 is the only record of the choice, and neither
/// the colour nor which of the two it was can be read back out of it.
@immutable
sealed class ClipPlaceholderFill {
  const ClipPlaceholderFill();

  /// Serializes the fill for persisted editor state.
  Map<String, dynamic> toJson();

  /// Rebuilds a fill from persisted JSON, re-anchoring file paths under
  /// [documentsPath].
  ///
  /// Returns `null` for anything unreadable — a draft written before the fill
  /// was recorded, a kind this build does not know, a colour of the wrong
  /// type. The clip is still a placeholder then; only the "open the picker on
  /// the colour you had" part of the flow is lost, which is why an unreadable
  /// fill is dropped rather than thrown.
  static ClipPlaceholderFill? fromJson(
    Map<String, dynamic> json,
    String documentsPath, {
    bool useOriginalPath = false,
  }) {
    switch (json[_fillTypeKey]) {
      case _fillTypeColor:
        final value = json[_fillColorKey];
        return value is int
            ? ClipPlaceholderColorFill(colorFromArgb32(value))
            : null;
      case _fillTypeImage:
        final path = resolvePath(
          json[_fillImageKey] as String?,
          documentsPath,
          useOriginalPath: useOriginalPath,
        );
        return path != null && path.isNotEmpty
            ? ClipPlaceholderImageFill(path)
            : null;
      default:
        return null;
    }
  }
}

/// Fill the slot with a solid colour.
final class ClipPlaceholderColorFill extends ClipPlaceholderFill {
  const ClipPlaceholderColorFill(this.color);

  final Color color;

  @override
  Map<String, dynamic> toJson() => {
    _fillTypeKey: _fillTypeColor,
    _fillColorKey: color.toARGB32(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClipPlaceholderColorFill && other.color == color;

  @override
  int get hashCode => color.hashCode;

  @override
  String toString() => 'ClipPlaceholderColorFill($color)';
}

/// Fill the slot with a photographed image, held for the clip's length.
final class ClipPlaceholderImageFill extends ClipPlaceholderFill {
  const ClipPlaceholderImageFill(this.imagePath);

  /// Absolute path to the image file.
  final String imagePath;

  @override
  // Stored as a basename: iOS rewrites the container path on app update, so an
  // absolute path in a persisted draft goes stale.
  Map<String, dynamic> toJson() => {
    _fillTypeKey: _fillTypeImage,
    _fillImageKey: p.basename(imagePath),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClipPlaceholderImageFill && other.imagePath == imagePath;

  @override
  int get hashCode => imagePath.hashCode;

  @override
  String toString() => 'ClipPlaceholderImageFill($imagePath)';
}
