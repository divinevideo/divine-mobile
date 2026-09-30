// ABOUTME: Events for ClipsLibraryBloc - managing saved video clips
// ABOUTME: Supports loading, selection, deletion, and gallery export

part of 'clips_library_bloc.dart';

/// Base class for all clips library events.
sealed class ClipsLibraryEvent extends Equatable {
  const ClipsLibraryEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load all clips from storage.
///
/// When [preSelectedIds] is provided, clips matching those IDs will
/// be marked as selected after loading.
final class ClipsLibraryLoadRequested extends ClipsLibraryEvent {
  const ClipsLibraryLoadRequested({
    this.preSelectedIds = const {},
    this.disabledClipIds = const {},
  });

  /// Clip IDs to pre-select after loading (e.g. clips already in the editor).
  final Set<String> preSelectedIds;

  /// Clip IDs that are already in the editor and cannot be deselected.
  final Set<String> disabledClipIds;

  @override
  List<Object?> get props => [preSelectedIds, disabledClipIds];
}

/// Clips changed in storage behind the bloc's back — a chroma-key take whose
/// keyed file landed while the library was open — so the listing reloads in
/// place.
///
/// Unlike [ClipsLibraryLoadRequested] it keeps what the user has selected and
/// does not pass through a loading state, so an update arriving mid-browse
/// neither flashes the grid nor drops the selection.
final class ClipsLibraryClipsChanged extends ClipsLibraryEvent {
  const ClipsLibraryClipsChanged();
}

/// Event to toggle selection of a clip.
final class ClipsLibraryToggleSelection extends ClipsLibraryEvent {
  const ClipsLibraryToggleSelection(this.clip);

  /// The clip to toggle selection for.
  final DivineVideoClip clip;

  @override
  List<Object?> get props => [clip];
}

/// Event to clear all selections.
final class ClipsLibraryClearSelection extends ClipsLibraryEvent {
  const ClipsLibraryClearSelection();
}

/// Event dispatched when a long press on [clip] opens a drag selection.
///
/// The clip is toggled right away, and whether it went into or out of the
/// selection decides what the rest of the drag does — see
/// [ClipsLibraryDragSelection.selecting].
final class ClipsLibraryDragSelectionStarted extends ClipsLibraryEvent {
  const ClipsLibraryDragSelectionStarted(
    this.clip, {
    this.targetAspectRatio,
    this.selectionEnabled = true,
  });

  /// The clip under the finger when the long press was recognized.
  final DivineVideoClip clip;

  /// Aspect ratio the drag is confined to, e.g. the one the editor's timeline
  /// is already committed to. `null` lets the first picked clip decide it.
  final double? targetAspectRatio;

  /// Whether the grid was already picking clips when the press landed.
  ///
  /// A long press while browsing opens selection mode, and always picks the
  /// clip up rather than toggling it: the selection it would toggle against
  /// is one the user cannot see, since clips already in the editor arrive
  /// pre-selected with their badges hidden.
  final bool selectionEnabled;

  @override
  List<Object?> get props => [clip, targetAspectRatio, selectionEnabled];
}

/// Event dispatched while a drag selection moves, once per clip the finger
/// reaches. Selects everything between the anchor and [clip] — and only that,
/// so dragging back over a clip takes it out again.
final class ClipsLibraryDragSelectionExtended extends ClipsLibraryEvent {
  const ClipsLibraryDragSelectionExtended(this.clip);

  /// The clip currently under the finger.
  final DivineVideoClip clip;

  @override
  List<Object?> get props => [clip];
}

/// Event dispatched when the finger lifts and the drag selection is over.
final class ClipsLibraryDragSelectionEnded extends ClipsLibraryEvent {
  const ClipsLibraryDragSelectionEnded();
}

/// Event to delete all selected clips.
final class ClipsLibraryDeleteSelected extends ClipsLibraryEvent {
  const ClipsLibraryDeleteSelected();
}

/// Event to delete a single clip.
final class ClipsLibraryDeleteClip extends ClipsLibraryEvent {
  const ClipsLibraryDeleteClip(this.clip);

  /// The clip to delete.
  final DivineVideoClip clip;

  @override
  List<Object?> get props => [clip];
}

/// Event to save selected clips to gallery.
final class ClipsLibrarySaveToGallery extends ClipsLibraryEvent {
  const ClipsLibrarySaveToGallery();
}

/// Event to change the active clip sort order. The new sort is
/// persisted to [SharedPreferences] using [ClipSort.persistenceKey].
final class ClipsLibrarySortChanged extends ClipsLibraryEvent {
  const ClipsLibrarySortChanged(this.sort);

  /// The new sort order to apply.
  final ClipSort sort;

  @override
  List<Object?> get props => [sort];
}

/// Event to change how many columns the clips grid renders, emitted when a
/// pinch on the grid settles. The count is clamped to the
/// [ClipGridColumns] range and persisted to [SharedPreferences].
final class ClipsLibraryGridColumnsChanged extends ClipsLibraryEvent {
  const ClipsLibraryGridColumnsChanged(this.columnCount);

  /// The new column count.
  final int columnCount;

