// ABOUTME: Placeholder shown while the video editor sets up its player
// ABOUTME: Renders the clip thumbnail clipped to the contain-fitted target rect

import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_thumbnail.dart';

/// Fills the canvas with the clip's thumbnail while the editor's video player
/// is still being set up.
class VideoEditorSetupLoadingIndicator extends StatelessWidget {
  /// Creates a [VideoEditorSetupLoadingIndicator].
  const VideoEditorSetupLoadingIndicator({
    required this.renderSize,
    required this.bodySize,
    required this.targetAspectRatio,
    super.key,
  });

  /// Size of the editor's render space.
  final Size renderSize;

  /// Size of the editor body, used to scale the corner radius.
  final Size bodySize;

  /// Aspect ratio the clip is being edited to.
  final model.AspectRatio targetAspectRatio;

  @override
  Widget build(BuildContext context) {
    // Contain mode: the visible area is targetAspectRatio fitted in renderSize
    final containSize = Size(
      renderSize.height * targetAspectRatio.value,
      renderSize.height,
    );
    final containRadius = Radius.circular(
      VideoEditorConstants.canvasRadius * containSize.width / bodySize.width,
    );

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.all(containRadius),
        child: SizedBox.fromSize(
          size: containSize,
          child: VideoEditorThumbnail(contentSize: containSize),
        ),
      ),
    );
  }
}
