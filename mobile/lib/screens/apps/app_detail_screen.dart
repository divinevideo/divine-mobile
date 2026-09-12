// ABOUTME: App detail screen for approved third-party integrations in Divine
// ABOUTME: Explains the bounded access model before launching an integration

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/blocs/app_detail/app_detail_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/apps/nostr_app_launch_mode.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

/// Displays detailed information about a single approved
/// third-party integration.
class AppDetailScreen extends ConsumerWidget {
  /// Route name used by GoRouter.
  static const routeName = 'app-detail';

  /// Route path used by GoRouter.
  static const path = '/apps/:slug';

  /// Creates an [AppDetailScreen].
  const AppDetailScreen({required this.slug, this.initialEntry, super.key});

  /// The slug of the app to display.
  final String slug;

  /// An optional pre-loaded entry to avoid a network call.
  final NostrAppDirectoryEntry? initialEntry;

  /// Returns the path for a given [slug].
  static String pathForSlug(String slug) => RoutePaths.appDetailForSlug(slug);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(nostrAppDirectoryServiceProvider);
    return BlocProvider(
      create: (_) => AppDetailCubit(
        slug: slug,
        directoryService: service,
        initialEntry: initialEntry,
      )..load(),
      child: const _AppDetailContent(),
    );
  }
}

class _AppDetailContent extends StatelessWidget {
  const _AppDetailContent();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppDetailCubit, AppDetailState>(
      builder: (context, state) {
        final app = switch (state) {
          AppDetailLoaded(:final app) => app,
          _ => null,
        };

        return Scaffold(
          appBar: DiVineAppBar(
            title: app?.name ?? context.l10n.appsDetailDefaultTitle,
            showBackButton: true,
            onBackPressed: context.pop,
          ),
          backgroundColor: context.vineColors.background,
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: switch (state) {
                AppDetailLoading() => const Center(
                  child: BrandedLoadingIndicator(size: 60),
                ),
                AppDetailNotFound() => _AppDetailMessage(
                  title: context.l10n.appsDetailNotFoundTitle,
                  subtitle: context.l10n.appsDetailNotFoundSubtitle,
                ),
                AppDetailLoaded(:final app) => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: context.vineColors.card,
                      child: DivineIcon(
                        icon: DivineIconName.gridNine,
                        color: context.vineColors.accentPositive,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      app.name,
                      style: VineTheme.headlineSmallFont(
                        color: context.vineColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      app.tagline,
                      style: VineTheme.bodyLargeFont(
                        color: context.vineColors.mutedText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AppDetailSection(
                      title: context.l10n.appsDetailHowItWorksTitle,
                      child: Text(
                        context.l10n.appsDetailHowItWorksBody,
                        style: VineTheme.bodyMediumFont(
                          color: context.vineColors.primaryText,
                        ),
                      ),
                    ),
                    _AppDetailSection(
                      title: context.l10n.appsDetailAboutTitle,
                      child: Text(
                        app.description,
                        style: VineTheme.bodyMediumFont(
                          color: context.vineColors.primaryText,
                        ),
                      ),
                    ),
                    _AppDetailSection(
                      title: context.l10n.appsDetailPrimaryOriginTitle,
                      child: Text(
                        app.primaryOrigin,
                        style: VineTheme.bodyMediumFont(
                          color: context.vineColors.accentPositive,
                        ),
                      ),
                    ),
                    _AppDetailSection(
                      title: context.l10n.appsDetailApprovedOriginsTitle,
                      child: _PillList(items: app.allowedOrigins),
                    ),
                    _AppDetailSection(
                      title: context.l10n.appsDetailCapabilitiesTitle,
                      child: _PillList(items: app.allowedMethods),
                    ),
                    _AppDetailSection(
                      title: context.l10n.appsDetailAskBeforeTitle,
                      child: _PillList(items: app.promptRequiredFor),
                    ),
                    const SizedBox(height: 8),
                    DivineButton(
                      label: context.l10n.appsDetailOpenButton,
                      onPressed: () => launchNostrApp(context, app),
                    ),
                  ],
                ),
              },
            ),
          ),
        );
      },
    );
  }
}

class _AppDetailSection extends StatelessWidget {
  const _AppDetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.vineColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: VineTheme.labelMediumFont(
              color: context.vineColors.mutedText,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PillList extends StatelessWidget {
  const _PillList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        context.l10n.appsDetailNoneDeclared,
        style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.vineColors.background,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: context.vineColors.accentPositive.withAlpha(80),
                ),
              ),
              child: Text(
                item,
                style: VineTheme.labelMediumFont(
                  color: context.vineColors.primaryText,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _AppDetailMessage extends StatelessWidget {
  const _AppDetailMessage({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: VineTheme.headlineSmallFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: VineTheme.bodyLargeFont(
              color: context.vineColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}
