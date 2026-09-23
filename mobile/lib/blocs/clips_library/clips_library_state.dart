// ABOUTME: States for ClipsLibraryBloc - managing saved video clips
// ABOUTME: Tracks clips list, selection state, and async operation status

part of 'clips_library_bloc.dart';

/// Sort order for clips in the library grid.
///
/// The string returned by [persistenceKey] is the stable identifier
/// stored in [SharedPreferences] — never use [Enum.name] for
/// persistence, since renaming an enum value would silently invalidate
/// every saved preference.
enum ClipSort {
  newestCreation,
  oldestCreation,
  longestClip,
  shortestClip,
  squareFirst,
  verticalFirst;

  static const _persistenceKeys = <ClipSort, String>{
    ClipSort.newestCreation: 'newest_creation',
    ClipSort.oldestCreation: 'oldest_creation',
    ClipSort.longestClip: 'longest_clip',
    ClipSort.shortestClip: 'shortest_clip',
    ClipSort.squareFirst: 'square_first',
    ClipSort.verticalFirst: 'vertical_first',
  };

  /// Stable string used to persist this sort in [SharedPreferences].
  String get persistenceKey => _persistenceKeys[this]!;

  /// Parses [key] back to a [ClipSort], falling back to
  /// [ClipSort.newestCreation] when the key is unknown (e.g. from a
  /// future build that wrote a value this build doesn't recognize).
  static ClipSort fromPersistenceKey(String key) {
    for (final entry in _persistenceKeys.entries) {
      if (entry.value == key) return entry.key;
    }
    return ClipSort.newestCreation;
  }
}

/// Column-count bounds for the pinch-zoomable clips grid.
abstract class ClipGridColumns {
  /// Fewest columns — the most zoomed-in step, with the largest thumbnails.
  static const min = 2;

  /// Most columns — the most zoomed-out step, with the smallest thumbnails.
  static const max = 5;

  /// Column count before the user has pinched the grid.
  static const initial = 3;

  /// SharedPreferences key for the persisted column count.
  static const prefsKey = 'library_clip_grid_columns';

  /// Clamps [value] into the supported range.
  static int clamp(int value) => value.clamp(min, max);
}

/// Which clip types the library shows.
///
/// Opened from the recorder, the library is scoped to the type that matches
/// the current recorder mode: a recording session is one mode from start to
/// finish, so it only takes clips of its own kind. Opened standalone it shows
/// [all] types but blocks mixing them in one selection (see
/// [ClipsLibraryState.selectedIsStopMotion]), so the editor always opens on a
/// single-typed composition. The editor's own picker is the one place both
/// types may be picked together — see [ClipsLibraryState.allowsMixedClipTypes].
enum LibraryClipTypeFilter {
  all,
  stopMotion,
  video;

  static const _queryValues = <LibraryClipTypeFilter, String>{
    LibraryClipTypeFilter.stopMotion: 'stop_motion',
    LibraryClipTypeFilter.video: 'video',
  };

  /// Query-parameter value for this filter, or `null` for [all] — the default,
  /// which is left off the URL entirely.
  String? get queryValue => _queryValues[this];

  /// Parses [value] back to a filter, defaulting to [all] for null/unknown.
  static LibraryClipTypeFilter fromQuery(String? value) {
    if (value == null) return LibraryClipTypeFilter.all;
    for (final entry in _queryValues.entries) {
      if (entry.value == value) return entry.key;
    }
    return LibraryClipTypeFilter.all;
  }

  /// Whether [clip] belongs to this filter.
  bool matches(DivineVideoClip clip) => switch (this) {
    LibraryClipTypeFilter.all => true,
    LibraryClipTypeFilter.stopMotion => clip.isStopMotion,
    LibraryClipTypeFilter.video => !clip.isStopMotion,
  };
}

/// Which slice of the clip library the grid shows.
///
/// All, Archive, and Deleted are built in and always available; the
/// remaining filters are the user's own [ClipCategory] rows. Trashing takes
/// a clip out of every one of them. Archiving takes it out of All only: an
/// archived clip keeps showing under its category unless the user chose to
/// take it out of there while archiving.
sealed class ClipLibraryFilter extends Equatable {
  const ClipLibraryFilter();

