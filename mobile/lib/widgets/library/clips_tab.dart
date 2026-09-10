// ABOUTME: Clips tab widget for the clip library screen
// ABOUTME: Displays a masonry grid of video clip thumbnails with selection support

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/extensions/media_query_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_category.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/library/clip_category_actions.dart';
import 'package:openvine/widgets/library/clip_category_chips.dart';
import 'package:openvine/widgets/library/drag_select_region.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';
import 'package:openvine/widgets/library/pinch_zoom_grid.dart';
import 'package:openvine/widgets/library/trashed_clips_list.dart';
import 'package:openvine/widgets/video_clip/video_clip_preview.dart';
import 'package:openvine/widgets/video_clip/video_clip_thumbnail_card.dart';

/// Tab widget displaying a grid of saved clips.
///
/// Uses [ClipsLibraryBloc] for state management and handles clip preview
/// internally. A filter chip row sits above the grid and narrows it to the
/// active [ClipLibraryFilter].
class ClipsTab extends StatelessWidget {
  /// Creates a clips tab.
  const ClipsTab({
    required this.showRecordButton,
    required this.backgroundColor,
    this.selectionEnabled = true,
    this.clips,
    this.targetAspectRatio,
    this.scrollController,
    this.gridTopPadding = 0,
    this.showCategoryManagement = false,
    super.key,
  });

  /// Optional externally provided clip order.
  final List<DivineVideoClip>? clips;

  /// Whether tapping a clip should toggle selection.
  final bool selectionEnabled;

  /// Whether in selection mode (adding to existing project).
  final bool showRecordButton;

  /// Surface this tab sits on. The zoomable grid paints it behind each of the
  /// two layouts it crossfades between — see [PinchZoomGrid.backgroundColor].
  final Color backgroundColor;

  /// Target aspect ratio for filtering compatible clips.
  final double? targetAspectRatio;

  /// Optional scroll controller, e.g. from a parent bottom sheet.
  final ScrollController? scrollController;

  /// Padding above the first grid row.
  ///
  /// The selection sheet sets this so the first row clears the bottom
  /// sheet header's divider instead of butting straight up against it.
  final double gridTopPadding;

  /// Whether the chip row offers the Archive and Deleted filters and lets
  /// the user create, rename, and delete categories.
  ///
  /// Only the standalone library sets this. The clip pickers leave it off:
  /// a trashed clip cannot join a timeline, and managing categories is not
  /// what the user came to the picker for. An archived clip that kept its
  /// category still shows up under it, badged as archived — the category is
  /// the whole truth about where a clip appears.
  final bool showCategoryManagement;

  @override
  Widget build(BuildContext context) {
    return Column(
      // The chip row scrolls horizontally, so it is only as wide as its
      // chips. Stretching keeps a short row start-aligned instead of letting
      // the Column's default centre alignment float it into the middle.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CategoryChipRow(showCategoryManagement: showCategoryManagement),
        Expanded(
          child: _ClipsBody(
            clips: clips,
            selectionEnabled: selectionEnabled,
            showRecordButton: showRecordButton,
            backgroundColor: backgroundColor,
            targetAspectRatio: targetAspectRatio,
            scrollController: scrollController,
            gridTopPadding: gridTopPadding,
          ),
        ),
      ],
    );
  }
}

/// The filter chip row, wired to [ClipsLibraryBloc].
class _CategoryChipRow extends StatelessWidget {
  const _CategoryChipRow({required this.showCategoryManagement});

  final bool showCategoryManagement;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClipsLibraryBloc, ClipsLibraryState>(
      buildWhen: (prev, curr) =>
          prev.categories != curr.categories || prev.filter != curr.filter,
      builder: (context, state) {
        // In a picker there are no built-in filters, so with no categories
        // yet the row would be a lone "All" chip that filters nothing.
        if (!showCategoryManagement && state.categories.isEmpty) {
          return const SizedBox.shrink();
        }
        return ClipCategoryChips(
          categories: state.categories,
          selected: state.filter,
          showBuiltInFilters: showCategoryManagement,
          onSelected: (filter) => context.read<ClipsLibraryBloc>().add(
            ClipsLibraryFilterChanged(filter),
          ),
          onCreateCategory: showCategoryManagement
              ? () => _createCategory(context)
              : null,
          onManageCategory: showCategoryManagement
              ? (category) => _manageCategory(context, category)
              : null,
        );
      },
    );
  }

  Future<void> _createCategory(BuildContext context) {
    return ClipCategoryActions.runCreateFlow(
      context: context,
      bloc: context.read<ClipsLibraryBloc>(),
    );
  }

  Future<void> _manageCategory(BuildContext context, ClipCategory category) {
    return ClipCategoryActions.runManageFlow(
      context: context,
      bloc: context.read<ClipsLibraryBloc>(),
      category: category,
    );
  }
}

