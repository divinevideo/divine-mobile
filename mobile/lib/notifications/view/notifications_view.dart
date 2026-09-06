// ABOUTME: BLoC-driven notifications list view with scroll pagination,
// ABOUTME: pull-to-refresh, date headers, and navigation to videos/profiles.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/blocs/video_engagement/video_engagement_bloc.dart'
    show VideoEngagementType;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/notifications/bloc/notification_feed_bloc.dart';
import 'package:openvine/notifications/routing/avatar_stack_tap_target.dart';
import 'package:openvine/notifications/routing/notification_tap_target.dart';
import 'package:openvine/notifications/widgets/widgets.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/curated_list_by_author_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/screens/video_engagement/video_engagement_list_screen.dart';
import 'package:openvine/services/notification_target_resolver.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:unified_logger/unified_logger.dart';

/// The notification list UI.
///
/// Reads state from [NotificationFeedBloc] and renders notification items
/// with date headers, scroll pagination, and pull-to-refresh.
@visibleForTesting
class NotificationsView extends ConsumerStatefulWidget {
  /// Creates a [NotificationsView].
  const NotificationsView({super.key});

  @override
  ConsumerState<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends ConsumerState<NotificationsView> {
  final ScrollController _scrollController = ScrollController();

  /// Threshold (in pixels from bottom) to trigger load-more.
  static const _loadMoreThreshold = 200.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll - currentScroll <= _loadMoreThreshold) {
      context.read<NotificationFeedBloc>().add(
        const NotificationFeedLoadMore(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.vineColors.surfaceContainerHigh,
      child: BlocBuilder<NotificationFeedBloc, NotificationFeedState>(
        builder: (context, state) {
          // Hard failure path. The bloc gates `failure` on
          // `notifications.isEmpty`, so we only land here when the cache
          // is also empty.
          if (state.status == NotificationFeedStatus.failure) {
            return _FailureBody(
              onRetry: () => context.read<NotificationFeedBloc>().add(
                const NotificationFeedRefreshed(),
              ),
            );
          }

          // Cached or freshly-loaded items present → render the list
          // immediately (stale-while-revalidate). A thin revalidation bar
          // overlays the top while a network refresh is in flight, so a
          // background refresh never blanks the cached list. The inline
          // refresh-error banner handles the soft-failure affordance via
          // `state.refreshError`.
          if (state.notifications.isNotEmpty) {
            return Stack(
              children: [
                RefreshIndicator(
                  color: VineTheme.onPrimary,
                  backgroundColor: VineTheme.vineGreen,
                  onRefresh: () async {
                    context.read<NotificationFeedBloc>().add(
                      const NotificationFeedRefreshed(),
                    );
                  },
                  child: _NotificationList(
                    notifications: state.notifications,
                    isLoadingMore: state.isLoadingMore,
                    hasMore: state.hasMore,
                    scrollController: _scrollController,
                    showRefreshErrorBanner: state.refreshError,
                    onRetryRefresh: () => context
                        .read<NotificationFeedBloc>()
                        .add(const NotificationFeedRefreshed()),
                    onItemTap: (notification) =>
                        _onItemTap(context, notification),
                    onAvatarStackTap: (notification) =>
                        _onAvatarStackTap(context, notification),
                    onFollowBack: (pubkey) => context
                        .read<NotificationFeedBloc>()
                        .add(NotificationFeedFollowBack(pubkey)),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _RevalidationBar(visible: state.isRefreshing),
                ),
              ],
            );
          }

          // Empty + cold start → full-screen spinner. This is the only
          // remaining full-screen spinner, gated on the `initial` status
          // alone: once the feed has loaded, an empty inbox keeps its empty
          // state during a manual refresh (with the thin revalidation bar as
          // the non-blocking in-flight affordance) instead of blinking back
          // to a spinner. Cold start keeps `status == initial` until the
          // first refresh resolves, so this still covers the empty-cache
          // launch.
          if (state.status == NotificationFeedStatus.initial) {
            return const Center(
              child: DivineCircularProgressIndicator(
                color: VineTheme.vineGreen,
              ),
            );
          }

          // Empty + loaded → empty state with pull-to-refresh. The
          // revalidation bar overlays the top while a refresh is in flight so
          // a slow or hanging refresh keeps a visible non-blocking affordance:
          // the empty state has no RefreshIndicator spinner of its own once
          // `onRefresh` returns.
          return Stack(
            children: [
              RefreshIndicator(
                color: VineTheme.onPrimary,
                backgroundColor: VineTheme.vineGreen,
                onRefresh: () async {
                  context.read<NotificationFeedBloc>().add(
                    const NotificationFeedRefreshed(),
                  );
                },
                child: _ScrollableEmptyState(controller: _scrollController),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _RevalidationBar(visible: state.isRefreshing),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _onItemTap(
    BuildContext context,
    NotificationItem notification,
  ) async {
    // Mark as read.
    context.read<NotificationFeedBloc>().add(
      NotificationFeedItemTapped(notification.id),
    );

    // Route the kind -> destination decision through the shared contract so
    // the in-app, push, and local tap paths share one target-selection policy.
    // The executors (here vs main.dart) still keep their own navigation
    // mechanics after that decision is made.
    switch (notification) {
      case VideoNotification(
        :final videoEventId,
        :final videoAddressableId,
        :final type,
        :final listCoordinate,
      ):
        final target = resolveNotificationTapTarget(
          kind: type,
          hasVideoTarget: true,
          listCoordinate: listCoordinate,
        );
        switch (target) {
          case OpenListTarget(:final pubkey, :final listId):
            _navigateToList(context, pubkey: pubkey, listId: listId);
          case OpenVideoTarget():
            await _navigateToVideo(
              context,
              videoEventId,
              videoAddressableId: videoAddressableId,
              notificationKind: type,
            );
          case OpenProfileTarget(:final actorPubkey):
            // Exhaustiveness-only: VideoNotification currently resolves to
            // OpenVideoTarget or OpenListTarget because it carries a video or
            // list target.
            _navigateToProfile(context, actorPubkey);
          case OpenInboxTarget():
            // Exhaustiveness-only: VideoNotification currently resolves to
            // OpenVideoTarget or OpenListTarget because it carries a video or
            // list target.
            break;
        }
      case ActorNotification(
        :final actor,
        :final type,
        :final targetEventId,
        :final videoAddressableId,
        :final hasCommentTarget,
      ):
        final hasVideoTarget =
            targetEventId != null && targetEventId.isNotEmpty;
        final target = resolveNotificationTapTarget(
          kind: type,
          hasVideoTarget: hasVideoTarget,
          hasCommentTarget: hasCommentTarget,
          actorPubkey: actor.pubkey,
        );
        switch (target) {
          case OpenListTarget(:final pubkey, :final listId):
            _navigateToList(context, pubkey: pubkey, listId: listId);
          case OpenVideoTarget():
            // targetEventId is the event the resolver walks to find the root
            // video. Any comment/reply/likeComment/mention whose root video
            // can't be resolved falls back to the actor's profile, mirroring
            // the push executor's #5079 fallback contract
            // (main.dart:_resolveAndPushVideoLink) so the tap never silently
            // dead-ends regardless of kind.
            final navigated = await _navigateToVideo(
              context,
              targetEventId!,
              videoAddressableId: videoAddressableId,
              notificationKind: type,
              hasCommentTarget: hasCommentTarget,
              resolveTargetToVideo: true,
            );
            if (!navigated && context.mounted) {
              Log.warning(
                'Notification tap could not resolve a video '
                '(kind=$type, targetEventId=$targetEventId) — '
                'falling back to actor profile',
                name: 'NotificationsView',
                category: LogCategory.ui,
              );
              _navigateToProfile(context, actor.pubkey);
            }
          case OpenProfileTarget(:final actorPubkey):
            _navigateToProfile(context, actorPubkey);
          case OpenInboxTarget():
            break;
        }
    }
  }

  void _onAvatarStackTap(BuildContext context, NotificationItem notification) {
    final target = resolveAvatarStackTapTarget(notification);
    switch (target) {
      case OpenEngagementListTarget(
        :final eventId,
        :final addressableId,
        :final type,
      ):
        _navigateToEngagementList(
          context,
          eventId: eventId,
          addressableId: addressableId,
          type: type,
        );
      case OpenActorProfileTarget(:final pubkey):
        _navigateToProfile(context, pubkey);
      case null:
        break;
    }
  }

  void _navigateToEngagementList(
    BuildContext context, {
    required String eventId,
    required String? addressableId,
    required VideoEngagementType type,
  }) {
    final routeName = switch (type) {
      VideoEngagementType.likers => VideoEngagementListScreen.likersRouteName,
      VideoEngagementType.reposters =>
        VideoEngagementListScreen.repostersRouteName,
    };
    context.pushNamed(
      routeName,
      pathParameters: {'eventId': eventId},
      queryParameters: addressableId == null ? const {} : {'a': addressableId},
    );
  }

  void _navigateToList(
    BuildContext context, {
    required String pubkey,
    required String listId,
  }) {
    context.push(
      CuratedListByAuthorScreen.pathFor(pubkey: pubkey, listId: listId),
    );
  }

  /// Resolves the video route and pushes [VideoDetailScreen].
  ///
  /// Returns `true` if a navigation was pushed, `false` if resolution failed
  /// (resolver returned null) and no navigation occurred. The caller decides
  /// what to do on `false`, such as falling back to the actor profile for
  /// unresolvable comment-opening notifications.
  ///
  /// This uses the durable `/video/<id>` route rather than the ephemeral
  /// fullscreen feed route, so web builds do not depend on in-memory
  /// GoRouter `extra` state to show the target video.
  Future<bool> _navigateToVideo(
    BuildContext context,
    String videoEventId, {
    String? videoAddressableId,
    NotificationKind? notificationKind,
    bool hasCommentTarget = false,
    bool resolveTargetToVideo = false,
  }) async {
    Log.info(
      'Navigating to video from notification: '
      'addressable=$videoAddressableId eventId=$videoEventId',
      name: 'NotificationsView',
      category: LogCategory.ui,
    );

    final videoEventService = ref.read(videoEventServiceProvider);
    final shouldAutoOpenComments = notificationKindOpensComments(
      notificationKind,
      hasCommentTarget: hasCommentTarget,
    );

    // Resolve the navigation target.
    //
    // The stable-ID path (videoAddressableId set) and raw-event-id fallback
    // are synchronous. Comment/reply/likeComment/mention targets without an
    // addressable coordinate may be Kind 1111 comments, so resolve them to the
    // root video before pushing the durable video route.
    String? routeId;
    var fallbackVideoIds = const <String>[];
    if (videoAddressableId != null && videoAddressableId.isNotEmpty) {
      // Stable path: addressable ID works even after a metadata update.
      routeId = videoAddressableId;
      if (videoEventId.isNotEmpty && videoEventId != videoAddressableId) {
        fallbackVideoIds = [videoEventId];
      }
    } else if (resolveTargetToVideo) {
      // Actor notification path: walk E/e/A tags to find the root video event
      // ID. Auto-opening comments is a separate presentation choice; plain
      // mentions still need this resolution so unresolvable note mentions can
      // fall back to the actor profile instead of routing to /video/<note-id>.
      routeId = await NotificationTargetResolver(
        videoEventService: videoEventService,
        nostrService: ref.read(nostrServiceProvider),
      ).resolveVideoEventIdFromNotificationTarget(videoEventId);

      if (!context.mounted) return false;
      if (routeId == null) {
        // Resolution failed — caller decides the fallback (e.g. profile).
        return false;
      }
    } else {
      // Fallback: no addressable ID available, use raw event ID.
      routeId = videoEventId;
    }

    if (!context.mounted) return false;

    context.push(
      VideoDetailScreen.pathForId(routeId),
      extra: shouldAutoOpenComments || fallbackVideoIds.isNotEmpty
          ? VideoDetailRouteExtra(
              autoOpenComments: shouldAutoOpenComments,
              fallbackVideoIds: fallbackVideoIds,
            )
          : null,
    );
    return true;
  }

  void _navigateToProfile(BuildContext context, String userPubkey) {
    Log.info(
      'Navigating to profile: ${pubkeyForLogs(userPubkey)}',
      name: 'NotificationsView',
      category: LogCategory.ui,
    );

    final npub = NostrKeyUtils.encodePubKey(userPubkey);
    context.push(OtherProfileScreen.pathForNpub(npub));
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

/// Thin background-refresh bar overlaid at the top of the cached list while
/// a network revalidation is in flight (stale-while-revalidate).
///
/// Fades and slides (size) in/out as [visible] toggles so the bar never
/// pops abruptly. Purely decorative — the cached list is already on screen —
/// so it stays out of the semantics tree. Mirrors `ProfileCacheLoadIndicator`.
class _RevalidationBar extends StatelessWidget {
  const _RevalidationBar({required this.visible});

  /// Whether a network revalidation is currently in flight.
  final bool visible;

  static const double _height = 4;
  static const _transitionDuration = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    // Honour the reduced-motion preference — collapse the animation to an
    // instant swap rather than dropping the affordance entirely.
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _transitionDuration;

    // RepaintBoundary isolates the indeterminate progress animation's
    // per-frame repaint from the cached list it overlays. Without it the
    // bar's continuous `markNeedsPaint` propagates up to the enclosing
    // Stack and re-runs the list pane's paint every frame for the entire
    // refresh — the open-jank reported after stale-while-revalidate landed.
    return RepaintBoundary(
      child: ExcludeSemantics(
        child: AnimatedSwitcher(
          duration: duration,
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: visible
              ? const SizedBox(
                  key: ValueKey('revalidation-bar'),
                  height: _height,
                  child: DivineLinearProgressIndicator(
                    minHeight: _height,
                    color: VineTheme.vineGreen,
                    backgroundColor: VineTheme.transparent,
                  ),
                )
              : const SizedBox(key: ValueKey('revalidation-bar-hidden')),
        ),
      ),
    );
  }
}

class _ScrollableEmptyState extends StatelessWidget {
  const _ScrollableEmptyState({required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: const NotificationEmptyState(),
        ),
      ),
    );
  }
}

class _FailureBody extends StatelessWidget {
  const _FailureBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DivineIcon(
            icon: DivineIconName.warningCircle,
            size: 64,
            color: context.vineColors.mutedText,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.notificationsFailedToLoad,
            style: VineTheme.bodyLargeFont(
              color: context.vineColors.secondaryText,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: Text(
              context.l10n.notificationsRetry,
              style: VineTheme.labelLargeFont(color: VineTheme.vineGreen),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationList extends StatelessWidget {
  const _NotificationList({
    required this.notifications,
    required this.isLoadingMore,
    required this.hasMore,
    required this.scrollController,
    required this.onItemTap,
    required this.onAvatarStackTap,
    required this.onFollowBack,
    required this.showRefreshErrorBanner,
    required this.onRetryRefresh,
  });

  final List<NotificationItem> notifications;
  final bool isLoadingMore;
  final bool hasMore;
  final ScrollController scrollController;
  final void Function(NotificationItem notification) onItemTap;

  /// Called when the row's avatar stack is tapped. Resolves to the engagement
  /// list for grouped like/repost rows and to a profile otherwise, so this is
  /// deliberately not named `onProfileTap`.
  final void Function(NotificationItem notification) onAvatarStackTap;
  final void Function(String pubkey) onFollowBack;

  /// When `true`, renders [_RefreshErrorBanner] as the list's first item so
  /// users see the cached snapshot together with a "couldn't refresh"
  /// affordance instead of a Retry-only blackout.
  final bool showRefreshErrorBanner;

  /// Callback fired by the banner's Retry button. Dispatches the same
  /// `NotificationFeedRefreshed` event the pull-to-refresh handler uses.
  final VoidCallback onRetryRefresh;

  @override
  Widget build(BuildContext context) {
    final bannerOffset = showRefreshErrorBanner ? 1 : 0;
    final itemCount =
        bannerOffset +
        notifications.length +
        (isLoadingMore && hasMore ? 1 : 0);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      controller: scrollController,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (showRefreshErrorBanner && index == 0) {
          return _RefreshErrorBanner(onRetry: onRetryRefresh);
        }
        final dataIndex = index - bannerOffset;

        // Loading indicator at bottom.
        if (dataIndex >= notifications.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: DivineCircularProgressIndicator(
                color: VineTheme.vineGreen,
              ),
            ),
          );
        }

        final notification = notifications[dataIndex];
        final showDateHeader = _shouldShowDateHeader(dataIndex);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDateHeader)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  LocalizedTimeFormatter.formatDateLabel(
                    context.l10n,
                    notification.timestamp.millisecondsSinceEpoch ~/ 1000,
                    locale: Localizations.localeOf(context).toLanguageTag(),
                  ),
                  style: VineTheme.labelLargeFont(
                    color: context.vineColors.onSurfaceMuted,
                  ),
                ),
              ),
            NotificationListItem(
              notification: notification,
              onTap: () => onItemTap(notification),
              onProfileTap: () => onAvatarStackTap(notification),
              onFollowBack: () {
                final pubkey = _profilePubkey(notification);
                if (pubkey != null) onFollowBack(pubkey);
              },
            ),
          ],
        );
      },
    );
  }

  bool _shouldShowDateHeader(int index) {
    if (index == 0) return true;

    final current = notifications[index];
    final previous = notifications[index - 1];

    final currentLocal = current.timestamp.toLocal();
    final currentDate = DateTime(
      currentLocal.year,
      currentLocal.month,
      currentLocal.day,
    );

    final previousLocal = previous.timestamp.toLocal();
    final previousDate = DateTime(
      previousLocal.year,
      previousLocal.month,
      previousLocal.day,
    );

    return currentDate != previousDate;
  }

  /// Extracts the primary actor pubkey from a notification.
  String? _profilePubkey(NotificationItem notification) {
    return switch (notification) {
      VideoNotification(:final actors) =>
        actors.isNotEmpty ? actors.first.pubkey : null,
      ActorNotification(:final actor) => actor.pubkey,
    };
  }
}

class _RefreshErrorBanner extends StatelessWidget {
  const _RefreshErrorBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.vineColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              DivineIcon(
                icon: DivineIconName.warningCircle,
                size: 20,
                color: context.vineColors.mutedText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.notificationsRefreshError,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.secondaryText,
                  ),
                ),
              ),
              TextButton(
                onPressed: onRetry,
                child: Text(
                  // Reuse the already-translated `notificationsRetry` key
                  // so the refresh-error banner ships in every locale
                  // without adding a duplicate English-only key.
                  context.l10n.notificationsRetry,
                  style: VineTheme.labelLargeFont(color: VineTheme.vineGreen),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
