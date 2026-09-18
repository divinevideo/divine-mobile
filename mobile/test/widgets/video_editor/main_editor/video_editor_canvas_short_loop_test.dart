// ABOUTME: Pins how the canvas drives the timeline position on a short loop:
// ABOUTME: from its playhead ticker, wrapping, with native reports suppressed.

import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_canvas.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/divine_video_player_channel.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

/// Seeds the editor with [clips] instead of the recorder's session.
class _SeededClipManagerNotifier extends ClipManagerNotifier {
  _SeededClipManagerNotifier(this._clips);

  final List<DivineVideoClip> _clips;

  @override
  ClipManagerState build() => ClipManagerState(clips: _clips);
}

/// The mocked native player's event channel, so a test can hand the canvas
/// the position reports a real player would.
class _PlayerReports extends MockStreamHandler {
  MockStreamHandlerEventSink? _sink;

  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    _sink = events;
  }

  @override
  void onCancel(Object? arguments) {
    _sink = null;
  }

  /// A playing player's report of [positionMs] into a [durationMs] loop.
  void playing({required int positionMs, required int durationMs}) {
    _sink!.success(<Object?, Object?>{
      'status': 'playing',
      'positionMs': positionMs,
      'durationMs': durationMs,
      'bufferedPositionMs': durationMs,
      'clipCount': 1,
      'isLooping': true,
      'isFirstFrameRendered': true,
      'videoWidth': 1080,
      'videoHeight': 1920,
    });
  }
}