class _ClipsBody extends StatelessWidget {
  const _ClipsBody({
    required this.clips,
    required this.selectionEnabled,
    required this.showRecordButton,
    required this.backgroundColor,
    required this.targetAspectRatio,
    required this.scrollController,
    required this.gridTopPadding,
  });

  final List<DivineVideoClip>? clips;
  final bool selectionEnabled;
  final bool showRecordButton;
  final Color backgroundColor;
  final double? targetAspectRatio;
  final ScrollController? scrollController;
  final double gridTopPadding;

  /// How long one filter's content takes to fade into the next.
  static const _filterFadeDuration = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClipsLibraryBloc, ClipsLibraryState>(
      builder: (context, state) {
        final content = _FilterContent(
          state: state,
          clips: clips,
          selectionEnabled: selectionEnabled,
          showRecordButton: showRecordButton,
          backgroundColor: backgroundColor,
          targetAspectRatio: targetAspectRatio,
          scrollController: scrollController,
          gridTopPadding: gridTopPadding,
        );

        // A cross-fade holds the outgoing filter's grid on screen alongside
        // the incoming one, so for those few frames two scroll views exist.
        // Each owns its own controller when none is supplied, which is fine.
        // A *supplied* one would be attached to both at once, and a pinch
        // landing in that window reads `controller.position` — which asserts
        // on anything other than exactly one attached position. The sheets
        // that supply a controller switch filters outright instead; their
        // surface is small enough that the fade earns little there.
        if (scrollController != null) return content;

        return AnimatedSwitcher(
          duration: _filterFadeDuration.autoReduceMotion(context),
          // Both children fill the box while they cross-fade; the default
          // layout would size the Stack to its children and let the shorter
          // one jump.
          layoutBuilder: (currentChild, previousChildren) => Stack(
            fit: StackFit.expand,
            children: [...previousChildren, ?currentChild],
          ),
          // Keyed on the filter alone, so only a filter switch cross-fades.
          // Selection toggles and reloads keep the key and update in place
          // rather than restarting the fade.
          child: KeyedSubtree(key: ValueKey(state.filter), child: content),
        );
      },
    );
  }
}

/// The clip content for one filter: the grid, the trash list, or the state
/// that stands in for them.
class _FilterContent extends StatelessWidget {
  const _FilterContent({
    required this.state,
    required this.clips,
    required this.selectionEnabled,
    required this.showRecordButton,
    required this.backgroundColor,
    required this.targetAspectRatio,
    required this.scrollController,
    required this.gridTopPadding,
  });

  /// Captured rather than watched, so the outgoing child of a cross-fade
  /// keeps rendering the filter it belongs to until the fade ends.
  final ClipsLibraryState state;

  final List<DivineVideoClip>? clips;
  final bool selectionEnabled;
  final bool showRecordButton;
  final Color backgroundColor;
  final double? targetAspectRatio;
  final ScrollController? scrollController;
  final double gridTopPadding;

  @override
  Widget build(BuildContext context) {
    // The trash bin has its own list, loading, and empty states — the
    // grid below only ever renders active clips.
    if (state.isShowingTrash) {
      return TrashedClipsList(scrollController: scrollController);
    }

    final visibleClips = clips ?? state.sortedClips;

    if (state.isLoading) {
      return const Center(child: BrandedLoadingIndicator(size: 60));
    }

    if (state.status == ClipsLibraryStatus.error) {
      return const _ClipsLoadError();
    }

    if (visibleClips.isEmpty) {
      return _FilterEmptyState(
        filter: state.filter,
        showRecordButton: showRecordButton,
        scrollController: scrollController,
      );
    }

    return _MasonryLayout(
      clips: visibleClips,
      columnCount: state.gridColumnCount,
      // Only inside a category, where archived clips sit next to active ones
      // and nothing else tells them apart.
      markArchivedClips: state.filter is ClipLibraryCategoryFilter,
      backgroundColor: backgroundColor,
      selectedClipIds: state.selectedClipIds,
      selectionEnabled: selectionEnabled,
      disabledClipIds: state.disabledClipIds,
      selectedIsStopMotion: state.selectedIsStopMotion,
      scrollController: scrollController,
      targetAspectRatio: targetAspectRatio,
      topPadding: gridTopPadding,
      onTapClip: (clip) {
        if (selectionEnabled) {
          context.read<ClipsLibraryBloc>().add(
            ClipsLibraryToggleSelection(clip),
          );
          return;
        }
        _showClipPreview(context, clip);
      },
    );
  }

