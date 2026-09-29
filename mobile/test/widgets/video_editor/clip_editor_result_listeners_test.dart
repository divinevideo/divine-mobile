// ABOUTME: Tests for the listeners that finish a detach and its way back —
// ABOUTME: the layer and the clip list land in one editor-history entry

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/widgets/video_editor/clip_editor_result_listeners.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
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

DivineVideoClip _clip(String id, {bool isPlaceholder = false}) =>
    DivineVideoClip(
      id: id,
      video: EditorVideo.file('/documents/$id.mp4'),
      duration: const Duration(seconds: 2),
      recordedAt: DateTime(2026),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
      isPlaceholder: isPlaceholder,
    );

void main() {
  group(ClipEditorResultListeners, () {
    late _MockClipEditorBloc clipBloc;
    late _MockTimelineOverlayBloc overlayBloc;
    late _MockProImageEditorState editor;
    late _MockStateManager stateManager;

    setUp(() {
      clipBloc = _MockClipEditorBloc();
      overlayBloc = _MockTimelineOverlayBloc();
      editor = _MockProImageEditorState();
      stateManager = _MockStateManager();
      when(() => overlayBloc.state).thenReturn(const TimelineOverlayState());
      when(() => editor.stateManager).thenReturn(stateManager);
      when(() => stateManager.activeMeta).thenReturn({});
    });

    Widget build() => MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<ClipEditorBloc>.value(value: clipBloc),
          BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
        ],
        child: VideoEditorScope(
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
          editorOverride: editor,
          child: const ClipEditorResultListeners(child: SizedBox.shrink()),
        ),
      ),
    );

    testWidgets('a detach records the placeholder that took the slot', (
      tester,
    ) async {
      final placeholder = _clip('placeholder_1', isPlaceholder: true);
      whenListen(
        clipBloc,
        Stream.value(
          ClipEditorState(
            clips: [_clip('a'), placeholder],
            lastDetachResult: ClipDetachSuccess(
              previousClips: [_clip('a'), _clip('b')],
              detachedClip: _clip('b'),
              placeholder: placeholder,
            ),
          ),
        ),
        initialState: const ClipEditorState(),
      );

      await tester.pumpWidget(build());
      await tester.pump();

      final layer =
          verify(
                () => editor.addHistory(
                  newLayer: captureAny(named: 'newLayer'),
                  meta: any(named: 'meta'),
                ),
              ).captured.single
              as Layer;
      // Without it, putting the clip back could not find its slot.
      expect(
        DetachedClipLayerData.placeholderClipIdOf(
          DetachedClipLayerData.metaOf(layer),
        ),
        'placeholder_1',
      );
    });

    testWidgets('every detach gets its own layer id, even for the same clip', (
      tester,
    ) async {
      // A clip that went back to the timeline keeps its id, so detaching it a
      // second time must not hand its new layer the id of the first.
      ClipEditorState detached() => ClipEditorState(
        clips: [_clip('a')],
        lastDetachResult: ClipDetachSuccess(
          previousClips: [_clip('a'), _clip('b')],
          detachedClip: _clip('b'),
        ),
      );
      whenListen(
        clipBloc,
        Stream.fromIterable([detached(), detached()]),
        initialState: const ClipEditorState(),
      );

      await tester.pumpWidget(build());
      await tester.pump();
      await tester.pump();

      final layers = verify(
        () => editor.addHistory(
          newLayer: captureAny(named: 'newLayer'),
          meta: any(named: 'meta'),
        ),
      ).captured.cast<Layer>();
      expect(layers, hasLength(2));
      expect(layers.first.id, isNot(layers.last.id));
      // The meta names the layer by the same id, or its window is read off the
      // wrong timeline item.
      for (final layer in layers) {
        expect(
          DetachedClipLayerData.layerIdOf(DetachedClipLayerData.metaOf(layer)),
          layer.id,
        );
      }
    });

    testWidgets('putting a clip back removes its layer in the same entry', (
      tester,
    ) async {
      when(() => editor.activeLayers).thenReturn([
        TextLayer(id: 'text', text: 'hi'),
        TextLayer(id: 'detached_b', text: 'clip'),
      ]);
      whenListen(
        clipBloc,
        Stream.value(
          ClipEditorState(
            clips: [_clip('a'), _clip('b')],
            lastDetachedClipReattachResult: DetachedClipReattachResult(
              previousClips: [
                _clip('a'),
                _clip('placeholder_1', isPlaceholder: true),
              ],
              layerId: 'detached_b',
              clipId: 'b',
            ),
          ),
        ),
        initialState: const ClipEditorState(),
      );

      await tester.pumpWidget(build());
      await tester.pump();

      final captured = verify(
        () => editor.addHistory(
          layers: captureAny(named: 'layers'),
          meta: captureAny(named: 'meta'),
        ),
      ).captured;
      expect((captured[0] as List<Layer>).map((l) => l.id), ['text']);
      final clips =
          (captured[1] as Map<String, dynamic>)[VideoEditorConstants
                  .clipsStateHistoryKey]
              as List<dynamic>;
      expect(clips.map((c) => (c as Map<String, dynamic>)['id']), ['a', 'b']);
    });
  });
}
