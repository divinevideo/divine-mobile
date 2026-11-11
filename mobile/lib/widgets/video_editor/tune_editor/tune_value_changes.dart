// ABOUTME: Sets one Adjust value from a control that names it, in the tune
// ABOUTME: bloc and in the tune editor's preview, through a drag's phases.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show TuneEditorState;

/// Changes the Adjust value [id] from a control of the Color or Curve
/// section, which shows several values at once.
///
/// The tune bloc drives the bar and the native preview; the tune editor's
/// own working matrix, which the session commits, only changes its
/// selected adjustment, so each call selects [id] there first.
abstract final class TuneValueChanges {
  /// A drag of [id] starts at [value]: the editor records an undo step.
  static void start(BuildContext context, String id, double value) {
    _select(context, id)?.onChangedStart(value);
  }

  /// [id] moved to [value].
  static void update(BuildContext context, String id, double value) {
    context.read<VideoEditorTuneBloc>().add(
      VideoEditorTuneValueChanged(value, id: id),
    );
    _select(context, id)?.onChanged(value);
  }

  /// A drag of [id] ended at [value].
  static void end(BuildContext context, String id, double value) {
    _select(context, id)?.onChangedEnd(value);
  }

  /// Sets [id] to [value] in one step, as an accessibility action or a
  /// reset does.
  static void set(BuildContext context, String id, double value) {
    start(context, id, value);
    update(context, id, value);
    end(context, id, value);
  }

  static TuneEditorState? _select(BuildContext context, String id) {
    final tuneEditor = VideoEditorScope.of(context).tuneEditor;
    if (tuneEditor == null) return null;
    final index = tuneEditor.tuneAdjustmentList.indexWhere((a) => a.id == id);
    if (index < 0) return null;
    return tuneEditor..selectedIndex = index;
  }
}
