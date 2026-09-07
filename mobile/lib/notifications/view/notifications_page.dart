// ABOUTME: ConsumerWidget page that provides NotificationFeedBloc to the
// ABOUTME: notifications view. Bridges Riverpod dependencies into BLoC.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/notifications/bloc/notification_feed_bloc.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/notifications/view/notifications_view.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_paths.dart';

/// Top-level page for the notifications tab.
///
/// Reads dependencies from Riverpod, creates [NotificationFeedBloc], and
/// provides it to [NotificationsView]. The bloc dispatches
/// `NotificationFeedStarted` on mount, which triggers `repository.refresh()`.
/// The resulting snapshot flows through the repository's snapshot stream and
/// propagates to the badge cubit automatically. Opening the page advances the
/// seen watermark; per-item taps still mark individual rows read when needed.
class NotificationsPage extends ConsumerWidget {
  /// Creates a [NotificationsPage].
  const NotificationsPage({super.key});

  /// Route name for this screen.
  static const routeName = 'notifications';

  /// Path for this route.
  static const String path = RoutePaths.notifications;

  /// Path for this route with index.
  static const pathWithIndex = '/notifications/:index';

  /// Build path for a specific index.
  static String pathForIndex([int? index]) =>
      RoutePaths.notificationsForIndex(index);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationRepository = ref.watch(notificationRepositoryProvider);

    // Dependencies not yet available (e.g. ProfileRepository during auth).
    if (notificationRepository == null) {
      return ColoredBox(
        color: context.vineColors.background,
        child: const Center(
          child: DivineCircularProgressIndicator(color: VineTheme.vineGreen),
        ),
      );
    }

    final followRepository = ref.watch(followRepositoryProvider);
    final appBadgeClearer = ref.watch(appBadgeServiceProvider);

    // Key on the watched dependency identities so the bloc rebuilds when
    // either repository swaps (account switch, sign-out → sign-in, or
    // provider invalidation). Without this the BlocProvider element
    // persists across rebuilds and keeps the bloc bound to stale
    // repositories — i.e. the previous user's notifications.
    // See `.claude/rules/state_management.md`.
    return BlocProvider(
      key: ValueKey((notificationRepository, followRepository)),
      create: (_) => NotificationFeedBloc(
        notificationRepository: notificationRepository,
        followRepository: followRepository,
        appBadgeClearer: appBadgeClearer,
      )..add(const NotificationFeedStarted()),
      child: const NotificationsView(),
    );
  }
}