  @override
  List<Object?> get props => [columnCount];
}

/// Event to manually enter multi-select mode (toolbar "Select" button).
final class ClipsLibraryEnterSelectionMode extends ClipsLibraryEvent {
  const ClipsLibraryEnterSelectionMode();
}

/// Event to exit multi-select mode and clear current selection.
final class ClipsLibraryExitSelectionMode extends ClipsLibraryEvent {
  const ClipsLibraryExitSelectionMode();
}

/// Event to enter multi-select mode automatically as a result of
/// the first selection arriving in clips-only mode. Sets
/// [ClipsLibraryState.didAutoOpenSelectionMode] so the toolbar can
/// lock the close button accordingly.
final class ClipsLibraryAutoOpenSelectionMode extends ClipsLibraryEvent {
  const ClipsLibraryAutoOpenSelectionMode();
}

/// Event to load the list of trashed clips.
final class ClipsLibraryTrashLoadRequested extends ClipsLibraryEvent {
  const ClipsLibraryTrashLoadRequested();
}

/// Event to restore one or more trashed clips back to the library.
final class ClipsLibraryRestoreClips extends ClipsLibraryEvent {
  const ClipsLibraryRestoreClips(this.clipIds);

  /// IDs of clips to restore.
  final Set<String> clipIds;

  @override
  List<Object?> get props => [clipIds];
}

/// Event to permanently delete a trashed clip (skip the trash window).
final class ClipsLibraryHardDeleteClip extends ClipsLibraryEvent {
  const ClipsLibraryHardDeleteClip(this.clip);

  /// The trashed clip to permanently delete.
  final DivineVideoClip clip;

  @override
  List<Object?> get props => [clip];
}

/// Event to permanently delete every trashed clip.
final class ClipsLibraryEmptyTrash extends ClipsLibraryEvent {
  const ClipsLibraryEmptyTrash();
}

/// Event to switch which slice of the library the grid shows.
///
/// Selecting [ClipLibraryTrashFilter] loads the trashed clips, which are
/// held separately from the active ones.
final class ClipsLibraryFilterChanged extends ClipsLibraryEvent {
  const ClipsLibraryFilterChanged(this.filter);

  /// The filter to apply.
  final ClipLibraryFilter filter;

  @override
  List<Object?> get props => [filter];
}

/// Event to create a new user category and file [clipIds] into it.
///
/// [clipIds] may be empty, which just creates the empty category.
final class ClipsLibraryCategoryCreated extends ClipsLibraryEvent {
  const ClipsLibraryCategoryCreated(this.name, {this.clipIds = const {}});

  /// The user-entered name. Blank input is rejected by the bloc.
  final String name;

  /// Clips to move into the new category right away.
  final Set<String> clipIds;

  @override
  List<Object?> get props => [name, clipIds];
}

/// Event to rename an existing user category.
final class ClipsLibraryCategoryRenamed extends ClipsLibraryEvent {
  const ClipsLibraryCategoryRenamed({
    required this.categoryId,
    required this.name,
  });

  /// The category to rename.
  final String categoryId;

  /// The user-entered name. Blank input is rejected by the bloc.
  final String name;

  @override
  List<Object?> get props => [categoryId, name];
}

/// Event to delete a user category. Its clips are kept and fall back to
/// the library's default view.
final class ClipsLibraryCategoryDeleted extends ClipsLibraryEvent {
  const ClipsLibraryCategoryDeleted(this.categoryId);

  /// The category to delete.
  final String categoryId;

  @override
  List<Object?> get props => [categoryId];
}

/// Event to file clips under [categoryId], or to unfile them when it is
/// `null`.
final class ClipsLibraryClipsMovedToCategory extends ClipsLibraryEvent {
  const ClipsLibraryClipsMovedToCategory({
    required this.clipIds,
    required this.categoryId,
  });

  /// Clips to move.
  final Set<String> clipIds;

  /// Target category, or `null` to remove the clips from their category.
  final String? categoryId;

  @override
  List<Object?> get props => [clipIds, categoryId];
}

/// Event to archive or unarchive clips. Archived clips stay in the library
/// but are hidden from its default view.
final class ClipsLibraryClipsArchiveChanged extends ClipsLibraryEvent {
  const ClipsLibraryClipsArchiveChanged({
    required this.clipIds,
    required this.archived,
    this.clearCategory = false,
    this.restoreCategoryIds = const {},
  });

  /// Clips to archive or unarchive.
  final Set<String> clipIds;

  /// True to archive, false to bring the clips back.
  final bool archived;

  /// Whether archiving also takes the clips out of their category. An
  /// archived clip stays visible under its category, so the user is asked
  /// which of the two they meant; this carries the answer.
  ///
  /// Ignored when [archived] is false — unarchiving never unfiles.
  final bool clearCategory;

  /// Category to file each clip back into while unarchiving, keyed by clip
  /// id. Set by the undo of an archive that unfiled the clips, so the undo
  /// restores both halves of what it reverses.
  ///
  /// Ignored when [archived] is true.
  final Map<String, String> restoreCategoryIds;

  @override
  List<Object?> get props => [
    clipIds,
    archived,
    clearCategory,
    restoreCategoryIds,
  ];
}
