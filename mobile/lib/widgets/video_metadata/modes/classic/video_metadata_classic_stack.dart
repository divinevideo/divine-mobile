import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/video_metadata/modes/classic/video_metadata_classic_app_bar.dart';
import 'package:openvine/widgets/video_metadata/modes/classic/video_metadata_classic_bottom_bar.dart';
import 'package:openvine/widgets/video_metadata/modes/classic/video_metadata_classic_preview_thumbnail.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_form_fields.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_render_failure_banner.dart';

class VideoMetadataClassicStack extends StatelessWidget {
  const VideoMetadataClassicStack({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.surfaceContainerHigh,
      appBar: const VideoMetadataClassicAppBar(),
      body: const Column(
        spacing: 12,
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: .only(top: 12),
              child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .stretch,
                children: [
                  VideoMetadataClassicPreviewThumbnail(),
                  // Why the render failed, when the card is too small to say
                  VideoMetadataRenderFailureBanner(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: VideoMetadataFormFields(),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(top: false, child: VideoMetadataClassicBottomBar()),
        ],
      ),
    );
  }
}
