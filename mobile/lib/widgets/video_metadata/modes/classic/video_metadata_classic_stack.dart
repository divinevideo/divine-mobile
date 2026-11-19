import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/video_metadata/modes/classic/video_metadata_classic_app_bar.dart';
import 'package:openvine/widgets/video_metadata/modes/classic/video_metadata_classic_bottom_bar.dart';
import 'package:openvine/widgets/video_metadata/modes/classic/video_metadata_classic_preview_thumbnail.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_form_fields.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_layout.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_render_failure_banner.dart';

class VideoMetadataClassicStack extends StatelessWidget {
  const VideoMetadataClassicStack({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.surfaceContainerHigh,
      appBar: const VideoMetadataClassicAppBar(),
      body: VideoMetadataLayout(
        padding: const EdgeInsets.only(top: 12),
        preview: const VideoMetadataClassicPreviewThumbnail(),
        sidePreview: (maxSize) => SizedBox.square(
          dimension: math.min(maxSize.width, maxSize.height),
          child: const VideoMetadataClassicPreviewThumbnail(),
        ),
        details: const [
          // Why the render failed, when the card is too small to say
          VideoMetadataRenderFailureBanner(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          ),
          Padding(
            padding: EdgeInsets.only(top: 16),
            child: VideoMetadataFormFields(enableIdeas: true),
          ),
        ],
        bottomBar: const VideoMetadataClassicBottomBar(),
      ),
    );
  }
}
