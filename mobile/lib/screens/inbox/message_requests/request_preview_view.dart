// ABOUTME: View for the message request preview screen.
// ABOUTME: Shows sender profile info, message count, and accept/decline actions.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/message_requests/message_request_actions_cubit.dart';
import 'package:openvine/blocs/dm/message_requests/request_preview_cubit.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/config/profile_metrics.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/collaborator_invite.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/conversation/widgets/widgets.dart';
import 'package:openvine/screens/inbox/inbox_page.dart';
import 'package:openvine/screens/inbox/widgets/dm_peer_identity.dart';
import 'package:openvine/screens/inbox/widgets/moderation_identity.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/services/collaborator_invite_parser.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// View for the message request preview screen.
///
/// Displays the sender's profile (avatar, name, NIP-05, stats),
/// a "View profile" button, message count text, and two action buttons:
/// "View messages" (accept) and "Decline and remove".
class RequestPreviewView extends ConsumerWidget {
  const RequestPreviewView({this.subject, super.key});

  final String? subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = context.select(
      (RequestPreviewCubit cubit) => cubit.state.status,
    );
    // #176 preview gate: a DM-restricted user reaching this route directly is
    // bounced to the inbox and nothing renders, mirroring the ConversationPage
    // route guard. A build-time branch (not a BlocListener) because the lazy
    // cubit emits `denied` synchronously during its `create:`/`load()`, before
    // any listener could subscribe.
    if (status == RequestPreviewStatus.denied) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(InboxPage.path);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final participantPubkeys = context.select(
      (RequestPreviewCubit cubit) => cubit.state.participantPubkeys,
    );

    final otherPubkey = participantPubkeys.isNotEmpty
        ? participantPubkeys.first
        : '';

    // #7335 unresolved-counterparty gate. Everything past this point either
    // identifies the sender or acts on them, and neither is possible until the
    // load resolves a counterparty. Falling through was not cosmetic:
    // `_ActionButtons` went live over an empty `participantPubkeys`, and its
    // "View messages" opened a conversation whose composer cleared the text
    // field and then threw before writing a queue row — no bubble, no toast,
    // no error, so the message looked sent. The header meanwhile named the
    // sender `UserProfile.defaultDisplayNameFor('')`, a generated "Adjective
    // Animal N", above a message count of 0.
    //
    // Returning before the profile watch below also stops the fetch for `''`
    // seen repeatedly in the August iOS release log, where the REST profile
    // fallback rejects it with "Pubkey cannot be empty" and the relay fallback
    // then goes looking for the empty string.
    //
    // `loaded` is gated on the pubkey rather than the status because
    // `_resolveParticipants` returns `[]` for a conversation the local
    // database does not have, reaching this same layout without ever failing.
    if (status == RequestPreviewStatus.loading) {
      return _UnresolvedRequestScaffold(
        child: DivineCircularProgressIndicator(
          color: context.vineColors.accentPositive,
        ),
      );
    }
    if (status == RequestPreviewStatus.error || otherPubkey.isEmpty) {
      return const _UnresolvedRequestScaffold(child: _LoadFailedMessage());
    }

    final messageCount = context.select(
      (RequestPreviewCubit cubit) => cubit.state.messageCount,
    );
    final messages = context.select(
      (RequestPreviewCubit cubit) => cubit.state.messages,
    );
    final currentPubkey =
        ref.watch(authServiceProvider).currentPublicKeyHex ?? '';

    final profileAsync = ref.watch(userProfileReactiveProvider(otherPubkey));

    final profile = profileAsync.asData?.value;
    final isResolving = ref.watch(
      profileIdentityResolvingProvider(otherPubkey),
    );

    // Same treatment as [ConversationTile]. This screen also links straight
    // through to [OtherProfileScreen], which already names a vanished account
    // for the state — so without this the same tap sequence showed a generated
    // handle and then "Deleted account" (#8185).
    final isDeleted = ref.watch(profileVanishedProvider(otherPubkey));

    // Suppressing the profile object as well as the name matches
    // [OtherProfileScreen], which nulls its own header profile on a vanish
    // rather than pass a deleted account's avatar, handle and counts
    // downstream.
    final visibleProfile = isDeleted ? null : profile;

