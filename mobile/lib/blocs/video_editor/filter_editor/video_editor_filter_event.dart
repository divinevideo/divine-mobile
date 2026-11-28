part of 'video_editor_filter_bloc.dart';

/// Base class for all video editor filter events.
sealed class VideoEditorFilterEvent extends Equatable {
  const VideoEditorFilterEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered right before the filter editor opens: to add a new filter, or
/// on the committed filter with [filterId], set up as [filter], to change it
/// in place.
class VideoEditorFilterSessionStarted extends VideoEditorFilterEvent {
  const VideoEditorFilterSessionStarted({this.filterId, this.filter});

  /// The id of the committed filter to change, or `null` to add a new one.
  final String? filterId;

  /// How the committed filter was set up; `null` for a new filter.
  final EditedFilter? filter;

  @override
  List<Object?> get props => [filterId, filter];
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

/// Triggered when the setting of the picked filter stored under [key] is
/// changed to [value].
class VideoEditorFilterSettingChanged extends VideoEditorFilterEvent {
  const VideoEditorFilterSettingChanged(this.key, this.value);

  final String key;
  final Object value;

  @override
  List<Object?> get props => [key, value];
}

/// Triggered when the settings on [card] are put back to the preset's own.
class VideoEditorFilterSettingsReset extends VideoEditorFilterEvent {
  const VideoEditorFilterSettingsReset(this.card);

  final FilterSettingsCard card;

  @override
  List<Object?> get props => [card];
}

/// Triggered when the settings of the picked filter are shown in place of
/// the picker, or the picker again.
class VideoEditorFilterSettingsToggled extends VideoEditorFilterEvent {
  const VideoEditorFilterSettingsToggled({required this.open});

  final bool open;

  @override
  List<Object?> get props => [open];
}

/// Triggered when the user cancels filter editing.
///
/// Clears the session. The UI is responsible for closing the sub-editor via
/// [VideoEditorScope].
class VideoEditorFilterCancelled extends VideoEditorFilterEvent {
  const VideoEditorFilterCancelled();
}

/// Triggered once the filter of this session is committed (done).
///
/// Clears the session so the next one starts fresh; the UI commits the
/// filter to the editor's history.
class VideoEditorFilterConfirmed extends VideoEditorFilterEvent {
  const VideoEditorFilterConfirmed();
}