  /// Whether the grid shows [clip] while this filter is active.
  bool admits(DivineVideoClip clip);

  @override
  List<Object?> get props => [];
}

/// Every clip that is neither archived nor trashed. The library's default.
final class ClipLibraryAllFilter extends ClipLibraryFilter {
  const ClipLibraryAllFilter();

  @override
  bool admits(DivineVideoClip clip) => clip.archivedAt == null;
}

/// Clips the user archived out of the default view.
final class ClipLibraryArchiveFilter extends ClipLibraryFilter {
  const ClipLibraryArchiveFilter();

  @override
  bool admits(DivineVideoClip clip) => clip.archivedAt != null;
}

/// Soft-deleted clips awaiting the 30-day purge.
final class ClipLibraryTrashFilter extends ClipLibraryFilter {
  const ClipLibraryTrashFilter();

  /// Always false: trashed clips are not part of [ClipsLibraryState.clips] at
  /// all, they live in [ClipsLibraryState.trashedClips] and the UI renders
  /// them from there.
  @override
  bool admits(DivineVideoClip clip) => false;
}

/// Clips filed under one of the user's own categories.
final class ClipLibraryCategoryFilter extends ClipLibraryFilter {
  const ClipLibraryCategoryFilter(this.categoryId);

  /// The [ClipCategory.id] this filter shows.
  final String categoryId;

  /// Archived clips count: the archive question offers keeping the clip
  /// filed here, and a clip that kept its category is meant to stay
  /// visible in it. One that did not keep it has no [categoryId] left to
  /// match, so it drops out on its own.
  @override
  bool admits(DivineVideoClip clip) => clip.categoryId == categoryId;

  @override
  List<Object?> get props => [categoryId];
}

/// What the last clip-organization action did, for the confirmation
/// snackbar. Carries the affected ids so the UI can offer an undo.
enum ClipsLibraryOrganizeAction {
  movedToCategory,
  removedFromCategory,
  archived,
  unarchived,
}

/// Outcome of the last move-to-category or archive action.
final class ClipsLibraryOrganizeResult extends Equatable {
  const ClipsLibraryOrganizeResult({
    required this.action,
    required this.clipIds,
    this.categoryName,
    this.previousCategoryIds = const {},
  });

  /// What happened to the clips.
  final ClipsLibraryOrganizeAction action;

  /// The clips it happened to. Also the undo target.
  final Set<String> clipIds;

  /// Name of the target category when clips were moved into one. The
  /// user's own text, never a localized message.
  final String? categoryName;

  /// Category each clip was filed under before the action took it out of
  /// there, keyed by clip id. Only filled when archiving also unfiled the
  /// clips, so the snackbar's undo can put them back where they were
  /// instead of returning them category-less.
  final Map<String, String> previousCategoryIds;

  @override
  List<Object?> get props => [
    action,
    clipIds,
    categoryName,
    previousCategoryIds,
  ];
}

/// A long-press-and-drag range selection running on the clips grid.
///
/// Held for the length of the gesture so every move can be resolved against
/// the same starting point: the range always runs from [anchorClipId] to the
/// clip under the finger, and everything outside it falls back to
/// [baseSelectedClipIds]. That is what lets the user drag back over a clip to
/// undo it.
final class ClipsLibraryDragSelection extends Equatable {
  const ClipsLibraryDragSelection({
    required this.anchorClipId,
    required this.selecting,
    required this.baseSelectedClipIds,
    this.targetAspectRatio,
  });

  /// The clip the drag started on. One end of the range.
  final String anchorClipId;

  /// Whether the drag selects or deselects. Decided by the anchor: starting
  /// on an unselected clip selects, starting on a selected one deselects.
  final bool selecting;

  /// The selection as it stood when the drag started.
  final Set<String> baseSelectedClipIds;

  /// Aspect ratio every clip the drag picks up has to match, or `null` while
  /// the selection is still empty and the first clip decides it.
  final double? targetAspectRatio;

