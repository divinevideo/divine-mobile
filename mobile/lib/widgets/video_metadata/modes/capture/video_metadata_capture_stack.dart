import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_app_bar.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_bottom_bar.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_clip_preview.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_form_fields.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_render_failure_banner.dart';

class VideoMetadataCaptureStack extends StatelessWidget {
  const VideoMetadataCaptureStack({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.surfaceContainerHigh,
      appBar: const VideoMetadataCaptureAppBar(),
      body: const Column(
        spacing: 12,
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .stretch,
                children: [
                  // Video preview at top
                  Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 16),
                    child: VideoMetadataCaptureClipPreview(),
                  ),

                  // Why the render failed, when the card is too small to say
                  VideoMetadataRenderFailureBanner(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  ),

                  // Form fields
                  VideoMetadataFormFields(),
                ],
              ),
            ),
          ),
          // Post button at bottom
          SafeArea(top: false, child: VideoMetadataCaptureBottomBar()),
        ],
      ),
    );
  }
}
