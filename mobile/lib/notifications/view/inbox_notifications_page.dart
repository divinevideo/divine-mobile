// ABOUTME: Inbox notifications scaffold — six filter tabs plus actionable
// ABOUTME: invite and pending-badge banners wrapping NotificationsView.

import 'package:badge_repository/badge_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/blocs/badges/badges_cubit.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/reduced_motion_tab_controller_mixin.dart';
import 'package:openvine/notifications/bloc/notification_feed_bloc.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/notifications/view/notifications_view.dart';
import 'package:openvine/notifications/view/pending_badge_awards_view.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/settings/invites_screen.dart';
import 'package:openvine/widgets/signup_invites_availability_builder.dart';

/// Inbox notifications page — owns the BLoC and tab scaffold.
///
/// Wraps [NotificationsView] with the six-tab UI (All / Likes / Comments /
/// Follows / Reposts / Badges) and actionable banners shown on the All tab.
/// Each notification tab owns a feed BLoC with independent pagination.
class InboxNotificationsPage extends ConsumerWidget {
  /// Creates an [InboxNotificationsPage].
  const InboxNotificationsPage({this.isVisible = true, super.key});

  /// Whether the kept-alive inbox notifications pane is currently visible.
  final bool isVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationRepository = ref.watch(notificationRepositoryProvider);
    if (notificationRepository == null) {
      return ColoredBox(
        color: context.vineColors.background,
        child: const Center(
          child: DivineCircularProgressIndicator(color: VineTheme.vineGreen),
        ),
      );
    }
    final followRepository = ref.watch(followRepositoryProvider);
    final badgeRepository = ref.watch(badgeRepositoryProvider);

    return _InboxNotificationsScaffold(
      notificationRepository: notificationRepository,
      followRepository: followRepository,
      badgeRepository: badgeRepository,
      isVisible: isVisible,
    );
  }
}

const int _inboxTabCount = 6;

/// Position of the Badges tab, last after the reaction filters.
const int _badgesTabIndex = _inboxTabCount - 1;

class _InboxNotificationsScaffold extends StatefulWidget {
  const _InboxNotificationsScaffold({
    required this.notificationRepository,
    required this.followRepository,
    required this.badgeRepository,
    required this.isVisible,
  });

  final NotificationRepository notificationRepository;
  final FollowRepository followRepository;
  final BadgeRepository badgeRepository;
  final bool isVisible;

  @override
  State<_InboxNotificationsScaffold> createState() =>
      _InboxNotificationsScaffoldState();
}

