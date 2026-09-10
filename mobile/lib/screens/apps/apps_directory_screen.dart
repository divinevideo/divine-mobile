// ABOUTME: Lists approved third-party app integrations surfaced inside Divine
// ABOUTME: Keeps the framing explicitly bounded instead of reading like a browser

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/blocs/apps_directory/apps_directory_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/apps/nostr_app_launch_mode.dart';
import 'package:openvine/utils/nostr_apps_platform_support.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Displays the directory of approved third-party apps.
class AppsDirectoryScreen extends ConsumerWidget {
  /// Route name used by GoRouter.
  static const routeName = 'apps-directory';

  /// Route path used by GoRouter.
  static const String path = RoutePaths.appsDirectory;

  /// Creates an [AppsDirectoryScreen].
  const AppsDirectoryScreen({super.key, this.embedded = false});

  /// When true the screen omits its own app bar.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!nostrAppsSandboxSupported) {
      return _AppsDirectoryFrame(
        embedded: embedded,
        child: const _AppsDirectoryUnsupportedMessage(),
      );
    }

    final service = ref.read(nostrAppDirectoryServiceProvider);
    return BlocProvider(
      create: (_) => AppsDirectoryCubit(directoryService: service)..loadApps(),
      child: _AppsDirectoryFrame(
        embedded: embedded,
        child: const _AppsDirectoryContent(),
      ),
    );
  }
}

class _AppsDirectoryContent extends StatelessWidget {
  const _AppsDirectoryContent();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.vineColors.background,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: BlocBuilder<AppsDirectoryCubit, AppsDirectoryState>(
            builder: (context, state) {
              return switch (state.status) {
                AppsDirectoryStatus.initial || AppsDirectoryStatus.loading =>
                  const Center(child: BrandedLoadingIndicator(size: 60)),
                AppsDirectoryStatus.error => _AppsDirectoryMessage(
                  title: context.l10n.appsDirectoryErrorTitle,
                  subtitle: context.l10n.appsDirectoryErrorSubtitle,
                  actionLabel: context.l10n.commonRetry,
                  onAction: () =>
                      context.read<AppsDirectoryCubit>().refreshApps(),
                ),
                AppsDirectoryStatus.loaded when state.apps.isEmpty =>
                  _AppsDirectoryMessage(
                    title: context.l10n.appsDirectoryEmptyTitle,
                    subtitle: context.l10n.appsDirectoryEmptySubtitle,
                    actionLabel: context.l10n.appsDirectoryRefresh,
                    onAction: () =>
                        context.read<AppsDirectoryCubit>().refreshApps(),
                  ),
                AppsDirectoryStatus.loaded => RefreshIndicator(
                  color: VineTheme.onPrimary,
                  backgroundColor: VineTheme.vineGreen,
                  onRefresh: () =>
                      context.read<AppsDirectoryCubit>().refreshApps(),
                  child: ListView.builder(
                    // A null padding makes Flutter fall back to the vertical
                    // MediaQuery.padding — both insets. Embedded in Explore
                    // there is no app bar above, so the top inset is still
                    // the status bar and would gap the intro card; standalone
                    // the bottom inset is real (no bottom nav) and has to stay
                    // so the last card clears the gesture bar. Resolved here,
                    // below the Scaffold: 0 embedded, the inset standalone.
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: state.apps.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const _AppsDirectoryIntro();
                      }

                      final app = state.apps[index - 1];
                      return _AppsDirectoryRow(
                        app: app,
                        onTap: () => launchNostrApp(context, app),
                      );
                    },
                  ),
                ),
              };
            },
          ),
        ),
      ),
    );
  }
}

class _AppsDirectoryFrame extends StatelessWidget {
  const _AppsDirectoryFrame({required this.embedded, required this.child});

  final bool embedded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (embedded) {
      return child;
    }

    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.appsDirectoryTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: context.vineColors.background,
      body: child,
    );
  }
}

class _AppsDirectoryRow extends StatelessWidget {
  const _AppsDirectoryRow({required this.app, required this.onTap});

  final NostrAppDirectoryEntry app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Name, tagline and description are one logical row, so they merge into a
    // single announcement rather than three stops.
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Material(
            color: VineTheme.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Ink(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.vineColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.vineColors.outlineMuted),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AppsDirectoryIcon(iconUrl: app.iconUrl),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.name,
                            style: VineTheme.titleMediumFont(
                              color: context.vineColors.primaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            app.tagline,
                            style: VineTheme.labelLargeFont(
                              color: context.vineColors.accentPositive,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            app.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: VineTheme.bodyMediumFont(
                              color: context.vineColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: DivineIcon(
                        icon: DivineIconName.caretRight,
                        color: context.vineColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppsDirectoryIcon extends StatelessWidget {
  const _AppsDirectoryIcon({required this.iconUrl});

  final String iconUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: context.vineColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DivineIcon(
        icon: DivineIconName.gridNine,
        color: context.vineColors.accentPositive,
      ),
    );

    if (iconUrl.isEmpty) {
      return fallback;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: VineCachedImage(
        imageUrl: iconUrl,
        width: 56,
        height: 56,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

class _AppsDirectoryMessage extends StatelessWidget {
  const _AppsDirectoryMessage({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: VineTheme.headlineSmallFont(
                color: context.vineColors.primaryText,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: VineTheme.bodyLargeFont(
                color: context.vineColors.mutedText,
              ),
            ),
            const SizedBox(height: 16),
            DivineButton(label: actionLabel, onPressed: onAction),
          ],
        ),
      ),
    );
  }
}

class _AppsDirectoryIntro extends StatelessWidget {
  const _AppsDirectoryIntro();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: DivineInfoCard(
        icon: null,
        tone: DivineInfoCardTone.neutral,
        title: context.l10n.appsDirectoryIntroTitle,
        message: context.l10n.appsDirectoryIntroBody,
      ),
    );
  }
}

class _AppsDirectoryUnsupportedMessage extends StatelessWidget {
  const _AppsDirectoryUnsupportedMessage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.appsDirectoryUnsupportedTitle,
              textAlign: TextAlign.center,
              style: VineTheme.headlineSmallFont(
                color: context.vineColors.primaryText,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.appsDirectoryUnsupportedSubtitle,
              textAlign: TextAlign.center,
              style: VineTheme.bodyLargeFont(
                color: context.vineColors.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
