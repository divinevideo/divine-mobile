// ABOUTME: Tests that the keyframe highlight follows the canvas play time and
// ABOUTME: rebuilds only when the playhead reaches or leaves a keyframe.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/keyframes/playhead_on_keyframe_builder.dart';

void main() {
  group(PlayheadOnKeyframeBuilder, () {
    late ValueNotifier<Duration> playTime;
    late List<bool> builds;

    setUp(() {
      playTime = ValueNotifier(Duration.zero);
      builds = [];
    });

    tearDown(() => playTime.dispose());

    Future<void> pump(WidgetTester tester, List<Duration> times) =>
        tester.pumpWidget(
          VideoEditorScope(
            editorKey: GlobalKey(),
            removeAreaKey: GlobalKey(),
            originalClipAspectRatio: 9 / 16,
            bodySizeNotifier: ValueNotifier(const Size(400, 600)),
            zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
            playTimeNotifier: playTime,
            playheadAdvancingNotifier: ValueNotifier<bool>(false),
            fromLibrary: false,
            onOpenCamera: () {},
            onOpenClipsEditor: () {},
            onAddStickers: () {},
            onAddEditTextLayer: ([layer]) async => null,
            onOpenMusicLibrary: () {},
            onOpenVoiceOver: () {},
            onOpenCaptions: () {},
            onOpenEffects: () {},
            child: PlayheadOnKeyframeBuilder(
              times: times,
              builder: (context, isOnKeyframe) {
                builds.add(isOnKeyframe);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

    testWidgets('follows the play time onto and off a keyframe', (
      tester,
    ) async {
      await pump(tester, const [Duration(seconds: 1)]);
      expect(builds, [false]);

      // Within a frame at 30 fps of the keyframe counts as on it.
      playTime.value = const Duration(milliseconds: 980);
      await tester.pump();
      playTime.value = const Duration(milliseconds: 1100);
      await tester.pump();

      expect(builds, [false, true, false]);
    });

    testWidgets('rebuilds only when the answer changes', (tester) async {
      await pump(tester, const [Duration(seconds: 1)]);

      for (var ms = 100; ms <= 900; ms += 100) {
        playTime.value = Duration(milliseconds: ms);
        await tester.pump();
      }

      expect(builds, [false]);
    });

    testWidgets('answers for new keyframe times at once', (tester) async {
      playTime.value = const Duration(seconds: 2);
      await pump(tester, const [Duration(seconds: 1)]);
      await pump(tester, const [Duration(seconds: 2)]);

      expect(builds.last, isTrue);
    });
  });
}