class _InboxNotificationsScaffoldState
    extends State<_InboxNotificationsScaffold>
    with TickerProviderStateMixin, ReducedMotionTabControllerMixin {
  @override
  int get tabCount => _inboxTabCount;

  /// Owned here rather than by a keyed `BlocProvider` so a repository swap
  /// rebuilds the badge subtree only. Keying a provider above the tabs would
  /// also tear down every notification feed and reset the open tab.
  late BadgesCubit _badgesCubit;

  @override
  void initState() {
    super.initState();
    _badgesCubit = BadgesCubit(repository: widget.badgeRepository)..load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<InviteStatusCubit>().load();
    });
  }

  @override
  void didUpdateWidget(_InboxNotificationsScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.badgeRepository != oldWidget.badgeRepository) {
      // Keep the old cubit alive through the rebuild while descendants rebind.
      // See PR #8046.
      final previous = _badgesCubit;
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.close());
      setState(() {
        _badgesCubit = BadgesCubit(repository: widget.badgeRepository)..load();
      });
      return;
    }

    if (!oldWidget.isVisible && widget.isVisible) {
      final cubit = _badgesCubit;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !identical(_badgesCubit, cubit)) return;
        cubit.refresh();
      });
    }
  }

  @override
  void dispose() {
    _badgesCubit.close();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncTabController();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(VineTheme.shellInnerCornerRadius),
      ),
      child: ColoredBox(
        color: context.vineColors.surfaceContainerHigh,
        // One cubit for the tab label's pending count, the All-tab banner, and
        // the Badges tab body, so accepting an award updates all three.
        child: BlocProvider<BadgesCubit>.value(
          value: _badgesCubit,
          child: Column(
            children: [
              const SizedBox(height: 12),
              _InboxTabBar(controller: tabController),
              Expanded(
                child: TabBarView(
                  controller: tabController,
                  children: [
                    _NotificationTab(
                      notificationRepository: widget.notificationRepository,
                      followRepository: widget.followRepository,
                      isVisible: widget.isVisible,
                      child: Column(
                        children: [
                          const _InvitesBanner(),
                          _PendingBadgesBanner(
                            onViewPending: () =>
                                tabController.animateTo(_badgesTabIndex),
                          ),
                          const Expanded(child: NotificationsView()),
                        ],
                      ),
                    ),
                    _NotificationTab(
                      notificationRepository: widget.notificationRepository,
                      followRepository: widget.followRepository,
                      isVisible: widget.isVisible,
                      filter: NotificationKind.like,
                    ),
                    _NotificationTab(
                      notificationRepository: widget.notificationRepository,
                      followRepository: widget.followRepository,
                      isVisible: widget.isVisible,
                      filter: NotificationKind.comment,
                    ),
                    _NotificationTab(
                      notificationRepository: widget.notificationRepository,
                      followRepository: widget.followRepository,
                      isVisible: widget.isVisible,
                      filter: NotificationKind.follow,
                    ),
                    _NotificationTab(
                      notificationRepository: widget.notificationRepository,
                      followRepository: widget.followRepository,
                      isVisible: widget.isVisible,
                      filter: NotificationKind.repost,
                    ),
                    const PendingBadgeAwardsView(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTab extends ConsumerStatefulWidget {
  const _NotificationTab({
    required this.notificationRepository,
    required this.followRepository,
    required this.isVisible,
    this.filter,
    this.child = const NotificationsView(),
  });

  final NotificationRepository notificationRepository;
  final FollowRepository followRepository;
  final bool isVisible;
  final NotificationKind? filter;
  final Widget child;

  @override
  ConsumerState<_NotificationTab> createState() => _NotificationTabState();
}

class _NotificationTabState extends ConsumerState<_NotificationTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final appBadgeClearer = ref.watch(appBadgeServiceProvider);
    // Key on the watched dependency identities plus filter so each tab's bloc
    // rebuilds when repositories swap and keeps an independent pagination
    // stream for its server-side category.
    return BlocProvider(
      key: ValueKey((
        widget.notificationRepository,
        widget.followRepository,
        widget.filter,
      )),
      create: (_) => NotificationFeedBloc(
        notificationRepository: widget.notificationRepository,
        followRepository: widget.followRepository,
        appBadgeClearer: appBadgeClearer,
        filter: widget.filter,
      )..add(const NotificationFeedStarted()),
      child: _NotificationVisibilityDispatcher(
        isVisible: widget.isVisible,
        child: widget.child,
      ),
    );
  }
}

class _NotificationVisibilityDispatcher extends StatefulWidget {
  const _NotificationVisibilityDispatcher({
    required this.isVisible,
    required this.child,
  });

  final bool isVisible;
  final Widget child;

  @override
  State<_NotificationVisibilityDispatcher> createState() =>
      _NotificationVisibilityDispatcherState();
}

class _NotificationVisibilityDispatcherState
    extends State<_NotificationVisibilityDispatcher> {
  bool? _wasVisible;

  void _observeVisibility() {
    final visible = widget.isVisible;
    final wasVisible = _wasVisible;
    _wasVisible = visible;
    if (wasVisible == false && visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<NotificationFeedBloc>().add(
          const NotificationFeedBecameVisible(),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _observeVisibility();
    return widget.child;
  }
}

/// Inbox filter tabs, built inside the badges cubit's subtree so the Badges
/// label can carry its pending count.
class _InboxTabBar extends StatelessWidget {
  const _InboxTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final pendingBadges = context.select(
      (BadgesCubit cubit) => cubit.state.pending.length,
    );
    // Material is required for the TabBar ink splash.
    return Material(
      type: MaterialType.transparency,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsetsDirectional.only(start: 16),
        indicatorColor: VineTheme.tabIndicatorGreen,
        indicatorWeight: 4,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: VineTheme.transparent,
        labelColor: context.vineColors.primaryText,
        unselectedLabelColor: context.vineColors.onSurfaceMuted,
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        labelStyle: VineTheme.titleMediumFont(
          color: context.vineColors.primaryText,
        ),
        unselectedLabelStyle: VineTheme.titleMediumFont(
          color: context.vineColors.onSurfaceMuted,
        ),
        tabs: [
          Tab(text: context.l10n.notificationsTabAll),
          Tab(text: context.l10n.notificationsTabLikes),
          Tab(text: context.l10n.notificationsTabComments),
          Tab(text: context.l10n.notificationsTabFollows),
          Tab(text: context.l10n.notificationsTabReposts),
          Tab(text: context.l10n.notificationsTabBadges(pendingBadges)),
        ],
      ),
    );
  }
}

/// Points at waiting badge awards from the All tab.
class _PendingBadgesBanner extends StatelessWidget {
  const _PendingBadgesBanner({required this.onViewPending});

  final VoidCallback onViewPending;

  @override
  Widget build(BuildContext context) {
    final pendingCount = context.select(
      (BadgesCubit cubit) => cubit.state.pending.length,
    );
    if (pendingCount == 0) return const SizedBox.shrink();

    return _InboxBanner(
      icon: DivineIconName.sealCheck,
      label: context.l10n.notificationsPendingBadges(pendingCount),
      onTap: onViewPending,
    );
  }
}

class _InvitesBanner extends StatelessWidget {
  const _InvitesBanner();

  @override
  Widget build(BuildContext context) {
    return SignupInvitesAvailabilityBuilder(
      builder: (context, availability) {
        if (!availability.isEnabled) return const SizedBox.shrink();
        return BlocBuilder<InviteStatusCubit, InviteStatusState>(
          builder: (context, state) {
            if (!state.hasAvailableInvites) return const SizedBox.shrink();
            return _InviteNotificationCard(count: state.availableInviteCount);
          },
        );
      },
    );
  }
}

class _InviteNotificationCard extends StatelessWidget {
  const _InviteNotificationCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count == 1
        ? context.l10n.notificationsInviteSingular
        : context.l10n.notificationsInvitePlural(count);
    return _InboxBanner(
      icon: DivineIconName.shareNetwork,
      label: label,
      onTap: () => context.push(InvitesScreen.path),
    );
  }
}

/// Shared actionable banner chrome for the All tab.
class _InboxBanner extends StatelessWidget {
  const _InboxBanner({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final DivineIconName icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The card color belongs to Material so the InkWell splash paints above it.
    return Material(
      color: context.vineColors.card,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            spacing: 12,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: VineTheme.vineGreen,
                  shape: BoxShape.circle,
                ),
                child: DivineIcon(
                  icon: icon,
                  color: context.vineColors.background,
                ),
              ),
              Expanded(
                child: Text(
                  label,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ),
              DivineIcon(
                icon: DivineIconName.caretRight,
                color: context.vineColors.mutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
