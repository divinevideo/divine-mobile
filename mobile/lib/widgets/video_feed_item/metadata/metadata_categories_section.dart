// ABOUTME: Category chip widget for the metadata expanded sheet tags area.
// ABOUTME: Shows accent-colored chips with emoji for VLM-classified categories.
// ABOUTME: Hidden when no categories are available (API support pending).

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show VideoCategory;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_category_name.dart';
import 'package:openvine/widgets/categories/category_visuals.dart';

/// A single category chip with accent background, emoji, and label.
///
/// Styled to match the Figma spec (node `12345:71463`): accent-colored
/// background from [CategoryVisuals], emoji from [VideoCategory.emoji],
/// and the display name in the accent foreground color.
///
/// Used inside the tags [Wrap] in [MetadataTagsSection].
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    required this.categoryName,
    required this.index,
    super.key,
  });

  final String categoryName;
  final int index;

  @override
  Widget build(BuildContext context) {
    final category = VideoCategory(name: categoryName, videoCount: 0);
    final visuals = CategoryVisuals.forCategory(category, index);

    return Container(
      padding: const EdgeInsetsDirectional.only(
        start: 12,
        end: 16,
        top: 8,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: visuals.backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          // Emoji renders with system font; only fontSize matters.
          Text(
            category.emoji,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.primaryText,
            ).copyWith(fontSize: 18),
          ),
          Flexible(
            child: Text(
              localizedCategoryName(context.l10n, category.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VineTheme.titleSmallFont(color: visuals.foregroundColor),
            ),
          ),
        ],
      ),
    );
  }
}
