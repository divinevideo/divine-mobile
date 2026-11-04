// ABOUTME: Card UI for structured collaborator invite direct messages.
// ABOUTME: Keeps invite plaintext fallback hidden and exposes accept/ignore.

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/blocs/dm/conversation/collaborator_invite_actions_cubit.dart';
import 'package:openvine/blocs/video_collaborator_status/video_collaborator_status_cubit.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/collaborator_invite.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/comments/widgets/video_comment_player.dart';
import 'package:openvine/screens/inbox/conversation/widgets/video_link_preview_cubit.dart';
import 'package:openvine/services/collaborator_invite_state_store.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:unified_logger/unified_logger.dart';

const double _collaboratorInviteMaxCardWidth = 420;
const double _collaboratorInviteMaxViewportHeightFraction = 0.62;

class CollaboratorInviteCard extends StatefulWidget {
  const CollaboratorInviteCard({
    required this.invite,
    required this.isSent,
    this.collaboratorPubkey,
    this.senderDisplayName,
    super.key,
  });

  final CollaboratorInvite invite;
  final bool isSent;

  /// The pubkey whose kind-34238 response settles this invite: the viewer on
  /// a received card, the invitee on a sent one. When null the card shows
  /// only what this device knows, and a sent card never claims "Accepted".
  final String? collaboratorPubkey;
  final String? senderDisplayName;

  @override
  State<CollaboratorInviteCard> createState() => _CollaboratorInviteCardState();
}

class _CollaboratorInviteCardState extends State<CollaboratorInviteCard> {
  @override
  void initState() {
    super.initState();
    // Sender-side cards never read or write the actions cubit: the sender
    // gets no Accept/Ignore (#3559), only the relay's answer (#7903).
    if (!widget.isSent) {
      _loadInviteState();
    } else if (widget.collaboratorPubkey == null) {
      Log.info(
        'Sent collaborator invite for ${widget.invite.videoAddress} has no '
        'single counterparty; showing its status without the relay',
        name: 'CollaboratorInviteCard',
        category: LogCategory.ui,
      );
    }
  }

  @override
  void didUpdateWidget(covariant CollaboratorInviteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSent) return;
    if (oldWidget.invite != widget.invite || oldWidget.isSent) {
      _loadInviteState();
    }
  }

  void _loadInviteState() {
    context.read<CollaboratorInviteActionsCubit>().loadInvites([
      widget.invite,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isSent) {
      return _CardChrome(
        invite: widget.invite,
        isSent: true,
        collaboratorPubkey: widget.collaboratorPubkey,
        senderDisplayName: widget.senderDisplayName,
        actionBuilder: (relayStatus) =>
            _SentInviteStatus(relayStatus: relayStatus),
      );
    }
    return _CardChrome(
      invite: widget.invite,
      isSent: false,
      collaboratorPubkey: widget.collaboratorPubkey,
      senderDisplayName: widget.senderDisplayName,
      actionBuilder: (relayStatus) =>
          BlocSelector<
            CollaboratorInviteActionsCubit,
            CollaboratorInviteActionsState,
            CollaboratorInviteState
          >(
            selector: (state) => state.displayStateFor(
              widget.invite,
              relayStatus: relayStatus,
            ),
            builder: (context, inviteState) =>
                _InviteActions(invite: widget.invite, state: inviteState),
          ),
    );
  }
}

/// Builds the card's action area from the confirmation repository's status
/// for the invitee. For the viewer that status already folds in this device's
/// stored accept or ignore. Null while nothing is watched: the video has not
/// resolved, is not the invite's, or no longer tags the invitee.
typedef _InviteActionBuilder = Widget Function(CollaboratorStatus? relayStatus);

class _CardChrome extends ConsumerWidget {
  const _CardChrome({
    required this.invite,
    required this.isSent,
    required this.actionBuilder,
    this.collaboratorPubkey,
    this.senderDisplayName,
  });

  final CollaboratorInvite invite;
  final bool isSent;
  final _InviteActionBuilder actionBuilder;
  final String? collaboratorPubkey;
  final String? senderDisplayName;

  String _titleText(BuildContext context) {
    final title = invite.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    return context.l10n.inboxCollabInviteCardUntitledVideo;
  }

