// ABOUTME: Pins how the canvas drives the timeline position on a short loop,
// ABOUTME: and that it hands the frame effects to the player after each load.

import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_video_player/divine_video_player.dart';
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
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_canvas.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show CustomVideoEffect, EditorVideo;
import 'package:pro_video_editor/pro_video_editor.dart' as editor;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/divine_video_player_channel.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

class _OwnedPaths extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _OwnedPaths(this.path);
  final String path;
  @override
  Future<String?> getTemporaryPath() async => path;
  @override
  Future<String?> getApplicationCachePath() async => path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _GatedRenderer extends editor.ProVideoEditor {
  final firstStarted = Completer<editor.VideoRenderData>();
  final pending = <String, Completer<void>>{};
  int completedRenders = 0;
  int metadataReads = 0;
  @override
  void initializeStream() {}
  @override
  Future<String> renderVideoToFile(
    String path,
    editor.VideoRenderData data, {
    editor.NativeLogLevel? nativeLogLevel,
  }) async {
    final gate = pending[data.id] = Completer<void>();
    if (!firstStarted.isCompleted) firstStarted.complete(data);
    await gate.future;
    File(path).writeAsStringSync('rendered');
    completedRenders++;
    return path;
  }

  @override
  Future<void> cancel(String id) async {
    final gate = pending.remove(id);
    if (gate != null && !gate.isCompleted) {
      gate.completeError(const editor.RenderCanceledException());
    }
  }

  @override
  Future<editor.VideoMetadata> getMetadata(
    editor.EditorVideo video, {
    bool checkStreamingOptimization = false,
    editor.NativeLogLevel? nativeLogLevel,
  }) async {
    metadataReads++;
    return editor.VideoMetadata(
      duration: const Duration(milliseconds: 1500),
      extension: 'mp4',
      fileSize: 1024,
      resolution: const Size(1080, 1920),
      rotation: 0,
      bitrate: 1000000,
    );
  }
}

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
  late VideoEditorEffectsCubit effectsCubit;
  late _MockClipEditorBloc clipBloc;
  late _MockTimelineOverlayBloc overlayBloc;
  late SharedPreferences prefs;
  final playerCalls = <MethodCall>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = Directory.systemTemp.createTempSync('canvas_short_loop');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    reports = _PlayerReports();
    playerCalls.clear();
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

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('divine_video_player'),
          null,
        );
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
  Future<void> pumpCanvas(
    WidgetTester tester,
    Duration duration, {
    double? playbackSpeed,
    Stream<ClipEditorState>? clipStates,
    void Function(MethodCall)? onPlayerCall,
  }) async {
    // Built inside the test body so the mocked channel's stream and the
    // bloc's event pipeline schedule on the binding's fake zone, where a
    // plain pump delivers them; created in setUp they would run on the real
    // event loop instead.
    installMockDivineVideoPlayer(
      streamHandler: reports,
      onMethodCall: (call) async {
        playerCalls.add(call);
        onPlayerCall?.call(call);
        return null;
      },
    );
    // Closed by this test's own tear-down, so a test that fails before it
    // gets here has nothing to close.
    mainBloc = VideoEditorMainBloc();
    addTearDown(mainBloc.close);
    effectsCubit = VideoEditorEffectsCubit();
    addTearDown(effectsCubit.close);
    final clip = clipOf(duration).copyWith(playbackSpeed: playbackSpeed);
    whenListen(
      clipBloc,
      clipStates ?? const Stream<ClipEditorState>.empty(),
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
              BlocProvider<VideoEditorEffectsCubit>.value(value: effectsCubit),
              // Read by the same capability sync, before the clip reconcile.
              BlocProvider(create: (_) => VideoEditorAudioVisualizerCubit()),
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
    testWidgets('a finished render keeps the uncommitted preview trim', (
      tester,
    ) async {
      final originalPlugin = editor.ProVideoEditor.instance;
      final originalPaths = PathProviderPlatform.instance;
      final renderer = _GatedRenderer();
      editor.ProVideoEditor.instance = renderer;
      PathProviderPlatform.instance = _OwnedPaths(tempDir.path);
      addTearDown(() {
        editor.ProVideoEditor.instance = originalPlugin;
        PathProviderPlatform.instance = originalPaths;
      });
      final states = StreamController<ClipEditorState>.broadcast();
      addTearDown(states.close);
      Completer<MethodCall>? nextReload;
      await pumpCanvas(
        tester,
        const Duration(seconds: 3),
        playbackSpeed: 2,
        clipStates: states.stream,
        onPlayerCall: (call) {
          if (call.method == 'setClips' &&
              nextReload != null &&
              !nextReload.isCompleted) {
            nextReload.complete(call);
          }
        },
      );
      expect(tester.takeException(), isNull);
      final firstRender = await tester.runAsync(
        () => renderer.firstStarted.future.timeout(const Duration(seconds: 10)),
      );
      final original = clipBloc.state.clips.single;
      nextReload = Completer<MethodCall>();
      states.add(
        ClipEditorState(
          clips: [original.copyWith(trimEnd: const Duration(seconds: 1))],
        ),
      );
      await tester.pump();
      final previewReload = await tester.runAsync(
        () => nextReload!.future.timeout(const Duration(seconds: 10)),
      );
      expect(
        (((previewReload!.arguments as Map)['clips'] as List).single
            as Map)['endMs'],
        2000,
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }

      nextReload = Completer<MethodCall>();
      await tester.runAsync(() async {
        renderer.pending[firstRender!.id]!.complete();
        await pumpEventQueue();
      });
      await tester.pump();
      expect(
        renderer.completedRenders,
        1,
        reason: 'the gated native render completed',
      );
      // Publishing the cache does copy, rename and delete I/O; each completion
      // needs a runAsync turn, then a pump for its fake-zone continuation.
      // Under disk load that takes more turns, so drain until the reload.
      final drain = Stopwatch()..start();
      while (!nextReload.isCompleted &&
          drain.elapsed < const Duration(seconds: 10)) {
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
      }
      expect(
        renderer.metadataReads,
        1,
        reason: 'the published speed file was read',
      );
      final reload = await tester.runAsync(
        () => nextReload!.future.timeout(const Duration(seconds: 10)),
      );
      final clips = (reload!.arguments as Map)['clips'] as List;
      final end = (clips.single as Map)['endMs'];
      await unmount(tester);
      expect(end, 2000);
    });

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

    testWidgets('uses the player loop duration when seams shorten playback', (
      tester,
    ) async {
      // A rendered transition seam can make the native composite 130ms while
      // the editor still draws a 600ms timeline. The native loop is what makes
      // coarse reports unusable, so it must choose the tick path.
      await pumpCanvas(tester, const Duration(milliseconds: 600));
      await report(tester, positionMs: 0, durationMs: loop.inMilliseconds);

      await tester.pump(const Duration(milliseconds: 45));
      await settleBloc(tester);

      expect(
        mainBloc.state.currentPosition,
        const Duration(milliseconds: 45),
      );
      expect(mainBloc.state.isShortLoop, isTrue);
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

  group('frame effects', () {
    const loop = Duration(seconds: 6);
    const echo = EditorVideoEffect.custom(
      id: 'echo',
      custom: CustomVideoEffect(
        id: echoVideoEffectId,
        params: {EditorVideoEffect.intensityParam: 0.6},
        startTime: Duration(seconds: 1),
      ),
    );

    const echoArguments = {
      'effects': [
        {
          'id': echoVideoEffectId,
          'params': {EditorVideoEffect.intensityParam: 0.6},
          'startUs': 1000000,
          'endUs': null,
        },
      ],
    };

    List<MethodCall> frameEffectCalls() => [
      for (final call in playerCalls)
        if (call.method == 'setFrameEffects') call,
    ];

    testWidgets('hands the echo to the player again once the clips are '
        'reloaded', (tester) async {
      await pumpCanvas(tester, loop);
      // The canvas mirrors the editor's history into the cubit while it
      // comes up, so the echo is applied once that has settled.
      effectsCubit.syncApplied(const [echo]);
      await tester.pump();
      expect(frameEffectCalls().last.arguments, echoArguments);
      playerCalls.clear();

      // A trim moves nothing in the effects themselves, so only the reload
      // can make the canvas send them again.
      ProviderScope.containerOf(
        tester.element(find.byType(VideoEditorCanvas)),
      ).read(clipManagerProvider.notifier).replaceClips([
        clipOf(loop).copyWith(trimEnd: const Duration(seconds: 1)),
      ], autosave: false);
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }

      expect(
        playerCalls.map((call) => call.method),
        containsAllInOrder(['setClips', 'setFrameEffects']),
      );
      expect(frameEffectCalls().single.arguments, echoArguments);
      await unmount(tester);
    });
  });
}
