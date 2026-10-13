// ABOUTME: Draws a combined sticker layer: every sticker it holds, placed,
// ABOUTME: rotated and mirrored the way its own layer was before combining.

import 'package:flutter/widgets.dart';
import 'package:openvine/models/video_editor/sticker_group.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker.dart';

/// Renders a [StickerGroupData] inside its `WidgetLayer`.
///
/// The layer item sizes its widget with a `FittedBox`, exactly as it does a
/// single sticker, so the group lays out at [StickerGroupData.size] and the
/// layer's width and scale stretch it from there. The outer [FittedBox] lets
/// the same widget shrink into a constrained slot such as a timeline row.
class VideoEditorStickerGroup extends StatelessWidget {
  const VideoEditorStickerGroup({required this.group, super.key});

  final StickerGroupData group;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: SizedBox.fromSize(
        size: group.size,
        child: Stack(
          clipBehavior: .none,
          children: [
            for (final child in group.children)
              _StickerGroupChildView(child: child),
          ],
        ),
      ),
    );
  }
}

/// One child of a group, transformed the way the layer item transforms a
/// layer: mirrored, then rotated around its centre.
class _StickerGroupChildView extends StatelessWidget {
  const _StickerGroupChildView({required this.child});

  final StickerGroupChild child;

  @override
  Widget build(BuildContext context) {
    final StickerGroupChild(:center, :size, :sticker, :group) = child;

    Widget content = FittedBox(
      child: group != null
          ? VideoEditorStickerGroup(group: group)
          : VideoEditorSticker(sticker: sticker!, enableLimitCacheSize: false),
    );
    if (child.rotation != 0 || child.flipX || child.flipY) {
      content = Transform(
        alignment: .center,
        transform: Matrix4.diagonal3Values(
          child.flipX ? -1 : 1,
          child.flipY ? -1 : 1,
          1,
        )..rotateZ(child.rotation),
        child: content,
      );
    }
    if (child.opacity < 1) {
      content = Opacity(opacity: child.opacity, child: content);
    }

    return Positioned(
      left: center.dx - size.width / 2,
      top: center.dy - size.height / 2,
      width: size.width,
      height: size.height,
      child: content,
    );
  }
}
