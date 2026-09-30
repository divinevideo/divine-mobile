// ABOUTME: Explore's curated badge definitions, linked to their holder pages.

import 'package:badge_repository/badge_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/screens/badges/badge_detail_screen.dart';
import 'package:openvine/widgets/badges/awarded_badge_card.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

/// Issuers whose badge definitions Divine curates in Explore.
///
/// The first key is the public issuer published by badges.divine.video.
const exploreBadgeIssuers = <String>{
  'e21369e63b98f58de8aa171ec9794006eb0118891ae70895106d44525b718d2b',
};

/// Discover badge definitions from curated issuers.
class ExploreBadgesTab extends ConsumerStatefulWidget {
  /// Creates the Explore Badges tab.
  const ExploreBadgesTab({super.key});

  @override
  ConsumerState<ExploreBadgesTab> createState() => _ExploreBadgesTabState();
}

class _ExploreBadgesTabState extends ConsumerState<ExploreBadgesTab> {
  Future<List<Nip58BadgeDefinition>>? _definitions;
  BadgeRepository? _repository;

  Future<List<Nip58BadgeDefinition>> _load(BadgeRepository repository) =>
      repository.loadDefinitionsByIssuers(exploreBadgeIssuers);

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(badgeRepositoryProvider);
    if (!identical(repository, _repository)) {
      _repository = repository;
      _definitions = _load(repository);
    }
    return FutureBuilder<List<Nip58BadgeDefinition>>(
      future: _definitions,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: BrandedLoadingIndicator(size: 60));
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => _definitions = _load(repository)),
              child: Text(context.l10n.badgesLoadError),
            ),
          );
        }
        final definitions = snapshot.data ?? const <Nip58BadgeDefinition>[];
        return RefreshIndicator(
          color: VineTheme.onPrimary,
          backgroundColor: VineTheme.vineGreen,
          onRefresh: () async {
            final next = _load(repository);
            setState(() => _definitions = next);
            await next;
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: definitions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final definition = definitions[index];
              final coordinate = BadgeCoordinate.parse(definition.coordinate)!;
              return BadgePanel(
                onTap: () => context.push<void>(
                  BadgeDetailScreen.pathFor(coordinate),
                ),
                child: Row(
                  spacing: 12,
                  children: [
                    BadgeMedallion(imageUrl: definition.imageUrl),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            definition.name ?? definition.dTag,
                            style: VineTheme.titleSmallFont(
                              color: context.vineColors.onSurface,
                            ),
                          ),
                          if (definition.description case final description?)
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: VineTheme.bodySmallFont(
                                color: context.vineColors.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
