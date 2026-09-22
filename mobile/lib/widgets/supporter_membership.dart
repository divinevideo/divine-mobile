// ABOUTME: Account-scoped supporter acknowledgement and discovery entry points.
// ABOUTME: Public profile badges use only the opt-in public recognition endpoint.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/supporter/public_supporter_cubit.dart';
import 'package:openvine/blocs/supporter/supporter_cubit.dart';
import 'package:openvine/blocs/supporter/supporter_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/authentication_source.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/supporter_providers.dart';
import 'package:openvine/screens/settings/supporter_screen.dart';
import 'package:openvine/services/supporter_api_client.dart';

/// Private acknowledgement remains visible even when public recognition is off.
class SupporterMembership extends ConsumerWidget {
  const SupporterMembership({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(supporterApiConfiguredProvider)) {
      return const SizedBox.shrink();
    }
    ref.watch(currentAuthStateProvider);
    final auth = ref.watch(authServiceProvider);
    if (!auth.isAuthenticated) {
      return DivineListTile(
        title: context.l10n.supporterTitle,
        icon: DivineIconName.heart,
        subtitle: context.l10n.supporterVerificationJoin,
        onTap: () => context.push(SupporterScreen.path),
      );
    }
    ref.watch(currentAuthRpcCapabilityProvider);
    final repository = ref.watch(supporterRepositoryProvider);
    // External signers may prompt. Passive entry must not interrupt browsing;
    // opening Supporter settings explicitly still requests fresh private state.
    final canRefresh =
        auth.canPublishNostrWritesNow &&
        switch (auth.authenticationSource) {
          AuthenticationSource.divineOAuth ||
          AuthenticationSource.importedKeys ||
          AuthenticationSource.automatic => true,
          _ => false,
        };
    ref.listen(appForegroundProvider, (_, foreground) {
      if (foreground && canRefresh) unawaited(repository.refreshIfStale());
    });
    return BlocProvider(
      key: ValueKey((repository, canRefresh)),
      create: (_) {
        final cubit = SupporterCubit(repository: repository)
          ..start(loadStore: false);
        if (canRefresh) unawaited(repository.refreshIfStale());
        return cubit;
      },
      child: BlocBuilder<SupporterCubit, SupporterState>(
        builder: (context, state) {
          final confirmedInactive =
              state.snapshot?.status == SupporterServerStatus.expired;
          final label = state.isSupporter
              ? context.l10n.supporterBadgeLabel
              : confirmedInactive
              ? context.l10n.supporterJoinLabel
              : context.l10n.supporterTitle;
          if (compact) {
            return ActionChip(
              avatar: const DivineIcon(icon: DivineIconName.heart, size: 16),
              label: Text(label),
              onPressed: () => context.push(SupporterScreen.path),
            );
          }
          return DivineListTile(
            title: label,
            icon: DivineIconName.heart,
            subtitle: state.isSupporter
                ? context.l10n.supporterActiveBadge
                : confirmedInactive
                ? context.l10n.supporterVerificationJoin
                : context.l10n.supporterTileSubtitle,
            onTap: () => context.push(SupporterScreen.path),
          );
        },
      ),
    );
  }
}

class PublicSupporterBadge extends ConsumerWidget {
  const PublicSupporterBadge({required this.pubkey, super.key});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(supporterApiConfiguredProvider)) {
      return const SizedBox.shrink();
    }
    final client = ref.watch(supporterApiClientProvider);
    if (client == null) return const SizedBox.shrink();
    return BlocProvider(
      key: ValueKey((client, pubkey)),
      create: (_) =>
          PublicSupporterCubit(client: client, pubkey: pubkey)..load(),
      child: BlocBuilder<PublicSupporterCubit, bool>(
        builder: (context, visible) => visible
            ? Chip(
                avatar: const DivineIcon(icon: DivineIconName.heart, size: 16),
                label: Text(context.l10n.supporterBadgeLabel),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
