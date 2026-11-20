// ABOUTME: Dims what of the frame a room part's layout cell cuts away, over
// ABOUTME: the editor's canvas while the part is edited

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/collab_room/collab_room_providers.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';
import 'package:openvine/widgets/video_clip/clip_crop_guide.dart';

/// Shows the cell of the room part being edited, or nothing outside a part.
///
/// The part keeps only a centred slice of its frame, so text or a sticker
/// placed outside it would be cut off in the posted video.
class CollabRoomCellGuide extends ConsumerWidget {
  /// Creates a guide over a frame of [frameAspectRatio].
  const CollabRoomCellGuide({required this.frameAspectRatio, super.key});

  /// Width / height of the video being edited.
  final double frameAspectRatio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:cellAspectRatio, :cellShape) = ref.watch(
      collabRoomPartProvider.select(
        (part) => part == null || !part.isActive
            ? (cellAspectRatio: null, cellShape: null)
            : (
                cellAspectRatio: part.cellAspectRatio,
                cellShape: part.cellShape,
              ),
      ),
    );
    if (cellAspectRatio == null) return const SizedBox.shrink();
    return Center(
      child: AspectRatio(
        aspectRatio: frameAspectRatio,
        child: ClipCropGuideOverlay(
          aspectRatio: cellAspectRatio,
          contentAspectRatio: frameAspectRatio,
          shape: cellShape ?? SplitScreenCellShape.rectangle,
        ),
      ),
    );
  }
}
