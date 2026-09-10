// ABOUTME: Bottom bar for the video editor filter selection.
// ABOUTME: Displays a horizontal scrollable list of filter previews.

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Bottom bar displaying filter options as thumbnail previews.
///
/// Shows a horizontal scrollable list with "None" as the first option,
/// followed by available filters. The selected filter is highlighted
/// with a primary-colored border.
class VideoEditorFilterBottomBar extends ConsumerWidget {
  const VideoEditorFilterBottomBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clip = ref.watch(
      clipManagerProvider.select((s) => s.firstClipOrNull),
    );
    if (clip == null) return const SizedBox.shrink();

    final (filters, selectedFilter) = context.select(
      (VideoEditorFilterBloc b) => (b.state.filters, b.state.selectedFilter),
    );
    final scope = VideoEditorScope.of(context);
    final stateManager = scope.editor?.stateManager;
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.25);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: ListView.separated(
        scrollDirection: .horizontal,
        padding: const .fromLTRB(16, 0, 16, 4),
        itemCount: filters.length,
        separatorBuilder: (_, index) {
          // Add vertical divider after "None"
          if (index == 0) {
            return Padding(
              padding: const .symmetric(horizontal: 8),
              child: VerticalDivider(
                color: VineTheme.onSurface.withValues(alpha: 0.3),
                thickness: 1,
                indent: 12,
                endIndent: 12,
              ),
            );
          }
          return const SizedBox(width: 8);
        },
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected =
              selectedFilter?.name == filter.name ||
              (selectedFilter == null && filter == PresetFilters.none);
          return _FilterItem(
            filter: filter,
            isSelected: isSelected,
            thumbnailPath: clip.thumbnailPath ?? '',
            activeFilters: stateManager?.activeFilters.allMatrices ?? [],
            activeTuneAdjustments: stateManager?.activeTuneAdjustments ?? [],
            activeBlur: stateManager?.activeBlur ?? 0,
            onTap: () {
              context.read<VideoEditorFilterBloc>().add(
                VideoEditorFilterSelected(filter),
              );
              scope.filterEditor?.setFilter(filter);
            },
          );
        },
      ),
    );
  }
}

class _FilterItem extends StatelessWidget {
  const _FilterItem({
    required this.filter,
    required this.isSelected,
    required this.thumbnailPath,
    required this.activeFilters,
    required this.activeTuneAdjustments,
    required this.activeBlur,
    required this.onTap,
  });

  final FilterModel filter;
  final bool isSelected;
  final String thumbnailPath;
  final FilterMatrix activeFilters;
  final List<TuneAdjustmentMatrix> activeTuneAdjustments;
  final double activeBlur;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: filter.name,
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisAlignment: .end,
            spacing: 4,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: context.vineColors.surfaceContainer,
                  borderRadius: .circular(20),
                  border: .all(
                    color: isSelected
                        ? context.vineColors.accentPositive
                        : context.vineColors.outlineMuted,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: .circular(18),
                  child: FilteredWidget(
                    width: 52,
                    height: 52,
                    enableCachedSize: true,
                    // In that scenario we don't need any special
                    // configurations, so we just use the default one.
                    configs: const ProImageEditorConfigs(),
                    filters: filter.filters,
                    tuneAdjustments: activeTuneAdjustments,
                    blurFactor: activeBlur,
                    fit: .cover,
                    image: EditorImage(file: File(thumbnailPath)),
                  ),
                ),
              ),
              Text(
                filter.name,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.onSurface,
                ),
                maxLines: 1,
                textAlign: .center,
                overflow: .ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
