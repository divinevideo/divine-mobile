part of 'video_editor_filter_bloc.dart';

/// State for the video editor filter selection.
class VideoEditorFilterState extends Equatable {
  const VideoEditorFilterState({
    this.selectedFilter,
    this.opacity = 1.0,
    this.initialSelectedFilter,
    this.initialOpacity = 1.0,
    this.appliedFilters = const [],
    this.initialAppliedFilters = const [],
  });

  /// The currently selected filter, or `null` when none is selected.
  final FilterModel? selectedFilter;

  /// The opacity of the filter (0.0 - 1.0).
  final double opacity;

  /// The filter that was selected when the editor was initialized.
  /// Used to restore on cancel.
  final FilterModel? initialSelectedFilter;

  /// The opacity that was set when the editor was initialized.
  /// Used to restore on cancel.
  final double initialOpacity;

  /// Filters that have been committed (done) in previous editor sessions.
  final List<FilterModel> appliedFilters;

  /// Snapshot of [appliedFilters] when the editor was opened.
  /// Used to restore on cancel.
  final List<FilterModel> initialAppliedFilters;

  /// Whether a filter is currently being previewed.
  bool get hasFilter => selectedFilter != null;

  /// Whether any filters have been committed.
  bool get hasAppliedFilters => appliedFilters.isNotEmpty;

  /// Creates a copy of this state with optionally updated values.
  ///
  /// Set [clearSelectedFilter] to `true` to explicitly set
  /// [selectedFilter] to `null`.
  VideoEditorFilterState copyWith({
    FilterModel? selectedFilter,
    bool clearSelectedFilter = false,
    double? opacity,
    FilterModel? initialSelectedFilter,
    double? initialOpacity,
    List<FilterModel>? appliedFilters,
    List<FilterModel>? initialAppliedFilters,
  }) {
    return VideoEditorFilterState(
      selectedFilter: clearSelectedFilter
          ? null
          : (selectedFilter ?? this.selectedFilter),
      opacity: opacity ?? this.opacity,
      initialSelectedFilter:
          initialSelectedFilter ?? this.initialSelectedFilter,
      initialOpacity: initialOpacity ?? this.initialOpacity,
      appliedFilters: appliedFilters ?? this.appliedFilters,
      initialAppliedFilters:
          initialAppliedFilters ?? this.initialAppliedFilters,
    );
  }

  @override
  List<Object?> get props => [
    selectedFilter,
    opacity,
    initialSelectedFilter,
    initialOpacity,
    appliedFilters,
    initialAppliedFilters,
  ];
}
