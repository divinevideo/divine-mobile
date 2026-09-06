import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_clip/clip_thumbnail_image.dart';

class VideoEditorThumbnail extends ConsumerWidget {
  const VideoEditorThumbnail({
    required this.contentSize,
    super.key,
  });

  final Size contentSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clip = ref.watch(
      clipManagerProvider.select((s) => s.firstClipOrNull),
    );
    if (clip == null) return const SizedBox.shrink();

    return FittedBox(
      fit: .cover,
      child: clip.thumbnailPath != null
          ? ClipThumbnailImage(
              path: clip.thumbnailPath!,
              // A stop-motion clip's thumbnail is a raw full-resolution camera
              // still (several MB decoded), and the stop-motion player decodes
              // the same file at this height right after — bounding the decode
              // keeps the placeholder from stalling on it, and both share one
              // image-cache entry instead of decoding twice.
              cacheHeight:
                  (contentSize.height * MediaQuery.devicePixelRatioOf(context))
                      .round(),
              placeholder: SizedBox.fromSize(size: contentSize),
            )
          : SizedBox.fromSize(
              size: contentSize,
              child: Center(
                child: DivineCircularProgressIndicator(
                  color: context.vineColors.accentPositive,
                ),
              ),
            ),
    );
  }
}
