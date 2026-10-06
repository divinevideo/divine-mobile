// ABOUTME: Badge detail page: badge artwork, accepted holders, and their videos.
// ABOUTME: Owners can also award, edit, and revoke from this page.

import 'dart:async';

import 'package:badge_repository/badge_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/badges/badge_detail_cubit.dart';
import 'package:openvine/blocs/badges/badge_holders_cubit.dart';
import 'package:openvine/blocs/badges/badge_videos_cubit.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/feed_repository_provider.dart';
import 'package:openvine/screens/badges/badge_award_screen.dart';
import 'package:openvine/screens/badges/badge_delete_confirmation_sheet.dart';
import 'package:openvine/screens/badges/badge_editor_screen.dart';
import 'package:openvine/screens/badges/badge_revoke_confirmation_sheet.dart';
import 'package:openvine/screens/badges/badges_screen.dart';
import 'package:openvine/screens/badges/widgets/badge_recipient_row.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/share_sheet.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/user_profile_tile.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:unified_logger/unified_logger.dart';

/// Shows one badge, its awardees, and the actions available on it.
class BadgeDetailScreen extends ConsumerWidget {
  /// Route name used by GoRouter.
  static const routeName = 'badgeDetail';

  /// Route path used by GoRouter.
  static const path = '/badges/b/:naddr';

  /// Path that opens the detail page for [coordinate].
  static String pathFor(BadgeCoordinate coordinate) =>
      '/badges/b/${coordinate.toNaddr()}';

  /// Creates the badge detail screen.
  const BadgeDetailScreen({required this.coordinate, super.key});

  /// Address of the badge being shown.
  final BadgeCoordinate coordinate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(badgeRepositoryProvider);
    final contentBlocklistRepository = ref.watch(
      contentBlocklistRepositoryProvider,
    );
    return BlocProvider(
      key: ValueKey((repository, coordinate)),
      create: (_) {
        final cubit = BadgeDetailCubit(
          repository: repository,
          contentBlocklistRepository: contentBlocklistRepository,
          coordinate: coordinate,
        );
        runDetached(
          cubit.load(),
          'load badge detail',
          logName: 'BadgeDetailScreen',
          category: LogCategory.ui,
        );
        return cubit;
      },
      child: const BadgeDetailView(),
    );
  }
}