  Future<void> _showClipPreview(
    BuildContext context,
    DivineVideoClip clip,
  ) async {
    await Navigator.push(
      context,
      videoClipPreviewRoute(
        clip: clip,
        onDelete: () => _confirmDeleteClip(context, clip),
      ),
    );
  }

  Future<void> _confirmDeleteClip(
    BuildContext context,
    DivineVideoClip clip,
  ) async {
    final confirmed = await VineBottomSheetPrompt.show<bool>(
      context: context,
      sticker: .alert,
      title: context.l10n.libraryDeleteClipTitle,
      subtitle: context.l10n.libraryDeleteClipMessage,
      additionalText: context.l10n.libraryDeleteClipsWarning,
      primaryButtonText: context.l10n.libraryDeleteConfirm,
      secondaryButtonText: context.l10n.commonCancel,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );

    if (confirmed != true || !context.mounted) return;

    context.read<ClipsLibraryBloc>().add(ClipsLibraryDeleteClip(clip));
    Navigator.of(context).pop();
  }
}

/// Empty state matching the active filter, so an empty category never reads
/// as an empty library.
class _FilterEmptyState extends StatelessWidget {
  const _FilterEmptyState({
    required this.filter,
    required this.showRecordButton,
    required this.scrollController,
  });

  final ClipLibraryFilter filter;
  final bool showRecordButton;

  /// Handed to the empty state so it drives the sheet the grid would have.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return switch (filter) {
      ClipLibraryArchiveFilter() => EmptyLibraryState(
        icon: DivineIconName.stackSimple,
        title: context.l10n.libraryArchiveEmptyTitle,
        subtitle: context.l10n.libraryArchiveEmptySubtitle,
        showRecordButton: false,
        scrollController: scrollController,
      ),
      ClipLibraryCategoryFilter() => EmptyLibraryState(
        icon: DivineIconName.folderOpen,
        title: context.l10n.libraryCategoryEmptyTitle,
        subtitle: context.l10n.libraryCategoryEmptySubtitle,
        showRecordButton: false,
        scrollController: scrollController,
      ),
      // The trash filter never reaches here: it renders TrashedClipsList,
      // which brings its own empty state.
      ClipLibraryAllFilter() || ClipLibraryTrashFilter() => EmptyLibraryState(
        icon: DivineIconName.filmSlate,
        title: context.l10n.libraryNoClipsYetTitle,
        subtitle: context.l10n.libraryNoClipsYetSubtitle,
        showRecordButton: showRecordButton,
        scrollController: scrollController,
      ),
    };
  }
}