    // Counts come from the profile-statistics store, not from the profile.
    // `UserProfile.rawData` only carries `follower_count` / `video_count` on
    // the people-search shape (`ProfileSearchResult.toUserProfile`), which is
    // never written to the Drift cache this screen reads — so the REST-only
    // getters are structurally null here and the Kind 0 `vine_*` fallback is
    // dead too (the archive importer writes those as tags, not content).
    // `_cacheProfileStatsFromResult` routes `social` / `stats` from
    // `GET /api/users/{pubkey}` into `profile_statistics`, which is where the
    // numbers actually live (#7486).
    final stats = isDeleted
        ? null
        : ref
              .watch(userProfileStatsReactiveProvider(otherPubkey))
              .asData
              ?.value;

    final peerName = dmPeerDisplayName(
      context,
      pubkeyHex: otherPubkey,
      isVanished: isDeleted,
      profile: visibleProfile,
      isResolving: isResolving,
    );
    final displayName = dmConversationDisplayTitle(
      context,
      participantPubkeys: [currentPubkey, ...participantPubkeys],
      currentUserPubkey: currentPubkey,
      isGroup: participantPubkeys.length > 1,
      peerName: peerName,
      subject: subject,
    );
    // Derived from the room title, not the peer name: a titled group resolves
    // without a profile and must not skeleton, while an untitled one is named
    // for its peer and must.
    final isIdentityResolving = isResolving && displayName.isEmpty;
    final visualDisplayName = displayName.isEmpty
        ? UserProfile.defaultDisplayNameFor(otherPubkey)
        : displayName;

    return Scaffold(
      backgroundColor: context.vineColors.surface,
      appBar: DiVineAppBar(
        title: isIdentityResolving ? null : displayName,
        titleWidget: isIdentityResolving
            ? Semantics(
                label: context.l10n.commonLoading,
                child: IdentitySkeletonizer(
                  isLoading: true,
                  excludeSemantics: true,
                  child: Text(
                    visualDisplayName,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
            : null,
        showBackButton: true,
        // Same one-entry-stack exposure as the unresolved states below:
        // `loading` is only the first frame of a cold deep-link entry, and
        // resolving to `loaded` does not put an entry behind it (#6112).
        onBackPressed: () => context.safePop(fallback: InboxPage.path),
      ),
      body: _PreviewBackdrop(
        child: Column(
          children: [
            Expanded(
              child: _ProfileContent(
                displayName: displayName,
                profile: visibleProfile,
                stats: stats,
                // A vanished account shows no counts and no shimmer waiting
                // for counts that will never arrive.
                statsPending: !isDeleted && stats == null,
                otherPubkey: otherPubkey,
                currentPubkey: currentPubkey,
                messageCount: messageCount,
                messages: messages,
                isResolving: isIdentityResolving,
              ),
            ),
            _ActionButtons(
              participantPubkeys: participantPubkeys,
              displayName: displayName,
              subject: subject,
            ),
          ],
        ),
      ),
    );
  }
}

/// The rounded panel every state of this screen sits on.
class _PreviewBackdrop extends StatelessWidget {
  const _PreviewBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(VineTheme.bottomSheetBorderRadius),
      ),
      child: ColoredBox(
        color: context.vineColors.surfaceContainerHigh,
        child: child,
      ),
    );
  }
}

/// Chrome for the states that have no counterparty to name yet (#7335).
///
/// Offers no accept action — that one hands the participant list to the
/// conversation route, and the whole point of this branch is that there isn't
/// one. Decline stays, because `declineRequest` keys off the conversation ID
/// alone: a preview read that fails is no reason to make an unwanted request
/// undismissable. Unlike the loaded state, this branch cannot check whether
/// the peer is a Divine moderation identity — there is no counterparty to
/// test, and the id is a hash of the participants — so the cubit answers that
/// for it and refuses (#6971). The app bar falls back to the section title,
/// since the loaded header's name would be a generated placeholder here.
class _UnresolvedRequestScaffold extends StatelessWidget {
  const _UnresolvedRequestScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.surface,
      appBar: DiVineAppBar(
        title: context.l10n.inboxMessageRequestsTitle,
        showBackButton: true,
        // safePop, not pop: `loading` is the first frame of *every* entry to
        // this route, deep links included, and a cold deep link leaves a
        // one-entry stack that plain `pop()` throws on (#6112).
        onBackPressed: () => context.safePop(fallback: InboxPage.path),
      ),
      body: _PreviewBackdrop(
        child: Column(
          children: [
            Expanded(child: Center(child: child)),
            const _ActionBar(children: [_DeclineAndRemoveButton()]),
          ],
        ),
      ),
    );
  }
}

