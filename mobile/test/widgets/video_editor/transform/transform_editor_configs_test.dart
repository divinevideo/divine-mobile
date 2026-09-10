// ABOUTME: Pins the shared crop-rotate editor configuration.
// ABOUTME: Chiefly the hero tag that must not match the main video editor's.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/transform/transform_editor_configs.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show OutputFormat, ProImageEditorConfigs;

void main() {
  group(transformEditorConfigs, () {
    late ProImageEditorConfigs configs;

    Future<void> build(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Builder(
            builder: (context) {
              configs = transformEditorConfigs(
                context,
                initAspectRatio: 9 / 16,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    }

    testWidgets("does not share the main editor's hero tag", (tester) async {
      await build(tester);

      // Sharing it flies a hero between the two routes, which re-parents the
      // main editor's clip preview into the navigator overlay — outside
      // BlocProvider<ClipEditorBloc> — and a stop-motion preview throws
      // ProviderNotFoundException mid-build, blanking the screen.
      expect(configs.heroTag, transformEditorHeroTag);
      expect(configs.heroTag, isNot(const ProImageEditorConfigs().heroTag));
    });

    testWidgets('locks the crop to the composition ratio', (tester) async {
      await build(tester);

      expect(configs.cropRotateEditor.initAspectRatio, 9 / 16);
      expect(configs.cropRotateEditor.enableKeepAspectRatioOnRotate, isTrue);
    });

    testWidgets('encodes JPEG, the extension the frame is written under', (
      tester,
    ) async {
      // `StopMotionFrameTransformService` names its output `.jpg`. Nothing
      // else makes that true, so a package default flipping to PNG would put
      // PNG bytes behind a `.jpg` name without a single test going red.
      await build(tester);

      expect(configs.imageGeneration.outputFormat, OutputFormat.jpg);
    });
  });
}
