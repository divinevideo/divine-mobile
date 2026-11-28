part of 'video_editor_filter_bloc.dart';

/// State for the video editor filter selection.
class VideoEditorFilterState extends Equatable {
  const VideoEditorFilterState({
    this.selectedFilter,
    this.opacity = 1.0,
    this.settingValues = const {},
    this.isSettingsOpen = false,
    this.editingFilterId,
  });

  /// The preset picked in the picker, or `null` when none is picked.
  final FilterModel? selectedFilter;

  /// The opacity of the filter (0.0 - 1.0).
  final double opacity;

  /// The settings of [selectedFilter] changed from the preset's own, by key;
  /// see [filterSettingsCardsOf].
  final EffectSettingValues settingValues;

  /// Whether the settings of [selectedFilter] show in place of the picker,
  /// while it has any; see [showsSettings].
  final bool isSettingsOpen;

  /// The id of the committed filter this session changes in place, or
  /// `null` when it adds a new one.
  final String? editingFilterId;

  /// Whether a filter is currently being previewed.
  bool get hasFilter => selectedFilter != null;

  /// Whether [selectedFilter] has settings to change.
  bool get hasSettings =>
      selectedFilter != null &&
      filterSettingsCardsOf(selectedFilter!).isNotEmpty;

  /// Whether the settings of [selectedFilter] show in place of the picker.
  bool get showsSettings => isSettingsOpen && hasSettings;

  /// The filter as it is set up: [selectedFilter] with [settingValues], at
  /// [opacity]; `null` when none is picked.
  EditedFilter? get edited => switch (selectedFilter) {
    final preset? => EditedFilter(
      preset: preset,
      values: settingValues,
      opacity: opacity,
    ),
    null => null,
  };

  /// Creates a copy of this state with optionally updated values.
  ///
  /// Set [clearSelectedFilter] or [clearEditingFilterId] to `true` to set
  /// [selectedFilter] or [editingFilterId] to `null`.
  VideoEditorFilterState copyWith({
    FilterModel? selectedFilter,
    bool clearSelectedFilter = false,
    double? opacity,
    EffectSettingValues? settingValues,
    bool? isSettingsOpen,
    String? editingFilterId,
    bool clearEditingFilterId = false,
  }) {
    return VideoEditorFilterState(
      selectedFilter: clearSelectedFilter
          ? null
          : (selectedFilter ?? this.selectedFilter),
      opacity: opacity ?? this.opacity,
      settingValues: settingValues ?? this.settingValues,
      isSettingsOpen: isSettingsOpen ?? this.isSettingsOpen,
      editingFilterId: clearEditingFilterId
          ? null
          : (editingFilterId ?? this.editingFilterId),
    );
  }

  @override
  List<Object?> get props => [
    selectedFilter,
    opacity,
    settingValues,
    isSettingsOpen,
    editingFilterId,
  ];
}
