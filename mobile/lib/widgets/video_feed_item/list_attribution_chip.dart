// ABOUTME: Widget displaying curated list attribution chips on video feed items
// ABOUTME: Shows up to 2 tappable chips linking to source curated lists

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';

/// Callback type for list tap events.
typedef ListTapCallback = void Function(String listId, String listName);

/// Widget that displays attribution chips showing which curated list(s) a video
/// is from. Each chip is tappable and navigates to the source list.
class ListAttributionChip extends StatelessWidget {
  /// Creates a ListAttributionChip widget.
  ///
  /// The [listIds] parameter specifies which lists to display attribution for.
  /// The [listLookup] function resolves list IDs to CuratedList objects.
  /// The optional [onListTap] callback is invoked when a chip is tapped.
  const ListAttributionChip({
    required this.listIds,
    required this.listLookup,
    this.onListTap,
    super.key,
  });

  /// Set of list IDs to display chips for.
  final Set<String> listIds;

  /// Function to look up a CuratedList by its ID.
  final CuratedList? Function(String listId) listLookup;

  /// Optional callback when a list chip is tapped.
  final ListTapCallback? onListTap;

  @override
  Widget build(BuildContext context) {
    if (listIds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 4,
      children: listIds.take(2).map((listId) {
        final list = listLookup(listId);
        final listName = list?.name ?? context.l10n.listAttributionFallback;

        return GestureDetector(
          onTap: () {
            onListTap?.call(listId, listName);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: context.vineColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.vineColors.accentPositive.withValues(
                  alpha: 0.5,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DivineIcon(
                  icon: DivineIconName.playlist,
                  size: 14,
                  color: context.vineColors.accentPositive,
                ),
                const SizedBox(width: 4),
                Text(
                  listName,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.vineColors.accentPositive,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
