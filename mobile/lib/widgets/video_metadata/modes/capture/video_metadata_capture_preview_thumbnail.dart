import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_clip/clip_thumbnail_image.dart';

class VideoMetadataCapturePreviewThumbnail extends StatelessWidget {
  const VideoMetadataCapturePreviewThumbnail({required this.clip, super.key});

  final DivineVideoClip clip;

  @override
  Widget build(BuildContext context) {
    if (clip.thumbnailPath == null) {
      return Center(
        child: DivineIcon(
          icon: .warning,
          size: 32,
          color: context.vineColors.mutedText,
        ),
      );
    }

    return ClipThumbnailImage(
      path: clip.thumbnailPath!,
      fit: .cover,
    );
  }
}
