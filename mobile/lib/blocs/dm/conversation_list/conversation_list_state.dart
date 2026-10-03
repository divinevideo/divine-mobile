// ABOUTME: State for ConversationListBloc.

part of 'conversation_list_bloc.dart';

enum ConversationListStatus { initial, loading, loaded, error }

/// Which slice of the Messages tab the chip row is showing.
///
/// An enum rather than a pair of bools because the set is expected to grow:
/// a Muted filter is the anticipated next case once muting exists as a user
/// action (today `ContentBlocklistRepository.isMutedByUs` only reflects mutes
/// authored from other Nostr clients). Adding a case means a new source list
/// in `_computeVisible` and a new chip — no call-site churn.
enum InboxFilter {
  /// Every conversation except those with accounts the viewer blocked.
  all,

  /// [all], narrowed to conversations with unread messages.
  unread,

  /// Conversations with accounts the viewer blocked — the only surface that
  /// shows them, so a block never costs the viewer their own message history.
  blocked,
}

/// Navigation target emitted when the user requests to open a conversation.
///
/// Consumed and cleared by the UI after navigating.
class ConversationNavigationTarget extends Equatable {
  const ConversationNavigationTarget({
    required this.conversationId,
    required this.participantPubkeys,
  });

  final String conversationId;
  final List<String> participantPubkeys;

  @override
  List<Object?> get props => [conversationId, participantPubkeys];
}

/// The pinned Divine Moderation support row (#6283).
///
/// The protected-minor inbound gate still withholds this: a restricted minor
/// whose approval was revoked gets no pin rather than a row the conversation
/// route guard would bounce (#176). Blocking the moderation account does not —
/// that is a user preference, the guard never consults the blocklist, and the
/// pin staying reachable is the point of #7850.
class PinnedSupport extends Equatable {
  const PinnedSupport({required this.conversation, required this.isPersisted});

  /// Either the adopted moderation thread — carrying its real unread state and
  /// last message — or a synthetic stand-in on the same conversation id.
  final DmConversation conversation;

  /// Whether [conversation] is a row that actually exists in the database.
  ///
  /// Gates the row's long-press actions: removing a thread that has never
  /// been written is a no-op the confirmation snackbar would misreport.
  final bool isPersisted;

  @override
  List<Object?> get props => [conversation, isPersisted];
}

class ConversationListState extends Equatable {
  const ConversationListState({
    this.status = ConversationListStatus.initial,
    this.conversations = const [],
    this.visibleConversations = const [],
    this.blockedConversations = const [],
    this.filter = InboxFilter.all,
    this.searchQuery = '',
    this.profileNames = const {},
    this.vanishedPubkeys = const {},
    this.peerLabels,
    this.requestConversations = const [],
    this.potentialRequests = const [],
    this.hasMore = true,
    this.isRestoringHistory = false,
    this.requestsWithheld = false,
    this.currentLimit = ConversationListState.pageSize,
    this.navigationTarget,
    this.pinnedSupport,
  });

  /// Number of conversations loaded per page.
  static const pageSize = 20;

  final ConversationListStatus status;

  /// The COMPLETE set of conversations for the Messages tab (accepted +
  /// followed contacts), unpaginated.
  ///
  /// Holding the full set is what lets the unread chip and search answer about
  /// the whole inbox instead of the loaded page.
  final List<DmConversation> conversations;

  /// The rendered slice of [conversations]: filtered when a filter is active,
  /// otherwise windowed to [currentLimit].
  ///
  /// A filter result is never windowed — it is already complete, so it can be
  /// shorter than a page without meaning "there might be more".
  ///
  /// Stored (not derived via a getter) so `context.select` sees a stable
  /// list identity across unrelated state emits.
  final List<DmConversation> visibleConversations;

  /// Conversations with accounts the viewer has blocked, newest first.
  ///
  /// Held rather than dropped so [InboxFilter.blocked] has something to render.
  /// Blocking removes a thread from the inbox but must never remove the
  /// viewer's own copy of it — a harasser would otherwise be able to make the
  /// evidence unreachable simply by being blocked. Seeded from
  /// `runtimeBlockedUsers`, so a blocked account the viewer never messaged is
  /// present too, carrying no last message.
  final List<DmConversation> blockedConversations;

  /// Which slice of the Messages list the chip row is showing.
  final InboxFilter filter;

  /// Trimmed inbox search query; empty when search is inactive.
  final String searchQuery;

  /// Resolved display names by counterparty pubkey, used for search
  /// matching. Grows lazily the first time a query needs a name.
  ///
  /// A step-4 value only — the kind-0 name, or the generated fallback when
  /// there is none. The vanished and moderation branches that outrank it are
  /// applied by [dmPeerName] at match time, never baked in here.
  final Map<String, String> profileNames;

  /// Counterparties that published a NIP-62 request to vanish.
  ///
  /// A live view of the durable `vanished_profiles` table, which is the same
  /// source `ConversationTile` renders from. Search has to read it rather than
  /// sample `ProfileRepository.isVanished`, or the index names an account the
  /// row on screen contradicts (#8204).
  final Set<String> vanishedPubkeys;

  /// Localized substitutes for a peer whose own name must not be shown.
  ///
  /// Null until the inbox delivers them, and re-delivered when the app locale
  /// changes; matching falls back to the generated name in the meantime.
  final DmPeerLabels? peerLabels;