  @override
  List<Object?> get props => [
    anchorClipId,
    selecting,
    baseSelectedClipIds,
    targetAspectRatio,
  ];
}

/// Operation status for clips library actions.
enum ClipsLibraryStatus {
  /// Initial state, no operation in progress.
  initial,

  /// Loading clips from storage.
  loading,

  /// Clips loaded successfully.
  loaded,

  /// Deleting selected clips.
  deleting,

  /// Saving to gallery.
  savingToGallery,

  /// Loading the list of trashed clips.
  trashLoading,

  /// Trashed clips loaded successfully.
  trashLoaded,

  /// An error occurred.
  error,
}

/// Result of a gallery save operation.
sealed class GallerySaveResult extends Equatable {
  const GallerySaveResult();

  @override
  List<Object?> get props => [];
}

/// Gallery save completed successfully.
final class GallerySaveResultSuccess extends GallerySaveResult {
  const GallerySaveResultSuccess({
    required this.successCount,
    required this.failureCount,
  });

  /// Number of clips saved successfully.
  final int successCount;

  /// Number of clips that failed to save.
  final int failureCount;

  @override
  List<Object?> get props => [successCount, failureCount];
}

/// Gallery save failed due to permission denial.
final class GallerySaveResultPermissionDenied extends GallerySaveResult {
  const GallerySaveResultPermissionDenied();
}

/// Gallery save failed for an unexpected reason.
///
/// Carries no message: `state_management.md` forbids error strings in state,
/// and the UI renders localized copy for this case. The underlying exception
/// reaches diagnostics through `addError` in the bloc.
final class GallerySaveResultError extends GallerySaveResult {
  const GallerySaveResultError();
}

/// State for the clips library.
final class ClipsLibraryState extends Equatable {
  const ClipsLibraryState({
    this.status = ClipsLibraryStatus.initial,
    this.clips = const [],
    this.sortedClips = const [],
    this.trashedClips = const [],
    this.selectedClipIds = const {},
    this.disabledClipIds = const {},
    this.preSelectedIds = const {},
    this.selectedDuration = Duration.zero,
    this.clipSort = ClipSort.newestCreation,
    this.gridColumnCount = ClipGridColumns.initial,
    this.isLibrarySelectionMode = false,
    this.didAutoOpenSelectionMode = false,
    this.lastGallerySaveResult,
    this.lastDeletedCount,
    this.lastDeletedClipIds = const {},
    this.categories = const [],
    this.filter = const ClipLibraryAllFilter(),
    this.lastOrganizeResult,
    this.dragSelection,
    this.allowsMixedClipTypes = false,
  });

  /// Current operation status.
  final ClipsLibraryStatus status;

  /// All available clips, in their original load order.
  final List<DivineVideoClip> clips;

  /// [clips] sorted by the current [clipSort] for display.
  final List<DivineVideoClip> sortedClips;

  /// Clips currently in trash, newest-deleted-first.
  final List<DivineVideoClip> trashedClips;

  /// IDs of currently selected clips.
  final Set<String> selectedClipIds;

  /// IDs of clips already in the editor that cannot be toggled.
  final Set<String> disabledClipIds;

  /// IDs that should be marked selected after the next reload (e.g.
  /// the editor's current clip set). Stored so background reloads
  /// (asset recovery, retry-on-error) preserve the original
  /// selection intent.
  final Set<String> preSelectedIds;

  /// Total duration of selected clips.
  final Duration selectedDuration;

  /// Active sort order for [sortedClips]. Persisted via
  /// [SharedPreferences] using [ClipSort.persistenceKey].
  final ClipSort clipSort;

  /// How many columns the clips grid renders. Changed by pinch-to-zoom on
  /// the grid and persisted via [SharedPreferences] under
  /// [ClipGridColumns.prefsKey].
  final int gridColumnCount;

  /// Whether the library UI is currently in multi-select mode (the
  /// non-`selectionMode` screen entry-point can toggle this on/off).
  final bool isLibrarySelectionMode;

