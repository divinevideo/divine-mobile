import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Shared initial-state placeholder for search result sections.
///
/// Rendered when the search query is empty and the corresponding BLoC is
/// in its pristine `initial` status — i.e. there is no work in flight and
/// the user has not yet typed a query. Accepts [title] and [subtitle] so
/// each section can provide its own localized copy via `context.l10n`.
class SearchSectionInitialState extends StatelessWidget {
  const SearchSectionInitialState({
    required this.title,
    required this.subtitle,
    super.key,
  });

  /// Short call-to-action, e.g. "Search for videos".
  final String title;

  /// One-line explanation, e.g. "Find vines by keyword".
  final String subtitle;

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
              icon: DivineIconName.search,
              color: context.vineColors.secondaryText,
              size: 48,
            ),
            Text(
              title,
              style: VineTheme.titleSmallFont(
                color: context.vineColors.primaryText,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
