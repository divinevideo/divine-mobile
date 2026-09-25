part of 'video_editor_filter_bloc.dart';

/// Base class for all video editor filter events.
sealed class VideoEditorFilterEvent extends Equatable {
  const VideoEditorFilterEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered when a filter is selected.
class VideoEditorFilterSelected extends VideoEditorFilterEvent {
  const VideoEditorFilterSelected(this.filter);

  /// The filter that was selected.
  final FilterModel filter;

  @override
  List<Object?> get props => [filter];
}

/// Triggered when the filter opacity is changed.
class VideoEditorFilterOpacityChanged extends VideoEditorFilterEvent {
  const VideoEditorFilterOpacityChanged(this.opacity);

  /// The new opacity value (0.0 - 1.0).
  final double opacity;

  @override
  List<Object?> get props => [opacity];
}

/// Triggered when the user cancels filter editing.
///
/// This resets the state to the initial values. The UI is responsible for
/// closing the sub-editor via [VideoEditorScope].
class VideoEditorFilterCancelled extends VideoEditorFilterEvent {
  const VideoEditorFilterCancelled();
}

/// Triggered when the user confirms the filter selection (presses done).
///
/// Appends the currently selected filter to
/// [VideoEditorFilterState.appliedFilters] and clears the selection so the
/// next editor session starts fresh.
class VideoEditorFilterConfirmed extends VideoEditorFilterEvent {
  const VideoEditorFilterConfirmed();
}

/// Triggered when the filter editor is initialized.
///
/// Snapshots the current selection, opacity and applied filters so
/// [VideoEditorFilterCancelled] can restore them.
class VideoEditorFilterEditorInitialized extends VideoEditorFilterEvent {
  const VideoEditorFilterEditorInitialized();
}