/// Body of [BadgeDetailScreen].
class BadgeDetailView extends StatelessWidget {
  /// Creates the badge detail view.
  @visibleForTesting
  const BadgeDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<BadgeDetailCubit, BadgeDetailState>(
      listenWhen: (previous, current) =>
          previous.actionStatus != current.actionStatus,
      listener: (context, state) {
        // Nothing left to render once the badge is gone.
        if (state.actionStatus == BadgeDetailActionStatus.deleted) {
          // A shared badge link opens this screen with nothing beneath it, so
          // popping is not always available; the dashboard is the way out.
          context.safePop(result: true, fallback: BadgesScreen.path);
          return;
        }
        // Announced rather than left to the row disappearing: to a screen
        // reader a row that is simply gone is no feedback at all.
        if (state.actionStatus == BadgeDetailActionStatus.revoked) {
          final message = l10n.badgeDetailRevokeSuccess;
          runDetached(
            SemanticsService.sendAnnouncement(
              View.of(context),
              message,
              Directionality.of(context),
            ),
            'announce badge revocation',
            logName: 'BadgeDetailScreen',
            category: LogCategory.ui,
          );
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(DivineSnackbarContainer.snackBar(message));
          return;
        }
        if (state.actionStatus == BadgeDetailActionStatus.deleteRejected) {
          // Same refusal, same advice as a refused video delete, so the
          // shared string is reused rather than translated twice.
          ScaffoldMessenger.of(context).showSnackBar(
            DivineSnackbarContainer.snackBar(
              l10n.shareMenuDeleteFailedRelayRejected,
              error: true,
            ),
          );
        }
      },
      builder: (context, state) {
        final detail = state.detail;
        final definition = detail?.definition;
        return Scaffold(
          appBar: DiVineAppBar(
            title: definition?.name ?? l10n.badgeDetailTitle,
            showBackButton: true,
            onBackPressed: () => context.safePop(fallback: BadgesScreen.path),
            actions: [
              DiVineAppBarAction(
                icon: SvgIconSource(DivineIconName.shareNetwork.assetPath),
                tooltip: l10n.badgeDetailShareAction,
                semanticLabel: l10n.badgeDetailShareAction,
                onPressed: () => _share(context, state.coordinate),
              ),
              if (detail?.isOwner ?? false) ...[
                DiVineAppBarAction(
                  icon: SvgIconSource(DivineIconName.pencilSimple.assetPath),
                  tooltip: l10n.badgeDetailEditAction,
                  semanticLabel: l10n.badgeDetailEditAction,
                  onPressed: () => _openEditor(context, state.coordinate),
                ),
                DiVineAppBarAction(
                  icon: SvgIconSource(DivineIconName.trashSimple.assetPath),
                  tooltip: l10n.badgeDetailDeleteAction,
                  semanticLabel: l10n.badgeDetailDeleteAction,
                  iconColor: VineTheme.error,
                  onPressed: state.isBusy ? null : () => _delete(context),
                ),
              ],
            ],
          ),
          backgroundColor: context.vineColors.background,
          body: switch (state.status) {
            BadgeDetailStatus.initial || BadgeDetailStatus.loading =>
              const Center(child: BrandedLoadingIndicator(size: 60)),
            BadgeDetailStatus.failure => _DetailMessage(
              message: l10n.badgeDetailLoadError,
              onRetry: () => context.read<BadgeDetailCubit>().load(),
            ),
            BadgeDetailStatus.loaded => _BadgeDetailBody(state: state),
          },
        );
      },
    );
  }

  static Future<void> _share(
    BuildContext context,
    BadgeCoordinate coordinate,
  ) async {
    final message = context.l10n.badgeDetailShareMessage(
      'https://badges.divine.video/b/${coordinate.toNaddr()}',
    );
    await showShareSheet(context, ShareParams(text: message));
  }

  static Future<void> _delete(BuildContext context) async {
    final cubit = context.read<BadgeDetailCubit>();
    final confirmed = await showBadgeDeleteConfirmation(context);
    if (confirmed ?? false) await cubit.deleteBadge();
  }

  static Future<void> _openEditor(
    BuildContext context,
    BadgeCoordinate coordinate,
  ) async {
    final cubit = context.read<BadgeDetailCubit>();
    await context.push<bool>(BadgeEditorScreen.editPathFor(coordinate));
    if (cubit.isClosed) return;
    await cubit.refresh();
  }
}

class _BadgeDetailBody extends StatelessWidget {
  const _BadgeDetailBody({required this.state});

