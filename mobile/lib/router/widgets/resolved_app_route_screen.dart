// ABOUTME: Resolves a NostrAppDirectoryEntry from the route's appId path
// ABOUTME: parameter and hands it to a caller-supplied builder once available.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/blocs/sandbox_route/sandbox_route_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/widgets/missing_sandbox_app_screen.dart';
import 'package:openvine/screens/apps/apps_directory_screen.dart';

/// Builds the destination screen for a resolved [NostrAppDirectoryEntry].
typedef ResolvedAppBuilder = Widget Function(NostrAppDirectoryEntry app);

/// Resolves a [NostrAppDirectoryEntry] by ID or slug and renders
/// [onResolved] once the entry is available.
///
/// The entry is looked up from the directory rather than required through
/// `GoRouterState.extra`, so a pasted URL, a browser refresh or a restored
/// session lands on the same screen as in-app navigation (#3335).
/// [initialApp] is only a warm-start hint that skips the fetch.
class ResolvedAppRouteScreen extends ConsumerWidget {
  /// Creates a [ResolvedAppRouteScreen].
  const ResolvedAppRouteScreen({
    required this.appId,
    required this.onResolved,
    this.initialApp,
    super.key,
  });

  /// The app ID or slug to resolve.
  final String appId;

  /// Builds the screen for the resolved entry.
  final ResolvedAppBuilder onResolved;

  /// An optional pre-loaded entry to avoid a network call.
  final NostrAppDirectoryEntry? initialApp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(nostrAppDirectoryServiceProvider);
    return BlocProvider(
      create: (_) => SandboxRouteCubit(
        appId: appId,
        directoryService: service,
        initialApp: initialApp,
      )..load(),
      child: _ResolvedAppRouteContent(onResolved: onResolved),
    );
  }
}

class _ResolvedAppRouteContent extends StatelessWidget {
  const _ResolvedAppRouteContent({required this.onResolved});

  final ResolvedAppBuilder onResolved;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SandboxRouteCubit, SandboxRouteState>(
      builder: (context, state) {
        return switch (state) {
          SandboxRouteLoading() => const _ResolvingAppScreen(),
          SandboxRouteNotFound() => const MissingSandboxAppScreen(),
          SandboxRouteResolved(:final app) => onResolved(app),
        };
      },
    );
  }
}

class _ResolvingAppScreen extends StatelessWidget {
  const _ResolvingAppScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.appsSandboxLoadingTitle,
        showBackButton: true,
        // These routes are reachable by direct URL, where the matched stack
        // has a single entry and a raw pop throws GoError (#6112).
        onBackPressed: () =>
            context.safePop(fallback: AppsDirectoryScreen.path),
      ),
      backgroundColor: context.vineColors.background,
      body: const Center(child: DivineCircularProgressIndicator()),
    );
  }
}
