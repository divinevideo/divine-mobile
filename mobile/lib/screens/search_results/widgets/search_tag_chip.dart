import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';

/// Hashtag chip used in both the Tags preview section and the full hashtag
/// search list. Renders a `#` prefix in vine green followed by the tag name.
class SearchTagChip extends StatelessWidget {
  const SearchTagChip({required this.tag, required this.onTap, super.key});

  final String tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: SemanticIds.searchTag(tag),
      label: context.l10n.searchTagChipViewVideosTaggedLabel(tag),
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: context.vineColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              Text(
                '#',
                style: VineTheme.bodyLargeFont(
                  color: context.vineColors.accentPositive,
                ),
              ),
              Flexible(
                child: Text(
                  tag,
                  style: VineTheme.titleSmallFont(
                    color: context.vineColors.primaryText,
                  ),
                  maxLines: 1,
                  overflow: .ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
