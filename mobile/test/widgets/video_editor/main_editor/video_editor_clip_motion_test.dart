import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/extensions/clip_keyframes.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_clip_motion.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

DivineVideoClip _clip(
  String id, {
  List<SegmentKeyframe> keyframes = const [],
  Duration duration = const Duration(seconds: 2),
}) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/tmp/$id.mp4'),
  duration: duration,
  recordedAt: DateTime(2026),
  targetAspectRatio: model.AspectRatio.vertical,
  originalAspectRatio: 9 / 16,
  keyframes: keyframes,
);

/// Counts how often it is mounted, as the player would be.
class _Surface extends StatefulWidget {
  const _Surface();

  static int mounts = 0;

  @override
  State<_Surface> createState() => _SurfaceState();
}

class _SurfaceState extends State<_Surface> {
  @override
  void initState() {
    super.initState();
    _Surface.mounts++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  group(ClipMotionSurface, () {
    final still = _clip('still');
    final moving = _clip(
      'moving',
      keyframes: const [SegmentKeyframe(time: Duration.zero, scale: 2)],
    );

    late ValueNotifier<Duration> playTime;
    late ValueNotifier<LiveClipKeyframes?> live;

    setUp(() {
      playTime = ValueNotifier(Duration.zero);
      live = ValueNotifier(null);
      _Surface.mounts = 0;
    });

    tearDown(() {
      playTime.dispose();
      live.dispose();
    });

    Future<void> pump(WidgetTester tester) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 90,
            height: 160,
            child: ClipMotionSurface(
              clips: [still, moving],
              playTime: playTime,
              liveKeyframes: live,
              child: const _Surface(),
            ),
          ),
        ),
      ),
    );

    Matrix4 shown(WidgetTester tester) => tester
        .widget<Transform>(
          find.ancestor(
            of: find.byType(_Surface),
            matching: find.byType(Transform),
          ),
        )
        .transform;

    testWidgets('moves the surface by the clip under the playhead', (
      tester,
    ) async {
      await pump(tester);
      expect(shown(tester), Matrix4.identity());

      playTime.value = const Duration(seconds: 3);
      await tester.pump();

      expect(
        MatrixUtils.transformPoint(shown(tester), const Offset(55, 80)),
        offsetMoreOrLessEquals(const Offset(65, 80)),
      );
    });

    testWidgets('shows keyframes being edited in place of the clip own', (
      tester,
    ) async {
      await pump(tester);

      live.value = (
        clipId: 'still',
        keyframes: const [
          SegmentKeyframe(time: Duration.zero, offset: Offset(0.5, 0)),
        ],
      );
      await tester.pump();

      expect(
        MatrixUtils.transformPoint(shown(tester), Offset.zero),
        offsetMoreOrLessEquals(const Offset(45, 0)),
      );
    });

    testWidgets('does not transform a seam whose motion is already baked', (
      tester,
    ) async {
      playTime.value = const Duration(seconds: 3);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 90,
            height: 160,
            child: ClipMotionSurface(
              clips: [still, moving],
              playTime: playTime,
              isSeamAt: (_) => true,
              child: const _Surface(),
            ),
          ),
        ),
      );
      expect(shown(tester), Matrix4.identity());
    });

    testWidgets('keeps the surface mounted as the picture starts and stops '
        'moving', (tester) async {
      await pump(tester);
      playTime.value = const Duration(seconds: 3);
      await tester.pump();
      playTime.value = Duration.zero;
      await tester.pump();

      expect(_Surface.mounts, 1);
    });
  });

  group('clipMotionAtPlayTime', () {
    test('loop-wrap bodies start after the consumed head frames', () {
      final clip =
          _clip(
            'loop',
            duration: const Duration(seconds: 4),
            keyframes: const [
              SegmentKeyframe(time: Duration.zero),
              SegmentKeyframe(time: Duration(seconds: 4), scale: 5),
            ],
          ).copyWith(
            transition: const ClipTransition(type: ClipTransitionType.dissolve),
          );
      // The 500ms wrap consumes 1s of the head and 1s of the tail.
      expect(clipMotionAtPlayTime([clip], Duration.zero).scale, 2);
      expect(
        clipMotionAtPlayTime([clip], Duration.zero, applyLoopWrap: false).scale,
        1,
      );
    });
    test('reads the clip keyframes at the frame the playhead shows', () {
      final clip = _clip(
        'clip',
        keyframes: const [
          SegmentKeyframe(time: Duration.zero),
          SegmentKeyframe(time: Duration(seconds: 2), scale: 3),
        ],
      ).copyWith(playbackSpeed: 2);

      // Half a second in at 2x shows the frame a second in.
      expect(
        clipMotionAtPlayTime([clip], const Duration(milliseconds: 500)).scale,
        2,
      );
    });
  });
}