  /// Whether [isLibrarySelectionMode] was entered automatically by
  /// the auto-open BlocListener rather than a manual user action.
  /// The toolbar uses this to lock the close button when the screen
  /// is opened in clips-only mode and the first selection arrives.
  final bool didAutoOpenSelectionMode;

  /// Result of the last gallery save operation (for UI feedback).
  final GallerySaveResult? lastGallerySaveResult;

  /// Number of clips deleted in the last delete operation (for UI feedback).
  final int? lastDeletedCount;

  /// IDs of clips deleted in the last delete operation. Used by the
  /// snackbar Undo action to restore them within the soft-delete window.
  final Set<String> lastDeletedClipIds;

  /// The user's own categories, in chip-row order.
  final List<ClipCategory> categories;

  /// Which slice of the library [sortedClips] shows. Not persisted — the
  /// library opens on [ClipLibraryAllFilter] every time.
  final ClipLibraryFilter filter;

  /// Result of the last move-to-category or archive action (for UI
  /// feedback), or `null` when there is nothing to report.
  final ClipsLibraryOrganizeResult? lastOrganizeResult;

  /// The long-press-and-drag range selection in progress, or `null` when the
  /// user is not dragging across the grid.
  final ClipsLibraryDragSelection? dragSelection;

  /// Whether one selection may hold both stop-motion sets and normal video
  /// clips.
  ///
  /// On only for the editor's picker, whose import gives every picked clip
  /// the composition's own shape — a set becomes a clip on a video timeline,
  /// a clip becomes stills on a stop-motion one (see
  /// `ClipEditorLibraryClipsImportRequested`). Everywhere else the two stay
  /// apart: a frames-only set cannot sit on a video timeline, and a video
  /// clip cannot enter the frame-first stop-motion editor, so a mixed
  /// selection would have nowhere to go. Fixed for the bloc's lifetime.
  final bool allowsMixedClipTypes;

  /// The category the [filter] is showing, or `null` for the built-in
  /// filters and for a category that no longer exists.
  ClipCategory? get activeCategory {
    final current = filter;
    if (current is! ClipLibraryCategoryFilter) return null;
    for (final category in categories) {
      if (category.id == current.categoryId) return category;
    }
    return null;
  }

  /// Whether the grid is showing the trash bin rather than active clips.
  bool get isShowingTrash => filter is ClipLibraryTrashFilter;

  /// Whether clips are currently loading.
  bool get isLoading => status == ClipsLibraryStatus.loading;

  /// Whether a delete operation is in progress.
  bool get isDeleting => status == ClipsLibraryStatus.deleting;

  /// Whether a gallery save is in progress.
  bool get isSavingToGallery => status == ClipsLibraryStatus.savingToGallery;

  /// The selected clips the active [filter] actually shows.
  ///
  /// A selection survives switching between the active filters so a timeline
  /// can span categories, which leaves part of it off screen. The bulk
  /// toolbar actions run on this set instead of [selectedClipIds]: moving or
  /// deleting clips the user cannot see is not something one tap should do.
  /// Bulk-organizing across categories still works from
  /// [ClipLibraryAllFilter], which shows them all at once.
  Set<String> get visibleSelectedClipIds => {
    for (final clip in clips)
      if (selectedClipIds.contains(clip.id) && filter.admits(clip)) clip.id,
  };

  /// Returns the currently selected clips in selection order.
  List<DivineVideoClip> get selectedClips {
    final clipsById = {for (final c in clips) c.id: c};
    return [for (final id in selectedClipIds) ?clipsById[id]];
  }

  /// Type the rest of the selection has to match: `true` when stop-motion
  /// clips are selected, `false` for normal video clips, `null` when nothing
  /// is selected. Drives the no-mixing rule — once one type is selected the
  /// other becomes non-selectable. Always `null` when
  /// [allowsMixedClipTypes], since then there is nothing to match.
  bool? get selectedIsStopMotion =>
      allowsMixedClipTypes ? null : stopMotionTypeOf(selectedClipIds);

