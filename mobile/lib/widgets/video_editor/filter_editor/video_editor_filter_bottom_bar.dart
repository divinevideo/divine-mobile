// ABOUTME: Bottom bar of the video editor's filter editor: a category picker
// ABOUTME: of preview tiles, each showing its filter on the first clip.

import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/editor_filter_category.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_category_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Bottom bar of the filter editor: a [VideoEditorCategoryPicker] of the
/// colour filters, one section per [EditorFilterCategory].
///
/// Each tile shows its filter on the first clip's thumbnail, over the tune
/// adjustments and blur already applied.
class VideoEditorFilterBottomBar extends ConsumerWidget {
  const VideoEditorFilterBottomBar({super.key});

  /// The height the editor reserves for the bar above the system navigation
  /// bar.
  static double heightOf(BuildContext context) =>
      VideoEditorCategoryPicker.heightOf(context);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnailPath = ref.watch(
      clipManagerProvider.select((s) => s.firstClipOrNull?.thumbnailPath),
    );
    final selectedName = context.select(
      (VideoEditorFilterBloc b) => b.state.selectedFilter?.name,
    );
    final scope = VideoEditorScope.of(context);
    final stateManager = scope.editor?.stateManager;
    return VideoEditorCategoryPicker<EditorFilterCategory, FilterModel>(
      sections: _sections,
      categoryLabel: _categoryLabel,
      isSelected: (filter) => filter.name == selectedName,
      tileBuilder: (context, filter, isSelected) =>
          VideoEditorCategoryPickerTile(
            label: filter.name,
            isSelected: isSelected,
            onTap: () {
              context.read<VideoEditorFilterBloc>().add(
                VideoEditorFilterSelected(filter),
              );
              scope.filterEditor?.setFilter(filter);
            },
            preview: thumbnailPath == null || thumbnailPath.isEmpty
                ? const SizedBox.expand()
                : FilteredWidget(
                    // Also the size the thumbnail is decoded at.
                    width: VideoEditorCategoryPickerTile.previewSize,
                    height: VideoEditorCategoryPickerTile.previewSize,
                    enableCachedSize: true,
                    // A preview needs none of the editor's configurations.
                    configs: const ProImageEditorConfigs(),
                    filters: filter.filters,
                    tuneAdjustments: stateManager?.activeTuneAdjustments ?? [],
                    blurFactor: stateManager?.activeBlur ?? 0,
                    fit: .cover,
                    image: EditorImage(file: File(thumbnailPath)),
                  ),
          ),
    );
  }
}

/// The filters of each category, in picker order.
final Map<EditorFilterCategory, List<FilterModel>> _sections = {
  for (final category in EditorFilterCategory.values)
    category: category.filters,
};

/// The localized name of [category].
String _categoryLabel(
  BuildContext context,
  EditorFilterCategory category,
) => switch (category) {
  EditorFilterCategory.natural => context.l10n.videoEditorFilterCategoryNatural,
  EditorFilterCategory.vibrant => context.l10n.videoEditorFilterCategoryVibrant,
  EditorFilterCategory.warm => context.l10n.videoEditorFilterCategoryWarm,
  EditorFilterCategory.cool => context.l10n.videoEditorFilterCategoryCool,
  EditorFilterCategory.vintage => context.l10n.videoEditorFilterCategoryVintage,
  EditorFilterCategory.blackAndWhite =>
    context.l10n.videoEditorFilterCategoryBlackAndWhite,
  EditorFilterCategory.tints => context.l10n.videoEditorFilterCategoryTints,
};