void main() {
  late Directory tempDir;
  late _PlayerReports reports;
  late VideoEditorMainBloc mainBloc;
  late _MockClipEditorBloc clipBloc;
  late _MockTimelineOverlayBloc overlayBloc;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = Directory.systemTemp.createTempSync('canvas_short_loop');
    reports = _PlayerReports();
    DivineVideoPlayerController.resetIdCounterForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('divine_video_player'),
          (call) async => call.method == 'create' ? {'textureId': 1} : null,
        );
    clipBloc = _MockClipEditorBloc();
    overlayBloc = _MockTimelineOverlayBloc();
    whenListen(
      overlayBloc,
      const Stream<TimelineOverlayState>.empty(),
      initialState: const TimelineOverlayState(),
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('divine_video_player'),
          null,
        );
    await mainBloc.close();
    tempDir.deleteSync(recursive: true);
  });

  DivineVideoClip clipOf(Duration duration) => DivineVideoClip(
    id: 'clip',
    video: EditorVideo.file(
      File('${tempDir.path}/clip.mp4')..writeAsBytesSync(const [0]),
    ),
    duration: duration,
    recordedAt: DateTime(2026),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
  );

  /// Mounts the canvas over one clip of [duration] and lets its player come
  /// up on the mocked channel.
  Future<void> pumpCanvas(WidgetTester tester, Duration duration) async {
    // Built inside the test body so the mocked channel's stream and the
    // bloc's event pipeline schedule on the binding's fake zone, where a
    // plain pump delivers them; created in setUp they would run on the real
    // event loop instead.
    installMockDivineVideoPlayer(streamHandler: reports);
    mainBloc = VideoEditorMainBloc();
    final clip = clipOf(duration);
    whenListen(
      clipBloc,
      const Stream<ClipEditorState>.empty(),
      initialState: ClipEditorState(clips: [clip]),
    );
    final bodySizeNotifier = ValueNotifier(const Size(360, 640));
    final zoomMatrixNotifier = ValueNotifier(Matrix4.identity());
    final playTimeNotifier = ValueNotifier(Duration.zero);
    final playheadAdvancingNotifier = ValueNotifier<bool>(false);
    addTearDown(() {
      bodySizeNotifier.dispose();
      zoomMatrixNotifier.dispose();
      playTimeNotifier.dispose();
      playheadAdvancingNotifier.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...getStandardTestOverrides(mockSharedPreferences: prefs),
          clipManagerProvider.overrideWith(
            () => _SeededClipManagerNotifier([clip]),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
              BlocProvider<ClipEditorBloc>.value(value: clipBloc),
              BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
              BlocProvider(create: (_) => VideoEditorDrawBloc()),
              BlocProvider(create: (_) => VideoEditorFilterBloc()),
            ],
            child: VideoEditorScope(
              editorKey: GlobalKey(),
              removeAreaKey: GlobalKey(),
              onOpenCamera: () {},
              onAddStickers: () {},
              onOpenClipsEditor: () {},
              onOpenMusicLibrary: () {},
              onOpenVoiceOver: () {},
              onOpenCaptions: () {},
              onAddEditTextLayer: ([_]) async => null,
              originalClipAspectRatio: 9 / 16,
              bodySizeNotifier: bodySizeNotifier,
              zoomMatrixNotifier: zoomMatrixNotifier,
              playTimeNotifier: playTimeNotifier,
              playheadAdvancingNotifier: playheadAdvancingNotifier,
              fromLibrary: false,
              child: const Scaffold(body: VideoEditorCanvas()),
            ),
          ),
        ),
      ),
    );
    // The player initialises across several awaited channel calls.
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  /// Hands the canvas a native report and lets it land, without advancing
  /// fake time — the playhead ticker stands still meanwhile.
  Future<void> report(
    WidgetTester tester, {
    required int positionMs,
    required int durationMs,
  }) async {
    reports.playing(positionMs: positionMs, durationMs: durationMs);
    await tester.pump(Duration.zero);
  }

  /// Lets the main bloc work through the position events the ticks queued,
  /// without advancing fake time.
  Future<void> settleBloc(WidgetTester tester) => tester.pump(Duration.zero);

  /// Unmounts the canvas so its player and tickers are released before the
  /// binding's pending-timer check.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  group('short loop', () {
    const loop = Duration(milliseconds: 130);

    testWidgets('drives the timeline position from the playhead ticker', (
      tester,
    ) async {
      await pumpCanvas(tester, loop);
      await report(tester, positionMs: 0, durationMs: loop.inMilliseconds);

      // 45ms of frames: one throttled emit past the 40ms interval.
      await tester.pump(const Duration(milliseconds: 45));
      await settleBloc(tester);

      expect(
        mainBloc.state.currentPosition,
        const Duration(milliseconds: 45),
      );
      await unmount(tester);
    });

    testWidgets('wraps at the loop end instead of parking there', (
      tester,
    ) async {
      await pumpCanvas(tester, loop);
      await report(tester, positionMs: 0, durationMs: loop.inMilliseconds);

      await tester.pump(const Duration(milliseconds: 45));
      await tester.pump(const Duration(milliseconds: 45));
      // 135ms since the report: 5ms into the second pass.
      await tester.pump(const Duration(milliseconds: 45));
      await settleBloc(tester);

      expect(mainBloc.state.currentPosition, const Duration(milliseconds: 5));
      await unmount(tester);
    });

    testWidgets('keeps a native report off the timeline', (tester) async {
      await pumpCanvas(tester, loop);
      await report(tester, positionMs: 0, durationMs: loop.inMilliseconds);
      await tester.pump(const Duration(milliseconds: 45));
      await settleBloc(tester);
      expect(
        mainBloc.state.currentPosition,
        const Duration(milliseconds: 45),
      );

      // A report 20ms past the last emit re-anchors the ticker but does not
      // reach the timeline itself: the tick it re-anchors is under the
      // throttle.
      await report(tester, positionMs: 65, durationMs: loop.inMilliseconds);
      await settleBloc(tester);

      expect(
        mainBloc.state.currentPosition,
        const Duration(milliseconds: 45),
      );
      await unmount(tester);
    });
  });

  group('long loop', () {
    const loop = Duration(seconds: 6);

    testWidgets('keeps following the native reports, not the ticker', (
      tester,
    ) async {
      await pumpCanvas(tester, loop);
      await report(tester, positionMs: 1000, durationMs: loop.inMilliseconds);
      await settleBloc(tester);

      expect(mainBloc.state.currentPosition, const Duration(seconds: 1));

      await tester.pump(const Duration(milliseconds: 45));
      await settleBloc(tester);

      expect(mainBloc.state.currentPosition, const Duration(seconds: 1));
      await unmount(tester);
    });
  });
}