  final BadgeDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final detail = state.detail!;
    return RefreshIndicator(
      color: VineTheme.onPrimary,
      backgroundColor: VineTheme.vineGreen,
      onRefresh: () => context.read<BadgeDetailCubit>().refresh(),
      // Constrains and centres the viewport itself; a sliver has no
      // max-width equivalent.
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  32 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 20,
                        children: [
                          _BadgeHero(
                            detail: detail,
                            coordinate: state.coordinate,
                          ),
                          if (state.isMissing)
                            Text(
                              l10n.badgeDetailMissing,
                              style: VineTheme.bodySmallFont(
                                color: context.vineColors.onSurfaceVariant,
                              ),
                            ),
                          if (state.actionStatus ==
                              BadgeDetailActionStatus.failure)
                            Text(
                              l10n.badgeDetailActionError,
                              style: VineTheme.bodySmallFont(
                                color: VineTheme.error,
                              ),
                            ),
                          _BadgeActions(state: state),
                        ],
                      ),
                    ),
                    _AcceptedHolders(
                      key: ObjectKey(detail),
                      coordinate: state.coordinate,
                    ),
                    if (!detail.isOwner)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: DivineButton(
                              label: l10n.badgeDetailBlockClaimantsAction,
                              type: DivineButtonType.link,
                              size: DivineButtonSize.small,
                              isLoading:
                                  state.actionStatus ==
                                  BadgeDetailActionStatus.blockingClaimants,
                              onPressed: state.isBusy
                                  ? null
                                  : () => _BadgeActions._openBlockClaimants(
                                      context,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    if (detail.isOwner && detail.recipients.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Text(
                            l10n.badgeDetailNoRecipients,
                            style: VineTheme.bodySmallFont(
                              color: context.vineColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else if (detail.isOwner) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Text(
                            l10n.badgeDetailRecipientsTitle,
                            style: VineTheme.titleSmallFont(
                              color: context.vineColors.primaryText,
                            ),
                          ),
                        ),
                      ),
                      // Lazily built: a popular badge can carry a long
                      // awardee list, and every row resolves a profile.
                      SliverList.builder(
                        itemCount: detail.recipients.length,
                        itemBuilder: (context, index) {
                          final recipient = detail.recipients[index];
                          return BadgeRecipientRow(
                            pubkey: recipient.pubkey,
                            isAccepted: recipient.isAccepted,
                            showRevokeAction: detail.isOwner,
                            isRevoking: state.isRevoking(recipient.pubkey),
                            onRevoke: state.isBusy
                                ? null
                                : () => _revoke(context, recipient),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _revoke(
    BuildContext context,
    BadgeRecipientViewData recipient,
  ) async {
    final cubit = context.read<BadgeDetailCubit>();
    final confirmed = await showBadgeRevokeConfirmation(
      context,
      isViewer: recipient.isViewer,
    );
    if (!(confirmed ?? false) || cubit.isClosed) return;
    await cubit.revokeAward(recipient.pubkey);
  }
}

/// Indexed holders appear first, then the complete relay set replaces them.
/// Individual follows stay separate from the account's badge subscription.
class _AcceptedHolders extends ConsumerWidget {
  const _AcceptedHolders({required this.coordinate, super.key});

  final BadgeCoordinate coordinate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocklistVersion = ref.watch(blocklistVersionProvider);
    final badgeRepository = ref.watch(badgeRepositoryProvider);
    final followRepository = ref.watch(followRepositoryProvider);
    final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
    final videosRepository = ref.watch(videosRepositoryProvider);
    final funnelcakeClient = ref.watch(funnelcakeApiClientProvider);
    final signedIn = ref.watch(authServiceProvider).currentPublicKeyHex != null;
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          key: ValueKey((badgeRepository, signedIn, blocklistVersion)),
          create: (_) {
            final cubit = BadgeHoldersCubit(
              repository: badgeRepository,
              coordinate: coordinate,
              canSubscribe: signedIn,
              loadIndexedPreview: (badge) =>
                  funnelcakeClient.getBadgeHolderPreview(
                    creatorPubkey: badge.pubkey,
                    dTag: badge.identifier,
                  ),
            );
            runDetached(
              cubit.load(),
              'load badge holders',
              logName: 'BadgeDetailScreen',
              category: LogCategory.ui,
            );
            return cubit;
          },
        ),
        BlocProvider(
          key: ValueKey((badgeRepository, videosRepository, coordinate)),
          // Eager, so a re-key after the holders loaded (a filter toggle
          // rebuilds videosRepository) reloads here; the listener below only
          // sees subsequent holder state transitions.
          lazy: false,
          create: (context) {
            final cubit = BadgeVideosCubit(
              badgeRepository: badgeRepository,
              videosRepository: videosRepository,
              coordinate: coordinate,
            );
            final holders = context.read<BadgeHoldersCubit>().state;
            if (holders.holdersStatus == BadgeHoldersStatus.preview ||
                holders.holdersStatus == BadgeHoldersStatus.loaded) {
              runDetached(
                cubit.loadForHolders(holders.holders.toSet()),
                'reload badge holder videos',
                logName: 'BadgeDetailScreen',
                category: LogCategory.ui,
              );
            }
            return cubit;
          },
        ),
        BlocProvider(
          key: ValueKey((followRepository, blocklistRepository)),
          create: (_) => MyFollowingBloc(
            followRepository: followRepository,
            contentBlocklistRepository: blocklistRepository,
          )..add(const MyFollowingListLoadRequested()),
        ),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<BadgeHoldersCubit, BadgeHoldersState>(
            listenWhen: (previous, current) =>
                previous.saveFailures != current.saveFailures,
            listener: (context, _) =>
                ScaffoldMessenger.of(context).showSnackBar(
                  DivineSnackbarContainer.snackBar(
                    context.l10n.badgesUpdateError,
                    error: true,
                  ),
                ),
          ),
          BlocListener<BadgeHoldersCubit, BadgeHoldersState>(
            listenWhen: (previous, current) {
              if (current.holdersStatus == BadgeHoldersStatus.preview) {
                return previous.holdersStatus != BadgeHoldersStatus.preview;
              }
              if (current.holdersStatus != BadgeHoldersStatus.loaded) {
                return false;
              }
              final previousHolders = previous.holders.toSet();
              return previous.holdersStatus != BadgeHoldersStatus.preview ||
                  previousHolders.length != current.holders.length ||
                  !previousHolders.containsAll(current.holders);
            },
            listener: (context, state) => runDetached(
              context.read<BadgeVideosCubit>().loadForHolders(
                state.holders.toSet(),
              ),
              'load badge holder videos',
              logName: 'BadgeDetailScreen',
              category: LogCategory.ui,
            ),
          ),
        ],
        child: SliverMainAxisGroup(
          slivers: [
            const SliverToBoxAdapter(child: _HoldersHeader()),
            const _AcceptedHolderList(),
            _BadgeVideoGrid(coordinate: coordinate),
            const SliverToBoxAdapter(child: _SubscriptionAction()),
          ],
        ),
      ),
    );
  }
}

