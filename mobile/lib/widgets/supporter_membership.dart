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

/// Settings entry to supporter membership, acknowledging supporters.
///
/// Reads the [SupporterCubit] of an enclosing [SupporterMembershipScope] when
/// there is one, so it shares that scope's single membership read.
class SupporterMembership extends ConsumerWidget {
  const SupporterMembership({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(supporterApiConfiguredProvider)) {
      return const SizedBox.shrink();
    }
    ref.watch(currentAuthStateProvider);
    if (!ref.watch(authServiceProvider).isAuthenticated) {
      return _MembershipEntry(
        label: context.l10n.supporterTitle,
        subtitle: context.l10n.supporterTileSubtitle,
      );
    }
    const status = _MembershipStatus();
    return context.read<SupporterCubit?>() != null
        ? status
        : const SupporterMembershipScope(child: status);
  }
}

/// Provides the signed-in account's [SupporterCubit] to [child], refreshing
/// the cached membership only where that cannot prompt an external signer.
///
/// Leaves [child] without a cubit when supporters are not configured or no
/// one is signed in.
class SupporterMembershipScope extends ConsumerWidget {
  const SupporterMembershipScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(supporterApiConfiguredProvider)) return child;
    ref.watch(currentAuthStateProvider);
    final auth = ref.watch(authServiceProvider);
    if (!auth.isAuthenticated) return child;
    ref.watch(currentAuthRpcCapabilityProvider);
    final repository = ref.watch(supporterRepositoryProvider);
    final canRefresh =
        auth.canPublishNostrWritesNow &&
        _signsWithoutPrompting(auth.authenticationSource);
    ref
      ..listen(appForegroundProvider, (_, foreground) {
        if (foreground && canRefresh) unawaited(repository.refreshIfStale());
      })
      // A remote signer becomes usable after sign-in. Refresh then, rather
      // than re-keying the cubit and remounting everything it wraps.
      ..listen(currentAuthRpcCapabilityProvider, (_, _) {
        final current = ref.read(authServiceProvider);
        if (current.canPublishNostrWritesNow &&
            _signsWithoutPrompting(current.authenticationSource)) {
          unawaited(repository.refreshIfStale());
        }
      });
    return BlocProvider(
      key: ValueKey(repository),
      create: (_) {
        final cubit = SupporterCubit(repository: repository)
          ..start(loadStore: false);
        if (canRefresh) unawaited(repository.refreshIfStale());
        return cubit;
      },
      child: child,
    );
  }
}

/// Whether [source] signs without a prompt, so the membership may refresh
/// without being asked. External signers may prompt, and passive entry must
/// not interrupt browsing; opening Supporter settings explicitly still
/// requests fresh private state.
bool _signsWithoutPrompting(AuthenticationSource source) => switch (source) {
  AuthenticationSource.divineOAuth ||
  AuthenticationSource.importedKeys ||
  AuthenticationSource.automatic => true,
  _ => false,
};

class _MembershipStatus extends StatelessWidget {
  const _MembershipStatus();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupporterCubit, SupporterState>(
      builder: (context, state) {
        final label = state.isSupporter
            ? context.l10n.supporterBadgeLabel
            : state.isConfirmedInactive
            ? context.l10n.supporterJoinLabel
            : context.l10n.supporterTitle;
        return _MembershipEntry(
          label: label,
          subtitle: state.isSupporter
              ? context.l10n.supporterActiveBadge
              : context.l10n.supporterTileSubtitle,
        );
      },
    );
  }
}

class _MembershipEntry extends StatelessWidget {
  const _MembershipEntry({required this.label, required this.subtitle});

  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: DivineListTile(
      title: label,
      icon: DivineIconName.heart,
      subtitle: subtitle,
      onTap: () => context.push(SupporterScreen.path),
    ),
  );
}
