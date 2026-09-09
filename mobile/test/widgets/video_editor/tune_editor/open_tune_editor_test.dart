// ABOUTME: Tests for the openTuneEditor helper.
// ABOUTME: Verifies it flips the main bloc into the tune sub-editor state.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/tune_editor/open_tune_editor.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A scope with no mounted editor: `scope.editor` is null, so the
  // pro_image_editor call is a no-op and only the bloc dispatch is exercised.
  VideoEditorScope buildScope() {
    final bodySize = ValueNotifier(Size.zero);
    addTearDown(bodySize.dispose);
    final zoom = ValueNotifier(Matrix4.identity());
    addTearDown(zoom.dispose);
    return VideoEditorScope(
      editorKey: GlobalKey<ProImageEditorState>(),
      removeAreaKey: GlobalKey(),
      onAddStickers: () {},
      onOpenCamera: () {},
      onOpenClipsEditor: () {},
      onAddEditTextLayer: ([_]) async => null,
      onOpenMusicLibrary: () {},
      onOpenVoiceOver: () {},
      onOpenCaptions: () {},
      originalClipAspectRatio: 9 / 16,
      bodySizeNotifier: bodySize,
      zoomMatrixNotifier: zoom,
      playTimeNotifier: ValueNotifier(Duration.zero),
      playheadAdvancingNotifier: ValueNotifier<bool>(false),
      fromLibrary: false,
    );
  }

  group('openTuneEditor', () {
    test(
      'opening for a new set flips the main bloc and records no set',
      () async {
        final mainBloc = VideoEditorMainBloc();
        addTearDown(mainBloc.close);
        final tuneBloc = VideoEditorTuneBloc();
        addTearDown(tuneBloc.close);

        expect(mainBloc.state.openSubEditor, isNull);

        openTuneEditor(mainBloc, tuneBloc, buildScope());
        await Future<void>.delayed(Duration.zero);

        expect(mainBloc.state.openSubEditor, SubEditorType.tune);
        expect(mainBloc.state.isSubEditorOpen, isTrue);
        expect(tuneBloc.state.editingSetId, isNull);
      },
    );

    test('opening for an existing set records the edited set id', () async {
      final mainBloc = VideoEditorMainBloc();
      addTearDown(mainBloc.close);
      final tuneBloc = VideoEditorTuneBloc();
      addTearDown(tuneBloc.close);

      openTuneEditor(mainBloc, tuneBloc, buildScope(), editSetId: 'set-1');
      await Future<void>.delayed(Duration.zero);

      expect(mainBloc.state.openSubEditor, SubEditorType.tune);
      expect(tuneBloc.state.editingSetId, 'set-1');
    });
  });
}