class _HoldersHeader extends StatelessWidget {
  const _HoldersHeader();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Text(
      context.l10n.badgeAcceptedHoldersTitle,
      style: VineTheme.titleSmallFont(color: context.vineColors.primaryText),
    ),
  );
}

class _SubscriptionAction extends StatelessWidget {
  const _SubscriptionAction();

  @override
  Widget build(BuildContext context) {
    final (status, subscribed) = context.select(
      (BadgeHoldersCubit cubit) =>
          (cubit.state.subscriptionStatus, cubit.state.isSubscribed),
    );
    final cubit = context.read<BadgeHoldersCubit>();
    return switch (status) {
      BadgeSubscriptionStatus.unavailable ||
      BadgeSubscriptionStatus.initial => const SizedBox.shrink(),
      BadgeSubscriptionStatus.failure => _DetailMessage(
        message: context.l10n.badgesLoadError,
        onRetry: cubit.load,
      ),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.badgeSubscriptionsPublicNotice,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
          DivineButton(
            label: subscribed
                ? context.l10n.badgeSubscribedAction
                : context.l10n.badgeSubscribeAction,
            type: DivineButtonType.link,
            size: DivineButtonSize.small,
            onPressed: status == BadgeSubscriptionStatus.ready
                ? cubit.toggleSubscription
                : null,
          ),
        ],
      ),
    };
  }
}

class _AcceptedHolderList extends StatefulWidget {
  const _AcceptedHolderList();

  @override
  State<_AcceptedHolderList> createState() => _AcceptedHolderListState();
}

