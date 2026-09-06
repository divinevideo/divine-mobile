// ABOUTME: Main view for a single DM conversation.
// ABOUTME: Displays grouped message bubbles and a bottom input bar.

import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart' show DmRepository;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow_repository/follow_repository.dart'
    show FollowRelationship;
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';
import 'package:openvine/blocs/dm/dm_thread_writability.dart';
import 'package:openvine/blocs/dm/reactions/conversation_reactions_cubit.dart';
import 'package:openvine/blocs/dm/restore_status/dm_restore_status_cubit.dart';
import 'package:openvine/blocs/dm/shared_video_save/shared_video_save_cubit.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/follow_relationship_provider.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/feed/dm_reply_context.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/conversation/dm_video_target.dart';
import 'package:openvine/screens/inbox/conversation/widgets/widgets.dart';
import 'package:openvine/screens/inbox/widgets/dm_peer_identity.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/services/collaborator_invite_parser.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/utils/clipboard_utils.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/utils/user_identifier_line_resolver.dart';
import 'package:openvine/widgets/profile/more_sheet/more_sheet_content.dart';
import 'package:openvine/widgets/profile/more_sheet/more_sheet_result.dart';
import 'package:openvine/widgets/report_content_dialog.dart';
import 'package:openvine/widgets/save_original_progress_sheet.dart';
import 'package:openvine/widgets/watermark_download_progress_sheet.dart';
import 'package:unified_logger/unified_logger.dart';

/// View for a single DM conversation.
///
/// Reads the [ConversationBloc] from the widget tree and renders messages
/// in a reverse-scrolling list with a bottom input bar.
///
/// Uses [BlocSelector] for child widgets that depend on specific slices of
/// [ConversationState] to avoid unnecessary rebuilds.
class ConversationView extends ConsumerStatefulWidget {
  const ConversationView({
    required this.participantPubkeys,
    this.subject,
    super.key,
  });

  /// Pubkeys of the other participants (excludes current user).
  final List<String> participantPubkeys;
  final String? subject;

  @override
  ConsumerState<ConversationView> createState() => _ConversationViewState();
}

/// The choice made on the recovery bottom sheet opened by
/// [_ConversationViewState._onFailedMessageTap].
enum _FailedMessageAction { resend, delete }

class _ConversationViewState extends ConsumerState<ConversationView> {
  bool _isOpeningOptions = false;

  /// The account this thread addresses. The route passes `participantPubkeys`
  /// as the counterparty list, so self is already excluded.
  String get _otherPubkey => widget.participantPubkeys.isNotEmpty
      ? widget.participantPubkeys.first
      : '';

