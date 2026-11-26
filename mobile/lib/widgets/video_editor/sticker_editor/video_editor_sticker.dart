// ABOUTME: Sticker display widget for bundled raster stickers, the legacy SVG
// ABOUTME: stickers older drafts still name, and cached network images.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show StickerData;
import 'package:openvine/models/video_editor/sticker_group.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker_group.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Rehydrates a [VideoEditorSticker] from a serialized
/// [StickerData] map produced during state-history export, or a
/// [VideoEditorStickerGroup] from a combined sticker's meta.
///
/// The fallback of `videoEditorWidgetLayerLoader`, the editor's
/// `widgetLoader`, so sticker layers survive the editor's
/// export/reopen round-trip. Returns an empty box when [meta] is
/// `null` (legacy widget layers without sticker metadata).
Widget videoEditorStickerWidgetLoader(
  String id, {
  Map<String, dynamic>? meta,
}) {
  if (meta == null) return const SizedBox.shrink();

  if (StickerGroupData.isStickerGroupMeta(meta)) {
    final group = StickerGroupData.fromMeta(meta);
    return group == null
        ? const SizedBox.shrink()
        : VideoEditorStickerGroup(group: group);
  }

  return VideoEditorSticker(
    sticker: StickerData.fromJson(meta),
    enableLimitCacheSize: false,
  );
}

/// Whether [assetPath] names one of the OpenMoji SVGs the picker offered
/// before it moved to the DivineSticker set.
///
/// The picker no longer offers them, but drafts made before the move still
/// name them, so they stay bundled and are drawn as vectors.
bool isLegacySvgStickerAsset(String assetPath) => assetPath.endsWith('.svg');

/// A sticker widget that displays an image from either an asset or URL.
///
/// Asset stickers are raster images, apart from the legacy SVGs described at
/// [isLegacySvgStickerAsset]. Network stickers are cached raster images.
class VideoEditorSticker extends StatelessWidget {
  const VideoEditorSticker({
    required this.sticker,
    super.key,
    this.onTap,
    this.enableLimitCacheSize = true,
  });

  final StickerData sticker;

  final VoidCallback? onTap;

  /// Whether to limit the image cache size based on the widget's constraints.
  ///
  /// When `true` (default), raster images are decoded at the displayed size to
  /// reduce memory usage. This has no effect on SVG assets, which are
  /// resolution-independent. Set to `false` when the image may be scaled or
  /// zoomed (e.g., in the video editor canvas) to preserve full resolution.
  final bool enableLimitCacheSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: sticker.description.resolve(
        Localizations.localeOf(context).languageCode,
      ),
      button: onTap != null,
      child: GestureDetector(
        behavior: .translucent,
        onTap: onTap,
        child: Center(
          child: sticker.networkUrl == null
              ? _AssetImage(
                  assetPath: sticker.assetPath!,
                  enableLimitCacheSize: enableLimitCacheSize,
                )
              : enableLimitCacheSize
              ? LayoutBuilder(
                  builder: (_, constraints) {
                    if (!constraints.hasBoundedWidth ||
                        !constraints.hasBoundedHeight) {
                      return _NetworkImage(sticker: sticker);
                    }

                    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
                    final cacheWidth = (constraints.maxWidth * pixelRatio)
                        .toInt();
                    final cacheHeight = (constraints.maxHeight * pixelRatio)
                        .toInt();

                    return _NetworkImage(
                      sticker: sticker,
                      cacheWidth: cacheWidth,
                      cacheHeight: cacheHeight,
                    );
                  },
                )
              : _NetworkImage(sticker: sticker),
        ),
      ),
    );
  }
}

/// Renders a bundled sticker, decoded at the displayed size when
/// [enableLimitCacheSize] is set and the box is bounded.
class _AssetImage extends StatelessWidget {
  const _AssetImage({
    required this.assetPath,
    required this.enableLimitCacheSize,
  });

  final String assetPath;
  final bool enableLimitCacheSize;

  @override
  Widget build(BuildContext context) {
    if (isLegacySvgStickerAsset(assetPath)) {
      return SvgPicture.asset(assetPath);
    }

    final image = AssetImage(assetPath);
    if (!enableLimitCacheSize) return _RasterAssetImage(image: image);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return _RasterAssetImage(image: image);
        }

        final pixelRatio = MediaQuery.devicePixelRatioOf(context);
        return _RasterAssetImage(
          // `fit` keeps the artwork's proportions inside the box, and the
          // default `allowUpscaling: false` never decodes above its 512 px.
          image: ResizeImage(
            image,
            width: (constraints.maxWidth * pixelRatio).ceil(),
            height: (constraints.maxHeight * pixelRatio).ceil(),
            policy: ResizeImagePolicy.fit,
          ),
        );
      },
    );
  }
}

class _RasterAssetImage extends StatelessWidget {
  const _RasterAssetImage({required this.image});

  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: image,
      fit: BoxFit.contain,
      // The surrounding Semantics already names the sticker.
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => const _ErrorImage(),
    );
  }
}

/// Renders a network sticker image with optional cache sizing.
class _NetworkImage extends StatelessWidget {
  const _NetworkImage({
    required this.sticker,
    this.cacheWidth,
    this.cacheHeight,
  });

  final StickerData sticker;
  final int? cacheWidth;
  final int? cacheHeight;

  @override
  Widget build(BuildContext context) {
    return VineCachedImage(
      imageUrl: sticker.networkUrl!,
      fit: BoxFit.contain,
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      placeholder: (context, url) =>
          const Center(child: DivineCircularProgressIndicator(strokeWidth: 2)),
      errorWidget: (_, _, _) => const _ErrorImage(),
    );
  }
}

/// Placeholder shown when a sticker image fails to load.
class _ErrorImage extends StatelessWidget {
  const _ErrorImage();

  @override
  Widget build(BuildContext context) {
    return DivineIcon(
      icon: DivineIconName.warningCircle,
      size: 48,
      color: context.vineColors.mutedText,
    );
  }
}