  String? get _inviteThumbnailUrl {
    final value = invite.thumbnailUrl?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String _previewTitle(BuildContext context) {
    if (isSent) return context.l10n.inboxCollabInviteCardTitle;
    final name = senderDisplayName?.trim();
    if (name != null && name.isNotEmpty) {
      return context.l10n.inboxCollabInvitePreviewTitleFrom(name);
    }
    return context.l10n.inboxCollabInvitePreviewTitle;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewportSize = MediaQuery.sizeOf(context);
    final maxViewportWidth = viewportSize.width * 0.78;
    final maxVisibleVideoWidth =
        viewportSize.height *
        _collaboratorInviteMaxViewportHeightFraction *
        9 /
        16;
    final maxCardWidth = math.min(
      math.min(maxViewportWidth, _collaboratorInviteMaxCardWidth),
      maxVisibleVideoWidth,
    );

    // Re-key the cubit on the repository identity: videosRepositoryProvider
    // yields a fresh instance when filter/aspect/host preferences change.
    final videosRepository = ref.watch(videosRepositoryProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: isSent
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: maxCardWidth,
          ),
          decoration: BoxDecoration(
            color: context.vineColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          foregroundDecoration: BoxDecoration(
            border: Border.all(color: context.vineColors.outlineMuted),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: BlocProvider(
            key: ValueKey(videosRepository),
            create: (_) => VideoLinkPreviewCubit(
              videoStableId: invite.videoDTag,
              authorPubkey: invite.creatorPubkey,
              videoKind: invite.videoKind,
              videosRepository: videosRepository,
            ),
            child: _InviteVideoContent(
              invite: invite,
              collaboratorPubkey: collaboratorPubkey,
              inviteThumbnailUrl: _inviteThumbnailUrl,
              title: _titleText(context),
              previewTitle: _previewTitle(context),
              actionBuilder: actionBuilder,
            ),
          ),
        ),
      ),
    );
  }
}

class _InviteVideoContent extends StatelessWidget {
  const _InviteVideoContent({
    required this.invite,
    required this.collaboratorPubkey,
    required this.inviteThumbnailUrl,
    required this.title,
    required this.previewTitle,
    required this.actionBuilder,
  });