class _AcceptedHolderListState extends State<_AcceptedHolderList> {
  /// Holders shown before "Show more", so the video grid stays in reach.
  static const _collapsedHolderCount = 6;

  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final (status, holders) = context.select(
      (BadgeHoldersCubit cubit) =>
          (cubit.state.holdersStatus, cubit.state.holders),
    );
    return switch (status) {
      BadgeHoldersStatus.initial ||
      BadgeHoldersStatus.loading => const SliverToBoxAdapter(
        child: Center(child: BrandedLoadingIndicator(size: 40)),
      ),
      BadgeHoldersStatus.failure => SliverToBoxAdapter(
        child: _DetailMessage(
          message: context.l10n.badgesLoadError,
          onRetry: context.read<BadgeHoldersCubit>().load,
        ),
      ),
      BadgeHoldersStatus.preview ||
      BadgeHoldersStatus.loaded => SliverMainAxisGroup(
        slivers: [
          SliverList.builder(
            itemCount: _showAll
                ? holders.length
                : holders.length.clamp(0, _collapsedHolderCount),
            itemBuilder: (context, index) {
              final holder = holders[index];
              return BlocSelector<MyFollowingBloc, MyFollowingState, bool>(
                selector: (state) => state.isFollowing(holder),
                builder: (context, isFollowing) => UserProfileTile(
                  pubkey: holder,
                  isFollowing: isFollowing,
                  onToggleFollow: () => context.read<MyFollowingBloc>().add(
                    MyFollowingToggleRequested(holder),
                  ),
                  padding: const EdgeInsets.fromLTRB(0, 12, 16, 12),
                ),
              );
            },
          ),
          if (status == BadgeHoldersStatus.preview)
            const SliverToBoxAdapter(
              child: Center(child: BrandedLoadingIndicator(size: 24)),
            ),
          if (status == BadgeHoldersStatus.loaded &&
              !_showAll &&
              holders.length > _collapsedHolderCount)
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerLeft,
                child: DivineButton(
                  label: context.l10n.profileShowMore,
                  type: DivineButtonType.link,
                  size: DivineButtonSize.small,
                  onPressed: () => setState(() => _showAll = true),
                ),
              ),
            ),
        ],
      ),
    };
  }
}

class _BadgeVideoGrid extends ConsumerWidget {
  const _BadgeVideoGrid({required this.coordinate});

  final BadgeCoordinate coordinate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdersStatus = context.select(
      (BadgeHoldersCubit cubit) => cubit.state.holdersStatus,
    );
    if (holdersStatus != BadgeHoldersStatus.loaded &&
        holdersStatus != BadgeHoldersStatus.preview) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final state = context.watch<BadgeVideosCubit>().state;
    final cubit = context.read<BadgeVideosCubit>();
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 12),
            child: Text(
              context.l10n.profileVideosLabel,
              style: VineTheme.titleSmallFont(
                color: context.vineColors.primaryText,
              ),
            ),
          ),
        ),
        switch (state.status) {
          BadgeVideosStatus.initial => const SliverToBoxAdapter(
            child: SizedBox.shrink(),
          ),
          BadgeVideosStatus.loading => const SliverToBoxAdapter(
            child: Center(child: BrandedLoadingIndicator(size: 40)),
          ),
          BadgeVideosStatus.failure => SliverToBoxAdapter(
            child: _DetailMessage(
              message: context.l10n.feedFailedToLoadVideos,
              onRetry: () => cubit.loadForHolders(
                context.read<BadgeHoldersCubit>().state.holders.toSet(),
              ),
            ),
          ),
          BadgeVideosStatus.loaded when state.videos.isEmpty =>
            SliverToBoxAdapter(
              child: Text(
                context.l10n.exploreNoVideosAvailable,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.onSurfaceVariant,
                ),
              ),
            ),
          BadgeVideosStatus.loaded => SliverGrid.builder(
            itemCount: state.videos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 0.75,
            ),
            itemBuilder: (context, index) {
              final video = state.videos[index];
              return Semantics(
                label: context.l10n.profileVideoThumbnailLabel(index + 1),
                button: true,
                child: GestureDetector(
                  onTap: () => unawaited(
                    context.push(
                      PooledFullscreenVideoFeedScreen.pathForVideoId(video.id),
                      extra: PooledFullscreenVideoFeedArgs(
                        source: VideoListViewSource(state.videos),
                        feedRepository: ref.read(feedRepositoryProvider),
                        initialIndex: index,
                        initialVideoId: video.id,
                        trafficSource: ViewTrafficSource.discoveryBadges,
                        sourceDetail: coordinate.value,
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: VideoThumbnailWidget(video: video),
                  ),
                ),
              );
            },
          ),
        },
        if (state.status == BadgeVideosStatus.loaded && state.hasMore)
          SliverToBoxAdapter(
            child: Center(
              child: DivineButton(
                label: context.l10n.profileShowMore,
                type: DivineButtonType.link,
                size: DivineButtonSize.small,
                isLoading: state.isLoadingMore,
                onPressed: state.isLoadingMore ? null : cubit.loadMore,
              ),
            ),
          ),
      ],
    );
  }
}

