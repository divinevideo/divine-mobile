// ABOUTME: Screen for reviewing and revoking remembered integration permissions
// ABOUTME: Shows per-user grant entries saved by the Nostr app grant store

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/blocs/apps_permissions/apps_permissions_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

/// Displays persisted permission grants and allows
/// revocation.
class AppsPermissionsScreen extends StatelessWidget {
  /// Route name used by GoRouter.
  static const routeName = 'apps-permissions';

  /// Route path used by GoRouter.
  static const path = '/apps/permissions';

  /// Creates an [AppsPermissionsScreen].
  const AppsPermissionsScreen({
    required this.grantStore,
    required this.currentUserPubkey,
    super.key,
  });

  /// The backing store for persisted grants.
  final NostrAppGrantStore grantStore;

  /// Hex public key of the logged-in user.
  final String? currentUserPubkey;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AppsPermissionsCubit(
        grantStore: grantStore,
        currentUserPubkey: currentUserPubkey,
      )..loadGrants(),
      child: const _AppsPermissionsContent(),
    );
  }
}

class _AppsPermissionsContent extends StatelessWidget {
  const _AppsPermissionsContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.appsPermissionsTitle,
        showBackButton: true,
        onBackPressed: Navigator.of(context).pop,
      ),
      backgroundColor: context.vineColors.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: BlocBuilder<AppsPermissionsCubit, AppsPermissionsState>(
            builder: (context, state) {
              if (state.status != AppsPermissionsStatus.loaded) {
                return const Center(child: BrandedLoadingIndicator(size: 60));
              }

              if (state.grants.isEmpty) {
                return const _AppsPermissionsEmptyState();
              }

              return RefreshIndicator(
                color: VineTheme.onPrimary,
                backgroundColor: VineTheme.vineGreen,
                onRefresh: () =>
                    context.read<AppsPermissionsCubit>().loadGrants(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.grants.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final grant = state.grants[index];
                    return _GrantCard(
                      grant: grant,
                      onRevoke: () => context
                          .read<AppsPermissionsCubit>()
                          .revokeGrant(grant),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AppsPermissionsEmptyState extends StatelessWidget {
  const _AppsPermissionsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DivineIcon(
              icon: DivineIconName.lockSimple,
              color: context.vineColors.accentPositive,
              size: 28,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.appsPermissionsEmptyTitle,
              textAlign: TextAlign.center,
              style: VineTheme.headlineSmallFont(
                color: context.vineColors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.appsPermissionsEmptySubtitle,
              textAlign: TextAlign.center,
              style: VineTheme.bodyLargeFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GrantCard extends StatelessWidget {
  const _GrantCard({required this.grant, required this.onRevoke});

  final NostrAppGrant grant;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.vineColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.vineColors.outlineMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            grant.appId,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            grant.origin,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            grant.capability,
            style: VineTheme.labelLargeFont(
              color: context.vineColors.accentPositive,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: DivineButton(
              label: context.l10n.appsPermissionsRevoke,
              onPressed: onRevoke,
            ),
          ),
        ],
      ),
    );
  }
}
