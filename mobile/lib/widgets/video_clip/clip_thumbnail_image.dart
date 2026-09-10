// ABOUTME: Error-tolerant Image.file wrapper for clip thumbnail and ghost
// ABOUTME: frame paths whose backing file can be missing (#5796).

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Renders a clip thumbnail / ghost frame from a local file path without
/// crashing when the file is gone.
///
/// Clip thumbnail and ghost paths are persisted as absolute paths; on iOS
/// the app container UUID changes on reinstall/update and cached files can
/// be evicted, so the file may not exist by the time it is decoded. A bare
/// `Image.file` has no image-stream error listener in that case, and the
/// resulting `PathNotFoundException` is recorded as a fatal crash
/// (Crashlytics 71e200c8, #5796). This widget renders [placeholder]
/// instead.
class ClipThumbnailImage extends StatelessWidget {
  const ClipThumbnailImage({
    required this.path,
    super.key,
    this.fit,
    this.width,
    this.height,
    this.cacheHeight,
    this.gaplessPlayback = false,
    this.excludeFromSemantics = false,
    this.placeholder,
    this.frameBuilder,
  });

  /// Absolute path of the thumbnail/ghost file.
  final String path;

  final BoxFit? fit;
  final double? width;
  final double? height;
  final int? cacheHeight;
  final bool gaplessPlayback;
  final bool excludeFromSemantics;

  /// Rendered when the file is missing or undecodable. Defaults to a
  /// neutral card-background tile with a film-slate icon (same fallback
  /// the drafts list uses for a clip with no thumbnail).
  final Widget? placeholder;

  /// Wraps the decoded image, e.g. to fade it in once the first frame
  /// lands. Forwarded verbatim to [Image.file]; not called on the error
  /// path, where [placeholder] replaces the image outright.
  final ImageFrameBuilder? frameBuilder;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: fit,
      width: width,
      height: height,
      cacheHeight: cacheHeight,
      gaplessPlayback: gaplessPlayback,
      excludeFromSemantics: excludeFromSemantics,
      frameBuilder: frameBuilder,
      errorBuilder: (context, error, stackTrace) =>
          placeholder ?? const _MissingThumbnailPlaceholder(),
    );
  }
}

class _MissingThumbnailPlaceholder extends StatelessWidget {
  const _MissingThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.vineColors.card,
      child: Center(
        child: DivineIcon(
          icon: DivineIconName.filmSlate,
          color: context.vineColors.secondaryText,
          size: 20,
        ),
      ),
    );
  }
}