  void _showSnackbar(String message, {required bool error}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(DivineSnackbarContainer.snackBar(message, error: error));
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  Future<void> _onOptions(String otherPubkey) async {
    if (otherPubkey.isEmpty || _isOpeningOptions) return;
    _isOpeningOptions = true;
    // Self is already excluded from the route's counterparty list, so more
    // than one of them is a group.
    final isGroup = widget.participantPubkeys.length > 1;
    try {
      bool isVanished;
      try {
        isVanished = await ref.read(
          profileVanishedSnapshotProvider(otherPubkey).future,
        );
      } catch (error, stackTrace) {
        Log.warning(
          'Could not read durable vanish state; opening conversation options '
          'with the live-account identity fallback',
          name: 'ConversationView',
          category: LogCategory.ui,
          error: error,
          stackTrace: stackTrace,
        );
        isVanished = false;
      }
      if (!mounted) return;

      final String displayName;
      final knownName = dmPeerNameWithoutProfile(
        context,
        pubkeyHex: otherPubkey,
        isVanished: isVanished,
      );
      if (knownName != null) {
        displayName = knownName;
      } else {
        UserProfile? profile;
        try {
          profile = await ref.read(
            fetchUserProfileProvider(otherPubkey).future,
          );
        } catch (error, stackTrace) {
          Log.warning(
            'Could not read the conversation peer profile; opening '
            'conversation options with the generated identity fallback',
            name: 'ConversationView',
            category: LogCategory.ui,
            error: error,
            stackTrace: stackTrace,
          );
        }
        if (!mounted) return;
        displayName = dmPeerDisplayName(
          context,
          pubkeyHex: otherPubkey,
          isVanished: isVanished,
          profile: profile,
        );
      }

      final blocklistRepository = ref.read(contentBlocklistRepositoryProvider);
      final followRepository = ref.read(followRepositoryProvider);
      final isBlocked = blocklistRepository.isBlocked(otherPubkey);
      final isFollowing = followRepository.isFollowing(otherPubkey);

      final result = await VineBottomSheet.show<MoreSheetResult>(
        context: context,
        expanded: false,
        scrollable: false,
        isScrollControlled: true,
        body: MoreSheetContent(
          userIdHex: otherPubkey,
          displayName: displayName,
          isFollowing: isFollowing,
          isBlocked: isBlocked,
          // Same rule as the inbox action sheet: Report and Block take one
          // account, and `otherPubkey` on a group is whichever member sorted
          // first — so offering them under a room's name reads as dealing
          // with the thread while acting on a stranger. Copy, Unfollow and
          // Add to list stay: each plainly names the person it affects and
          // none implies the thread stops. An individual is still reportable
          // and blockable from their own profile.
          showReport: !isGroup,
          showBlock: !isGroup,
          // Hidden for a group too: this sheet has no room identity to copy,
          // and `otherPubkey` is an arbitrary member.
          showCopy: !isGroup,
        ),
        children: const [],
      );

      if (!mounted || result == null) return;

      switch (result) {
        case MoreSheetResult.copy:
          final npub = NostrKeyUtils.encodePubKey(otherPubkey);
          await ClipboardUtils.copyPubkey(context, npub);
        case MoreSheetResult.unfollow:
          await followRepository.toggleFollow(otherPubkey);
        case MoreSheetResult.report:
          if (!mounted) return;
          await ReportContentDialog.showForUser(
            context,
            userPubkey: otherPubkey,
          );
        case MoreSheetResult.blockConfirmed:
          await blocklistRepository.blockUser(
            otherPubkey,
            ourPubkey: ref.read(authServiceProvider).currentPublicKeyHex ?? '',
          );
          if (mounted) context.pop();
        case MoreSheetResult.unblockConfirmed:
          await blocklistRepository.unblockUser(otherPubkey);
        case MoreSheetResult.addToList:
          // addToList is not surfaced from this caller (showAddToList defaults
          // to false on MoreSheetContent here), so this branch is unreachable.
          break;
      }
    } finally {
      _isOpeningOptions = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex ?? '';

    // Reactors to hide from the reaction pill + who-reacted sheet: the
    // repository's DM-hide set (blocked ∪ muted), the same union
    // `shouldFilterFromDms` enforces across DM surfaces. Deliberately not
    // `feedHiddenPubkeys`, which also carries muted-by and blocked-by — a
    // third party must not be able to strip reactions out of the viewer's own
    // thread by publishing a list (#7345).
    // Watching blocklistVersionProvider rebuilds this view — re-reading the
    // set and re-passing it to every ReactionsRow — on any block/unblock/mute
    // change while the thread is open.
    ref.watch(blocklistVersionProvider);
    final blocklistRepository = ref.read(contentBlocklistRepositoryProvider);
    final blockedReactors = blocklistRepository.dmHiddenPubkeys;

    // A thread reached from the Blocked chip is readable but not writable:
    // the block stays in force, so the composer and the reaction affordance
    // both go. Reading and screenshotting is the point (#7025); replying
    // would undo the block the viewer deliberately set. Rebuilds off the
    // `blocklistVersionProvider` watch above, so unblocking from the kebab
    // brings the composer straight back.
    // Resolve other participant's profile for the app bar + empty state
    final otherPubkey = _otherPubkey;
    final threadWritability = resolveDmThreadWritability(
      participantPubkeys: widget.participantPubkeys,
      isBlockedByUs: blocklistRepository.isBlocked,
    );
    final isBlockedByUs = threadWritability == DmThreadWritability.blockedByUs;
    final isRetiredModerationThread =
        threadWritability == DmThreadWritability.closedRetired;
    final profileAsync = ref.watch(fetchUserProfileProvider(otherPubkey));
    final profile = profileAsync.asData?.value;
    final isResolving = ref.watch(
      profileIdentityResolvingProvider(otherPubkey),
    );
    // The conversation and its history remain readable — they are the viewer's
    // own copy of messages a NIP-62 vanish cannot retract. Only the header
    // identity changes.
    final isDeleted = ref.watch(profileVanishedProvider(otherPubkey));
    final displayName = dmPeerDisplayName(
      context,
      pubkeyHex: otherPubkey,
      isVanished: isDeleted,
      profile: profile,
      isResolving: isResolving,
    );
    final isGroup = widget.participantPubkeys.length > 1;
    final conversationDisplayName = dmConversationDisplayTitle(
      context,
      participantPubkeys: [currentPubkey, ...widget.participantPubkeys],
      currentUserPubkey: currentPubkey,
      isGroup: isGroup,
      peerName: displayName,
      subject: widget.subject,
    );
    // Derived from the room title, not the peer name: a titled group resolves
    // without a profile and must not skeleton, while an untitled one is named
    // for its peer and must.
    final isIdentityResolving = isResolving && conversationDisplayName.isEmpty;
    final visualDisplayName = conversationDisplayName.isEmpty
        ? UserProfile.defaultDisplayNameFor(otherPubkey)
        : conversationDisplayName;
    final claimedNip05 = profile?.shortDisplayNip05;
    final verificationStatus = claimedNip05 != null && claimedNip05.isNotEmpty
        ? ref
              .watch(nip05VerificationProvider(otherPubkey))
              .whenOrNull(data: (status) => status)
        : null;
    // Counts live in the `profile_statistics` store, not on the profile.
    // `UserProfile.restFollowerCount` reads `rawData['follower_count']`, which
    // only the people-search shape ever writes and which is never persisted to
    // the cache this screen reads — so it was permanently null here and the
    // social-proof fallback never fired (#8403). The repository routes
    // `GET /api/users/{pubkey}`'s `social` block into `profile_statistics`
    // instead. A vanished account takes the branch below and never reaches the
    // resolver; `fetchFreshProfile` short-circuits for it in any case.
    final followerCount = ref
        .watch(userProfileStatsReactiveProvider(otherPubkey))
        .asData
        ?.value
        ?.followers;

    // Prefer the profile's NIP-05 / divine handle when set, otherwise the
    // follow relationship — which tells the viewer which of several
    // same-named people they are messaging, as a truncated npub never did.
    final handle = isDeleted
        ? context.l10n.inboxConversationDeletedAccountSubtitle
        : resolveUserIdentifierLine(
                l10n: context.l10n,
                locale: Localizations.localeOf(context).toLanguageTag(),
                handle: claimedNip05,
                verificationStatus: verificationStatus,
                relationship:
                    ref.watch(followRelationshipProvider(otherPubkey)).value ??
                    FollowRelationship.none,
                followerCount: followerCount,
              ) ??
              '';

    return BlocProvider(
      create: (_) => SharedVideoSaveCubit(
        videosRepository: ref.read(videosRepositoryProvider),
        profileRepository: ref.read(profileRepositoryProvider),
        currentPubkey: currentPubkey,
      ),
      child: BlocListener<SharedVideoSaveCubit, SharedVideoSaveState>(
        listener: _onSharedVideoSaveState,
        child: Scaffold(
          backgroundColor: context.vineColors.surface,
          body: MultiBlocListener(
            listeners: [
              BlocListener<ConversationBloc, ConversationState>(
                // A hard failure is shown on the bubble itself (tap → resend/delete),
                // so this listener only handles the toasts that have no bubble —
                // a policy block, a recipient-less send (#7335), and a partial
                // (self-wrap) delivery — plus a screen-reader announcement (no
                // toast) for hard failures, since the red in-bubble row is silent
                // to assistive tech until focused.
                // Also fire on a sentPartial → sentPartial transition whose rumor-id
                // set changed: with concurrent() sends, a second overlapping partial
                // keeps the same sendStatus and would otherwise never surface its
                // recovery snackbar.
                listenWhen: (previous, current) =>
                    (previous.sendStatus != current.sendStatus ||
                        (current.sendStatus == SendStatus.sentPartial &&
                            previous.lastPartialSend !=
                                current.lastPartialSend)) &&
                    (current.sendStatus == SendStatus.sentPartial ||
                        current.sendStatus == SendStatus.blocked ||
                        current.sendStatus == SendStatus.noRecipient ||
                        current.sendStatus == SendStatus.resendFailed ||
                        current.sendStatus == SendStatus.tooLong ||
                        current.sendStatus == SendStatus.failed),
                listener: _onSendOutcome,
              ),
              BlocListener<ConversationBloc, ConversationState>(
                // A shrink can mean refusal or confirmed delivery. Announce
                // only removed ids whose bubble is still visible as failed;
                // confirmed retractions leave the thread silently.
                listenWhen: (previous, current) {
                  final removed = previous.awaitingRetraction.difference(
                    current.awaitingRetraction,
                  );
                  return current.messages.any(
                    (message) =>
                        removed.contains(message.id) &&
                        message.retractionStatus == DmRetractionStatus.failed,
                  );
                },
                listener: _onRetractionRefused,
              ),
              BlocListener<
                ConversationReactionsCubit,
                ConversationReactionsState
              >(
                listenWhen: (previous, current) {
                  return previous.removalRetries != current.removalRetries &&
                      current.removalRetries.values.any(
                        (status) =>
                            status !=
                                ReactionRemovalRetryLocalStatus.retrying &&
                            status != ReactionRemovalRetryLocalStatus.sent,
                      );
                },
                listener: (_, _) => _showSnackbar(
                  context.l10n.dmReactionRemovalRefusedTitle,
                  error: true,
                ),
              ),
              BlocListener<
                ConversationReactionsCubit,
                ConversationReactionsState
              >(
                listenWhen: (previous, current) =>
                    previous.blockedReactionAttempts !=
                    current.blockedReactionAttempts,
                listener: (_, _) => _showSnackbar(
                  context.l10n.dmReactionAddBlockedByRemoval,
                  error: true,
                ),
              ),
            ],
            child: Column(
              children: [
                // Wrap the AppBar + messages region in a Listener so any
                // tap above the input bar — back button, title, options,
                // dead space in the messages area, a MessageBubble —
                // dismisses the keyboard before any navigation or sheet
                // animation begins. The `_SendBar` is intentionally
                // OUTSIDE this Listener: wrapping the input would
                // `unfocus` on pointer-down and race with the TextField's
                // own focus request, producing a re-focus flicker on
                // every input tap.
                //
                // `Listener` catches pointer-downs without entering the
                // gesture arena, so descendant tap/long-press recognizers
                // (MessageBubble.onLongPress, ConversationAppBar's three
                // buttons) still resolve normally afterwards. Matches the
                // pattern shipped in `comments_list.dart`.
                Expanded(
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    child: Column(
                      children: [
                        ConversationAppBar(
                          displayName: conversationDisplayName,
                          isResolving: isIdentityResolving,
                          loadingDisplayName: visualDisplayName,
                          handle: handle,
                          onBack: () => context.pop(),
                          onTitleTap: otherPubkey.isNotEmpty
                              ? () => context.push(
                                  '${OtherProfileScreen.path}/${NostrKeyUtils.encodePubKey(otherPubkey)}',
                                )
                              : null,
                          onOptions: () => _onOptions(otherPubkey),
                        ),
                        Expanded(
                          // Force the messages card to fill the available width
                          // regardless of its content. Without this, the empty /
                          // loading state's SingleChildScrollView shrink-wraps the
                          // ClipRRect down to the EmptyConversation column's
                          // intrinsic width and the surface card renders as a
                          // narrow strip; the ListView (with messages) is fine on
                          // its own.
                          child: SizedBox(
                            width: double.infinity,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: ColoredBox(
                                color: context.vineColors.surfaceContainerHigh,
                                child: _ConversationContent(
                                  currentPubkey: currentPubkey,
                                  otherPubkey: otherPubkey,
                                  participantPubkeys: widget.participantPubkeys,
                                  blockedPubkeys: blockedReactors,
                                  displayName: conversationDisplayName,
                                  isResolving: isIdentityResolving,
                                  reactionsEnabled:
                                      !isRetiredModerationThread &&
                                      !isBlockedByUs,
                                  retractionsEnabled:
                                      !isRetiredModerationThread,
                                  sendRecoveryEnabled:
                                      !isRetiredModerationThread &&
                                      !isBlockedByUs,
                                  imageUrl: isDeleted ? null : profile?.picture,
                                  nip05: isDeleted
                                      ? null
                                      : profile?.shortDisplayNip05,
                                  onViewProfile: () {
                                    final npub = NostrKeyUtils.encodePubKey(
                                      otherPubkey,
                                    );
                                    context.push(
                                      '${OtherProfileScreen.path}/$npub',
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isRetiredModerationThread)
                  _ClosedThreadNotice(currentPubkey: currentPubkey)
                else if (isBlockedByUs)
                  const _BlockedThreadNotice()
                else
                  _SendBar(participantPubkeys: widget.participantPubkeys),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onSharedVideoSaveState(
    BuildContext context,
    SharedVideoSaveState state,
  ) async {
    switch (state.status) {
      case SharedVideoSaveStatus.idle:
        return;
      case SharedVideoSaveStatus.resolving:
        _showSnackbar(context.l10n.libraryPreparingVideo, error: false);
        return;
      case SharedVideoSaveStatus.unavailable:
        _showSnackbar(context.l10n.notificationsVideoUnavailable, error: true);
        context.read<SharedVideoSaveCubit>().reset();
        return;
      case SharedVideoSaveStatus.originalReady:
        final video = state.video;
        if (video == null) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        await showSaveOriginalSheet(context: context, ref: ref, video: video);
        if (context.mounted) context.read<SharedVideoSaveCubit>().reset();
        return;
      case SharedVideoSaveStatus.watermarkReady:
        final video = state.video;
        final watermarkText = state.watermarkText;
        if (video == null || watermarkText == null) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        await showWatermarkDownloadSheet(
          context: context,
          ref: ref,
          video: video,
          watermarkText: watermarkText,
        );
        if (context.mounted) context.read<SharedVideoSaveCubit>().reset();
        return;
    }
  }

  /// Briefly announces an unconfirmed "Delete for everyone" (#8201).
  ///
  /// The durable affordance is the warning beside the visible bubble; this
  /// toast is only immediate feedback and dismisses on the standard timer.
  void _onRetractionRefused(BuildContext context, ConversationState state) {
    _showErrorToastAndAnnounce(context, context.l10n.dmDeleteRefusedMessage);
  }

  void _onSendOutcome(BuildContext context, ConversationState state) {
    final l10n = context.l10n;

    // The send was refused by policy (#176, #6416). No bubble is created for a
    // blocked send, so surface it as a toast (no retry — retrying only re-hits
    // the same block). The reason is re-derived from the peer rather than
    // carried in state: `DmSendPolicyDecision` deliberately does not name it,
    // so that `dm_repository` stays free of Divine's policy semantics.
    if (state.sendStatus == SendStatus.blocked) {
      final message = isRetiredModerationAccount(_otherPubkey)
          ? l10n.dmSendBlockedRetiredMessage
          : l10n.dmSendBlockedMessage;
      _showErrorToastAndAnnounce(context, message);
      return;
    }

    // Nobody to send to (#7335). Like a block, this is refused before a queue
    // row exists, so there is no bubble to carry it — and unlike a block, the
    // thread itself is the broken thing, so the copy points back at the inbox
    // rather than at the peer. No retry: the same tap re-hits the same empty
    // participant list.
    if (state.sendStatus == SendStatus.noRecipient) {
      final message = l10n.dmSendNoRecipientMessage;
      _showErrorToastAndAnnounce(context, message);
      return;
    }

    // Oversized rumor (#7331). Refused before the enqueue for the same reason
    // as the two above — a hard-failed row would be re-driven by the retry
    // sweep against content that can never succeed — so there is no bubble to
    // carry it. `_SendBar` puts the text back in the composer, and this names
    // the reason so the user knows shortening is the fix.
    if (state.sendStatus == SendStatus.tooLong) {
      _showErrorToastAndAnnounce(context, l10n.dmSendTooLongMessage);
      return;
    }

    // A resend that failed again (#8461). The bubble was already red when the
    // user tapped it, so — unlike the first-send case below — turning it red
    // is not a state change and the tap would otherwise produce no visible
    // result at all. Toast it so the attempt is legible; the bubble stays red
    // and re-tappable, and `resetRetryBudget` has re-armed the sweep.
    if (state.sendStatus == SendStatus.resendFailed) {
      final message = l10n.dmResendFailedMessage;
      _showErrorToastAndAnnounce(context, message);
      return;
    }

    // Hard failure: the red "Not delivered" row on the bubble is the visual
    // affordance, so no toast — but announce it, per `accessibility.md`,
    // because the bubble's state change is silent to assistive tech.
    if (state.sendStatus == SendStatus.failed) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        l10n.dmSendFailedMessage,
        Directionality.of(context),
      );
      return;
    }

    // Partial delivery (#4102): the recipient got the message but our
    // self-addressed wrap didn't land, so it won't sync to our other devices.
    // Not a failure (the bubble shows delivered) — a one-tap self-wrap-only
    // recovery. Hard failures are surfaced on the bubble itself, not here.
    final partialSend = state.lastPartialSend;
    if (partialSend == null) return;

    final message = l10n.dmSendPartialMessage;
    final bloc = context.read<ConversationBloc>();
    final messenger = ScaffoldMessenger.of(context);
    var handled = false;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        DivineSnackbarContainer.snackBar(
          message,
          actionLabel: l10n.dmSendFailedRetry,
          // One-shot + dismiss + closed-bloc guard: the snackbar can outlive
          // the route (and its bloc), and the plain buttons in
          // DivineSnackbarContainer neither auto-dismiss nor debounce.
          onActionPressed: () {
            if (handled || bloc.isClosed) return;
            handled = true;
            messenger.hideCurrentSnackBar();
            bloc.add(
              ConversationSelfWrapRecoveryRequested(
                rumorIds: partialSend.rumorIds,
              ),
            );
          },
        ),
      );
    // Per `accessibility.md`, async visible state changes must announce
    // explicitly — Material's default SnackBar semantics are weaker than the
    // written rule and not guaranteed across platforms.
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  void _showErrorToastAndAnnounce(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(DivineSnackbarContainer.snackBar(message, error: true));
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }
}

/// Renders [MessageInputBar]. Deliberately NOT gated on
/// [ConversationState.sendStatus]: sends are optimistic (the bubble comes
/// from the durable queue row the instant the event is dispatched), and the
/// OK-confirmed publish can legitimately run for tens of seconds on a slow
/// relay or remote signer — freezing the composer for that window swallowed
/// every follow-up message the user tried to type.
class _SendBar extends StatefulWidget {
  const _SendBar({required this.participantPubkeys});

  final List<String> participantPubkeys;

  @override
  State<_SendBar> createState() => _SendBarState();
}

class _SendBarState extends State<_SendBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // An oversized rumor is refused before the enqueue, so it leaves no queue
    // row and no bubble to carry the failure (#7331). The bar has already
    // cleared itself by then, so put the text back: it is the only copy the
    // user has, and the fix they need is to shorten it.
    return BlocListener<ConversationBloc, ConversationState>(
      listenWhen: (previous, current) =>
          previous.sendStatus != current.sendStatus &&
          current.sendStatus == SendStatus.tooLong,
      listener: (context, state) {
        final rejected = _lastSubmitted;
        if (rejected == null || _controller.text.isNotEmpty) return;
        _controller.value = TextEditingValue(
          text: rejected,
          selection: TextSelection.collapsed(offset: rejected.length),
        );
      },
      child: MessageInputBar(
        controller: _controller,
        onSend: (text) {
          _lastSubmitted = text;
          context.read<ConversationBloc>().add(
            ConversationMessageSent(
              recipientPubkeys: widget.participantPubkeys,
              content: text,
            ),
          );
        },
      ),
    );
  }

  String? _lastSubmitted;
}

/// Takes the composer's place in a thread keyed on a retired moderation
/// account, and offers the current one instead (#6416).
///
/// Nothing has read those keys since the rotation, so the composer was a silent
/// dead end: the gift wrap published, the bubble turned green, and the message
/// reached nobody. Worst on an enforcement notice, whose own copy invites a
/// reply as the appeal channel.
///
/// Replaces [MessageInputBar] rather than disabling it. `MessageInputBar` has
/// no disabled state, and adding one would leave a focusable text field that
/// still reads as "maybe this works".
class _ClosedThreadNotice extends StatelessWidget {
  const _ClosedThreadNotice({required this.currentPubkey});

  final String currentPubkey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Matches the composer's slot geometry so the layout does not shift.
    return Container(
      color: context.vineColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text(
              l10n.dmRetiredThreadClosedTitle,
              style: VineTheme.titleSmallFont(
                color: context.vineColors.primaryText,
              ),
            ),
            Text(
              l10n.dmRetiredThreadClosedBody,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
            // `semanticLabel` is what makes this announce as a button:
            // `DivineButton` only wires `Semantics(button: true)` when it is
            // given one. The composer is gone here, so this is the screen's
            // only control and the only route to a moderation account that
            // reads — without the flag a screen reader gets a third line of
            // prose after the title and body, naming no way out.
            DivineButton(
              label: l10n.dmRetiredThreadOpenSupport,
              semanticLabel: l10n.dmRetiredThreadOpenSupport,
              type: DivineButtonType.secondary,
              expanded: true,
              onPressed: currentPubkey.isEmpty
                  ? null
                  : () => _openCurrentSupportThread(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the live moderation thread, replacing this route rather than
  /// stacking on it — backing out of the destination should reach the inbox,
  /// not return the user to the dead thread they were just moved off.
  ///
  /// The id is derived rather than looked up, so this works even when no
  /// current-key thread exists yet: `ConversationPage` renders an empty thread,
  /// which is the same state the pinned inbox row opens.
  void _openCurrentSupportThread(BuildContext context) {
    context.pushReplacement(
      ConversationPage.pathForId(
        DmRepository.computeConversationId([
          currentPubkey,
          kModerationPubkeyHex,
        ]),
      ),
      extra: const [kModerationPubkeyHex],
    );
  }
}

/// Takes the composer's place in a thread with an account the viewer blocked
/// (#7025).
///
/// The thread is reachable from the inbox's Blocked chip so the viewer can
/// read — and screenshot — what was already sent to them without lifting the
/// block, which would re-expose them to the person they blocked. The block is
/// still in force, so there is nothing to compose with.
///
/// Replaces [MessageInputBar] rather than disabling it, for the same reason
/// [_ClosedThreadNotice] does: the input has no disabled state, and a
/// focusable text field reads as "maybe this works".
///
/// Carries no action of its own — unblocking is in the app bar's more-sheet,
/// and that is the deliberate route back to replying.
class _BlockedThreadNotice extends StatelessWidget {
  const _BlockedThreadNotice();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Matches the composer's slot geometry so the layout does not shift.
    return Container(
      color: context.vineColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text(
              l10n.dmBlockedThreadTitle,
              style: VineTheme.titleSmallFont(
                color: context.vineColors.primaryText,
              ),
            ),
            Text(
              l10n.dmBlockedThreadBody,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selects status and messages from the bloc and switches between loading,
/// error, empty, and message-list states.
class _ConversationContent extends StatelessWidget {
  const _ConversationContent({
    required this.currentPubkey,
    required this.otherPubkey,
    required this.participantPubkeys,
    required this.blockedPubkeys,
    required this.displayName,
    required this.isResolving,
    required this.reactionsEnabled,
    required this.retractionsEnabled,
    required this.sendRecoveryEnabled,
    this.imageUrl,
    this.nip05,
    this.onViewProfile,
  });

  final String currentPubkey;
  final String otherPubkey;
  final List<String> participantPubkeys;

  /// Effective block/mute set; reactions from these pubkeys are hidden.
  final Set<String> blockedPubkeys;
  final String displayName;
  final bool isResolving;
  final bool reactionsEnabled;

  /// Whether the viewer may retract something already delivered here.
  final bool retractionsEnabled;

  /// Whether tapping a failed own bubble may offer to resend it.
  final bool sendRecoveryEnabled;
  final String? imageUrl;
  final String? nip05;
  final VoidCallback? onViewProfile;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      ConversationBloc,
      ConversationState,
      ({ConversationStatus status, List<DmMessage> messages})
    >(
      selector: (state) =>
          (status: state.status, messages: state.displayedMessages),
      builder: (context, selected) {
        return switch (selected.status) {
          ConversationStatus.initial || ConversationStatus.loading => Center(
            child: DivineCircularProgressIndicator(
              color: context.vineColors.accentPositive,
            ),
          ),
          ConversationStatus.error => Center(
            child: Text(
              context.l10n.dmConversationLoadError,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.onSurfaceMuted,
              ),
            ),
          ),
          ConversationStatus.loaded =>
            selected.messages.isEmpty
                ? EmptyConversation(
                    displayName: isResolving
                        ? UserProfile.defaultDisplayNameFor(otherPubkey)
                        : displayName,
                    pubkey: otherPubkey,
                    imageUrl: imageUrl,
                    nip05: nip05,
                    onViewProfile: onViewProfile,
                    isIdentityResolving: isResolving,
                    mayBeIncomplete: context.select<DmRestoreStatusCubit, bool>(
                      (cubit) => cubit.state.mayBeIncomplete,
                    ),
                  )
                : _MessageList(
                    messages: selected.messages,
                    currentPubkey: currentPubkey,
                    participantPubkeys: participantPubkeys,
                    blockedPubkeys: blockedPubkeys,
                    senderDisplayName: displayName,
                    reactionsEnabled: reactionsEnabled,
                    retractionsEnabled: retractionsEnabled,
                    sendRecoveryEnabled: sendRecoveryEnabled,
                  ),
        };
      },
    );
  }
}

/// The video reference to render as a compact quoted preview above a reply's
/// text: the parent shared-reel's video (resolved via `replyToId` from
/// [messagesById]), falling back to the reply's own self-carried citation when
/// the parent isn't in the local store (cross-device / reinstall). Returns
/// `null` when [message] is not a reply.
@visibleForTesting
DmSharedVideoRef? resolveQuotedVideoRef(
  DmMessage message,
  Map<String, DmMessage> messagesById,
) {
  final replyToId = message.replyToId;
  if (replyToId == null) return null;
  return messagesById[replyToId]?.sharedVideoRef ?? message.sharedVideoRef;
}

/// The video reference to render as [message]'s own full share card: its
/// `sharedVideoRef` only when it is NOT a reply. A reply that self-carries a
/// citation renders a compact quote (via [resolveQuotedVideoRef]) instead of
/// the full card, so this returns `null` for replies to keep the two paths
/// mutually exclusive.
@visibleForTesting
DmSharedVideoRef? resolveOwnShareVideoRef(DmMessage message) =>
    message.replyToId == null ? message.sharedVideoRef : null;

/// The emoji a double-tap-to-like publishes: the ❤️ that heads the DM quick
/// reaction row ([kDefaultDmReactionEmojis]), reused verbatim so a double-tap
/// and a picker ❤️ collapse to one reaction instead of two distinct rows
/// (there is no emoji normalization on the reaction path).
final String _doubleTapLikeEmoji = kDefaultDmReactionEmojis.first;

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.currentPubkey,
    required this.participantPubkeys,
    required this.blockedPubkeys,
    required this.senderDisplayName,
    required this.reactionsEnabled,
    required this.retractionsEnabled,
    required this.sendRecoveryEnabled,
  });

  final List<DmMessage> messages;
  final String currentPubkey;
  final List<String> participantPubkeys;

  /// Effective block/mute set; reactions from these pubkeys are hidden.
  final Set<String> blockedPubkeys;
  final String senderDisplayName;
  final bool reactionsEnabled;

  /// Whether the viewer may retract something this thread already delivered:
  /// "Delete for everyone" on an own bubble, and "Remove" on an own reaction
  /// in the reactions detail sheet.
  ///
  /// False on a retired moderation thread. Both retractions publish a NIP-09
  /// kind-5 through the same send path the composer uses, so `DmSendPolicy`
  /// refuses them for a retired recipient — but each one has *already* dropped
  /// the local row by then, so the message or reaction disappears for the
  /// viewer while the copy the recipient received before the rotation stays
  /// exactly where it was. A button reading "Delete for everyone" that deletes
  /// for one person is the same false success `[_ClosedThreadNotice]` removes
  /// the composer to avoid.
  ///
  /// Only the write goes. The bubble, the pill, and the detail sheet all stay
  /// readable — a closed thread is an archive, and the viewer keeps their own
  /// copy of an enforcement notice either way.
  final bool retractionsEnabled;

  /// Whether tapping a failed own bubble may offer to resend it (#7025).
  ///
  /// False in a thread with an account the viewer blocked, and on a retired
  /// moderation thread. Removing the composer is not enough on its own: a
  /// message that hard-failed before the block or rotation is still on screen
  /// as a red bubble, and its tap opens a recovery sheet whose primary action
  /// republishes the rumor. On a blocked thread that delivers a DM to the
  /// account the viewer blocked, from the one screen built to make that
  /// impossible. On a retired thread the send policy refuses the kind-14, so
  /// the resend is a dead affordance either way.
  ///
  /// This flag removes the affordance only — the bubble itself stays rendered,
  /// so the evidence is intact and nothing is force-deleted here. On a blocked
  /// thread that holds end to end, and unblocking restores the sheet along with
  /// the composer. On a retired thread a terminal queue state preserves the
  /// bubble without exposing a retry action.
  ///
  /// This closes the user-initiated path only. TODO(#7047): Decide whether a
  /// block cancels queued outgoing sends; the reconnect sweep still re-drives
  /// a failed row that is under `maxRetries`
  /// (`OutgoingDmsDao.getRetryableForOwner`).
  final bool sendRecoveryEnabled;

  Future<void> _onMessageLongPress(
    BuildContext context,
    DmMessage message,
    bool isSent,
    DmDeliveryStatus deliveryStatus,
    DmRetractionStatus retractionStatus,
    bool isPersisted,
  ) async {
    final videoTarget = resolveDmVideoTarget(
      content: StringUtils.sanitizeUtf16(message.content),
      sharedVideoRef: resolveOwnShareVideoRef(message),
    );
    // Reaction picker hidden on failed-send own DMs and messages whose
    // retraction is unresolved — reacting to a message the recipient may not
    // have is meaningless (#4633 round 25, #8201).
    // A failed bubble's resend/delete affordance lives on a single TAP
    // (see [_onFailedMessageTap]), not this long-press menu.
    final showPicker =
        reactionsEnabled &&
        retractionStatus == DmRetractionStatus.none &&
        !(isSent &&
            (deliveryStatus == DmDeliveryStatus.failed ||
                deliveryStatus == DmDeliveryStatus.blocked));
    final result = await ReactionPickerOverlay.show(
      context: context,
      isSent: isSent,
      isVideoShare: videoTarget != null,
      showPicker: showPicker,
      showDelete:
          (retractionsEnabled || !isPersisted) &&
          retractionStatus == DmRetractionStatus.none,
      deleteForEveryone: isPersisted,
    );
    if (result == null) return;
    if (!context.mounted) return;

    if (result.emoji != null) {
      _toggleReaction(context, message, result.emoji!);
      return;
    }
    if (result.openFullPicker) {
      final emoji = await FullReactionEmojiPickerSheet.show(context: context);
      if (emoji == null || !context.mounted) return;
      _toggleReaction(context, message, emoji);
      return;
    }
    final action = result.action;
    if (action == null) return;
    switch (action) {
      case MessageAction.copy:
        await ClipboardUtils.copy(context, message.content);
      case MessageAction.copyVideoUrl:
        if (videoTarget == null) return;
        await ClipboardUtils.copy(context, videoTarget.canonicalUrl);
      case MessageAction.saveVideo:
        if (videoTarget == null) return;
        context.read<SharedVideoSaveCubit>().save(videoTarget);
      case MessageAction.delete:
        context.read<ConversationBloc>().add(
          ConversationMessageDeleted(rumorId: message.id),
        );
      case MessageAction.report:
        if (!context.mounted) return;
        await ReportContentDialog.showForMessage(
          context,
          messageId: message.id,
          senderPubkey: message.senderPubkey,
        );
    }
  }

  Future<void> _onUnconfirmedRetractionTap(
    BuildContext context,
    DmMessage message,
  ) async {
    final bloc = context.read<ConversationBloc>();
    final retry = await VineBottomSheetPrompt.show<bool>(
      context: context,
      sticker: DivineStickerName.alert,
      title: message.retractionStatus == DmRetractionStatus.pending
          ? context.l10n.dmDeletePendingLabel
          : context.l10n.dmDeleteRefusedMessage,
      subtitle: context.l10n.dmDeleteRefusedDetails,
      primaryButtonText: context.l10n.authTryAgain,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      secondaryButtonText: context.l10n.commonCancel,
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );
    if (retry != true || bloc.isClosed) return;
    bloc.add(ConversationMessageDeletionRetryRequested(rumorId: message.id));
  }

  /// Tapping a failed own bubble opens a recovery bottom sheet offering a
  /// queue-aware resend or a delete. Resend replays the batch's FAILED
  /// row(s) via [ConversationFullSendRecoveryRequested] (a manual retry
  /// bypasses the sweep's retry-count cap) — never the siblings that
  /// already delivered. Delete ("cancel send") drops every UNDELIVERED
  /// sibling row (pending + failed) via [ConversationOutgoingSendCancelled]:
  /// cancelling only the failed ones left pending siblings for the retry
  /// sweep to publish after the user said give up. Delivered-awaiting-
  /// self-wrap rows are excluded — those recipients already have the
  /// message. The sheet is modal, so both actions are inherently one-shot;
  /// the bloc is still checked for closure before dispatching, since the
  /// route (and its bloc) can be torn down while the sheet is open.
  Future<void> _onFailedMessageTap(
    BuildContext context,
    DmMessage message,
  ) async {
    final l10n = context.l10n;
    final bloc = context.read<ConversationBloc>();
    final failedIds = bloc.state.failedSiblingRumorIdsFor(message.id);
    final resendIds = failedIds.isEmpty ? [message.id] : failedIds;
    final undeliveredIds = bloc.state.undeliveredSiblingRumorIdsFor(message.id);
    final cancelIds = undeliveredIds.isEmpty ? [message.id] : undeliveredIds;

    // Per `accessibility.md`, async visible state changes must announce
    // explicitly — same rule as the blocked/partial snackbars in
    // [_onSendOutcome].
    SemanticsService.sendAnnouncement(
      View.of(context),
      l10n.dmSendFailedMessage,
      Directionality.of(context),
    );

    // The prompt must stay open until the user picks resend or stop-trying
    // (#6092): block both barrier-tap and drag-to-dismiss so a stray gesture
    // can't return null and silently leave the failed send untouched.
    final action = await VineBottomSheetPrompt.show<_FailedMessageAction>(
      context: context,
      sticker: DivineStickerName.alert,
      title: l10n.dmSendFailedMessage,
      subtitle: l10n.dmSendFailedSubtitle,
      isDismissible: false,
      enableDrag: false,
      primaryButtonText: l10n.dmMessageActionRetrySend,
      onPrimaryPressed: () =>
          Navigator.of(context).pop(_FailedMessageAction.resend),
      secondaryButtonText: l10n.dmMessageActionCancelSend,
      onSecondaryPressed: () =>
          Navigator.of(context).pop(_FailedMessageAction.delete),
    );

    if (bloc.isClosed) return;
    switch (action) {
      case _FailedMessageAction.resend:
        bloc.add(ConversationFullSendRecoveryRequested(rumorIds: resendIds));
      case _FailedMessageAction.delete:
        for (final id in cancelIds) {
          bloc.add(ConversationOutgoingSendCancelled(rumorId: id));
        }
      case null:
        return;
    }
  }

  void _toggleReaction(BuildContext context, DmMessage message, String emoji) {
    context.read<ConversationReactionsCubit>().add(
      ConversationReactionToggled(
        conversationId: message.conversationId,
        messageId: message.id,
        messageAuthorPubkey: message.senderPubkey,
        emoji: emoji,
      ),
    );
  }

  /// Double-tap-to-like (Instagram-style). Fires a light haptic and adds a ❤️
  /// via [ConversationReactionSet] (add-only: a repeat double-tap never
  /// un-likes — removal stays on the long-press picker). The chip itself
  /// animates in via [ReactionsRow]. Dedup lives in the cubit's
  /// [ConversationReactionSet] handler — including the pre-persist optimistic
  /// window — so a rapid double-tap burst can't fan out duplicate gift-wrapped
  /// reactions; the UI just dispatches.
  void _likeOnDoubleTap(BuildContext context, DmMessage message) {
    HapticFeedback.lightImpact();
    context.read<ConversationReactionsCubit>().add(
      ConversationReactionSet(
        conversationId: message.conversationId,
        messageId: message.id,
        messageAuthorPubkey: message.senderPubkey,
        emoji: _doubleTapLikeEmoji,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Index built once per render pass so a reply bubble can resolve its
    // parent shared-reel message (and thus the quoted video) in O(1).
    final messagesById = {for (final m in messages) m.id: m};
    // Rows are keyed by message id and located through
    // findChildIndexCallback so a bubble's State (its Show more expansion)
    // survives the index shift every newer message causes in this reversed
    // list. Without the callback the keyed rows are index-matched, every
    // shifted row is inflated afresh, and an expanded bubble collapses.
    final messageIndexById = {
      for (var index = 0; index < messages.length; index++)
        messages[index].id: index,
    };
    return ListView.builder(
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      // bottom: 8 stacks with the newest bubble's own 8 px bottom padding
      // for a 16 px gap to the scroll-view edge.
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: messages.length,
      findChildIndexCallback: (key) =>
          key is ValueKey<String> ? messageIndexById[key.value] : null,
      itemBuilder: (context, index) {
        final message = messages[index];
        final messageKey = ValueKey(message.id);
        final isSent = message.senderPubkey == currentPubkey;
        final invite = CollaboratorInviteParser.parse(message);
        if (invite != null) {
          return KeyedSubtree(
            key: messageKey,
            child: CollaboratorInviteCard(
              invite: invite,
              isSent: isSent,
              senderDisplayName: isSent ? null : senderDisplayName,
            ),
          );
        }

        // Suppress legacy NIP-04 invite plaintext duplicates (#3559).
        // Phase 1 stopped new sends from emitting this fallback, but
        // older app builds and cross-client senders can still produce
        // bubbles that read "Open Divine to review and accept" (or its
        // pre-#7915 "diVine" spelling) — useless copy inside Divine, and
        // the structured fields needed to render an actionable card are
        // not recoverable from plaintext alone.
        if (CollaboratorInviteService.hasInvitePlaintextSuffix(
          message.content,
        )) {
          return KeyedSubtree(
            key: messageKey,
            child: const SizedBox.shrink(),
          );
        }

        // Grouping: in a reversed list, index 0 is newest (bottom of screen).
        // "Above" = index + 1 (older), "below" = index - 1 (newer).
        final isFirstInGroup =
            index == messages.length - 1 ||
            messages[index + 1].senderPubkey != message.senderPubkey;
        final isLastInGroup =
            index == 0 ||
            messages[index - 1].senderPubkey != message.senderPubkey;

        // participantPubkeys excludes self, so a length > 1 is a group.
        final isGroup = participantPubkeys.length > 1;

        // Context for the in-player reply/reaction bar when this bubble's
        // shared reel is opened. Carries the reel's structured video ref so a
        // text reply can self-carry the NIP-18 `q` citation (cross-device /
        // other-client durability).
        final dmReplyContext = DmReplyContext(
          conversationId: message.conversationId,
          participantPubkeys: participantPubkeys,
          isGroup: isGroup,
          sharedReelMessageId: message.id,
          messageAuthorPubkey: message.senderPubkey,
          hintName: senderDisplayName,
          isOwnMessage: isSent,
          sharedVideoRef: message.sharedVideoRef,
        );

        // A non-reply share renders the full card; a reply that references a
        // video renders a compact quote above its text (mutually exclusive).
        final ownShareVideoRef = resolveOwnShareVideoRef(message);
        final quotedVideoRef = resolveQuotedVideoRef(message, messagesById);

        Widget buildBubbleWithReactions(DmDeliveryStatus status) {
          final bubble = MessageBubble(
            message: message.content,
            timestamp: LocalizedTimeFormatter.formatMessageTime(
              context.l10n,
              message.createdAt,
              locale: Localizations.localeOf(context).toLanguageTag(),
              use24Hour: MediaQuery.of(context).alwaysUse24HourFormat,
            ),
            isSent: isSent,
            isFirstInGroup: isFirstInGroup,
            isLastInGroup: isLastInGroup,
            onLongPress: () => _onMessageLongPress(
              context,
              message,
              isSent,
              status,
              message.retractionStatus,
              context.read<ConversationBloc>().state.messages.any(
                (persisted) => persisted.id == message.id,
              ),
            ),
            // A single tap on a failed own bubble opens the resend/stop-trying
            // recovery bottom sheet; every other bubble keeps its default tap.
            // Withheld in a blocked thread, where resending would publish to
            // the blocked account (see [sendRecoveryEnabled]).
            //
            // The retraction arm is gated on [retractionsEnabled] for the same
            // reason `showDelete` is: on a retired moderation thread the send
            // policy refuses every kind 5, so offering Try again would loop
            // straight back to failed.
            onTap:
                retractionsEnabled &&
                    message.retractionStatus != DmRetractionStatus.none
                ? () => _onUnconfirmedRetractionTap(context, message)
                : sendRecoveryEnabled &&
                      isSent &&
                      status == DmDeliveryStatus.failed
                ? () => _onFailedMessageTap(context, message)
                : null,
            // Double-tap-to-like, hidden on failed own sends to mirror the
            // long-press picker guard (reacting to a message the recipient
            // never received is meaningless).
            onDoubleTap:
                !reactionsEnabled ||
                    message.retractionStatus != DmRetractionStatus.none ||
                    (isSent &&
                        (status == DmDeliveryStatus.failed ||
                            status == DmDeliveryStatus.blocked))
                ? null
                : () => _likeOnDoubleTap(context, message),
            deliveryStatus: status,
            retractionStatus: message.retractionStatus,
            dmReplyContext: dmReplyContext,
            sharedVideoRef: ownShareVideoRef,
            quotedVideoRef: quotedVideoRef,
          );
          return Column(
            crossAxisAlignment: isSent
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              bubble,
              // One combined reaction pill (distinct emoji glyphs + reactor
              // avatars) for both 1:1 and group; tapping it opens the
              // "who reacted" sheet.
              ReactionsRow(
                conversationId: message.conversationId,
                messageId: message.id,
                messageAuthorPubkey: message.senderPubkey,
                ownerPubkey: currentPubkey,
                isSentByMe: isSent,
                blockedPubkeys: blockedPubkeys,
                removalEnabled: retractionsEnabled,
              ),
            ],
          );
        }

        // Per-row BlocSelector scopes rebuilds to just the indicator's
        // status — the bubble body stays cached across watchOutgoing
        // ticks affecting other rows. Received bubbles never read the
        // outgoing queue, so they bypass the selector and short-circuit
        // to `delivered`.
        if (!isSent) {
          return KeyedSubtree(
            key: messageKey,
            child: buildBubbleWithReactions(DmDeliveryStatus.delivered),
          );
        }
        return KeyedSubtree(
          key: messageKey,
          child:
              BlocSelector<
                ConversationBloc,
                ConversationState,
                DmDeliveryStatus
              >(
                selector: (state) => state.statusFor(message.id),
                builder: (_, status) => buildBubbleWithReactions(status),
              ),
        );
      },
    );
  }
}
