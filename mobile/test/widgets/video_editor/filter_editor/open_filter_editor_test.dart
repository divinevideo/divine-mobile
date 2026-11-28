// ABOUTME: Tests for the openFilterEditor helper: it starts the filter
// ABOUTME: session on the filter bloc, new or on a committed filter.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/models/video_editor/editor_filter_category.dart';
import 'package:openvine/models/video_editor/filter_settings.dart';
import 'package:openvine/widgets/video_editor/filter_editor/open_filter_editor.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

class _MockStateManager extends Mock implements StateManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final crema = EditedFilter(
    preset: editorFilterNamed('Crema')!,
    values: const {'temperature': -0.1},
    opacity: 0.7,
  );

  group('openFilterEditor', () {
    late _MockProImageEditorState editor;

    setUp(() {
      editor = _MockProImageEditorState();
      final stateManager = _MockStateManager();
      when(() => editor.stateManager).thenReturn(stateManager);
      when(() => stateManager.activeFilters).thenReturn([
        FilterState(id: 'crema', name: 'Crema', meta: crema.toMeta()),
        FilterState(id: 'old', name: 'Ludwig'),
      ]);
    });

    VideoEditorScope buildScope() {
      final bodySize = ValueNotifier(Size.zero);
      addTearDown(bodySize.dispose);
      final zoom = ValueNotifier(Matrix4.identity());
      addTearDown(zoom.dispose);
      return VideoEditorScope(
        editorKey: GlobalKey<ProImageEditorState>(),
        editorOverride: editor,
        removeAreaKey: GlobalKey(),
        onAddStickers: () {},
        onOpenCamera: () {},
        onOpenClipsEditor: () {},
        onAddEditTextLayer: ([_]) async => null,
        onOpenMusicLibrary: () {},
        onOpenVoiceOver: () {},
        onOpenCaptions: () {},
        onOpenEffects: () {},
        originalClipAspectRatio: 9 / 16,
        bodySizeNotifier: bodySize,
        zoomMatrixNotifier: zoom,
        playTimeNotifier: ValueNotifier(Duration.zero),
        playheadAdvancingNotifier: ValueNotifier<bool>(false),
        fromLibrary: false,
      );
    }

    test('starts on a committed filter as it was left, then opens', () async {
      final bloc = VideoEditorFilterBloc();
      addTearDown(bloc.close);

      openFilterEditor(bloc, buildScope(), editFilterId: 'crema');
      await pumpEventQueue();

      expect(bloc.state.editingFilterId, 'crema');
      expect(bloc.state.edited, crema);
      verify(() => editor.openFilterEditor()).called(1);
    });

    test('adds a new filter for a committed one without settings', () async {
      final bloc = VideoEditorFilterBloc();
      addTearDown(bloc.close);

      openFilterEditor(bloc, buildScope(), editFilterId: 'old');
      await pumpEventQueue();

      expect(bloc.state, const VideoEditorFilterState());
    });

    test('starts a new filter fresh after an edit', () async {
      final bloc = VideoEditorFilterBloc();
      addTearDown(bloc.close);
      openFilterEditor(bloc, buildScope(), editFilterId: 'crema');
      await pumpEventQueue();

      openFilterEditor(bloc, buildScope());
      await pumpEventQueue();

      expect(bloc.state, const VideoEditorFilterState());
      verify(() => editor.openFilterEditor()).called(2);
    });
  });
}
