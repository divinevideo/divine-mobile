// ABOUTME: Pins what the canvas tells the editor_ready trace about its first
// ABOUTME: clip load: ready only once the player shows a frame, or failed.

import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:divine_video_player/src/linux/linux_video_player_backend.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/audio_visualizer/video_editor_audio_visualizer_cubit.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/blocs/video_editor/effects_editor/video_editor_effects_cubit.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/loop_suggestion/loop_suggestion_cubit.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/text_wrap_hint/text_wrap_hint_cubit.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/observability/editor_ready_trace.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_canvas.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/divine_video_player_channel.dart';
import '../../../helpers/recording_performance_monitor.dart';
import '../../../helpers/test_provider_overrides.dart';
import '../../../helpers/video_editor/loop_repair.dart';

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

class _TraceDesktopBackend extends Fake
    implements LinuxVideoPlayerBackend, DesktopVideoFrameReadiness {
  final frame = Completer<bool>();
  int loads = 0;

  @override
  Future<bool> get firstFrameRendered => frame.future;

  @override
  Future<void> initialize({
    required void Function(DivineVideoPlayerState state) onStateChanged,
    required void Function(Object error) onError,
  }) async {}

  @override
  Future<void> setClips(
    List<VideoClip> clips, {
    Duration? startPosition,
  }) async {
    loads++;
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setLooping({required bool looping}) async {}

  @override
  Future<void> setPlaybackSpeed(double speed) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> dispose() async {}

  @override
  Widget buildView() => const SizedBox.shrink();
}

/// Seeds the editor with [clips] instead of the recorder's session.
class _SeededClipManagerNotifier extends ClipManagerNotifier {
  _SeededClipManagerNotifier(this._clips);

  final List<DivineVideoClip> _clips;

  @override
  ClipManagerState build() => ClipManagerState(clips: _clips);
}

/// The mocked native player's event channel, so a test can report the first
/// rendered frame the way the native player does.
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

  void firstFrameRendered() {
    _sink!.success(<Object?, Object?>{
      'status': 'ready',
      'positionMs': 0,
      'durationMs': 3000,
      'bufferedPositionMs': 3000,
      'clipCount': 1,
      'isLooping': true,
      'isFirstFrameRendered': true,
      'videoWidth': 1080,
      'videoHeight': 1920,
    });
  }
}

/// The streams the real `pro_video_editor` plugin listens on when the first
/// read of `ProVideoEditor.instance` constructs it.
const _proVideoEditorStreams = [
  EventChannel('pro_video_editor_progress'),
  EventChannel('pro_video_editor_logs'),
];

