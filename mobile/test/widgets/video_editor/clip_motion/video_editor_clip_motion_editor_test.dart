import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/clip_motion/clip_motion_editor_cubit.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/clip_motion/video_editor_clip_motion_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

DivineVideoClip _clip({List<SegmentKeyframe> keyframes = const []}) =>
    DivineVideoClip(
      id: 'clip',
      video: EditorVideo.file('/tmp/clip.mp4'),
      duration: const Duration(seconds: 4),
      recordedAt: DateTime(2026),
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
      keyframes: keyframes,
    );

void main() {
  group('movedClipMotion', () {
    const surface = Size(100, 200);
    const base = (offset: Offset(0.1, 0), scale: 1.0, rotation: 0.0);

    test('carries the picture with the fingers', () {
      final moved = movedClipMotion(
        base,
        surface: surface,
        focalStart: Offset.zero,
        focal: const Offset(20, -40),
        scale: 1,
        rotation: 0,
      );

      expect(moved.offset, offsetMoreOrLessEquals(const Offset(0.3, -0.2)));
      expect(moved.scale, 1);
    });

    test('zooms and turns around where the fingers started', () {
      const focal = Offset(30, 50);
      final moved = movedClipMotion(
        base,
        surface: surface,
        focalStart: focal,
        focal: focal,
        scale: 2,
        rotation: math.pi / 2,
      );

      expect(moved.scale, 2);
      expect(moved.rotation, closeTo(math.pi / 2, 1e-9));
      // The picture's point under the fingers stays under them: the shift
      // (10, 0) is 20 px left of them and 50 px above, and twice as far,
      // turned clockwise, it is 100 px right and 40 px above.
      expect(
        moved.offset,
        offsetMoreOrLessEquals(const Offset(130 / 100, 10 / 200)),
      );
    });
  });

  group(VideoEditorClipMotionEditorView, () {
    late ValueNotifier<Duration> playTime;
    late List<List<SegmentKeyframe>> changes;

    setUp(() {
      playTime = ValueNotifier(const Duration(seconds: 1));
      changes = [];
    });

    tearDown(() => playTime.dispose());

    Future<void> pump(WidgetTester tester, DivineVideoClip clip) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => VideoEditorMainBloc()),
              BlocProvider(create: (_) => ClipMotionEditorCubit(clip: clip)),
            ],
            child: VideoEditorClipMotionEditorView(
              clip: clip,
              clipStart: Duration.zero,
              playTime: playTime,
              // A 90 x 160 frame at the top left of the screen.
              resolveFrame: () => (
                size: const Size(90, 160),
                transform: Matrix4.identity(),
                cornerRadius: 4,
              ),
              canvasChanges: playTime,
              onChanged: changes.add,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('adds the keyframe at the playhead', (tester) async {
      await pump(tester, _clip());
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.text(l10n.videoEditorKeyframeAdd));
      await tester.pump();

      expect(changes.last.single.time, const Duration(seconds: 1));
      expect(find.text(l10n.videoEditorKeyframeRemove), findsOneWidget);
    });

    testWidgets('moving the picture sets the keyframe at the playhead', (
      tester,
    ) async {
      await pump(tester, _clip());
      final cubit = tester
          .element(find.byType(VideoEditorClipMotionEditorView))
          .read<ClipMotionEditorCubit>();
      // Zoomed in first, so the picture has room to move.
      cubit.moveAt(const Duration(seconds: 1), (
        offset: Offset.zero,
        scale: 3,
        rotation: 0,
      ));

      // Past the slop a pan needs; the picture follows the finger from where
      // the gesture is recognized.
      final gesture = await tester.startGesture(const Offset(45, 80));
      await gesture.moveBy(const Offset(40, 0));
      await gesture.moveBy(const Offset(27, 0));
      await gesture.up();
      await tester.pump();

      final keyframe = changes.last.single;
      expect(keyframe.scale, 3);
      // At least the 27 px moved after it, of the 90 px wide frame.
      expect(keyframe.offset.dx, greaterThanOrEqualTo(0.3));
      expect(keyframe.offset.dy, 0);
    });

    testWidgets('a tap on a keyframe diamond seeks exactly onto it', (
      tester,
    ) async {
      await pump(
        tester,
        _clip(keyframes: const [SegmentKeyframe(time: Duration(seconds: 2))]),
      );
      final scrubber = tester.getRect(find.byType(DivineSlider));

      // A few pixels right of the diamond halfway along the 4 s clip.
      await tester.tapAt(
        Offset(scrubber.left + scrubber.width / 2 + 5, scrubber.center.dy),
      );
      await tester.pump();

      final mainBloc = tester
          .element(find.byType(VideoEditorClipMotionEditorView))
          .read<VideoEditorMainBloc>();
      expect(mainBloc.state.seekPosition, const Duration(seconds: 2));
    });

    testWidgets('outlines the exported frame', (tester) async {
      await pump(tester, _clip());

      final outline = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .whereType<ClipFrameOutlinePainter>()
          .single;
      expect(outline.frame.size, const Size(90, 160));
    });
  });
}
