// ABOUTME: Pins that the test harness installs StreamlessProVideoEditor before
// ABOUTME: any test reads ProVideoEditor.instance (#10352).

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show ProVideoEditor;

import 'streamless_pro_video_editor.dart';

void main() {
  group(StreamlessProVideoEditor, () {
    test('is the plugin a test reads before it installs its own', () {
      // The real plugin never listens on Linux, so Mobile CI cannot see the
      // macOS failure itself. This is what fails there if
      // flutter_test_config.dart stops installing the harness default.
      expect(ProVideoEditor.instance, isA<StreamlessProVideoEditor>());
    });
  });
}