  /// Conversations shown in the Requests tab (non-followed, never replied).
  final List<DmConversation> requestConversations;

  /// Raw potential requests from DB (`currentUserHasSent == false`).
  ///
  /// Stored so that follow-list changes can re-split without a DB query.
  final List<DmConversation> potentialRequests;

  /// Whether [conversations] holds more rows than the current render window.
  ///
  /// Exact, not a heuristic: the full set is loaded, so this is a comparison
  /// against [currentLimit] rather than a guess from a truncated page.
  final bool hasMore;

  /// Whether a one-time DM history recovery (reinstall backfill / failed-
  /// decrypt replay) is actively running. Drives the restore progress
  /// indicator at the top of the Messages list. See #5202.
  final bool isRestoringHistory;

  /// Whether the #5304 recovery gate is currently hiding conversations that
  /// would otherwise appear as message requests.
  ///
  /// Distinct from [isRestoringHistory] on purpose. That flag tracks whether a
  /// drain is *actively running* (`_activeRecoveryOps > 0`), but the gate reads
  /// the *persisted* completion record, which only ever flips on a clean
  /// exhaustion. A drain that stops at the page cap, hits an exception, or
  /// finds no connected relay clears the running flag while leaving the gate
  /// shut — so the progress bar vanished while requests stayed hidden, with no
  /// banner, no badge and no spinner to show anything was missing. Drives the
  /// restore-paused banner, which offers the retry that reopens the gate.
  ///
  /// Only a first-ever drain can shut the gate. A forced recovery pass on an
  /// install that completed one before keeps it open: that install already
  /// holds its own replies, so nothing would be misclassified, and the banner
  /// read as lost chats to users who had lost nothing (#8550).
  final bool requestsWithheld;

  /// Size of the render window over [conversations] — grows as the user pages.
  ///
  /// Not a fetch bound: the conversations are already loaded in full, so
  /// growing this is a pure re-slice with no query and no spinner.
  final int currentLimit;

  /// Set when the user requests navigation to a specific conversation.
  /// Consumed and cleared by the UI after navigating.
  final ConversationNavigationTarget? navigationTarget;

  /// The pinned Divine Moderation support row, or null when it should not
  /// render (#6283). An adopted thread is removed from [conversations] and
  /// [requestConversations], so the inbox never shows moderation twice.
  final PinnedSupport? pinnedSupport;

  /// Number of unread message requests.
  int get requestUnreadCount =>
      requestConversations.where((c) => !c.isRead).length;

  /// Whether a client-side filter (a chip other than All, or search) is
  /// narrowing the visible list.
  ///
  /// Load-more is suspended while this is true: a filtered result is computed
  /// over the full conversation set and is therefore already complete, so
  /// growing the render window could only append unfiltered rows — and a short
  /// filtered list can never scroll far enough to trigger it anyway. The
  /// blocked slice is complete for the same reason, and is never windowed.
  bool get isFiltering => filter != InboxFilter.all || searchQuery.isNotEmpty;

  ConversationListState copyWith({
    ConversationListStatus? status,
    List<DmConversation>? conversations,
    List<DmConversation>? visibleConversations,
    List<DmConversation>? blockedConversations,
    InboxFilter? filter,
    String? searchQuery,
    Map<String, String>? profileNames,
    Set<String>? vanishedPubkeys,
    DmPeerLabels? peerLabels,
    List<DmConversation>? requestConversations,
    List<DmConversation>? potentialRequests,
    bool? hasMore,
    bool? isRestoringHistory,
    bool? requestsWithheld,
    int? currentLimit,
    ConversationNavigationTarget? navigationTarget,
    bool clearNavigationTarget = false,
    PinnedSupport? pinnedSupport,
    bool clearPinnedSupport = false,
  }) {
    return ConversationListState(
      status: status ?? this.status,
      conversations: conversations ?? this.conversations,
      visibleConversations: visibleConversations ?? this.visibleConversations,
      blockedConversations: blockedConversations ?? this.blockedConversations,
      filter: filter ?? this.filter,
      searchQuery: searchQuery ?? this.searchQuery,
      profileNames: profileNames ?? this.profileNames,
      vanishedPubkeys: vanishedPubkeys ?? this.vanishedPubkeys,
      peerLabels: peerLabels ?? this.peerLabels,
      requestConversations: requestConversations ?? this.requestConversations,
      potentialRequests: potentialRequests ?? this.potentialRequests,
      hasMore: hasMore ?? this.hasMore,
      isRestoringHistory: isRestoringHistory ?? this.isRestoringHistory,
      requestsWithheld: requestsWithheld ?? this.requestsWithheld,
      currentLimit: currentLimit ?? this.currentLimit,
      navigationTarget: clearNavigationTarget
          ? null
          : navigationTarget ?? this.navigationTarget,
      pinnedSupport: clearPinnedSupport
          ? null
          : pinnedSupport ?? this.pinnedSupport,
    );
  }

  @override
  List<Object?> get props => [
    status,
    conversations,
    visibleConversations,
    blockedConversations,
    filter,
    searchQuery,
    profileNames,
    vanishedPubkeys,
    peerLabels,
    requestConversations,
    potentialRequests,
    hasMore,
    isRestoringHistory,
    requestsWithheld,
    currentLimit,
    navigationTarget,
    pinnedSupport,
  ];
}
