// ABOUTME: Chroma-key recorder mode: the capture stack with a live-keyed
// ABOUTME: viewfinder and a chip that opens the key and backdrop settings.

import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_capture_stack.dart';
import 'package:openvine/widgets/video_recorder/modes/chroma_key/video_recorder_chroma_key_settings.dart';

/// Chroma-key mode stack.
///
/// Records exactly like capture mode. The difference is the viewfinder, which
/// shows the keyed composite live — the camera preview keys itself in this
/// mode — and the settings chip in the top bar, which opens the key and
/// backdrop controls over that live picture.
class VideoRecorderChromaKeyStack extends StatelessWidget {
  const VideoRecorderChromaKeyStack({super.key});

  @override
  Widget build(BuildContext context) {
    return const VideoRecorderCaptureStack(
      fromEditor: false,
      topBarCenter: VideoRecorderChromaKeyChip(),
    );
  }
}
