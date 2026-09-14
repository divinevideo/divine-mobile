// ABOUTME: Widget tests for VideoEditorProcessingOverlay's progress and failure
// ABOUTME: copy. Pins that "no reading yet" is not rendered as a genuine 0%.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_editor/video_editor_processing_overlay.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

import '../../helpers/test_provider_overrides.dart';

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

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

    group('failure copy', () {
      testWidgets('asks for space instead of a blind retry when the device is '
          'out of storage (#7125)', (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: VideoEditorProcessingOverlay(
              clip: clip,
              hasFailed: true,
              failureReason: VideoRenderFailureReason.insufficientStorage,
              onRetry: () {},
            ),
          ),
        );
        await tester.pump();

        expect(find.text(_l10n.publishErrorLowStorage), findsOneWidget);
        expect(find.text(_l10n.videoMetadataGenerationFailed), findsNothing);
        expect(
          find.bySemanticsLabel(_l10n.videoErrorRetry),
          findsOneWidget,
          reason: 'freeing space and trying again is still the way out',
        );
      });

      testWidgets('keeps the generic copy for every other failure', (
        tester,
      ) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: VideoEditorProcessingOverlay(
              clip: clip,
              hasFailed: true,
              failureReason: VideoRenderFailureReason.nativeRender,
              onRetry: () {},
            ),
          ),
        );
        await tester.pump();

        expect(find.text(_l10n.videoMetadataGenerationFailed), findsOneWidget);
        expect(find.text(_l10n.publishErrorLowStorage), findsNothing);
      });
    });
  });
}