class _BadgeHero extends StatelessWidget {
  const _BadgeHero({required this.detail, required this.coordinate});

  final BadgeDetailData detail;
  final BadgeCoordinate coordinate;

  @override
  Widget build(BuildContext context) {
    final definition = detail.definition;
    final imageUrl =
        definition?.imageUrl ??
        (definition?.thumbnails.isNotEmpty ?? false
            ? definition!.thumbnails.first
            : null);
    return Column(
      spacing: 14,
      children: [
        _BadgeArtwork(imageUrl: imageUrl),
        Text(
          definition?.name ?? coordinate.identifier,
          textAlign: TextAlign.center,
          style: VineTheme.titleLargeFont(color: context.vineColors.onSurface),
        ),
        if (definition?.description?.isNotEmpty ?? false)
          Text(
            definition!.description!,
            textAlign: TextAlign.center,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.badgeDetailMadeBy,
              style: VineTheme.titleSmallFont(
                color: context.vineColors.primaryText,
              ),
            ),
            UserProfileTile(
              pubkey: coordinate.pubkey,
              showFollowButton: false,
              // The enclosing sliver already pads to the screen inset.
              padding: const EdgeInsets.fromLTRB(0, 12, 16, 12),
            ),
          ],
        ),
      ],
    );
  }
}

class _BadgeArtwork extends StatelessWidget {
  const _BadgeArtwork({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const fallback = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: VineTheme.vineGreen,
      ),
      child: Center(
        child: DivineIcon(
          icon: DivineIconName.sparkle,
          color: VineTheme.primaryDarkGreen,
          size: 56,
        ),
      ),
    );

    return SizedBox(
      width: 156,
      height: 156,
      child: imageUrl == null || imageUrl!.isEmpty
          ? fallback
          : ClipOval(
              child: VineCachedImage(
                imageUrl: imageUrl!,
                errorWidget: (_, _, _) => fallback,
              ),
            ),
    );
  }
}

class _BadgeActions extends StatelessWidget {
  const _BadgeActions({required this.state});

  final BadgeDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<BadgeDetailCubit>();
    final detail = state.detail!;
    final viewerAward = detail.viewerAward;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        if (detail.isOwner)
          DivineButton(
            label: l10n.badgeDetailAwardAction,
            leadingIcon: DivineIconName.userPlus,
            isLoading: state.actionStatus == BadgeDetailActionStatus.awarding,
            onPressed: state.isBusy
                ? null
                : () => _openAwardFlow(context, state.coordinate),
          ),
        if (viewerAward != null)
          if (viewerAward.isAccepted)
            DivineButton(
              label: l10n.badgesActionRemove,
              type: DivineButtonType.secondary,
              isLoading: state.actionStatus == BadgeDetailActionStatus.removing,
              onPressed: state.isBusy ? null : cubit.removeAward,
            )
          else
            DivineButton(
              label: l10n.badgesActionAccept,
              isLoading:
                  state.actionStatus == BadgeDetailActionStatus.accepting,
              onPressed: state.isBusy ? null : cubit.acceptAward,
            ),
      ],
    );
  }

  static Future<void> _openAwardFlow(
    BuildContext context,
    BadgeCoordinate coordinate,
  ) async {
    final cubit = context.read<BadgeDetailCubit>();
    await context.push<bool>(BadgeAwardScreen.pathFor(coordinate));
    if (cubit.isClosed) return;
    await cubit.refresh();
  }

  static Future<void> _openBlockClaimants(BuildContext context) {
    final cubit = context.read<BadgeDetailCubit>();
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: const _BlockClaimantsConfirmationScreen(),
        ),
      ),
    );
  }
}

class _BlockClaimantsConfirmationScreen extends StatefulWidget {
  const _BlockClaimantsConfirmationScreen();

  @override
  State<_BlockClaimantsConfirmationScreen> createState() =>
      _BlockClaimantsConfirmationScreenState();
}

