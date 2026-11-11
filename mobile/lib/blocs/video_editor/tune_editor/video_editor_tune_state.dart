part of 'video_editor_tune_bloc.dart';

/// The part of the Adjust bar a selected adjustment belongs to.
enum VideoEditorTuneSection {
  /// One of the adjustments with a slider and chip of their own.
  slider,

  /// The Color section: hue, saturation and lightness per colour band.
  color,

  /// The Curve section: the tone curve's points.
  curve,
}

/// State for the video editor tune adjustments.
class VideoEditorTuneState extends Equatable {
  const VideoEditorTuneState({
    required this.adjustments,
    this.selectedIndex = 0,
    this.values = const {},
    this.initialValues = const {},
    this.editingSetId,
    this.colorBand = AdjustColorBand.red,
    this.curveChannel = AdjustCurveChannel.rgb,
  });

  /// The available tune adjustment options: those with a slider and chip of
  /// their own first, then the Color and Curve sections' adjustments.
  final List<TuneAdjustmentItem> adjustments;

  /// Index of the currently selected adjustment in [adjustments].
  final int selectedIndex;

  /// Current value per adjustment id. A missing id means the adjustment is at
  /// its neutral value (`0`).
  final Map<String, double> values;

  /// Snapshot of [values] captured when the editor was opened. Used to restore
  /// on cancel.
  final Map<String, double> initialValues;

  /// The id of the timeline set this session is editing, or `null` when the
  /// session creates a new set. On done, an edit session replaces the set's
  /// adjustments in place (keeping its time window); a new session appends a
  /// fresh set.
  final String? editingSetId;

  /// The colour band the Color section shows.
  final AdjustColorBand colorBand;

  /// The curve the Curve section shows.
  final AdjustCurveChannel curveChannel;

  /// The currently selected adjustment.
  TuneAdjustmentItem get selectedAdjustment => adjustments[selectedIndex];

  /// The section the selected adjustment belongs to.
  VideoEditorTuneSection get section => sectionOf(selectedAdjustment.id);

  /// The adjustments with a slider and chip of their own, in display order.
  List<TuneAdjustmentItem> get sliderAdjustments => [
    for (final adjustment in adjustments)
      if (sectionOf(adjustment.id) == .slider) adjustment,
  ];

  /// Whether any adjustment of [section] is set.
  bool isSectionAdjusted(VideoEditorTuneSection section) => values.entries.any(
    (entry) => entry.value != 0 && sectionOf(entry.key) == section,
  );

  /// The index of the adjustment [id] in [adjustments], or -1.
  int indexOf(String id) => adjustments.indexWhere((a) => a.id == id);

  /// The section the adjustment [id] belongs to.
  static VideoEditorTuneSection sectionOf(String id) {
    if (adjustColorKinds.contains(id)) return .color;
    if (adjustCurveKinds.contains(id)) return .curve;
    return .slider;
  }

  /// The value of the currently selected adjustment.
  double get selectedValue => valueOf(selectedAdjustment.id);

  /// Returns the current value for the adjustment with the given [id], or `0`
  /// when it has not been adjusted.
  double valueOf(String id) => values[id] ?? 0;

  VideoEditorTuneState copyWith({
    List<TuneAdjustmentItem>? adjustments,
    int? selectedIndex,
    Map<String, double>? values,
    Map<String, double>? initialValues,
    String? editingSetId,
    bool clearEditingSetId = false,
    AdjustColorBand? colorBand,
    AdjustCurveChannel? curveChannel,
  }) {
    return VideoEditorTuneState(
      adjustments: adjustments ?? this.adjustments,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      values: values ?? this.values,
      initialValues: initialValues ?? this.initialValues,
      editingSetId: clearEditingSetId
          ? null
          : (editingSetId ?? this.editingSetId),
      colorBand: colorBand ?? this.colorBand,
      curveChannel: curveChannel ?? this.curveChannel,
    );
  }

  @override
  List<Object?> get props => [
    adjustments,
    selectedIndex,
    values,
    initialValues,
    editingSetId,
    colorBand,
    curveChannel,
  ];
}
