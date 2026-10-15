// ABOUTME: Creator approval and requester use/save cards for sound request DMs.
// ABOUTME: Cards dispatch Cubit actions; current policy remains authoritative.
import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/blocs/sound_requests/sound_ready_actions_cubit.dart';
import 'package:openvine/blocs/sound_requests/sound_requests_cubit.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/recorder_sound_selection.dart';
import 'package:openvine/screens/comments/widgets/video_comment_player.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

class SoundRequestCard extends StatefulWidget {
  const SoundRequestCard({
    required this.message,
    required this.isSent,
    super.key,
  });
  final SoundRequestMessage message;
  final bool isSent;
  @override
  State<SoundRequestCard> createState() => _SoundRequestCardState();
}

class _SoundRequestCardState extends State<SoundRequestCard> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SoundRequestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) _load();
  }

  void _load() => runDetached(
    context.read<SoundRequestsCubit>().loadPreview(widget.message.videoAddress),
    'load sound request video preview',
    logName: 'SoundRequestCard',
    category: LogCategory.ui,
  );
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<SoundRequestsCubit, SoundRequestsState>(
        builder: (context, state) {
          final m = widget.message;
          final ready = m.kind == SoundRequestMessageKind.ready;
          final video = state.videos[m.videoAddress];
          return Align(
            alignment: widget.isSent
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.82,
              ),
              decoration: BoxDecoration(
                color: context.vineColors.surfaceContainerHigh,
                border: Border.all(color: context.vineColors.outlineMuted),
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (video != null) _SoundSourcePreview(video: video),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 12,
                      children: [
                        Text(
                          ready
                              ? context.l10n.soundReadyTitle
                              : context.l10n.soundRequestTitle,
                          style: VineTheme.titleMediumFont(
                            color: context.vineColors.primaryText,
                          ),
                        ),
                        Text(
                          ready
                              ? context.l10n.soundReadyDescription
                              : context.l10n.soundRequestDescription,
                          style: VineTheme.bodyMediumFont(
                            color: context.vineColors.onSurfaceVariant,
                          ),
                        ),
                        if (ready &&
                            !widget.isSent &&
                            m.senderPubkey == m.creatorPubkey &&
                            m.recipientPubkey == state.ownerPubkey &&
                            state.snapshot.requests[m.requestId]?.requester ==
                                state.ownerPubkey)
                          BlocProvider(
                            key: ValueKey((state.ownerPubkey, m.messageId)),
                            create: (_) {
                              final root = context.read<SoundRequestsCubit>();
                              final owner = state.ownerPubkey;
                              return SoundReadyActionsCubit(
                                resolveSound: () => root.resolveReady(m),
                                isCurrentAccount: () =>
                                    !root.isClosed &&
                                    root.state.ownerPubkey == owner,
                              );
                            },
                            child: _ReadyActions(
                              message: m,
                              owner: state.ownerPubkey,
                            ),
                          ),
                        if (!ready)
                          _CreatorActions(message: m, isSent: widget.isSent),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class _SoundSourcePreview extends StatelessWidget {
  const _SoundSourcePreview({required this.video});
  final VideoEvent video;
  @override
  Widget build(BuildContext context) {
    final url = video.inlinePlayerVideoUrl ?? video.videoUrl;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (url != null && url.isNotEmpty)
          SizedBox(
            height: 180,
            child: VideoCommentPlayer(
              videoUrl: url,
              thumbnailUrl: video.thumbnailUrl,
            ),
          )
        else if (video.thumbnailUrl case final thumbnail?)
          SizedBox(
            height: 140,
            child: VineCachedImage(imageUrl: thumbnail),
          ),
        if (video.title?.isNotEmpty ?? false)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Text(
              video.title!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.primaryText,
              ),
            ),
          ),
      ],
    );
  }
}

