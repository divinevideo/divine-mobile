import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Shared error state for search result sections.
///
/// Displays a warning icon, "Something went wrong" message, and a
/// "Try again" button that calls [onRetry].
class SearchSectionErrorState extends StatelessWidget {
  const SearchSectionErrorState({required this.onRetry, super.key});

  /// Called when the user taps "Try again".
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 16,
          children: [
            DivineIcon(
              icon: DivineIconName.warningCircle,
              color: context.vineColors.secondaryText,
              size: 48,
            ),
            Text(
              context.l10n.searchSomethingWentWrong,
              style: VineTheme.titleSmallFont(
                color: context.vineColors.primaryText,
              ),
            ),
            DivineButton(
              type: DivineButtonType.secondary,
              size: DivineButtonSize.small,
              label: context.l10n.searchTryAgain,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
