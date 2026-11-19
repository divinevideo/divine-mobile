// ABOUTME: Status for the featured slot while its campaign feed is hidden.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/featured_tabs/featured_tabs_cubit.dart';
import 'package:openvine/l10n/l10n.dart';

/// Renders the lookup status in the campaign's featured tab.
class FeaturedCampaignGate extends StatelessWidget {
  const FeaturedCampaignGate({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select(
      (FeaturedTabsCubit cubit) => cubit.state.status,
    );
    final l10n = context.l10n;
    return Center(
      child: switch (status) {
        FeaturedTabsStatus.initial ||
        FeaturedTabsStatus.loading => const DivineCircularProgressIndicator(),
        FeaturedTabsStatus.failed => Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.commonSomethingWentWrong),
        ),
        FeaturedTabsStatus.resolved => Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.featuredFeedUnavailable),
        ),
      },
    );
  }
}