void main() {
  group(VideoEditorCanvas, () {
    late Directory tempDir;
    late SharedPreferences prefs;
    late _PlayerReports reports;
    late RecordingPerformanceMonitor monitor;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      tempDir = Directory.systemTemp.createTempSync('canvas_ready_trace');
      reports = _PlayerReports();
      monitor = RecordingPerformanceMonitor();
      DivineVideoPlayerController.resetIdCounterForTesting();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player'),
            (call) async => call.method == 'create' ? {'textureId': 1} : null,
          );
      for (final stream in _proVideoEditorStreams) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockStreamHandler(
              stream,
              MockStreamHandler.inline(onListen: (_, _) {}),
            );
      }
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player'),
            null,
          );
      for (final stream in _proVideoEditorStreams) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockStreamHandler(stream, null);
      }
      tempDir.deleteSync(recursive: true);
    });

    /// Mounts the canvas over one video clip with [readyTrace] in its scope,
    /// and lets its player come up on the mocked channel. [onPlayerCall]
    /// answers the player's own method calls.
    Future<void> pumpCanvas(
      WidgetTester tester,
      EditorReadyTrace readyTrace, {
      Future<Object?> Function(MethodCall call)? onPlayerCall,
    }) async {
      installMockDivineVideoPlayer(
        streamHandler: reports,
        onMethodCall: onPlayerCall,
      );
      final clip = DivineVideoClip(
        id: 'clip',
        video: EditorVideo.file(
          File('${tempDir.path}/clip.mp4')..writeAsBytesSync(const [0]),
        ),
        duration: const Duration(seconds: 3),
        recordedAt: DateTime(2026),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
      );
      final mainBloc = VideoEditorMainBloc();
      final effectsCubit = VideoEditorEffectsCubit();
      final tuneBloc = VideoEditorTuneBloc();
      final clipBloc = _MockClipEditorBloc();
      final overlayBloc = _MockTimelineOverlayBloc();
      whenListen(
        clipBloc,
        const Stream<ClipEditorState>.empty(),
        initialState: ClipEditorState(clips: [clip]),
      );
      whenListen(
        overlayBloc,
        const Stream<TimelineOverlayState>.empty(),
        initialState: const TimelineOverlayState(),
      );
      final bodySizeNotifier = ValueNotifier(const Size(360, 640));
      final zoomMatrixNotifier = ValueNotifier(Matrix4.identity());
      final playTimeNotifier = ValueNotifier(Duration.zero);
      final playheadAdvancingNotifier = ValueNotifier<bool>(false);
      addTearDown(() async {
        await mainBloc.close();
        await effectsCubit.close();
        await tuneBloc.close();
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
                BlocProvider<VideoEditorEffectsCubit>.value(
                  value: effectsCubit,
                ),
                BlocProvider<VideoEditorTuneBloc>.value(value: tuneBloc),
                BlocProvider(create: (_) => VideoEditorAudioVisualizerCubit()),
                BlocProvider(create: (_) => TextWrapHintCubit()),
                BlocProvider(
                  create: (_) =>
                      LoopSuggestionCubit(repository: noMatchLoopRepository()),
                ),
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
                onOpenEffects: () {},
                onAddEditTextLayer: ([_]) async => null,
                originalClipAspectRatio: 9 / 16,
                bodySizeNotifier: bodySizeNotifier,
                zoomMatrixNotifier: zoomMatrixNotifier,
                playTimeNotifier: playTimeNotifier,
                playheadAdvancingNotifier: playheadAdvancingNotifier,
                fromLibrary: false,
                readyTrace: readyTrace,
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

    /// Unmounts the canvas so its player and tickers are released before the
    /// binding's pending-timer check.
    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }

    group('editor_ready', () {
      testWidgets('keeps waiting when desktop first-frame work is cancelled', (
        tester,
      ) async {
        final originalFactory = DivineVideoPlayerController.linuxBackendFactory;
        final originalForce =
            DivineVideoPlayerController.debugForceLinuxBackend;
        final backend = _TraceDesktopBackend();
        DivineVideoPlayerController.debugForceLinuxBackend = true;
        DivineVideoPlayerController.linuxBackendFactory = () => backend;
        try {
          final readyTrace = EditorReadyTrace(
            monitor,
            entry: EditorEntry.recording,
          )..clipsLoaded(clipCount: 1, stopMotion: false);
          await pumpCanvas(tester, readyTrace);
          expect(backend.loads, 1);
          expect(monitor.traces.single.stops, 0);

          backend.frame.complete(false);
          await tester.pump();

          expect(readyTrace.isPending, isTrue);
          expect(monitor.traces.single.stops, 0);
          expect(tester.takeException(), isNull);
        } finally {
          await unmount(tester);
          DivineVideoPlayerController.linuxBackendFactory = originalFactory;
          DivineVideoPlayerController.debugForceLinuxBackend = originalForce;
        }
      });

      testWidgets('ends ready only once the preview shows its first frame', (
        tester,
      ) async {
        final readyTrace = EditorReadyTrace(
          monitor,
          entry: EditorEntry.recording,
        )..clipsLoaded(clipCount: 1, stopMotion: false);
        await pumpCanvas(tester, readyTrace);

        final trace = monitor.traces.single;
        expect(trace.stops, 0, reason: 'the poster still covers the preview');
        expect(readyTrace.isPending, isTrue);

        reports.firstFrameRendered();
        await tester.pump();

        expect(trace.stops, 1);
        expect(trace.attributes['outcome'], 'ready');
        expect(trace.metrics.keys, contains('player_ready_ms'));
        expect(trace.metrics.keys, contains('first_frame_ms'));

        await unmount(tester);
      });

      testWidgets('ends failed when the composition cannot load', (
        tester,
      ) async {
        final readyTrace = EditorReadyTrace(monitor, entry: EditorEntry.draft)
          ..clipsLoaded(clipCount: 1, stopMotion: false);
        await pumpCanvas(
          tester,
          readyTrace,
          onPlayerCall: (call) async {
            if (call.method == 'setClips') {
              throw PlatformException(code: 'COMPOSITION_ERROR');
            }
            return null;
          },
        );

        final trace = monitor.traces.single;
        expect(trace.stops, 1);
        expect(trace.attributes['outcome'], 'failed');
        expect(trace.metrics.keys, isNot(contains('player_ready_ms')));

        await unmount(tester);
      });
    });
  });
}
