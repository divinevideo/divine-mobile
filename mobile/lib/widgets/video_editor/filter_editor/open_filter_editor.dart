// ABOUTME: Helper to open the filter sub-editor for a new or an existing
// ABOUTME: filter. Records the session on the filter bloc before it opens.

import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/models/video_editor/filter_settings.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';

/// Opens the filter sub-editor.
///
/// Pass [editFilterId] to change the committed filter with that id in place,
/// starting from the preset, settings and opacity it was committed with;
/// omit it, or pass a filter that holds none, to add a new filter.
void openFilterEditor(
  VideoEditorFilterBloc filterBloc,
  VideoEditorScope scope, {
  String? editFilterId,
}) {
  final committed = editFilterId == null
      ? null
      : scope.editor?.stateManager.activeFilters
            .where((filter) => filter.id == editFilterId)
            .firstOrNull;
  filterBloc.add(
    VideoEditorFilterSessionStarted(
      filterId: editFilterId,
      filter: committed == null ? null : EditedFilter.fromMeta(committed.meta),
    ),
  );
  scope.editor?.openFilterEditor();
}
