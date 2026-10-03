// ABOUTME: One row of a list picker sheet: the list's media block small at
// ABOUTME: the start, its name and count, and a check when it is picked.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Width of a picker row's media block: half the 177pt the gallery cards
/// draw it at (Figma 14085:129140 places a 40pt avatar here; the pickers
/// show the list's own card media instead so a row reads as its list).
const double listPickerMediaWidth = 88;

/// Edge of the check that marks a picked row, and of the space an unpicked
/// row keeps for it so the titles line up.
const double _checkSize = 24;

/// A row in the sheet that picks which lists hold a video or a person.
///
/// Both pickers render their rows through this so they look the same by
/// construction. [media] is the list's [DivineListMedia], sized here;
/// [meta] is the line under the name, the count and, for a video list, its
/// visibility. Reads to assistive tech as a checkable row.
class ListPickerRow extends StatelessWidget {
  /// Creates the row.
  const ListPickerRow({
    required this.media,
    required this.title,
    required this.meta,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  /// The list's media block, drawn [listPickerMediaWidth] wide.
  final Widget media;

  /// The list's name.
  final String title;

  /// The line under the name.
  final String meta;

  /// Whether the list is picked.
  final bool isSelected;

  /// Toggles the pick; null while the row cannot be changed.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Semantics(
      checked: isSelected,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.outlineDisabled)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              spacing: 16,
              children: [
                ExcludeSemantics(
                  child: SizedBox(
                    width: DivineIcon.scaleSize(context, listPickerMediaWidth),
                    child: media,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: VineTheme.titleMediumFont(
                          color: colors.onSurface,
                        ),
                      ),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VineTheme.bodyMediumFont(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox.square(
                  dimension: DivineIcon.scaleSize(context, _checkSize),
                  child: isSelected
                      ? DivineIcon(
                          icon: DivineIconName.check,
                          color: colors.accentPositive,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