  final CollaboratorInvite invite;
  final String? collaboratorPubkey;
  final String? inviteThumbnailUrl;
  final String title;
  final String previewTitle;
  final _InviteActionBuilder actionBuilder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VideoLinkPreviewCubit, VideoLinkPreviewState>(
      builder: (context, state) {
        final resolvedVideo = switch (state) {
          VideoLinkPreviewResolved(:final video) => video,
          _ => null,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _InvitePreviewSurface(
              inviteThumbnailUrl: inviteThumbnailUrl,
              resolvedVideo: resolvedVideo,
              isLoading: state is VideoLinkPreviewLoading,
              title: title,
              previewTitle: previewTitle,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _InviteRelayStatusScope(
                invite: invite,
                video: resolvedVideo,
                collaboratorPubkey: collaboratorPubkey,
                builder: actionBuilder,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Watches the invite's kind-34238 responses once its video has resolved.
///
/// It watches with the video's full collaborator list, as the video's own
/// surfaces do: the repository keys its state by video address alone, so a
/// narrower list would replace their subscription and drop their answers.
/// With no video, a video that is not the invite's, no invitee, or an invitee
/// the video no longer tags, there is nothing to watch and the action area
/// gets no relay answer.
class _InviteRelayStatusScope extends ConsumerWidget {
  const _InviteRelayStatusScope({
    required this.invite,
    required this.video,
    required this.collaboratorPubkey,
    required this.builder,
  });

  final CollaboratorInvite invite;
  final VideoEvent? video;
  final String? collaboratorPubkey;
  final _InviteActionBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final video = this.video;
    final collaborator = collaboratorPubkey?.toLowerCase();
    if (video == null ||
        collaborator == null ||
        !invite.isForVideo(video) ||
        !video.collaboratorPubkeys.contains(collaborator)) {
      return builder(null);
    }
    final repository = ref.watch(collaboratorConfirmationRepositoryProvider);
    if (repository == null) return builder(null);
    final taggedPubkeys = video.collaboratorPubkeys;

    return BlocProvider<VideoCollaboratorStatusCubit>(
      key: ValueKey((
        repository,
        invite.videoAddress,
        Object.hashAll(taggedPubkeys),
      )),
      create: (_) {
        Log.info(
          'Watching collaborator invite on ${invite.videoAddress} for '
          '${pubkeyForLogs(collaborator)}',
          name: 'CollaboratorInviteCard',
          category: LogCategory.ui,
        );
        return VideoCollaboratorStatusCubit(
          repository: repository,
          videoAddress: invite.videoAddress,
          creatorPubkey: invite.creatorPubkey,
          taggedPubkeys: taggedPubkeys,
        );
      },
      child: _InviteRelayStatus(
        videoAddress: invite.videoAddress,
        collaboratorPubkey: collaborator,
        builder: builder,
      ),
    );
  }
}

class _InviteRelayStatus extends StatelessWidget {
  const _InviteRelayStatus({
    required this.videoAddress,
    required this.collaboratorPubkey,
    required this.builder,
  });

  final String videoAddress;
  final String collaboratorPubkey;
  final _InviteActionBuilder builder;

  @override
  Widget build(BuildContext context) {
    final relayStatus = context.select(
      (VideoCollaboratorStatusCubit cubit) =>
          cubit.state.statusByPubkey[collaboratorPubkey],
    );
    return BlocListener<
      VideoCollaboratorStatusCubit,
      VideoCollaboratorStatusState
    >(
      listenWhen: (previous, current) =>
          !previous.isResolved && current.isResolved,
      listener: (_, state) => Log.info(
        'Collaborator invite on $videoAddress resolved to '
        '${state.statusByPubkey[collaboratorPubkey]?.name} for '
        '${pubkeyForLogs(collaboratorPubkey)}',
        name: 'CollaboratorInviteCard',
        category: LogCategory.ui,
      ),
      child: builder(relayStatus),
    );
  }
}

/// The sender's passive status: "Accepted" once the invitee's response is
/// seen, "Invitation sent" otherwise. Never Accept/Ignore (#3559).
class _SentInviteStatus extends StatelessWidget {
  const _SentInviteStatus({required this.relayStatus});

  final CollaboratorStatus? relayStatus;

  @override
  Widget build(BuildContext context) {
    if (relayStatus == CollaboratorStatus.confirmed) {
      return _StatusText(
        label: context.l10n.inboxCollabInviteAcceptedStatus,
        color: context.vineColors.accentPositive,
      );
    }
    return _StatusText(
      label: context.l10n.inboxCollabInviteSentStatus,
      color: context.vineColors.onSurfaceMuted,
    );
  }
}

class _InvitePreviewSurface extends StatelessWidget {
  const _InvitePreviewSurface({
    required this.inviteThumbnailUrl,
    required this.resolvedVideo,
    required this.isLoading,
    required this.title,
    required this.previewTitle,
  });

  final String? inviteThumbnailUrl;
  final VideoEvent? resolvedVideo;
  final bool isLoading;
  final String title;
  final String previewTitle;

  String? get _thumbnailUrl {
    final resolvedThumbnail = resolvedVideo?.thumbnailUrl?.trim();
    if (resolvedThumbnail != null && resolvedThumbnail.isNotEmpty) {
      return resolvedThumbnail;
    }
    return inviteThumbnailUrl;
  }

  String? get _videoUrl {
    final value = resolvedVideo?.videoUrl?.trim();
    if (value == null || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final videoUrl = _videoUrl;
    final thumbnailUrl = _thumbnailUrl;
    if (videoUrl != null) {
      return Stack(
        children: [
          VideoCommentPlayer(
            key: const ValueKey('collaborator_invite_inline_player'),
            videoUrl: resolvedVideo!.inlinePlayerVideoUrl ?? videoUrl,
            thumbnailUrl: thumbnailUrl,
          ),
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: IgnorePointer(
              child: _InviteGradientCopy(
                title: title,
                previewTitle: previewTitle,
              ),
            ),
          ),
        ],
      );
    }

    return _InviteThumbnailPreview(
      thumbnailUrl: thumbnailUrl,
      title: title,
      previewTitle: previewTitle,
      isLoading: isLoading,
    );
  }
}

class _InviteThumbnailPreview extends StatelessWidget {
  const _InviteThumbnailPreview({
    required this.thumbnailUrl,
    required this.title,
    required this.previewTitle,
    required this.isLoading,
  });

  final String? thumbnailUrl;
  final String title;
  final String previewTitle;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final thumbnailSemanticLabel = title.trim().isEmpty
        ? l10n.notificationsVideoThumbnail
        : l10n.notificationsVideoThumbnailFor(title);
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailUrl == null)
            ColoredBox(
              key: const ValueKey('collaborator_invite_video_placeholder'),
              color: context.vineColors.surfaceContainer,
              child: Center(
                child: DivineIcon(
                  icon: DivineIconName.videoCamera,
                  color: context.vineColors.onSurfaceMuted,
                  size: 32,
                ),
              ),
            )
          else
            Semantics(
              image: true,
              label: thumbnailSemanticLabel,
              child: VineCachedImage(
                key: const ValueKey('collaborator_invite_thumbnail'),
                imageUrl: thumbnailUrl!,
                placeholder: (context, url) => ColoredBox(
                  color: context.vineColors.surfaceContainer,
                ),
                errorWidget: (context, url, error) => ColoredBox(
                  color: context.vineColors.surfaceContainer,
                ),
              ),
            ),
          _InvitePreviewOverlay(
            showLoading: isLoading,
            title: title,
            previewTitle: previewTitle,
          ),
        ],
      ),
    );
  }
}

