part of 'video_editor_tune_bloc.dart';

/// Base class for all video editor tune-adjustment events.
sealed class VideoEditorTuneEvent extends Equatable {
  const VideoEditorTuneEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered before opening the tune editor to record whether this session
/// creates a new set (`setId == null`) or edits an existing one.
///
/// Dispatched up front — before the editor's `onInit` fires — so the seed in
/// [VideoEditorTuneEditorInitialized] and the commit both know the session
/// kind.
class VideoEditorTuneSessionStarted extends VideoEditorTuneEvent {
  const VideoEditorTuneSessionStarted({this.setId});

  /// The timeline set being edited, or `null` for a new set.
  final String? setId;

  @override
  List<Object?> get props => [setId];
}

/// Triggered when the tune editor is initialized.
///
/// Seeds the session values from the given adjustments (empty for a new set,
/// the edited set's adjustments otherwise) and snapshots them so a cancel can
/// restore the pre-open state. Preserves the session's
/// [VideoEditorTuneState.editingSetId].
class VideoEditorTuneEditorInitialized extends VideoEditorTuneEvent {
  const VideoEditorTuneEditorInitialized(this.activeAdjustments);

  /// The tune adjustments to seed the session from.
  final List<TuneAdjustmentMatrix> activeAdjustments;

  @override
  List<Object?> get props => [activeAdjustments];
}

/// Triggered when the user selects a different adjustment to tune.
class VideoEditorTuneAdjustmentSelected extends VideoEditorTuneEvent {
  const VideoEditorTuneAdjustmentSelected(this.index);

  /// The index of the selected adjustment in
  /// [VideoEditorTuneState.adjustments].
  final int index;

  @override
  List<Object?> get props => [index];
}

/// Triggered when the value of the selected adjustment changes.
class VideoEditorTuneValueChanged extends VideoEditorTuneEvent {
  const VideoEditorTuneValueChanged(this.value);

  /// The new value for the currently selected adjustment.
  final double value;

  @override
  List<Object?> get props => [value];
}

/// Triggered when the user cancels tune editing.
///
/// Restores the values captured when the editor was opened. The UI is
/// responsible for closing the sub-editor via [VideoEditorScope].
class VideoEditorTuneCancelled extends VideoEditorTuneEvent {
  const VideoEditorTuneCancelled();
}

/// Triggered when the user confirms the tune adjustments (presses done).
class VideoEditorTuneConfirmed extends VideoEditorTuneEvent {
  const VideoEditorTuneConfirmed();
}
