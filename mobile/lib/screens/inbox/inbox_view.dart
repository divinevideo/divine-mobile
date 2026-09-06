// ABOUTME: Main view for the inbox screen with Messages/Notifications toggle.
// ABOUTME: Shows conversation list (with following bar) or notifications
// ABOUTME: depending on the selected tab.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/blocs/dm/conversation_actions/conversation_actions_cubit.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/blocs/dm/conversation_mute/conversation_mute_cubit.dart';
import 'package:openvine/blocs/dm/dm_peer_name.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/blocs/notifications/badge/notification_badge_cubit.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/scroll_pagination_mixin.dart';
import 'package:openvine/notifications/view/inbox_notifications_page.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/message_requests/message_requests_page.dart';
import 'package:openvine/screens/inbox/message_requests/widgets/message_requests_banner.dart';
import 'package:openvine/screens/inbox/new_message_sheet.dart';
import 'package:openvine/screens/inbox/widgets/conversation_actions_sheet.dart';
import 'package:openvine/screens/inbox/widgets/conversation_tile.dart';
import 'package:openvine/screens/inbox/widgets/dm_peer_identity.dart';
import 'package:openvine/screens/inbox/widgets/following_bar.dart';
import 'package:openvine/screens/inbox/widgets/inbox_empty_state.dart';
import 'package:openvine/screens/inbox/widgets/inbox_error_state.dart';
import 'package:openvine/screens/inbox/widgets/inbox_fab.dart';
import 'package:openvine/screens/inbox/widgets/inbox_filter_chips.dart';
import 'package:openvine/screens/inbox/widgets/inbox_segmented_toggle.dart';
import 'package:openvine/screens/inbox/widgets/restore_paused_banner.dart';
import 'package:unified_logger/unified_logger.dart';

/// Main inbox view containing the Messages/Notifications segmented toggle
/// and the corresponding content for each tab.
class InboxView extends ConsumerStatefulWidget {
  const InboxView({super.key});