class _InvitePreviewOverlay extends StatelessWidget {
  const _InvitePreviewOverlay({
    required this.showLoading,
    required this.title,
    required this.previewTitle,
  });

  final bool showLoading;
  final String title;
  final String previewTitle;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                VineTheme.backgroundColor.withValues(alpha: 0),
                VineTheme.backgroundColor.withValues(alpha: 0.82),
              ],
            ),
          ),
        ),
        Center(
          child: showLoading
              ? const SizedBox.square(
                  dimension: 32,
                  child: DivineCircularProgressIndicator(
                    strokeWidth: 2,
                    color: VineTheme.primary,
                  ),
                )
              : const _InvitePlayBadge(),
        ),
        PositionedDirectional(
          start: 12,
          end: 12,
          bottom: 12,
          child: _InviteCopy(
            previewTitle: previewTitle,
            title: title,
            consequence: context.l10n.inboxCollabInviteTimelineConsequence,
          ),
        ),
      ],
    );
  }
}

class _InviteGradientCopy extends StatelessWidget {
  const _InviteGradientCopy({
    required this.title,
    required this.previewTitle,
  });

  final String title;
  final String previewTitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            VineTheme.backgroundColor.withValues(alpha: 0),
            VineTheme.backgroundColor.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 48, 12, 12),
        child: _InviteCopy(
          previewTitle: previewTitle,
          title: title,
          consequence: context.l10n.inboxCollabInviteTimelineConsequence,
        ),
      ),
    );
  }
}

class _InvitePlayBadge extends StatelessWidget {
  const _InvitePlayBadge();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: VineTheme.primary,
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: 48,
        height: 48,
        child: DivineIcon(
          icon: DivineIconName.playFill,
          color: VineTheme.onPrimary,
          size: 32,
        ),
      ),
    );
  }
}

/// Invite copy laid over the video thumbnail's dark gradient.
///
/// Both call sites paint a fixed dark scrim behind this column, so the text
/// stays light-on-dark in either appearance mode.
class _InviteCopy extends StatelessWidget {
  const _InviteCopy({
    required this.previewTitle,
    required this.title,
    required this.consequence,
  });

  final String previewTitle;
  final String title;
  final String consequence;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          previewTitle,
          style: VineTheme.labelLargeFont(color: VineTheme.primary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: VineTheme.titleMediumFont(color: VineTheme.primaryText),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          consequence,
          style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceMuted),
        ),
      ],
    );
  }
}

class _InviteActions extends StatelessWidget {
  const _InviteActions({
    required this.invite,
    required this.state,
  });

  final CollaboratorInvite invite;
  final CollaboratorInviteState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (state) {
      CollaboratorInviteState.accepted => _StatusText(
        label: l10n.inboxCollabInviteAcceptedStatus,
        color: context.vineColors.accentPositive,
      ),
      CollaboratorInviteState.ignored => _StatusText(
        label: l10n.inboxCollabInviteIgnoredStatus,
        color: context.vineColors.onSurfaceMuted,
      ),
      CollaboratorInviteState.failed => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusText(
            label: l10n.inboxCollabInviteAcceptError,
            color: VineTheme.error,
          ),
          const SizedBox(height: 12),
          _ActionRow(invite: invite, isAccepting: false),
        ],
      ),
      CollaboratorInviteState.accepting => _ActionRow(
        invite: invite,
        isAccepting: true,
      ),
      CollaboratorInviteState.pending => _ActionRow(
        invite: invite,
        isAccepting: false,
      ),
    };
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.invite,
    required this.isAccepting,
  });

  final CollaboratorInvite invite;
  final bool isAccepting;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: DivineButton(
            label: l10n.inboxCollabInviteCoPostButton,
            size: DivineButtonSize.small,
            isLoading: isAccepting,
            onPressed: isAccepting
                ? null
                : () {
                    runDetached(
                      context
                          .read<CollaboratorInviteActionsCubit>()
                          .acceptInvite(invite),
                      'accept collaborator invite',
                      logName: 'CollaboratorInviteCard',
                      category: LogCategory.ui,
                    );
                  },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DivineButton(
            label: l10n.inboxCollabInviteNotMineButton,
            type: DivineButtonType.secondary,
            size: DivineButtonSize.small,
            onPressed: isAccepting
                ? null
                : () {
                    runDetached(
                      context
                          .read<CollaboratorInviteActionsCubit>()
                          .ignoreInvite(invite),
                      'ignore collaborator invite',
                      logName: 'CollaboratorInviteCard',
                      category: LogCategory.ui,
                    );
                  },
          ),
        ),
      ],
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: VineTheme.labelLargeFont(color: color),
    );
  }
}
