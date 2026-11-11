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
  const VideoEditorTuneSessionStarted({this.setId, this.values = const {}});

  /// The timeline set being edited, or `null` for a new set.
  final String? setId;

  /// The values the session starts from, by adjustment kind: the edited
  /// set's, or none for a new set.
  ///
  /// The editor seeds the sliders with the same values once it is built, but
  /// the native preview shows the session's highlights, shadows, vibrance and
  /// sharpening from the moment the editor opens, rather than the previous
  /// session's until then.
  final Map<String, double> values;

  @override
  List<Object?> get props => [setId, values];
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

/// Triggered when the user picks a colour band in the Color section.
///
/// Remembers the band for the section and selects its hue, which keeps the
/// Color chip selected.
class VideoEditorTuneColorBandSelected extends VideoEditorTuneEvent {
  const VideoEditorTuneColorBandSelected(this.band);

  /// The band whose hue, saturation and lightness the section shows.
  final AdjustColorBand band;

  @override
  List<Object?> get props => [band];
}

/// Triggered when the user picks a curve in the Curve section.
///
/// Remembers the curve for the section and selects its first point, which
/// keeps the Curve chip selected.
class VideoEditorTuneCurveChannelSelected extends VideoEditorTuneEvent {
  const VideoEditorTuneCurveChannelSelected(this.channel);

  /// The curve the section shows.
  final AdjustCurveChannel channel;

  @override
  List<Object?> get props => [channel];
}

/// Triggered when the value of an adjustment changes.
class VideoEditorTuneValueChanged extends VideoEditorTuneEvent {
  const VideoEditorTuneValueChanged(this.value, {this.id});

  /// The new value.
  final double value;

  /// The adjustment that changed, which becomes the selected one, or `null`
  /// for the selected adjustment.
  ///
  /// The Color and Curve sections show several controls at once, each
  /// setting its own adjustment.
  final String? id;

  @override
  List<Object?> get props => [value, id];
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
