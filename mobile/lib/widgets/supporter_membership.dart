// ABOUTME: Account-scoped supporter acknowledgement and discovery entry points.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/supporter/supporter_cubit.dart';
import 'package:openvine/blocs/supporter/supporter_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/authentication_source.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/supporter_providers.dart';
import 'package:openvine/screens/settings/supporter_screen.dart';

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
      return _MembershipEntry(
        compact: compact,
        label: context.l10n.supporterTitle,
        subtitle: context.l10n.supporterTileSubtitle,
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
          final confirmedInactive = state.isConfirmedInactive;
          final label = state.isSupporter
              ? context.l10n.supporterBadgeLabel
              : confirmedInactive
              ? context.l10n.supporterJoinLabel
              : context.l10n.supporterTitle;
          return _MembershipEntry(
            compact: compact,
            label: label,
            subtitle: state.isSupporter
                ? context.l10n.supporterActiveBadge
                : context.l10n.supporterTileSubtitle,
          );
        },
      ),
    );
  }
}

class _MembershipEntry extends StatelessWidget {
  const _MembershipEntry({
    required this.compact,
    required this.label,
    required this.subtitle,
  });

  final bool compact;
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: compact
        ? ActionChip(
            avatar: DivineIcon(
              icon: DivineIconName.heart,
              size: 16,
              color: context.vineColors.primaryText,
            ),
            label: Text(label),
            onPressed: () => context.push(SupporterScreen.path),
          )
        : DivineListTile(
            title: label,
            icon: DivineIconName.heart,
            subtitle: subtitle,
            onTap: () => context.push(SupporterScreen.path),
          ),
  );
}