  @override
  ConsumerState<InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends ConsumerState<InboxView>
    with SingleTickerProviderStateMixin {
  /// Drives the shared-axis transition between the two tabs. `0` fully shows
  /// Notifications, `1` fully shows Messages. Runs linearly; the curves are
  /// applied per-property in [_InboxTabContent].
  late final AnimationController _transitionController;

  /// Currently selected tab.
  InboxTab _selectedTab = InboxTab.notifications;

  /// Whether the Messages tab UI has been opened at least once. The
  /// `ConversationListBloc` is provided by `InboxPage` and starts immediately
  /// so DM backfill and streams can warm the tab before it is visible; this flag
  /// only keeps the Messages pane out of the animated stack until first open.
  /// After that first open, the pane stays mounted so later switches preserve
  /// UI state. Notifications is the default tab and is always mounted.
  bool _messagesActivated = false;

  /// Pubkey the current tab state belongs to. When the signed-in identity
  /// changes we collapse back to Notifications and re-arm lazy Messages UI
  /// activation. The account-scoped DM bloc still starts from `InboxPage` so
  /// Messages can be ready by the time the user opens it.
  String? _activePubkey;
  bool _pubkeyObserved = false;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: kInboxTabTransitionDuration,
      // Notifications is the default tab (value 0); Messages is value 1.
      value: 0,
    );
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  void _onTabSelected(InboxTab tab) {
    if (tab == _selectedTab) return;
    setState(() {
      _selectedTab = tab;
      if (tab == InboxTab.messages) _messagesActivated = true;
    });
    final target = tab == InboxTab.messages ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _transitionController.value = target;
    } else {
      _transitionController.animateTo(target);
    }
  }

  /// Resets the tab state to its defaults when the signed-in identity changes,
  /// so a new account opens on Notifications and re-arms lazy Messages UI.
  void _syncToIdentity(String? currentPubkey) {
    if (!_pubkeyObserved) {
      _pubkeyObserved = true;
      _activePubkey = currentPubkey;
      return;
    }
    if (currentPubkey == _activePubkey) return;
    _activePubkey = currentPubkey;
    _selectedTab = InboxTab.notifications;
    _messagesActivated = false;
    _transitionController.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild the inbox surfaces when auth identity changes so per-screen UI
    // state does not linger across account switches.
    ref.watch(currentAuthStateProvider);

    // Re-filter conversation list when blocklist changes.
    ref.listen(blocklistVersionProvider, (previous, current) {
      if (previous != null && current > previous) {
        context.read<ConversationListBloc>().add(
          const ConversationListBlocklistChanged(),
        );
      }
    });

    // Watch unread counts for both segments. Without a Messages-side badge
    // users had no signal that a still-lit bottom-nav inbox dot was caused
    // by unread DMs rather than notifications they thought they'd cleared.
    final notificationCount = context.watch<NotificationBadgeCubit>().state;
    final messageCount = context.watch<DmUnreadCountCubit>().state;
    final currentPubkey = ref.read(authServiceProvider).currentPublicKeyHex;
    final isInboxBranchVisible = ref.watch(activeBranchIndexProvider) == 2;
    _syncToIdentity(currentPubkey);

    return ColoredBox(
      color: context.vineColors.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Segmented toggle (Messages / Notifications)
            InboxSegmentedToggle(
              selected: _selectedTab,
              onChanged: _onTabSelected,
              notificationCount: notificationCount,
              messageCount: messageCount,
            ),
            // Content area with rounded top corners. Both tabs stay mounted
            // (Notifications always, Messages once first opened) so returning
            // to a tab never reloads. The shared-axis transition slides +
            // cross-fades between them; each pane sits on an opaque surface so
            // neither the near-black background nor the other tab shows
            // through.
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: ColoredBox(
                  color: context.vineColors.surfaceContainerHigh,
                  child: _InboxTabContent(
                    animation: _transitionController,
                    selected: _selectedTab,
                    // BLoC-driven view (video-anchored grouping + 56x56
                    // thumbnails + l10n); see
                    // lib/notifications/view/inbox_notifications_page.dart.
                    notifications: KeyedSubtree(
                      key: ValueKey('notifications-$currentPubkey'),
                      child: InboxNotificationsPage(
                        isVisible:
                            isInboxBranchVisible &&
                            _selectedTab == InboxTab.notifications,
                      ),
                    ),
                    messages: _messagesActivated
                        ? KeyedSubtree(
                            key: ValueKey('messages-$currentPubkey'),
                            child: const _MessagesContent(),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal travel of each pane during the transition, as a fraction of the
/// pane width — the subtle shared-axis slide.
const double _kTabSlideFraction = 0.06;

/// Inset of the compose FAB from the bottom-right of the Messages pane.
const double _kFabInset = 16;

/// Bottom padding reserved on the conversation list so the compose FAB
/// ([InboxFab], inset [_kFabInset] from the bottom) never covers the last
/// conversation tile when scrolled to the end. Equals the FAB's footprint
/// plus a margin, so it tracks [InboxFab.size] automatically.
const double _kConversationListBottomInset =
    _kFabInset + InboxFab.size + _kFabInset;

/// Material shared-axis transition between the two inbox tabs: a short
/// horizontal slide combined with an overlapping cross-fade.
///
/// [animation] runs `0` (Notifications) → `1` (Messages). Both panes stay
/// mounted and are painted on an opaque surface, so the near-black background
/// never flashes and the panes never bleed through one another. The selected
/// pane is the only one that receives pointer events.
class _InboxTabContent extends StatelessWidget {
  const _InboxTabContent({
    required this.animation,
    required this.selected,
    required this.notifications,
    required this.messages,
  });

  final Animation<double> animation;
  final InboxTab selected;
  final Widget notifications;
  final Widget messages;

  @override
  Widget build(BuildContext context) {
    final notificationsSelected = selected == InboxTab.notifications;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        final slide = Curves.easeInOut.transform(t);
        return Stack(
          fit: StackFit.expand,
          children: [
            _InboxTabPane(
              opacity: Curves.easeInOut.transform(1 - t),
              dx: -_kTabSlideFraction * slide,
              active: notificationsSelected,
              child: notifications,
            ),
            _InboxTabPane(
              opacity: Curves.easeInOut.transform(t),
              dx: _kTabSlideFraction * (1 - slide),
              active: !notificationsSelected,
              child: messages,
            ),
          ],
        );
      },
    );
  }
}

/// A single inbox pane within the shared-axis transition: opaque background,
/// [opacity] + horizontal [dx] (fraction of width) for the slide/fade, and
/// [active] gating pointer events, semantics, and tickers so the faded-out pane
/// never intercepts taps, appears to assistive technologies, or keeps
/// descendant animations running.
class _InboxTabPane extends StatelessWidget {
  const _InboxTabPane({
    required this.opacity,
    required this.dx,
    required this.active,
    required this.child,
  });

  final double opacity;
  final double dx;
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TickerMode(
      enabled: active,
      child: ExcludeSemantics(
        excluding: !active,
        child: IgnorePointer(
          ignoring: !active,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: FractionalTranslation(
              translation: Offset(dx, 0),
              child: ColoredBox(
                color: context.vineColors.surfaceContainerHigh,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pushes the conversation page using the [GoRouter] instance directly,
/// bypassing the nested Navigator's context which cannot reach GoRouter.
void _pushConversation(
  BuildContext context,
  String conversationId,
  List<String> participantPubkeys, [
  String? subject,
]) {
  Log.info(
    '🚀 Pushing conversation: id=$conversationId',
    name: 'InboxView',
    category: LogCategory.ui,
  );
  context.push(
    ConversationPage.pathForId(conversationId),
    extra: subject == null
        ? participantPubkeys
        : {'participantPubkeys': participantPubkeys, 'subject': subject},
  );
}

/// Hands `ConversationListBloc` the localized names it substitutes for peers
/// whose own name must not be shown, so inbox search matches the string the
/// row actually renders (#8204).
///
/// A widget of its own, mounted inside the Messages subtree, for two reasons.
/// The bloc has no `context.l10n`, so the strings have to come from the UI —
/// and `BlocProvider` is lazy, so reading the bloc anywhere higher would drag
/// its creation earlier than the Messages tab being opened. Everything below
/// the enclosing `BlocListener` is already a consumer, so nothing here changes
/// when the bloc starts.
///
/// `didChangeDependencies` rather than `initState`: reading l10n registers a
/// dependency on `Localizations`, so this fires again when the language
/// changes. It can, without an app restart, via Settings -> General — and
/// `BlocProvider.create:` runs once, so labels injected only at construction
/// would leave search matching the previous language.
class _PeerLabelSync extends StatefulWidget {
  const _PeerLabelSync({required this.child});

  final Widget child;

  @override
  State<_PeerLabelSync> createState() => _PeerLabelSyncState();
}

class _PeerLabelSyncState extends State<_PeerLabelSync> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.read<ConversationListBloc>().add(
      ConversationListPeerLabelsChanged(dmPeerLabels(context)),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Content for the Messages tab: following bar + conversation list or
/// empty state, with a FAB for composing new messages.
class _MessagesContent extends ConsumerWidget {
  const _MessagesContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex ?? '';

    return BlocListener<ConversationListBloc, ConversationListState>(
      listenWhen: (prev, curr) =>
          curr.navigationTarget != null &&
          prev.navigationTarget != curr.navigationTarget,
      listener: (context, state) {
        final target = state.navigationTarget;
        if (target == null) return;

        Log.info(
          '🎯 Navigation target received: ${target.conversationId}',
          name: 'InboxView',
          category: LogCategory.ui,
        );

        // Clear the navigation target so it doesn't re-fire.
        context.read<ConversationListBloc>().add(
          const ConversationListNavigationConsumed(),
        );

        _pushConversation(
          context,
          target.conversationId,
          target.participantPubkeys,
        );
      },
      child: Stack(
        children: [
          _PeerLabelSync(
            child: _MessagesScrollView(currentUserPubkey: currentPubkey),
          ),
          // FAB positioned bottom-right
          PositionedDirectional(
            end: _kFabInset,
            bottom: _kFabInset,
            child: InboxFab(onPressed: () => _onNewConversation(context, ref)),
          ),
        ],
      ),
    );
  }

  Future<void> _onNewConversation(BuildContext context, WidgetRef ref) async {
    final profileRepo = ref.read(profileRepositoryProvider);
    if (profileRepo == null) {
      Log.warning(
        'Cannot open new message: profileRepo is null',
        name: 'InboxView',
        category: LogCategory.ui,
      );
      return;
    }

    // Read before opening the sheet: the picker needs it to exclude the
    // viewer from its own candidate list (#8351), and with no signed-in
    // pubkey there is nobody to message anyway.
    final currentPubkey = ref.read(authServiceProvider).currentPublicKeyHex;
    if (currentPubkey == null) return;

    final selectedUser = await NewMessageSheet.show(
      context,
      profileRepository: profileRepo,
      followRepository: ref.read(followRepositoryProvider),
      currentUserPubkey: currentPubkey,
    );

    if (selectedUser == null || !context.mounted) return;

    final conversationId = DmRepository.computeConversationId([
      currentPubkey,
      selectedUser.pubkey,
    ]);
    _pushConversation(context, conversationId, [selectedUser.pubkey]);
  }
}

/// Thin progress bar shown at the top of the Messages list while the one-time
/// DM history recovery (reinstall backfill / failed-decrypt replay) is still
/// running, so the user knows older chats are still being restored. See #5202.
class _RestoringHistoryIndicator extends StatelessWidget {
  const _RestoringHistoryIndicator();

  @override
  Widget build(BuildContext context) {
    final isRestoring = context.select<ConversationListBloc, bool>(
      (bloc) => bloc.state.isRestoringHistory,
    );
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      child: isRestoring
          ? LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: context.vineColors.surfaceContainerHigh,
              color: context.vineColors.accentPositive,
              semanticsLabel: context.l10n.inboxRestoringMessages,
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Renders [RestorePausedBanner] while the recovery gate is hiding would-be
/// message requests.
///
/// Scoped to the loaded state on purpose: the loading branch already shows a
/// spinner, and [InboxErrorState] carries its own retry, so surfacing a second
/// one above it would be redundant.
class _RestorePausedBannerGate extends StatelessWidget {
  const _RestorePausedBannerGate();

  @override
  Widget build(BuildContext context) {
    final withheld = context.select<ConversationListBloc, bool>(
      (bloc) =>
          bloc.state.requestsWithheld &&
          !bloc.state.isRestoringHistory &&
          bloc.state.status == ConversationListStatus.loaded,
    );
    if (!withheld) return const SizedBox.shrink();
    return RestorePausedBanner(
      onRetry: () => context.read<ConversationListBloc>().add(
        const ConversationListRestoreRetryRequested(),
      ),
    );
  }
}

/// "Divine Moderation" support tile, always rendered as the first row of the
/// conversation list (#6283).
///
/// It sits *inside* the scroll view rather than above it: as fixed chrome it
/// cost ~92px of a viewport the keyboard already halves on a small phone, and
/// it read as the screen's headline rather than as one chat among many.
/// Ordering is not left to the list's recency sort — a synthetic row carries
/// no timestamp and would sink out of reach.
///
/// The caller only builds this when [ConversationListState.pinnedSupport] is
/// non-null. The bloc withholds that for a restricted minor whose approval was
/// revoked, so this tile is never the row the conversation route guard would
/// bounce (#176). Blocking the moderation account does not withhold it (#7850).
class _PinnedSupportRow extends StatelessWidget {
  const _PinnedSupportRow({
    required this.pinned,
    required this.currentUserPubkey,
    required this.onLongPress,
  });

  /// The adopted real moderation thread, or the synthetic stand-in.
  final PinnedSupport pinned;

  /// Signed-in pubkey. Passed in rather than derived from the conversation's
  /// participant list — that list is sorted, so its first entry is not
  /// reliably self, and [ConversationTile] uses self to pick which
  /// participant's avatar to render.
  final String currentUserPubkey;

  /// Opens the conversation action sheet. Null while the pin is synthetic:
  /// there is no row to mute or remove yet, and the confirmation snackbars
  /// would report work that did not happen.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final conversation = pinned.conversation;

    return ConversationTile(
      conversation: conversation,
      currentUserPubkey: currentUserPubkey,
      // Fixed identity: the profile lookup yields null until the relay client
      // is ready, and the tile's fallback is a generated name — so sourcing
      // this from kind-0 would show a random display name at cold start.
      displayNameOverride: context.l10n.inboxSupportRowTitle,
      // Only stand in for the preview when there is no real thread yet; once
      // the team replies, the last message is more useful than the blurb.
      subtitleOverride: conversation.lastMessageContent == null
          ? context.l10n.inboxSupportRowSubtitle
          : null,
      onTap: () => _pushConversation(
        context,
        conversation.id,
        // Self must be stripped, matching _onConversationTapped: the route
        // reads `extra` as the COUNTERPARTY list, so passing the raw
        // participants opens a conversation with the signed-in user instead
        // of with moderation.
        dmConversationPeerPubkeys(
          participantPubkeys: conversation.participantPubkeys,
          currentUserPubkey: currentUserPubkey,
        ),
      ),
      onLongPress: onLongPress,
    );
  }
}

/// The whole Messages pane as a single scroll view.
///
/// Every piece of chrome — following bar, search field, filter chips — used to
/// be a fixed-height child of a [Column] wrapping the list, which on a small
/// Android phone left the list roughly one row tall once the keyboard opened,
/// and overflowed outright (#6388 review, items 4 and 5). Only the filter
/// chips stay pinned now; everything above them scrolls away, handing the
/// viewport back on every device rather than only below some height
/// threshold. The keyboard, not the screen, is what collapses the viewport —
/// a threshold would have missed the tall-phone case entirely.
class _MessagesScrollView extends ConsumerStatefulWidget {
  const _MessagesScrollView({required this.currentUserPubkey});

  final String currentUserPubkey;

  @override
  ConsumerState<_MessagesScrollView> createState() =>
      _MessagesScrollViewState();
}

class _MessagesScrollViewState extends ConsumerState<_MessagesScrollView>
    with ScrollPaginationMixin {
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _searchController;
  final FocusNode _searchFocusNode = FocusNode();

  /// Whether the search field holds focus, i.e. the keyboard is up and the
  /// viewport is roughly halved.
  bool _searchFocused = false;

  /// ID of the conversation whose long-press action sheet is currently open.
  /// Drives the [ConversationTile] highlight so the user can see which row
  /// the sheet refers to. Cleared in a `finally` block after the sheet closes.
  String? _highlightedConversationId;

  @override
  ScrollController get paginationScrollController => _scrollController;

  @override
  bool canLoadMore() {
    final state = context.read<ConversationListBloc>().state;
    // Re-entrancy is guarded by ScrollPaginationMixin's own pending-load latch.
    return state.hasMore && !state.isFiltering;
  }

  @override
  FutureOr<void> onLoadMore() {
    context.read<ConversationListBloc>().add(const ConversationListLoadMore());
  }

  @override
  void initState() {
    super.initState();
    // Seed from the bloc rather than starting empty. This State survives a
    // status change now that it owns every branch, but a keyed BlocProvider
    // above still re-inflates it while the bloc — and so state.searchQuery —
    // survives. A fresh empty controller would leave the list filtered by an
    // invisible query: the search empty state over a blank field, with
    // pagination silently suspended.
    _searchController = TextEditingController(
      text: context.read<ConversationListBloc>().state.searchQuery,
    );
    _searchFocusNode.addListener(_onSearchFocusChanged);
    initPagination();
  }

  void _onSearchFocusChanged() {
    if (_searchFocusNode.hasFocus == _searchFocused) return;
    setState(() => _searchFocused = _searchFocusNode.hasFocus);
  }

  @override
  void dispose() {
    disposePagination();
    _scrollController.dispose();
    _searchFocusNode
      ..removeListener(_onSearchFocusChanged)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = context.select<ConversationListBloc, ConversationListStatus>(
      (bloc) => bloc.state.status,
    );

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Collapses while the search field holds focus (#6388 review, item 5).
        //
        // Keyed off focus rather than off a non-empty query on purpose: the
        // keyboard is what halves the viewport, and `state.searchQuery` stays
        // empty below `minSearchQueryLength` (2) — so a query-driven collapse
        // would still be showing 128px of faces after the first keystroke,
        // which is exactly the moment the list has the least room.
        SliverToBoxAdapter(
          child: AnimatedSize(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _searchFocused
                ? const SizedBox(width: double.infinity)
                : FollowingBar(
                    currentUserPubkey: widget.currentUserPubkey,
                    onUserTapped: (pubkey) {
                      Log.info(
                        '👤 User tapped in following bar: ${pubkeyForLogs(pubkey)}',
                        name: 'InboxView',
                        category: LogCategory.ui,
                      );
                      context.read<ConversationListBloc>().add(
                        ConversationListNavigateToUser(pubkey),
                      );
                    },
                  ),
          ),
        ),
        // Thin restore progress bar while the one-time reinstall history
        // recovery is still running (#5202).
        const SliverToBoxAdapter(child: _RestoringHistoryIndicator()),
        // Static banner while the recovery gate is still hiding would-be
        // message requests (#6431). Emitted OUTSIDE the status switch, which
        // is what its Column placement bought before this pane became a single
        // scroll view: it still covers every branch below — empty inbox,
        // requests-only, filtered, and populated — without threading a flag
        // through each one. It gates itself on the loaded status, so the
        // loading spinner and InboxErrorState branches are unaffected.
        const SliverToBoxAdapter(child: _RestorePausedBannerGate()),
        ...switch (status) {
          ConversationListStatus.initial || ConversationListStatus.loading => [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(
                  color: context.vineColors.accentPositive,
                ),
              ),
            ),
          ],
          ConversationListStatus.error => [
            SliverFillRemaining(
              hasScrollBody: false,
              child: InboxErrorState(
                onRetry: () => context.read<ConversationListBloc>().add(
                  const ConversationListStarted(),
                ),
              ),
            ),
          ],
          ConversationListStatus.loaded => _loadedSlivers(context),
        },
      ],
    );
  }

  /// Slivers for the `loaded` status, in render order.
  List<Widget> _loadedSlivers(BuildContext context) {
    final conversations = context
        .select<ConversationListBloc, List<DmConversation>>(
          (bloc) => bloc.state.conversations,
        );
    final visibleConversations = context
        .select<ConversationListBloc, List<DmConversation>>(
          (bloc) => bloc.state.visibleConversations,
        );
    final filter = context.select<ConversationListBloc, InboxFilter>(
      (bloc) => bloc.state.filter,
    );
    final hasBlocked = context.select<ConversationListBloc, bool>(
      (bloc) => bloc.state.blockedConversations.isNotEmpty,
    );
    final showingBlocked = filter == InboxFilter.blocked;
    final hasRequests = context.select<ConversationListBloc, bool>(
      (bloc) => bloc.state.requestConversations.isNotEmpty,
    );
    final requestUnreadCount = context.select<ConversationListBloc, int>(
      (bloc) => bloc.state.requestUnreadCount,
    );
    final hasMore = context.select<ConversationListBloc, bool>(
      (bloc) => bloc.state.hasMore,
    );
    final searchQuery = context.select<ConversationListBloc, String>(
      (bloc) => bloc.state.searchQuery,
    );
    final isFiltering = context.select<ConversationListBloc, bool>(
      (bloc) => bloc.state.isFiltering,
    );
    final pinned = context.select<ConversationListBloc, PinnedSupport?>(
      (bloc) => bloc.state.pinnedSupport,
    );

    final supportRow = pinned == null
        ? null
        : _PinnedSupportRow(
            pinned: pinned,
            currentUserPubkey: widget.currentUserPubkey,
            // Only an adopted thread has something to act on. Its actions are
            // the ones the ordinary row carried before the pin replaced it —
            // blocking moderation hides the pin, and Safety Settings is the
            // way back, exactly as for any other blocked account.
            onLongPress: pinned.isPersisted
                ? () => _onConversationLongPressed(
                    context,
                    ref,
                    pinned.conversation,
                    displayNameOverride: context.l10n.inboxSupportRowTitle,
                  )
                : null,
          );

    // Nothing but the support row to show. Keep the empty-state copy — a
    // brand-new user still needs to be told the inbox is empty — but render
    // the row above it rather than dropping it, and skip the search field and
    // filter chips, which have nothing to act on.
    // `hasBlocked` keeps the chip row alive here: blocking your only
    // correspondent empties `conversations` while leaving a blocked chat to
    // read, and the early return would drop the only affordance that reaches
    // it.
    if (conversations.isEmpty && !hasBlocked) {
      return [
        if (supportRow != null) SliverToBoxAdapter(child: supportRow),
        if (hasRequests)
          SliverToBoxAdapter(
            child: MessageRequestsBanner(
              requestCount: requestUnreadCount,
              onTap: () => _openMessageRequests(context),
            ),
          ),
        const SliverFillRemaining(
          hasScrollBody: false,
          child: InboxEmptyState(),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: DivineSearchBar(
            controller: _searchController,
            focusNode: _searchFocusNode,
            hintText: context.l10n.inboxSearchHint,
            onChanged: (value) => context.read<ConversationListBloc>().add(
              ConversationListSearchQueryChanged(value),
            ),
          ),
        ),
      ),
      PinnedHeaderSliver(
        child: _FilterChipsHeader(
          selected: filter,
          hasBlocked: hasBlocked,
          onChanged: (value) => context.read<ConversationListBloc>().add(
            ConversationListFilterChanged(value),
          ),
        ),
      ),
      // First tile of the list, ahead of the requests banner and every real
      // conversation — but only when it would survive the active filter. A
      // row that matches neither the query nor the Unread chip, sitting atop
      // a filtered result set, reads as a search hit that isn't one.
      if (supportRow != null &&
          _supportRowSurvivesFilter(
            context,
            pinned: pinned!.conversation,
            filter: filter,
            query: searchQuery,
          ))
        SliverToBoxAdapter(child: supportRow),
      // Requests are a slice of the inbox, not of the blocked list — leaving
      // the banner up under the Blocked chip reads as if these requests are
      // themselves blocked.
      if (visibleConversations.isEmpty) ...[
        if (hasRequests && !showingBlocked)
          SliverToBoxAdapter(
            child: MessageRequestsBanner(
              requestCount: requestUnreadCount,
              onTap: () => _openMessageRequests(context),
            ),
          ),
        // With no filter and no query there is nothing narrowing the list, so
        // an empty result means the inbox itself is empty — say that, rather
        // than "You're all caught up", which claims a filter did the emptying.
        // Reachable now that a viewer holding only blocked conversations skips
        // the early return above.
        if (searchQuery.isEmpty && filter == InboxFilter.all)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: InboxEmptyState(),
          )
        else
          SliverFillRemaining(
            hasScrollBody: false,
            child: _FilteredEmptyContent(
              title: searchQuery.isNotEmpty
                  ? context.l10n.inboxSearchEmptyTitle
                  : showingBlocked
                  ? context.l10n.inboxBlockedEmptyTitle
                  : context.l10n.inboxUnreadEmptyTitle,
              subtitle: searchQuery.isNotEmpty
                  ? context.l10n.inboxSearchEmptySubtitle
                  : showingBlocked
                  ? context.l10n.inboxBlockedEmptySubtitle
                  : context.l10n.inboxUnreadEmptySubtitle,
            ),
          ),
      ] else ...[
        if (hasRequests && !showingBlocked)
          SliverToBoxAdapter(
            child: MessageRequestsBanner(
              requestCount: requestUnreadCount,
              onTap: () => _openMessageRequests(context),
            ),
          ),
        SliverList.builder(
          itemCount: visibleConversations.length,
          itemBuilder: (context, index) {
            final conversation = visibleConversations[index];
            // Only the Blocked slice synthesises rows for accounts with no
            // thread; everywhere else a missing timestamp is a real
            // conversation whose first message has yet to land, and must stay
            // tappable. The synthesised row states it has nothing to open and
            // goes inert — the sheet's actions (mute, remove conversation) act
            // on a database row, and one that was never written would only
            // produce a confirmation snackbar for work that did not happen.
            final isBlockedPlaceholder =
                showingBlocked && conversation.lastMessageTimestamp == null;
            return ConversationTile(
              conversation: conversation,
              currentUserPubkey: widget.currentUserPubkey,
              highlighted: conversation.id == _highlightedConversationId,
              subtitleOverride: isBlockedPlaceholder
                  ? context.l10n.inboxBlockedNoMessages
                  : null,
              onTap: isBlockedPlaceholder
                  ? null
                  : () => _onConversationTapped(context, conversation),
              onLongPress: isBlockedPlaceholder
                  ? null
                  : () =>
                        _onConversationLongPressed(context, ref, conversation),
            );
          },
        ),
        // Suppress the load-more affordance while a filter/search narrows the
        // list: the filtered result is already complete, and a short one
        // can't scroll to trigger a load — leaving a spinner that never
        // resolves.
        if (hasMore && !isFiltering)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: context.vineColors.accentPositive,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          ),
        // Clears the compose FAB so it never covers the last tile.
        const SliverToBoxAdapter(
          child: SizedBox(height: _kConversationListBottomInset),
        ),
      ],
    ];
  }

  /// Whether the support row should still render under the active filter.
  ///
  /// It is pinned against the *sort*, not against the user's filters: hiding
  /// it here is what makes it behave like any other chat once a query or the
  /// Unread chip is on. [query] arrives already thresholded by the bloc — it
  /// is `''` below `minSearchQueryLength` — so an empty string reliably means
  /// "no search active".
  ///
  /// Matches title OR whatever the row renders as its preview, mirroring the
  /// bloc's `_applyFilters`. Once the team has replied the preview is a real
  /// message, and a query drawn from it should surface this row for the same
  /// reason it surfaces any other. Before that it is the subtitle blurb — the
  /// same string [_PinnedSupportRow] passes as `subtitleOverride`, and matching
  /// it is what stops a search for a word the user can read on screen from
  /// hiding the row that shows it.
  bool _supportRowSurvivesFilter(
    BuildContext context, {
    required DmConversation pinned,
    required InboxFilter filter,
    required String query,
  }) {
    // The Blocked slice is the viewer's blocked peers. The pin is the support
    // channel, not a blocked-account row, so it does not sit above that list
    // even when the viewer has blocked the moderation account (#7850).
    if (filter == InboxFilter.blocked) return false;
    if (filter == InboxFilter.unread && pinned.isRead) return false;
    if (query.isEmpty) return true;
    final needle = query.toLowerCase();
    final preview =
        pinned.lastMessageContent ?? context.l10n.inboxSupportRowSubtitle;
    return context.l10n.inboxSupportRowTitle.toLowerCase().contains(needle) ||
        preview.toLowerCase().contains(needle);
  }

  void _openMessageRequests(BuildContext context) {
    context.pushNamed(MessageRequestsPage.routeName);
  }

  void _onConversationTapped(
    BuildContext context,
    DmConversation conversation,
  ) {
    Log.info(
      '💬 Conversation tapped: ${conversation.id}',
      name: 'InboxView',
      category: LogCategory.ui,
    );
    final otherPubkeys = dmConversationPeerPubkeys(
      participantPubkeys: conversation.participantPubkeys,
      currentUserPubkey: widget.currentUserPubkey,
    );

    _pushConversation(
      context,
      conversation.id,
      otherPubkeys,
      conversation.subject,
    );
  }

  Future<void> _onConversationLongPressed(
    BuildContext context,
    WidgetRef ref,
    DmConversation conversation, {
    String? displayNameOverride,
  }) async {
    final otherPubkey = dmConversationFirstPeer(
      participantPubkeys: conversation.participantPubkeys,
      currentUserPubkey: widget.currentUserPubkey,
    );

    // Match [ConversationTile]'s identity chain, so the row and the sheet it
    // opens cannot name two different accounts (#7380, #8185). A known
    // identity skips the lookup entirely: applying a vanish evicts the cached
    // profile, moderation's kind-0 resolves late, and a retired moderation key
    // has none at all — so the sheet would otherwise open labelled with the
    // generated fallback the row's own name exists to avoid.
    //
    // The reactive provider intentionally renders false while its shared
    // Drift stream is loading. An imperative read cannot use that placeholder:
    // the sheet needs the durable answer before choosing a name.
    bool isVanished;
    try {
      isVanished = await ref.read(
        profileVanishedSnapshotProvider(otherPubkey).future,
      );
    } catch (error, stackTrace) {
      // The sheet contains safety actions. A transient local-database failure
      // must not make Report and Block disappear with the whole gesture.
      Log.warning(
        'Could not read durable vanish state; opening conversation actions '
        'with the live-account identity fallback',
        name: 'InboxView',
        category: LogCategory.ui,
        error: error,
        stackTrace: stackTrace,
      );
      isVanished = false;
    }
    if (!context.mounted) return;

    final String peerName;
    final knownName = dmPeerNameWithoutProfile(
      context,
      pubkeyHex: otherPubkey,
      isVanished: isVanished,
      displayNameOverride: displayNameOverride,
    );
    if (knownName != null) {
      peerName = knownName;
    } else {
      UserProfile? profile;
      try {
        profile = await ref.read(fetchUserProfileProvider(otherPubkey).future);
      } catch (error, stackTrace) {
        // A profile-cache failure must not suppress safety actions either.
        Log.warning(
          'Could not read the conversation peer profile; opening conversation '
          'actions with the generated identity fallback',
          name: 'InboxView',
          category: LogCategory.ui,
          error: error,
          stackTrace: stackTrace,
        );
      }
      if (!context.mounted) return;
      peerName = dmPeerDisplayName(
        context,
        pubkeyHex: otherPubkey,
        isVanished: isVanished,
        displayNameOverride: displayNameOverride,
        profile: profile,
      );
    }

    if (!context.mounted) return;

    // The sheet has to name what the row names. `otherPubkey` is an arbitrary
    // member of a group, so a group resolves to the room's own title instead.
    final isGroup = conversation.isGroup;
    final displayName = dmConversationDisplayTitle(
      context,
      participantPubkeys: conversation.participantPubkeys,
      currentUserPubkey: widget.currentUserPubkey,
      isGroup: isGroup,
      peerName: peerName,
      subject: conversation.subject,
    );

    final muteCubit = context.read<ConversationMuteCubit>();
    final isMuted = muteCubit.state.isMuted(conversation.id);

    final actionsCubit = context.read<ConversationActionsCubit>();
    final isBlocked = actionsCubit.isBlocked(otherPubkey);
    final blockConfirmation = switch ((isBlocked, isVanished)) {
      (true, true) => context.l10n.inboxUnblockedVanishedAccount,
      (true, false) => context.l10n.inboxUnblockedUser(displayName),
      (false, true) => context.l10n.inboxBlockedVanishedAccount,
      (false, false) => context.l10n.inboxBlockedUser(displayName),
    };
    setState(() => _highlightedConversationId = conversation.id);
    try {
      final action = await ConversationActionsSheet.show(
        context,
        displayName: displayName,
        isVanished: isVanished,
        isMuted: isMuted,
        isBlocked: isBlocked,
        // Covers the pinned support row AND an ordinary row, which is the
        // same moderation thread whenever a filter or search drops the pin.
        canRemove: !actionsCubit.isRemovalProtected(conversation),
        isGroup: isGroup,
      );

      if (action == null || !context.mounted) return;

      switch (action) {
        case ConversationAction.toggleMute:
          final nowMuted = await muteCubit.toggleMute(conversation.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  nowMuted
                      ? context.l10n.inboxConversationMuted
                      : context.l10n.inboxConversationUnmuted,
                ),
              ),
            );
          }

        case ConversationAction.report:
          final reported = await actionsCubit.reportUser(otherPubkey);
          if (context.mounted) {
            // `reported` is false when the report reached no channel off
            // this device. Staying silent there would be worse than the
            // false confirmation it replaced — the user would have no way
            // to tell the report was lost.
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  reported
                      ? isVanished
                            ? context.l10n.inboxReportedVanishedAccount
                            : context.l10n.inboxReportedUser(displayName)
                      : context.l10n.reportNotSent,
                ),
              ),
            );
          }

        case ConversationAction.block:
          if (isBlocked) {
            actionsCubit.unblockUser(otherPubkey);
          } else {
            actionsCubit.blockUser(otherPubkey);
          }
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(blockConfirmation)));
          }

        case ConversationAction.remove:
          if (!context.mounted) return;
          final confirmed = await _confirmRemove(
            context,
            displayName,
            isVanished: isVanished,
            isGroup: isGroup,
          );
          if (confirmed && context.mounted) {
            final messenger = ScaffoldMessenger.of(context);
            final removedText = context.l10n.inboxRemovedConversation;
            // Not an error: the repository protects a Divine Moderation
            // thread. Only reachable if the action was offered anyway, since
            // the sheet drops it for a protected peer (#8391).
            final refusedText =
                context.l10n.messageRequestModerationNoticeCannotBeRemoved;
            // Captured before the await for the same reason as the two above:
            // this context can retire while the removal is in flight.
            final errorText = context.l10n.commonSomethingWentWrong;
            final outcome = await actionsCubit.removeConversation(
              conversation.id,
            );
            switch (outcome) {
              case RemoveConversationOutcome.removed:
                messenger.showSnackBar(
                  SnackBar(content: Text(removedText)),
                );
              case RemoveConversationOutcome.refused:
                messenger.showSnackBar(
                  SnackBar(content: Text(refusedText)),
                );
              case RemoveConversationOutcome.failed:
                // Silence here reads as a mistap: the dialog closes and the
                // row is still there. Both sibling surfaces already say so
                // (`request_preview_view`, `message_requests_view`), and a
                // failure must not be mistaken for the refusal above — that
                // one is the guard working, this one is Drift throwing.
                messenger.showSnackBar(
                  DivineSnackbarContainer.snackBar(errorText, error: true),
                );
            }
          }
      }
    } finally {
      if (mounted) {
        setState(() => _highlightedConversationId = null);
      }
    }
  }

  Future<bool> _confirmRemove(
    BuildContext context,
    String displayName, {
    required bool isVanished,
    required bool isGroup,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.vineColors.card,
        title: Text(
          context.l10n.inboxRemoveConfirmTitle,
          style: VineTheme.titleLargeFont(
            color: context.vineColors.primaryText,
          ),
        ),
        content: Text(
          // The 1:1 body says "your conversation with {displayName}". A group
          // title is the room's name, not a person, so that template would
          // read as a conversation with the room — name nobody instead, the
          // way the vanished body already does.
          switch ((isGroup, isVanished)) {
            (true, _) => context.l10n.inboxRemoveConfirmBodyGroup,
            (false, true) => context.l10n.inboxRemoveConfirmBodyVanishedAccount,
            (false, false) => context.l10n.inboxRemoveConfirmBody(displayName),
          },
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.secondaryText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.popModalIfMounted(false),
            child: Text(
              context.l10n.commonCancel,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.popModalIfMounted(true),
            child: Text(
              context.l10n.inboxRemoveConfirmConfirm,
              style: VineTheme.bodyMediumFont(color: VineTheme.error),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// Shown when an active filter (Unread chip or search) leaves nothing to
/// list, confirming the list is not empty by accident.
///
/// The requests banner is emitted as its own sliver above this, so it stays
/// reachable without this widget having to lay it out.
class _FilteredEmptyContent extends StatelessWidget {
  const _FilteredEmptyContent({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Text(
              title,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.onSurfaceMuted,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.onSurfaceMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pinned header carrying [InboxFilterChips].
///
/// Pinned rather than scrolled away so the user can always drop back to All
/// after narrowing to Unread without hunting for the chip. Opaque, because the
/// conversation list scrolls underneath it.
///
/// Rendered through [PinnedHeaderSliver] rather than a
/// [SliverPersistentHeaderDelegate] on purpose, the same way
/// `sound_detail_screen.dart` does: a delegate has to declare its extent
/// before its child is laid out, and a header that ends up shorter than that
/// extent makes `layoutExtent` exceed `paintExtent`. The sliver then fails
/// layout, every sliver after it keeps a null geometry, and paint reports it
/// as "Null check operator used on a null value" against the enclosing
/// [CustomScrollView] — a blank Messages pane. The chips' height comes from
/// font metrics that snap to whole pixels, while any declared extent is
/// arithmetic over `textScaler.scale(...)`, so the two diverged at eleven of
/// iOS's twelve Dynamic Type sizes: six blanked the pane and five clipped the
/// chips, leaving only the default correct (#7854). [PinnedHeaderSliver]
/// measures the child, so there is nothing to keep in sync.
class _FilterChipsHeader extends StatelessWidget {
  const _FilterChipsHeader({
    required this.selected,
    required this.hasBlocked,
    required this.onChanged,
  });

  final InboxFilter selected;
  final bool hasBlocked;
  final ValueChanged<InboxFilter> onChanged;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.vineColors.surfaceContainerHigh,
    child: InboxFilterChips(
      selected: selected,
      hasBlocked: hasBlocked,
      onChanged: onChanged,
    ),
  );
}
