// ABOUTME: Pins that a route transition between two editors never builds the
// ABOUTME: canvas preview outside the editor that owns it.

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
import 'package:openvine/blocs/video_editor/loop_suggestion/loop_suggestion_cubit.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/text_wrap_hint/text_wrap_hint_cubit.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_canvas.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_clip_preview.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/divine_video_player_channel.dart';
import '../../../helpers/test_provider_overrides.dart';
import '../../../helpers/video_editor/loop_repair.dart';

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

/// The streams the real `pro_video_editor` plugin listens on when the first
/// read of `ProVideoEditor.instance` constructs it.
const _proVideoEditorStreams = [
  EventChannel('pro_video_editor_progress'),
  EventChannel('pro_video_editor_logs'),
];

/// One editor session's blocs and notifiers, as `VideoEditorScreen` owns them.
class _EditorSession {
  _EditorSession(List<DivineVideoClip> clips) {
    whenListen(
      clipBloc,
      const Stream<ClipEditorState>.empty(),
      initialState: ClipEditorState(clips: clips),
    );
    whenListen(
      overlayBloc,
      const Stream<TimelineOverlayState>.empty(),
      initialState: const TimelineOverlayState(),
    );
  }

  final mainBloc = VideoEditorMainBloc();
  final effectsCubit = VideoEditorEffectsCubit();
  final tuneBloc = VideoEditorTuneBloc();
  final clipBloc = _MockClipEditorBloc();
  final overlayBloc = _MockTimelineOverlayBloc();
  final bodySizeNotifier = ValueNotifier<Size>(const Size(360, 640));
  final zoomMatrixNotifier = ValueNotifier<Matrix4>(Matrix4.identity());
  final playTimeNotifier = ValueNotifier<Duration>(Duration.zero);
  final playheadAdvancingNotifier = ValueNotifier<bool>(false);

  Future<void> dispose() async {
    await mainBloc.close();
    await effectsCubit.close();
    await tuneBloc.close();
    bodySizeNotifier.dispose();
    zoomMatrixNotifier.dispose();
    playTimeNotifier.dispose();
    playheadAdvancingNotifier.dispose();
  }
}

/// An editor route's body: the blocs and the scope the screen puts above the
/// canvas.
class _EditorBody extends StatelessWidget {
  const _EditorBody(this.session);

  final _EditorSession session;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<VideoEditorMainBloc>.value(value: session.mainBloc),
        BlocProvider<ClipEditorBloc>.value(value: session.clipBloc),
        BlocProvider<TimelineOverlayBloc>.value(value: session.overlayBloc),
        BlocProvider(create: (_) => VideoEditorDrawBloc()),
        BlocProvider(create: (_) => VideoEditorFilterBloc()),
        BlocProvider<VideoEditorEffectsCubit>.value(
          value: session.effectsCubit,
        ),
        BlocProvider<VideoEditorTuneBloc>.value(value: session.tuneBloc),
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
        bodySizeNotifier: session.bodySizeNotifier,
        zoomMatrixNotifier: session.zoomMatrixNotifier,
        playTimeNotifier: session.playTimeNotifier,
        playheadAdvancingNotifier: session.playheadAdvancingNotifier,
        fromLibrary: false,
        child: const Scaffold(body: VideoEditorCanvas()),
      ),
    );
  }
}

/// Alternates real async turns with frames until [count] previews are built.
///
/// pro_image_editor builds its video body only after decoding a transparent
/// background image, which finishes on the real event loop rather than the
/// test's fake one, so the wait is bounded in real time.
Future<void> _settleUntilPreviews(
  WidgetTester tester,
  Finder previews,
  int count,
) async {
  final waited = Stopwatch()..start();
  while (previews.evaluate().length < count &&
      waited.elapsed < const Duration(seconds: 10)) {
    await tester.runAsync(pumpEventQueue);
    await tester.pump();
  }
}

void main() {
  group(VideoEditorCanvas, () {
    late Directory tempDir;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      tempDir = Directory.systemTemp.createTempSync('canvas_hero');
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

    testWidgets(
      'closing an editor pushed over another builds no preview outside its '
      '$VideoEditorScope',
      (tester) async {
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
        // Each canvas creates its own player, on its own channels.
        installMockDivineVideoPlayer();
        installMockDivineVideoPlayer(playerId: 1);
        final first = _EditorSession([clip]);
        final second = _EditorSession([clip]);
        addTearDown(first.dispose);
        addTearDown(second.dispose);
        final navigatorKey = GlobalKey<NavigatorState>();
        final previews = find.byType(
          VideoEditorClipPreview,
          skipOffstage: false,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...getStandardTestOverrides(mockSharedPreferences: prefs),
              clipManagerProvider.overrideWith(
                () => _SeededClipManagerNotifier([clip]),
              ),
            ],
            child: MaterialApp(
              navigatorKey: navigatorKey,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: _EditorBody(first),
            ),
          ),
        );
        await _settleUntilPreviews(tester, previews, 1);
        expect(previews, findsOneWidget);

        // A second tap on the recorder's next button pushes another editor
        // over the first, on the same app navigator.
        final pushed = navigatorKey.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => _EditorBody(second)),
        );
        await _settleUntilPreviews(tester, previews, 2);
        expect(previews, findsNWidgets(2));
        // Lets the push transition finish.
        await tester.pump(const Duration(milliseconds: 500));

        // Both editors have loaded, so a hero tag they share flies the first
        // one's preview through the app navigator's overlay on the way back.
        navigatorKey.currentState!.pop();
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          for (final preview in previews.evaluate()) {
            expect(VideoEditorScope.maybeOf(preview), isNotNull);
          }
        }
        await pushed;
        // Lets the pop transition finish and remove the second editor.
        await tester.pump(const Duration(milliseconds: 500));

        expect(tester.takeException(), isNull);
        expect(previews, findsOneWidget);

        // Unmounts the canvas so its player and tickers are released before
        // the binding's pending-timer check.
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  });
}
