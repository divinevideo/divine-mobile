// ABOUTME: Helper to open the tune sub-editor for a new or an existing set.
// ABOUTME: Records the session kind on the tune bloc before the editor opens.

import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/extensions/tune_adjustment_matrix_extensions.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';

/// Opens the tune sub-editor.
///
/// Pass [editSetId] to edit an existing timeline set (the session seeds from
/// and replaces that set); omit it to create a new set. The session kind is
/// recorded on [VideoEditorTuneBloc] up front so the canvas's `onInit` /
/// `onAfterViewInit` seed the bottom bar and preview accordingly.
void openTuneEditor(
  VideoEditorTuneBloc tuneBloc,
  VideoEditorScope scope, {
  String? editSetId,
}) {
  final seed = TuneSet.sessionSeed(
    scope.editor?.stateManager.activeTuneAdjustments ?? const [],
    editSetId,
  );
  tuneBloc.add(
    VideoEditorTuneSessionStarted(
      setId: editSetId,
      values: {for (final m in seed) m.id: m.value},
    ),
  );
  scope.editor?.openTuneEditor();
}
