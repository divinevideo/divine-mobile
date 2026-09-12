import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Section header with a title and optional trailing chevron.
///
/// Used in the "All" search results view to separate People, Tags,
/// Lists, and Videos sections.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    super.key,
    this.onTap,
    this.semanticIdentifier,
  });

  final String title;
  final VoidCallback? onTap;

  /// Stable UI-test anchor, so flows do not have to match translated
  /// section titles.
  final String? semanticIdentifier;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: semanticIdentifier,
      header: true,
      label: title,
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          // 1 px outline-disabled hairline above and below each section
          // header, matching the Figma list-divider treatment.
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: context.vineColors.outlineDisabled,
                width: 0,
              ),
              bottom: BorderSide(
                color: context.vineColors.outlineDisabled,
                width: 0,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style:
                        VineTheme.titleMediumFont(
                          color: context.vineColors.primaryText,
                        ).copyWith(
                          color: context.vineColors.primaryText,
                        ),
                  ),
                ),
                if (onTap != null)
                  DivineIcon(
                    icon: DivineIconName.caretRight,
                    color: context.vineColors.accentPositive,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
