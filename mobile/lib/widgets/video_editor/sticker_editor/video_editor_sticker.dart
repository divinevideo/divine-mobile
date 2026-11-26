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

/// The sticker picker grid's `maxCrossAxisExtent`, in logical pixels.
///
/// A cell can come out wider by up to the grid's 16 px spacing.
const stickerPickerCellExtent = 120.0;

/// The image the sticker picker draws the raster sticker [assetPath] with.
///
/// It is decoded for [stickerPickerCellExtent] rather than the cell it lands
/// in, so [precacheStickerPickerImage] can fill the same cache entry before
/// the picker is laid out. `fit` keeps the artwork's proportions, and the
/// default `allowUpscaling: false` never decodes above its 512 px.
ImageProvider<Object> stickerPickerImage(
  String assetPath, {
  required double devicePixelRatio,
}) {
  final pixels = (stickerPickerCellExtent * devicePixelRatio).ceil();
  return ResizeImage(
    AssetImage(assetPath),
    width: pixels,
    height: pixels,
    policy: ResizeImagePolicy.fit,
  );
}

/// Decodes the picker image of the raster sticker [assetPath] into the image
/// cache, so the picker draws it in its first frame instead of popping it in.
Future<void> precacheStickerPickerImage(
  BuildContext context,
  String assetPath,
) => precacheImage(
  stickerPickerImage(
    assetPath,
    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
  ),
  context,
);

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

  /// Whether raster stickers are decoded below full size to save memory.
  ///
  /// When `true` (default), raster images are decoded small to reduce memory
  /// usage: asset stickers at the picker's cell size ([stickerPickerImage]),
  /// network images at the displayed size. This has no effect on SVG assets,
  /// which are resolution-independent. Set to `false` when the image may be
  /// scaled or zoomed (e.g., in the video editor canvas) to preserve full
  /// resolution.
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

/// Renders a bundled sticker, decoded at the picker's cell size when
/// [enableLimitCacheSize] is set.
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

    return _RasterAssetImage(
      image: enableLimitCacheSize
          ? stickerPickerImage(
              assetPath,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            )
          : AssetImage(assetPath),
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
      // No errorBuilder: a sticker that cannot load, such as one a newer
      // build bundles in a draft shared by DM, has to draw nothing, so a
      // draft render drops its layer and blocks the publish instead of
      // baking a warning icon into the video.
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