class _ClipsLoadError extends StatelessWidget {
  const _ClipsLoadError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                context.l10n.libraryCouldNotLoadClips,
                textAlign: TextAlign.center,
                style: VineTheme.titleMediumFont(
                  color: context.vineColors.primaryText,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.libraryOpenErrorDescription,
                textAlign: TextAlign.center,
                style: VineTheme.bodyLargeFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
              const SizedBox(height: 24),
              DivineButton(
                label: context.l10n.searchTryAgain,
                type: DivineButtonType.secondary,
                onPressed: () {
                  final bloc = context.read<ClipsLibraryBloc>();
                  final s = bloc.state;
                  bloc.add(
                    ClipsLibraryLoadRequested(
                      preSelectedIds: s.preSelectedIds,
                      disabledClipIds: s.disabledClipIds,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Footer action bar for clip selection mode.
///
/// Sits below the clip grid and confirms the current selection. Renders no
/// background of its own so the enclosing bottom sheet's surface shows
/// through.
class ClipSelectionFooter extends StatelessWidget {
  /// Creates a selection footer.
  const ClipSelectionFooter({required this.onCreate, super.key});

  /// Callback when the select button is tapped.
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ClipsLibraryBloc, ClipsLibraryState, bool>(
      selector: (state) => state.selectedClipIds.isNotEmpty,
      builder: (context, hasSelection) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DivineButton(
              expanded: true,
              label: context.l10n.librarySelect,
              onPressed: hasSelection ? onCreate : null,
            ),
          ),
        );
      },
    );
  }
}

class _MasonryLayout extends StatelessWidget {
  const _MasonryLayout({
    required this.clips,
    required this.columnCount,
    required this.backgroundColor,
    required this.selectedClipIds,
    required this.selectionEnabled,
    required this.onTapClip,
    this.markArchivedClips = false,
    this.disabledClipIds = const {},
    this.scrollController,
    this.targetAspectRatio,
    this.selectedIsStopMotion,
    this.topPadding = 0,
  });

  final List<DivineVideoClip> clips;
  final int columnCount;
  final Color backgroundColor;
  final Set<String> selectedClipIds;

  /// Whether the grid is picking clips rather than browsing them: tiles carry
  /// a selection badge, a tap toggles one, and a long press drags a range of
  /// them out.
  final bool selectionEnabled;

  /// Whether an archived clip in [clips] carries the archived marker.
  final bool markArchivedClips;

  final Set<String> disabledClipIds;
  final ScrollController? scrollController;
  final ValueChanged<DivineVideoClip> onTapClip;
  final double? targetAspectRatio;
  final double topPadding;

  /// Type of the current selection (`true` = stop-motion). When set, clips of
  /// the other type are disabled so a selection can't mix stop-motion stills
  /// with normal video clips.
  final bool? selectedIsStopMotion;

  @override
  Widget build(BuildContext context) {
    // Walked rather than indexed: `Set.elementAt` restarts the iterator every
    // time, and a drag selection is large enough for that to cost frames.
    var selectionIndex = 0;
    final selectionIndexById = <String, int>{
      for (final id in selectedClipIds) id: ++selectionIndex,
    };
    return PinchZoomGrid(
      columnCount: columnCount,
      minColumnCount: ClipGridColumns.min,
      maxColumnCount: ClipGridColumns.max,
      backgroundColor: backgroundColor,
      scrollController: scrollController,
      onColumnCountChanged: (columns) {
        context.read<ClipsLibraryBloc>().add(
          ClipsLibraryGridColumnsChanged(columns),
        );
        SemanticsService.sendAnnouncement(
          View.of(context),
          context.l10n.libraryGridSizeColumns(columns),
          Directionality.of(context),
        );
      },
      builder: (context, columns, controller) => DragSelectRegion(
        scrollController: controller,
        onStarted: (index) => context.read<ClipsLibraryBloc>().add(
          ClipsLibraryDragSelectionStarted(
            clips[index],
            targetAspectRatio: targetAspectRatio,
            selectionEnabled: selectionEnabled,
          ),
        ),
        onExtended: (index) => context.read<ClipsLibraryBloc>().add(
          ClipsLibraryDragSelectionExtended(clips[index]),
        ),
        onEnded: () => context.read<ClipsLibraryBloc>().add(
          const ClipsLibraryDragSelectionEnded(),
        ),
        child: MasonryGridView.count(
          controller: controller,
          padding: .only(
            top: topPadding,
            bottom: MediaQuery.viewPaddingOf(context).bottom,
          ),
          crossAxisCount: columns,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          cacheExtent: MediaQuery.sizeOf(context).height * 2,
          itemCount: clips.length,
          itemBuilder: (context, index) {
            final clip = clips[index];
            final selectionIndex = selectionIndexById[clip.id] ?? -1;
            final disabled =
                disabledClipIds.contains(clip.id) ||
                (targetAspectRatio != null &&
                    targetAspectRatio != clip.targetAspectRatio.value) ||
                (selectedIsStopMotion != null &&
                    clip.isStopMotion != selectedIsStopMotion);

            return DragSelectSlot(
              index: index,
              enabled: !disabled,
              child: VideoClipThumbnailCard(
                clip: clip,
                selectionIndex: selectionIndex,
                showSelectionIndicator: selectionEnabled,
                showArchivedBadge: markArchivedClips && clip.archivedAt != null,
                disabled: disabled,
                onTap: () => onTapClip(clip),
                // No long press here: it belongs to the drag selection above,
                // and a handler at this depth would win the arena from it.
              ),
            );
          },
        ),
      ),
    );
  }
}
