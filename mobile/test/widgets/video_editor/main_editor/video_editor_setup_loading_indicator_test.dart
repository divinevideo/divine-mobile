import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_setup_loading_indicator.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_thumbnail.dart';

void main() {
  group(VideoEditorSetupLoadingIndicator, () {
    Future<void> pumpIndicator(
      WidgetTester tester, {
      required Size renderSize,
      required Size bodySize,
      required model.AspectRatio targetAspectRatio,
    }) {
      return tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox.fromSize(
                size: bodySize,
                child: VideoEditorSetupLoadingIndicator(
                  renderSize: renderSize,
                  bodySize: bodySize,
                  targetAspectRatio: targetAspectRatio,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('sizes the thumbnail to the target ratio at render height', (
      tester,
    ) async {
      // A square target inside a 9:16 render space is contain-fitted on the
      // render height, so the visible rect is 400x400 — not the full 225x400.
      await pumpIndicator(
        tester,
        renderSize: const Size(225, 400),
        bodySize: const Size(400, 800),
        targetAspectRatio: model.AspectRatio.square,
      );

      final thumbnail = tester.widget<VideoEditorThumbnail>(
        find.byType(VideoEditorThumbnail),
      );
      expect(thumbnail.contentSize, const Size(400, 400));
    });

    testWidgets('scales the canvas radius from the visible width', (
      tester,
    ) async {
      const bodySize = Size(400, 800);
      const renderSize = Size(225, 400);

      await pumpIndicator(
        tester,
        renderSize: renderSize,
        bodySize: bodySize,
        targetAspectRatio: model.AspectRatio.vertical,
      );

      // Visible width is 400 * 9/16 = 225, so the screen-space 8px radius maps
      // to 8 * 225 / 400 in the render space the indicator is painted in.
      final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(
        clip.borderRadius,
        const BorderRadius.all(
          Radius.circular(VideoEditorConstants.canvasRadius * 225 / 400),
        ),
      );
    });
  });
}
