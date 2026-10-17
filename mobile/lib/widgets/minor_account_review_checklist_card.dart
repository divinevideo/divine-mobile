// ABOUTME: Checklist card shared by the minor-account review consent screens:
// ABOUTME: a title over check-marked lines.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';

/// A titled card with one check-marked line per item.
///
/// Used by both consent screens, which list the same points the consent video
/// must show.
class MinorAccountReviewChecklistCard extends StatelessWidget {
  /// Creates a card titled [title] over one checked line per entry in [items].
  const MinorAccountReviewChecklistCard({
    required this.title,
    required this.items,
    super.key,
  });

  /// Heading shown above the list.
  final String title;

  /// Lines shown beside a check mark, in order.
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: ExcludeSemantics(
                      child: DivineIcon(
                        icon: DivineIconName.checkCircle,
                        size: 16,
                        color: VineTheme.vineGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: VineTheme.bodyMediumFont(
                        color: context.vineColors.mutedText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