class _BlockClaimantsConfirmationScreenState
    extends State<_BlockClaimantsConfirmationScreen> {
  late Future<Set<String>> _claimantsFuture;

  @override
  void initState() {
    super.initState();
    _claimantsFuture = context.read<BadgeDetailCubit>().loadClaimantPubkeys();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocListener<BadgeDetailCubit, BadgeDetailState>(
      listenWhen: (previous, current) =>
          previous.actionStatus != current.actionStatus,
      listener: (context, state) {
        if (state.actionStatus == BadgeDetailActionStatus.completed) {
          final message = l10n.badgeDetailBlockClaimantsSuccess;
          runDetached(
            SemanticsService.sendAnnouncement(
              View.of(context),
              message,
              Directionality.of(context),
            ),
            'announce blocked claimants success',
            logName: 'BlockClaimantsConfirmationScreen',
            category: LogCategory.ui,
          );
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(DivineSnackbarContainer.snackBar(message));
          context.safePop(result: true);
        } else if (state.actionStatus == BadgeDetailActionStatus.failure) {
          final message = l10n.badgeDetailBlockClaimantsFailure;
          runDetached(
            SemanticsService.sendAnnouncement(
              View.of(context),
              message,
              Directionality.of(context),
            ),
            'announce blocked claimants failure',
            logName: 'BlockClaimantsConfirmationScreen',
            category: LogCategory.ui,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            DivineSnackbarContainer.snackBar(message, error: true),
          );
        }
      },
      child: Scaffold(
        appBar: DiVineAppBar(
          title: l10n.badgeDetailBlockClaimantsTitle,
          showBackButton: true,
          onBackPressed: context.safePop,
        ),
        backgroundColor: context.vineColors.background,
        body: FutureBuilder<Set<String>>(
          future: _claimantsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: BrandedLoadingIndicator(size: 60));
            }
            if (snapshot.hasError) {
              return _DetailMessage(
                message: l10n.badgeDetailBlockClaimantsLoadError,
                onRetry: () => setState(() {
                  _claimantsFuture = context
                      .read<BadgeDetailCubit>()
                      .loadClaimantPubkeys();
                }),
              );
            }

            final claimants = snapshot.data ?? const <String>{};
            return SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 16,
                            children: [
                              Text(
                                claimants.isEmpty
                                    ? l10n.badgeDetailBlockClaimantsEmptyTitle
                                    : l10n.badgeDetailBlockClaimantsHeading(
                                        claimants.length,
                                      ),
                                textAlign: TextAlign.center,
                                style: VineTheme.titleLargeFont(
                                  color: context.vineColors.onSurface,
                                ),
                              ),
                              Text(
                                claimants.isEmpty
                                    ? l10n.badgeDetailBlockClaimantsEmptyBody
                                    : l10n.badgeDetailBlockClaimantsBody(
                                        claimants.length,
                                      ),
                                textAlign: TextAlign.center,
                                style: VineTheme.bodyMediumFont(
                                  color: context.vineColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        BlocBuilder<BadgeDetailCubit, BadgeDetailState>(
                          builder: (context, state) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: 12,
                              children: [
                                DivineButton(
                                  label: claimants.isEmpty
                                      ? l10n.commonCancel
                                      : l10n.badgeDetailBlockClaimantsConfirm(
                                          claimants.length,
                                        ),
                                  type: claimants.isEmpty
                                      ? DivineButtonType.secondary
                                      : DivineButtonType.error,
                                  leadingIcon: claimants.isEmpty
                                      ? null
                                      : DivineIconName.prohibit,
                                  isLoading:
                                      state.actionStatus ==
                                      BadgeDetailActionStatus.blockingClaimants,
                                  onPressed: state.isBusy
                                      ? null
                                      : claimants.isEmpty
                                      ? () => context.safePop()
                                      : () => context
                                            .read<BadgeDetailCubit>()
                                            .blockClaimants(claimants),
                                ),
                                if (claimants.isNotEmpty)
                                  DivineButton(
                                    label: l10n.commonCancel,
                                    type: DivineButtonType.secondary,
                                    onPressed: state.isBusy
                                        ? null
                                        : () => context.safePop(),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DetailMessage extends StatelessWidget {
  const _DetailMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: VineTheme.titleSmallFont(
                color: context.vineColors.primaryText,
              ),
            ),
            DivineButton(label: context.l10n.commonRetry, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
