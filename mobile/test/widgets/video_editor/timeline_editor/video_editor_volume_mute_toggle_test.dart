// ABOUTME: Tests the timeline's mute-all toggle: what it decides from the
// ABOUTME: clip, sound and detached-clip volumes, and where it writes them.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_layer_view.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_volume_mute_toggle.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show
        Layer,
        ProImageEditorState,
        StateManager,
        WidgetLayer,
        WidgetLayerExportConfigs;
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

class _MockStateManager extends Mock implements StateManager {}

/// A clip detached onto the canvas, playing at [volume].
WidgetLayer _detachedLayer({required double volume}) {
  final meta = DetachedClipLayerData(
    clip: DivineVideoClip(
      id: 'clip-b',
      video: EditorVideo.file('/test/clip-b.mp4'),
      duration: const Duration(seconds: 2),
      recordedAt: DateTime(2025),
      originalAspectRatio: 9 / 16,
      targetAspectRatio: .vertical,
      volume: volume,
    ),
    layerId: 'layer-b',
  ).toMeta();
  return WidgetLayer(
    id: 'layer-b',
    widget: const SizedBox.shrink(),
    meta: meta,
    exportConfigs: WidgetLayerExportConfigs(id: 'layer-b', meta: meta),
  );
}

DivineVideoClip _clip({required double volume}) => DivineVideoClip(
  id: 'clip-a',
  video: EditorVideo.file('/test/clip-a.mp4'),
  duration: const Duration(seconds: 3),
  recordedAt: DateTime(2025),
  originalAspectRatio: 9 / 16,
  targetAspectRatio: .vertical,
  volume: volume,
);

AudioEvent _sound({
  required String id,
  required double volume,
  String? anchorClipId,
}) => AudioEvent(
  id: id,
  pubkey: 'pubkey-$id',
  createdAt: 1704067200,
  volume: volume,
  anchorClipId: anchorClipId,
);

