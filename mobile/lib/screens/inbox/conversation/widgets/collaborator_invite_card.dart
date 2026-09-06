// ABOUTME: Card UI for structured collaborator invite direct messages.
// ABOUTME: Keeps invite plaintext fallback hidden and exposes accept/ignore.

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide AspectRatio, LogCategory;
import 'package:openvine/blocs/dm/conversation/collaborator_invite_actions_cubit.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/collaborator_invite.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/comments/widgets/video_comment_player.dart';
import 'package:openvine/screens/inbox/conversation/widgets/video_link_preview_cubit.dart';
import 'package:openvine/services/collaborator_invite_state_store.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

const double _collaboratorInviteMaxCardWidth = 420;
const double _collaboratorInviteMaxViewportHeightFraction = 0.62;

class CollaboratorInviteCard extends StatefulWidget {
  const CollaboratorInviteCard({
    required this.invite,
    required this.isSent,
    this.senderDisplayName,
    super.key,
  });

  final CollaboratorInvite invite;
  final bool isSent;
  final String? senderDisplayName;

  @override
  State<CollaboratorInviteCard> createState() => _CollaboratorInviteCardState();
}

class _CollaboratorInviteCardState extends State<CollaboratorInviteCard> {
  @override
  void initState() {
    super.initState();
    // Sender-side cards are static — they never read or write cubit
    // state. The recipient is the only side with actionable state, so
    // skip the load and the BlocSelector subscription entirely (#3559).
    if (!widget.isSent) {
      _loadInviteState();
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
        senderDisplayName: widget.senderDisplayName,
        action: _StatusText(
          label: context.l10n.inboxCollabInviteSentStatus,
          color: context.vineColors.onSurfaceMuted,
        ),
      );
    }
    return BlocSelector<
      CollaboratorInviteActionsCubit,
      CollaboratorInviteActionsState,
      CollaboratorInviteState
    >(
      selector: (state) => state.stateFor(widget.invite),
      builder: (context, inviteState) {
        return _CardChrome(
          invite: widget.invite,
          isSent: false,
          senderDisplayName: widget.senderDisplayName,
          action: _InviteActions(
            invite: widget.invite,
            state: inviteState,
          ),
        );
      },
    );
  }
}

class _CardChrome extends ConsumerWidget {
  const _CardChrome({
    required this.invite,
    required this.isSent,
    required this.action,
    this.senderDisplayName,
  });

  final CollaboratorInvite invite;
  final bool isSent;
  final Widget action;
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
              inviteThumbnailUrl: _inviteThumbnailUrl,
              title: _titleText(context),
              previewTitle: _previewTitle(context),
              action: action,
            ),
          ),
        ),
      ),
    );
  }
}

class _InviteVideoContent extends StatelessWidget {
  const _InviteVideoContent({
    required this.inviteThumbnailUrl,
    required this.title,
    required this.previewTitle,
    required this.action,
  });

  final String? inviteThumbnailUrl;
  final String title;
  final String previewTitle;
  final Widget action;

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
              child: action,
            ),
          ],
        );
      },
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
                    context.read<CollaboratorInviteActionsCubit>().acceptInvite(
                      invite,
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
                    context.read<CollaboratorInviteActionsCubit>().ignoreInvite(
                      invite,
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