/// The read failed. Offers a retry rather than a dead end — the cubit's own
/// `load()` is idempotent, and a Drift read failure is usually transient.
class _LoadFailedMessage extends StatelessWidget {
  const _LoadFailedMessage();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          Text(
            l10n.messageRequestLoadFailed,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.onSurfaceMuted,
            ),
            textAlign: TextAlign.center,
          ),
          _OutlinedActionButton(
            label: l10n.commonRetry,
            onTap: () => context.read<RequestPreviewCubit>().load(),
          ),
        ],
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.displayName,
    required this.profile,
    required this.stats,
    required this.statsPending,
    required this.otherPubkey,
    required this.currentPubkey,
    required this.messageCount,
    required this.messages,
    required this.isResolving,
  });

  final String displayName;
  final UserProfile? profile;
  final ProfileStats? stats;

  /// Whether counts are still expected to arrive for this account.
  ///
  /// False for a vanished account, whose stats are suppressed outright rather
  /// than awaited.
  final bool statsPending;
  final String otherPubkey;
  final String currentPubkey;
  final int messageCount;
  final List<DmMessage> messages;
  final bool isResolving;

  @override
  Widget build(BuildContext context) {
    final visualDisplayName = displayName.isEmpty
        ? UserProfile.defaultDisplayNameFor(otherPubkey)
        : displayName;
    final imageUrl = profile?.picture;
    final nip05 = profile?.shortDisplayNip05;
    // A zero is not data on any of the three. Funnelcake collapses a stats
    // failure into zeros behind an HTTP 200 — `get_social_stats` never
    // surfaces an error, and `get_user_stats` maps both a miss and a failure
    // to a default — so "never indexed", "genuinely zero" and "the summary
    // table is down" are indistinguishable. The repository already withholds
    // a zero follower/following count for that reason; videos get the same
    // treatment here (#7486).
    final followerCount = (stats?.followers ?? 0) > 0 ? stats!.followers : null;
    final videoCount = (stats?.videoCount ?? 0) > 0 ? stats!.videoCount : null;

    // The sender of a message request is never the viewer, so the owner
    // exemption the profile header applies does not exist here — the floor
    // always applies.
    final loopCount = (stats?.totalViews ?? 0) >= profileLoopsVisibilityFloor
        ? stats!.totalViews
        : null;

    return ColoredBox(
      color: VineTheme.scrim15,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 64),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: isResolving ? context.l10n.commonLoading : null,
                child: IdentitySkeletonizer(
                  isLoading: isResolving,
                  excludeSemantics: true,
                  child: UserAvatar(
                    imageUrl: imageUrl,
                    name: visualDisplayName,
                    placeholderSeed: otherPubkey,
                    size: 96,
                    contentOverride: isModerationAccount(otherPubkey)
                        ? const ModerationAvatar()
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              IdentitySkeletonizer(
                isLoading: isResolving,
                excludeSemantics: true,
                child: Text(
                  visualDisplayName,
                  style: VineTheme.titleLargeFont(
                    color: context.vineColors.primaryText,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (nip05 != null && nip05.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  nip05,
                  style: VineTheme.bodySmallFont(
                    color: context.vineColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (statsPending ||
                  followerCount != null ||
                  videoCount != null ||
                  loopCount != null) ...[
                const SizedBox(height: 4),
                _StatsLine(
                  followerCount: followerCount,
                  videoCount: videoCount,
                  loopCount: loopCount,
                  isLoading: statsPending,
                ),
              ],
              const SizedBox(height: 16),
              _OutlinedActionButton(
                label: context.l10n.messageRequestViewProfileButton,
                onTap: () => context.push(
                  OtherProfileScreen.pathForNpub(
                    NostrKeyUtils.encodePubKey(otherPubkey),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (isRetiredModerationAccount(otherPubkey))
                const _ClosedNoticeDescription()
              else
                _MessageCountDescription(
                  displayName: displayName,
                  messageCount: messageCount,
                ),
              _InvitePreview(
                messages: messages,
                senderDisplayName: displayName,
                currentPubkey: currentPubkey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvitePreview extends StatelessWidget {
  const _InvitePreview({
    required this.messages,
    required this.senderDisplayName,
    required this.currentPubkey,
  });

  final List<DmMessage> messages;
  final String senderDisplayName;
  final String currentPubkey;

  @override
  Widget build(BuildContext context) {
    ({DmMessage message, CollaboratorInvite invite})? inviteMessage;
    for (final message in messages) {
      final invite = CollaboratorInviteParser.parse(message);
      if (invite == null) continue;
      inviteMessage = (message: message, invite: invite);
      break;
    }
    if (inviteMessage == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: CollaboratorInviteCard(
        invite: inviteMessage.invite,
        isSent:
            currentPubkey.isNotEmpty &&
            inviteMessage.message.senderPubkey == currentPubkey,
        senderDisplayName: senderDisplayName,
      ),
    );
  }
}

/// Followers · videos · loops for the account behind a message request.
///
/// Mirrors the profile header's loading vocabulary — a Skeletonizer shimmer
/// while the counts are still arriving, bounded by [_skeletonTimeout] so a
/// pubkey the stats store never answers for does not shimmer forever. Where
/// the header then degrades each column to a `—`, this line hides instead:
/// its counts are ICU plurals whose number and noun are one string, so there
/// is no numeral to swap out without picking a plural form for a dash.
class _StatsLine extends StatefulWidget {
  const _StatsLine({
    this.followerCount,
    this.videoCount,
    this.loopCount,
    this.isLoading = false,
  });

  final int? followerCount;
  final int? videoCount;
  final int? loopCount;

  /// Whether counts are still expected. Drives the shimmer, and the timeout
  /// that eventually gives up on it.
  final bool isLoading;

  @override
  State<_StatsLine> createState() => _StatsLineState();
}

class _StatsLineState extends State<_StatsLine> {
  /// Matches the profile header's stats row, so the two surfaces give up on a
  /// silent stats store at the same moment.
  static const _skeletonTimeout = Duration(seconds: 7);

  /// Painted behind the shimmer only. The number is never legible — it exists
  /// to give the skeleton bar a realistic width.
  static const _skeletonPlaceholderCount = 99;

  Timer? _timer;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    if (widget.isLoading) _startTimer();
  }

  @override
  void didUpdateWidget(_StatsLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _timedOut = false;
      _startTimer();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(_skeletonTimeout, () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final showSkeleton = widget.isLoading && !_timedOut;

    final parts = <String>[];
    if (showSkeleton) {
      // Two placeholder parts set the shimmer's width. Followers and videos
      // are the pair every account can have; loops are floored, so promising
      // a third bar would usually shimmer into nothing.
      parts
        ..add(
          StringUtils.compactPlural(
            _skeletonPlaceholderCount,
            l10n.messageRequestFollowersCount,
          ),
        )
        ..add(
          StringUtils.compactPlural(
            _skeletonPlaceholderCount,
            l10n.messageRequestVideosCount,
          ),
        );
    } else {
      final followerCount = widget.followerCount;
      final videoCount = widget.videoCount;
      final loopCount = widget.loopCount;
      if (followerCount != null) {
        parts.add(
          StringUtils.compactPlural(
            followerCount,
            l10n.messageRequestFollowersCount,
          ),
        );
      }
      if (videoCount != null) {
        parts.add(
          StringUtils.compactPlural(
            videoCount,
            l10n.messageRequestVideosCount,
          ),
        );
      }
      if (loopCount != null) {
        // `videoFeedLoopCountLine` declares its display string before its
        // plural selector, the reverse of the two keys above, so it cannot be
        // handed to `compactPlural` directly. Reused rather than duplicated
        // into a new key because it already carries this wording in all 22
        // locales.
        parts.add(
          StringUtils.compactPlural(
            loopCount,
            (value, display) => l10n.videoFeedLoopCountLine(display, value),
          ),
        );
      }
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return Skeletonizer(
      enabled: showSkeleton,
      effect: vineSkeletonEffectOf(context),
      child: ExcludeSemantics(
        excluding: showSkeleton,
        child: Text(
          parts.join(' \u2022 '),
          style: VineTheme.bodySmallFont(
            color: context.vineColors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Replaces the overture on a retired moderation notice, whose key nobody is
/// behind. "Wants to message you" is wrong twice over there: the account was
/// retired, and an enforcement notice is not a social approach.
///
/// Reuses the two ARB keys `_ClosedThreadNotice` renders in
/// `conversation_view.dart`, which the request row also already shows, so the
/// three surfaces a user crosses in one tap sequence cannot drift onto
/// different wording (#6971).
///
/// Deliberately copy only. The thread behind "View messages" carries the
/// redirect to the live support account, and this screen has been kept light
/// on controls since #8090 pulled one back out of it.
class _ClosedNoticeDescription extends StatelessWidget {
  const _ClosedNoticeDescription();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        spacing: 8,
        children: [
          Text(
            l10n.dmRetiredThreadClosedTitle,
            style: VineTheme.titleSmallFont(
              color: context.vineColors.primaryText,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            l10n.dmRetiredThreadClosedBody,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MessageCountDescription extends StatelessWidget {
  const _MessageCountDescription({
    required this.displayName,
    required this.messageCount,
  });

  final String displayName;
  final int messageCount;

  @override
  Widget build(BuildContext context) {
    final msgText = context.l10n.messageRequestMessageCount(messageCount);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        context.l10n.messageRequestWantsToMessageYou(displayName, msgText),
        style: VineTheme.bodyLargeFont(
          color: context.vineColors.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// The bottom action strip, in the same place on every state of this screen so
/// decline does not move when the load resolves.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: children,
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.participantPubkeys,
    required this.displayName,
    this.subject,
  });

  final List<String> participantPubkeys;
  final String displayName;
  final String? subject;

  @override
  Widget build(BuildContext context) {
    final conversationId = context.read<RequestPreviewCubit>().conversationId;

    return _ActionBar(
      children: [
        _PrimaryActionButton(
          label: context.l10n.messageRequestViewMessagesButton,
          onTap: () {
            context.pushReplacementNamed(
              ConversationPage.routeName,
              pathParameters: {'id': conversationId},
              extra: subject == null
                  ? participantPubkeys
                  : {
                      'participantPubkeys': participantPubkeys,
                      'subject': subject,
                    },
            );
          },
        ),
        // An enforcement notice is not a request to decline. Removing it is
        // permanent and it is the user's only copy of why they were actioned,
        // so the action is not offered (#6971). The cubit refuses it too, for
        // the unresolved states below that cannot name the peer.
        if (!participantPubkeys.any(isModerationAccount))
          _DeclineAndRemoveButton(displayName: displayName),
      ],
    );
  }
}

/// The one action that survives an unresolved counterparty: `declineRequest`
/// takes the conversation ID, not the participants.
///
/// Not rendered at all once the peer resolves to a Divine moderation identity
/// — see [_ActionButtons]. It stays here because this branch has no peer to
/// test, so the refusal comes back from the cubit instead.
///
/// [displayName] is null on the unresolved-counterparty states, where there is
/// no name to put in the confirmation snackbar; the decline still runs.
class _DeclineAndRemoveButton extends StatelessWidget {
  const _DeclineAndRemoveButton({this.displayName});

  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final conversationId = context.read<RequestPreviewCubit>().conversationId;

    return _SecondaryActionButton(
      label: context.l10n.messageRequestDeclineAndRemoveButton,
      onTap: () async {
        final cubit = context.read<MessageRequestActionsCubit>();
        if (cubit.state.status == MessageRequestActionsStatus.processing) {
          return;
        }
        final messenger = ScaffoldMessenger.of(context);
        final errorText = context.l10n.commonSomethingWentWrong;
        final name = displayName;
        // A resolved counterparty names them in the confirmation; the
        // unresolved states have no name, so fall back to the name-free
        // "Removed conversation" rather than staying silent (#7881 review).
        final successText = name == null
            ? context.l10n.inboxRemovedConversation
            : context.l10n.messageRequestDeclinedSnackbar(name);
        // Not an error: the row is a Divine moderation notice the cubit
        // protects. Only the unresolved states can reach it, since the action
        // bar drops this button once the peer resolves (#6971).
        final refusedText =
            context.l10n.messageRequestModerationNoticeCannotBeRemoved;
        final outcome = await cubit.declineRequest(conversationId);
        switch (outcome) {
          case DeclineRequestOutcome.failed:
            messenger.showSnackBar(
              DivineSnackbarContainer.snackBar(errorText, error: true),
            );
            return;
          case DeclineRequestOutcome.refused:
            messenger.showSnackBar(
              DivineSnackbarContainer.snackBar(refusedText),
            );
            return;
          case DeclineRequestOutcome.removed:
            break;
        }
        // safePop for the same reason as the app-bar back button above: this
        // route is deep-linkable, and a cold entry has nothing to pop (#6112).
        if (context.mounted) context.safePop(fallback: InboxPage.path);
        messenger.showSnackBar(DivineSnackbarContainer.snackBar(successText));
      },
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: VineTheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text(
                label,
                style: VineTheme.titleMediumFont(color: VineTheme.onPrimary),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinedActionButton extends StatelessWidget {
  const _OutlinedActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.vineColors.surfaceContainer,
            border: Border.all(
              color: context.vineColors.outlineMuted,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.accentPositive,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.vineColors.surfaceContainer,
              border: Border.all(
                color: context.vineColors.outlineMuted,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text(
                label,
                style: VineTheme.titleMediumFont(
                  color: context.vineColors.accentPositive,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