  /// Type of the clips [clipIds] names — `true` when they are stop-motion,
  /// `false` for normal video clips, `null` when the set names none of the
  /// loaded clips. See [selectedIsStopMotion] for the current selection.
  bool? stopMotionTypeOf(Set<String> clipIds) {
    if (clipIds.isEmpty) return null;
    for (final clip in clips) {
      if (clipIds.contains(clip.id)) return clip.isStopMotion;
    }
    return null;
  }

  /// Combined duration of the clips [clipIds] names.
  Duration durationOf(Set<String> clipIds) {
    var total = Duration.zero;
    for (final clip in clips) {
      if (clipIds.contains(clip.id)) total += clip.duration;
    }
    return total;
  }

  /// Creates a copy of this state with the given fields replaced.
  ClipsLibraryState copyWith({
    ClipsLibraryStatus? status,
    List<DivineVideoClip>? clips,
    List<DivineVideoClip>? sortedClips,
    List<DivineVideoClip>? trashedClips,
    Set<String>? selectedClipIds,
    Set<String>? disabledClipIds,
    Set<String>? preSelectedIds,
    Duration? selectedDuration,
    ClipSort? clipSort,
    int? gridColumnCount,
    bool? isLibrarySelectionMode,
    bool? didAutoOpenSelectionMode,
    GallerySaveResult? lastGallerySaveResult,
    int? lastDeletedCount,
    Set<String>? lastDeletedClipIds,
    List<ClipCategory>? categories,
    ClipLibraryFilter? filter,
    ClipsLibraryOrganizeResult? lastOrganizeResult,
    ClipsLibraryDragSelection? dragSelection,
    bool clearDragSelection = false,
    bool clearOrganizeResult = false,
    bool clearGallerySaveResult = false,
    bool clearDeletedCount = false,
    bool clearDeletedClipIds = false,
  }) {
    return ClipsLibraryState(
      status: status ?? this.status,
      clips: clips ?? this.clips,
      sortedClips: sortedClips ?? this.sortedClips,
      trashedClips: trashedClips ?? this.trashedClips,
      selectedClipIds: selectedClipIds ?? this.selectedClipIds,
      disabledClipIds: disabledClipIds ?? this.disabledClipIds,
      preSelectedIds: preSelectedIds ?? this.preSelectedIds,
      selectedDuration: selectedDuration ?? this.selectedDuration,
      clipSort: clipSort ?? this.clipSort,
      gridColumnCount: gridColumnCount ?? this.gridColumnCount,
      isLibrarySelectionMode:
          isLibrarySelectionMode ?? this.isLibrarySelectionMode,
      didAutoOpenSelectionMode:
          didAutoOpenSelectionMode ?? this.didAutoOpenSelectionMode,
      lastGallerySaveResult: clearGallerySaveResult
          ? null
          : (lastGallerySaveResult ?? this.lastGallerySaveResult),
      lastDeletedCount: clearDeletedCount
          ? null
          : (lastDeletedCount ?? this.lastDeletedCount),
      lastDeletedClipIds: clearDeletedClipIds
          ? const {}
          : (lastDeletedClipIds ?? this.lastDeletedClipIds),
      categories: categories ?? this.categories,
      filter: filter ?? this.filter,
      lastOrganizeResult: clearOrganizeResult
          ? null
          : (lastOrganizeResult ?? this.lastOrganizeResult),
      dragSelection: clearDragSelection
          ? null
          : (dragSelection ?? this.dragSelection),
      allowsMixedClipTypes: allowsMixedClipTypes,
    );
  }

  @override
  List<Object?> get props => [
    status,
    clips,
    sortedClips,
    trashedClips,
    selectedClipIds,
    disabledClipIds,
    preSelectedIds,
    selectedDuration,
    clipSort,
    gridColumnCount,
    isLibrarySelectionMode,
    didAutoOpenSelectionMode,
    lastGallerySaveResult,
    lastDeletedCount,
    lastDeletedClipIds,
    categories,
    filter,
    lastOrganizeResult,
    dragSelection,
    allowsMixedClipTypes,
  ];
}