void main() {
  group('toggleAllTimelineVolumeMuted', () {
    late _MockClipEditorBloc clipBloc;
    late _MockTimelineOverlayBloc overlayBloc;

    setUp(() {
      clipBloc = _MockClipEditorBloc();
      overlayBloc = _MockTimelineOverlayBloc();
    });

    Future<void> toggle(
      WidgetTester tester, {
      required List<DivineVideoClip> clips,
      required List<AudioEvent> audioTracks,
      ProImageEditorState? editor,
    }) async {
      when(() => clipBloc.state).thenReturn(ClipEditorState(clips: clips));
      when(
        () => overlayBloc.state,
      ).thenReturn(TimelineOverlayState(audioTracks: audioTracks));

      late BuildContext context;
      final probe = Builder(
        builder: (builderContext) {
          context = builderContext;
          return const SizedBox();
        },
      );
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<ClipEditorBloc>.value(value: clipBloc),
            BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
          ],
          child: editor == null
              ? probe
              : VideoEditorScope(
                  editorKey: GlobalKey(),
                  removeAreaKey: GlobalKey(),
                  originalClipAspectRatio: 9 / 16,
                  bodySizeNotifier: ValueNotifier(const Size(400, 600)),
                  zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
                  playTimeNotifier: ValueNotifier(Duration.zero),
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
                  editorOverride: editor,
                  child: probe,
                ),
        ),
      );

      toggleAllTimelineVolumeMuted(context);
    }

    void expectVolumeSent(double volume) {
      verify(
        () => clipBloc.add(ClipEditorAllClipsVolumeChanged(volume: volume)),
      ).called(1);
      verify(
        () => overlayBloc.add(
          TimelineOverlayAllAudioVolumeChanged(volume: volume),
        ),
      ).called(1);
    }

    testWidgets('mutes everything while any added sound is still audible', (
      tester,
    ) async {
      await toggle(
        tester,
        clips: [_clip(volume: 0)],
        audioTracks: [_sound(id: 'song', volume: 0.4)],
      );

      expectVolumeSent(0);
    });

    testWidgets('turns everything back up once clips and sounds are muted', (
      tester,
    ) async {
      await toggle(
        tester,
        clips: [_clip(volume: 0)],
        audioTracks: [_sound(id: 'song', volume: 0)],
      );

      expectVolumeSent(1);
    });

    testWidgets(
      "ignores a clip's own anchored sound, which follows the clip's volume",
      (tester) async {
        await toggle(
          tester,
          clips: [_clip(volume: 0)],
          audioTracks: [
            _sound(id: 'song', volume: 0),
            _sound(id: 'video_clip-a', volume: 1, anchorClipId: 'clip-a'),
          ],
        );

        expectVolumeSent(1);
      },
    );

    group('with a clip detached onto the canvas', () {
      late _MockProImageEditorState editor;

      setUp(() {
        editor = _MockProImageEditorState();
        final stateManager = _MockStateManager();
        when(() => editor.stateManager).thenReturn(stateManager);
        when(() => stateManager.activeMeta).thenReturn({});
        when(
          () => editor.addHistory(
            layers: any(named: 'layers'),
            meta: any(named: 'meta'),
          ),
        ).thenAnswer((_) {});
        when(() => editor.setState(any())).thenAnswer((_) {});
      });

      /// The layers and meta of the one history entry the toggle wrote.
      ({List<Layer> layers, Map<String, dynamic> meta}) written() {
        final captured = verify(
          () => editor.addHistory(
            layers: captureAny(named: 'layers'),
            meta: captureAny(named: 'meta'),
          ),
        ).captured;
        return (
          layers: captured[0] as List<Layer>,
          meta: captured[1] as Map<String, dynamic>,
        );
      }

      testWidgets('mutes everything while only the detached clip is audible, '
          'in one undo step', (tester) async {
        when(
          () => editor.activeLayers,
        ).thenReturn([_detachedLayer(volume: 1)]);

        await toggle(
          tester,
          clips: [_clip(volume: 0)],
          audioTracks: [_sound(id: 'song', volume: 0)],
          editor: editor,
        );

        expectVolumeSent(0);
        final entry = written();
        final layer = entry.layers.single as WidgetLayer;
        // Every place the clip is read from: the export, a draft and the
        // canvas.
        expect(DetachedClipLayerData.volumeOf(layer.meta), 0);
        expect(DetachedClipLayerData.volumeOf(layer.exportConfigs.meta), 0);
        expect(layer.widget, isA<DetachedClipLayerView>());
        // The same entry carries the clips and sounds, so the blocs' own
        // write of those volumes finds nothing left to record.
        final clips = entry.meta[VideoEditorConstants.clipsStateHistoryKey];
        expect(clips, [_clip(volume: 0).toJson()]);
        final sounds = entry.meta[VideoEditorConstants.audioStateHistoryKey];
        expect(sounds, [_sound(id: 'song', volume: 0).toJson()]);
      });

      testWidgets('turns a muted detached clip back up with everything else', (
        tester,
      ) async {
        when(
          () => editor.activeLayers,
        ).thenReturn([_detachedLayer(volume: 0)]);

        await toggle(
          tester,
          clips: [_clip(volume: 0)],
          audioTracks: [],
          editor: editor,
        );

        expectVolumeSent(1);
        final layer = written().layers.single as WidgetLayer;
        expect(DetachedClipLayerData.volumeOf(layer.meta), 1);
      });

      testWidgets('leaves the history to the blocs when the detached clip '
          'already plays at the new volume', (tester) async {
        when(
          () => editor.activeLayers,
        ).thenReturn([_detachedLayer(volume: 0)]);

        await toggle(
          tester,
          clips: [_clip(volume: 1)],
          audioTracks: [],
          editor: editor,
        );

        expectVolumeSent(0);
        verifyNever(
          () => editor.addHistory(
            layers: any(named: 'layers'),
            meta: any(named: 'meta'),
          ),
        );
      });
    });
  });
}
