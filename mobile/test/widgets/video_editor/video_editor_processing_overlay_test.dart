// ABOUTME: Widget tests for VideoEditorProcessingOverlay's progress reading.
// ABOUTME: Pins that "no reading yet" is not rendered as a genuine 0%.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_editor/video_editor_processing_overlay.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

import '../../helpers/test_provider_overrides.dart';

void main() {
  final clip = DivineVideoClip(
    id: 'clip-1',
    video: EditorVideo.file('/tmp/clip.mp4'),
    duration: const Duration(seconds: 3),
    recordedAt: DateTime(2026),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
  );

  group(VideoEditorProcessingOverlay, () {
    group('progress reading', () {
      testWidgets('draws no progress ring before the first reading arrives', (
        tester,
      ) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: VideoEditorProcessingOverlay(clip: clip, isProcessing: true),
          ),
        );
        await tester.pump();

        expect(
          find.byType(BrandedLoadingIndicator),
          findsOneWidget,
          reason: 'The overlay must still say work is in flight.',
        );
        expect(
          find.byType(PartialCircleSpinner),
          findsNothing,
          reason:
              'A ring drawn at 0% before any reading exists is what made a '
              'healthy export read as a hang (#8796).',
        );
      });

      testWidgets('draws the ring once a reading arrives', (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: VideoEditorProcessingOverlay(clip: clip, isProcessing: true),
          ),
        );
        await tester.pump();

        VideoEditorRenderService.emitCompositeProgressForTesting(
          taskId: VideoEditorConstants.autoSaveId,
          progress: 0.4,
        );
        await tester.pump();
        await tester.pump();

        final spinner = tester.widget<PartialCircleSpinner>(
          find.byType(PartialCircleSpinner),
        );
        expect(spinner.progress, closeTo(0.4, 1e-9));
      });
    });
  });
}
