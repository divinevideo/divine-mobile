import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/constants/text_scale_limits.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_stop_motion_budget.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_progress_bar.dart';

import '../../../../helpers/text_lines.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

class _StubClipManagerNotifier extends ClipManagerNotifier {
  _StubClipManagerNotifier(this._clips);

  final List<DivineVideoClip> _clips;

  @override
  ClipManagerState build() => ClipManagerState(clips: _clips);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoRecorderStopMotionBudget, () {
    late _MockVideoRecorderBloc recorderBloc;
    late AppLocalizations l10n;

    setUp(() {
      recorderBloc = _MockVideoRecorderBloc();
      l10n = lookupAppLocalizations(const Locale('en'));
    });

    /// The stop-motion composition the recorder was reopened over: [frames]
    /// stills each held for [framesPerImage] output frames.
    List<DivineVideoClip> clipsOf({
      required int frames,
      required int framesPerImage,
    }) {
      if (frames == 0) return const [];
      final hold = StopMotionFrameOps.framesPerImageToDuration(framesPerImage);
      return [
        DivineVideoClip(
          id: 'committed',
          stopMotionFrames: [
            for (var i = 0; i < frames; i++)
              StopMotionClipFrame(
                path: '/tmp/committed_$i.jpg',
                duration: hold,
              ),
          ],
          duration: hold * frames,
          recordedAt: DateTime(2024),
          targetAspectRatio: model.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
        ),
      ];
    }

    Widget buildWidget({
      required int capturedFrames,
      int committedFrames = 0,
      int committedFramesPerImage = 1,
      Locale locale = const Locale('en'),
      bool betweenButtons = false,
    }) {
      when(() => recorderBloc.state).thenReturn(
        VideoRecorderBlocState(
          recorderMode: .stopMotion,
          stopMotionFrames: [
            for (var i = 0; i < capturedFrames; i++) 'frame_$i.jpg',
          ],
        ),
      );

      return ProviderScope(
        overrides: [
          clipManagerProvider.overrideWith(
            () => _StubClipManagerNotifier(
              clipsOf(
                frames: committedFrames,
                framesPerImage: committedFramesPerImage,
              ),
            ),
          ),
        ],
        child: BlocProvider<VideoRecorderBloc>.value(
          value: recorderBloc,
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // Renders a Flexible for the top bar's center slot, so it needs a
            // Row around it.
            home: Scaffold(
              body: betweenButtons
                  // The top bar's insets, with its close and next buttons on
                  // either side.
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        spacing: 12,
                        children: [
                          SizedBox.square(dimension: 40),
                          VideoRecorderStopMotionBudget(),
                          SizedBox.square(dimension: 40),
                        ],
                      ),
                    )
                  : const Row(children: [VideoRecorderStopMotionBudget()]),
            ),
          ),
        ),
      );
    }

    /// The rendered count. The label is in the tree twice — once visible, once
    /// as the invisible spacer that drops the bar onto the buttons' center
    /// line — so this reads it off the bar rather than counting Text widgets.
    String renderedLabel(WidgetTester tester) => tester
        .widget<VideoRecorderProgressBar>(
          find.byType(VideoRecorderProgressBar),
        )
        .label;

    testWidgets('shows the full budget before the first still', (tester) async {
      await tester.pumpWidget(buildWidget(capturedFrames: 0));

      expect(
        renderedLabel(tester),
        l10n.videoRecorderStopMotionShotsLeft(
          StopMotionFrameOps.maxCaptureFrames,
        ),
      );
      expect(find.text(renderedLabel(tester)), findsWidgets);
    });

    testWidgets('counts the remaining stills down as frames are captured', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget(capturedFrames: 5));

      expect(
        renderedLabel(tester),
        l10n.videoRecorderStopMotionShotsLeft(
          StopMotionFrameOps.maxCaptureFrames - 5,
        ),
      );
    });

    testWidgets('puts the bar itself on the center line the row aligns to', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget(capturedFrames: 5));

      // The bar is the only Container in the subtree carrying a decoration;
      // the three segments are plain `Container(color:)`.
      final barRect = tester.getRect(
        find.byWidgetPredicate((w) => w is Container && w.decoration != null),
      );
      final groupRect = tester.getRect(
        find.byType(VideoRecorderStopMotionBudget),
      );

      // A Row centers its children, so the group's center is what lands on the
      // close/next buttons' center line — the bar has to sit on it, not the
      // count above it.
      expect(barRect.center.dy, moreOrLessEquals(groupRect.center.dy));
    });

    testWidgets('fills the bar in proportion to the stills captured', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget(capturedFrames: 5));

      final bar = tester.widget<VideoRecorderProgressBar>(
        find.byType(VideoRecorderProgressBar),
      );
      expect(bar.filled, 5);
      expect(bar.remaining, StopMotionFrameOps.maxCaptureFrames - 5);
      expect(bar.overflow, 0);
    });

    testWidgets('shows the overflow segment once the budget is blown', (
      tester,
    ) async {
      final over = StopMotionFrameOps.maxCaptureFrames + 3;
      await tester.pumpWidget(buildWidget(capturedFrames: over));

      final bar = tester.widget<VideoRecorderProgressBar>(
        find.byType(VideoRecorderProgressBar),
      );
      expect(bar.filled, StopMotionFrameOps.maxCaptureFrames);
      expect(bar.remaining, 0);
      expect(bar.overflow, 3);
      expect(bar.label, l10n.videoRecorderStopMotionShotsLeft(0));
    });

    testWidgets('counts only what the committed composition has left', (
      tester,
    ) async {
      // Reopened from the editor over a composition already holding a third of
      // the ceiling: the session starts from what is left, not a full budget.
      final committed = StopMotionFrameOps.maxCaptureFrames ~/ 3;
      await tester.pumpWidget(
        buildWidget(capturedFrames: 0, committedFrames: committed),
      );

      expect(
        renderedLabel(tester),
        l10n.videoRecorderStopMotionShotsLeft(
          StopMotionFrameOps.maxCaptureFrames - committed,
        ),
      );
    });

    testWidgets('counts at the hold the composition will give the new stills', (
      tester,
    ) async {
      // A clip on threes re-holds spliced stills at three output frames each,
      // so what is left of the ceiling fits a third as many of them.
      await tester.pumpWidget(
        buildWidget(
          capturedFrames: 0,
          committedFrames: 3,
          committedFramesPerImage: 3,
        ),
      );

      expect(
        renderedLabel(tester),
        l10n.videoRecorderStopMotionShotsLeft(
          StopMotionFrameOps.maxCaptureFramesAfter(
            StopMotionFrameOps.framesPerImageToDuration(3) * 3,
            framesPerImage: 3,
          ),
        ),
      );
    });

    // The budget is the one piece of chrome capture mode does not render, so
    // e2e/maestro/asserts/assertStopMotionMode.yaml uses it to prove the top
    // bar's center slot is the stop-motion one. Every other test here reads
    // the widget directly and would stay green with the anchor dropped.
    testWidgets('exposes the E2E identifier, carrying the count', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildWidget(capturedFrames: 5));

      final node = tester.getSemantics(
        find.bySemanticsIdentifier(SemanticIds.cameraStopMotionBudget),
      );
      expect(
        node.label,
        l10n.videoRecorderStopMotionShotsLeft(
          StopMotionFrameOps.maxCaptureFrames - 5,
        ),
      );

      handle.dispose();
    });

    testWidgets('keeps the count to one line between the top-bar buttons at '
        'the largest font size', (tester) async {
      // A 360dp Android phone at the largest font size, in German, whose
      // count is the longest. Wrapped, it pushed the buttons down into the
      // side rail.
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view
          ..resetPhysicalSize()
          ..resetDevicePixelRatio();
        tester.platformDispatcher.clearAllTestValues();
      });

      await tester.pumpWidget(
        buildWidget(
          capturedFrames: 5,
          locale: const Locale('de'),
          betweenButtons: true,
        ),
      );

      final labelFinder = find.descendant(
        of: find.byType(VideoRecorderProgressBar),
        matching: find.byType(RichText),
      );
      expect(lineCountOf(tester, labelFinder), 1);
      final label = tester.renderObject<RenderParagraph>(labelFinder);
      // No larger than the audio chip lip-sync puts in the same slot.
      expect(
        label.textScaler.scale(14),
        lessThanOrEqualTo(14 * chipLabelTextScaleLimit),
      );
    });

    testWidgets('offers nothing once the composition fills the maximum', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(
          capturedFrames: 0,
          committedFrames: StopMotionFrameOps.maxCaptureFrames,
        ),
      );

      expect(renderedLabel(tester), l10n.videoRecorderStopMotionShotsLeft(0));
    });
  });
}