class _CreatorActions extends StatelessWidget {
  const _CreatorActions({required this.message, required this.isSent});
  final SoundRequestMessage message;
  final bool isSent;
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<SoundRequestsCubit, SoundRequestsState>(
        builder: (context, state) {
          if (isSent) return Text(context.l10n.soundRequestSent);
          if (message.creatorPubkey != state.ownerPubkey) {
            return const SizedBox.shrink();
          }
          final entry =
              state.snapshot.requests[message.messageId] ??
              state.snapshot.requests.values
                  .where(
                    (r) =>
                        r.requester == message.senderPubkey &&
                        r.videoAddress == message.videoAddress,
                  )
                  .firstOrNull;
          if (entry?.status == SoundRequestStatus.ready) {
            return Text(context.l10n.soundReadyTitle);
          }
          if (entry?.status == SoundRequestStatus.dismissed) {
            return Text(context.l10n.inboxCollabInviteIgnoredStatus);
          }
          final working =
              (state.target == entry?.id &&
                  state.operation == SoundRequestOperation.working) ||
              entry == null;
          final retry =
              entry?.status == SoundRequestStatus.failed ||
              entry?.status == SoundRequestStatus.awaitingPolicy;
          final failed =
              state.target == entry?.id &&
              state.operation == SoundRequestOperation.failed;
          final cubit = context.read<SoundRequestsCubit>();
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              if (failed) Text(context.l10n.soundReuseUnavailable),
              DivineButton(
                label: retry
                    ? context.l10n.commonRetry
                    : context.l10n.soundRequestEnable,
                isLoading: working,
                size: DivineButtonSize.small,
                onPressed: working
                    ? null
                    : () => runDetached(
                        retry ? cubit.retry(entry.id) : cubit.approve(entry.id),
                        'approve sound request',
                        logName: 'SoundRequestCard',
                        category: LogCategory.ui,
                      ),
              ),
              DivineButton(
                label: context.l10n.saveOriginalDismiss,
                type: DivineButtonType.secondary,
                size: DivineButtonSize.small,
                onPressed: working
                    ? null
                    : () => runDetached(
                        cubit.dismiss(entry.id),
                        'dismiss sound request',
                        logName: 'SoundRequestCard',
                        category: LogCategory.ui,
                      ),
              ),
            ],
          );
        },
      );
}

class _ReadyActions extends StatelessWidget {
  const _ReadyActions({required this.message, required this.owner});
  final SoundRequestMessage message;
  final String owner;
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<SoundReadyActionsCubit, SoundReadyActionStatus>(
        builder: (context, status) =>
            BlocBuilder<SavedSoundsBloc, SavedSoundsState>(
              builder: (context, library) {
                final saved = library.sounds.any(
                  (s) => s.audio.id == message.audioEventId,
                );
                final working = status == SoundReadyActionStatus.working;
                final actions = context.read<SoundReadyActionsCubit>();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: [
                    if (status == SoundReadyActionStatus.failed)
                      Text(context.l10n.soundReuseUnavailable),
                    DivineButton(
                      label: context.l10n.soundReadyUse,
                      size: DivineButtonSize.small,
                      isLoading: working,
                      onPressed: working
                          ? null
                          : () => runDetached(
                              actions.use((sound) async {
                                if (!context.mounted) return;
                                await context.pushWithVideoPause(
                                  VideoRecorderScreen.path,
                                  extra: RecorderSoundSelection(
                                    sound: sound,
                                    ownerPubkey: owner,
                                  ),
                                );
                              }),
                              'use requested sound',
                              logName: 'SoundRequestCard',
                              category: LogCategory.ui,
                            ),
                    ),
                    DivineButton(
                      label: saved
                          ? context.l10n.soundRequestSaved
                          : context.l10n.soundReadySave,
                      size: DivineButtonSize.small,
                      type: DivineButtonType.secondary,
                      onPressed: working || saved
                          ? null
                          : () => runDetached(
                              actions.save((sound) async {
                                if (!context.mounted) return;
                                await context.read<SavedSoundsBloc>().saveSound(
                                  sound,
                                );
                              }),
                              'save requested sound',
                              logName: 'SoundRequestCard',
                              category: LogCategory.ui,
                            ),
                    ),
                  ],
                );
              },
            ),
      );
}
