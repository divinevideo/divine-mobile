import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/extensions/layer_blend_mode.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show Layer;
import 'package:pro_video_editor/pro_video_editor.dart' show LayerBlendMode;

void main() {
  group('LayerBlendModeExport', () {
    group('exportBlendMode', () {
      test('renders every mode the editor offers as the canvas paints it', () {
        for (final mode in editorBlendModes) {
          expect(Layer(blendMode: mode.blendMode).exportBlendMode, mode);
        }
      });

      test('draws a mode the export has not as normal', () {
        expect(
          Layer(blendMode: BlendMode.colorBurn).exportBlendMode,
          LayerBlendMode.normal,
        );
      });
    });
  });
}
