// ABOUTME: Full-screen people discovery with existing search and profile routes.
// ABOUTME: Optional onboarding never requires a minimum number of follows.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/find_people/find_people_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/search_routes.dart';
import 'package:openvine/screens/find_people/widgets/find_people_recommendations.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';

/// Render-only view. Page owns dependencies and navigation after onboarding.
class FindPeopleView extends StatelessWidget {
  const FindPeopleView({
    this.source = 'findPeople',
    this.onAction,
    this.onSkip,
    this.onDone,
    super.key,
  });
  final String source;
  final FindPeopleActionCallback? onAction;
  final VoidCallback? onSkip;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.vineColors.background,
    appBar: DiVineAppBar(
      title: context.l10n.findPeopleTitle,
      showBackButton: source != 'onboarding',
      onBackPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(RoutePaths.root);
        }
      },
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: FindPeopleSuggestionsList.maxContentWidth,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: DivineSearchBar(
                  hintText: context.l10n.peopleListsAddPeopleSearchHint,
                  readOnly: true,
                  onTap: () => unawaited(
                    const SearchRouteData(
                      focus: SearchResultsPage.requestFocusQueryValue,
                    ).push<void>(context),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  context.l10n.findPeopleDescription,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.secondaryText,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: FindPeopleSuggestionsList(onAction: onAction),
                ),
              ),
              if (source == 'onboarding')
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      DivineButton(
                        label: context.l10n.videoErrorSkip,
                        type: DivineButtonType.quiet,
                        onPressed: onSkip,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DivineButton(
                          label: context.l10n.listContinue,
                          onPressed: onDone,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
