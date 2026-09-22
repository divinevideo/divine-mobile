// ABOUTME: Library tab listing the account's scheduled posts (#3538), with
// ABOUTME: cancel, change time, post now and retry per row.

import 'package:db_client/db_client.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/scheduled_posts/scheduled_posts_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/providers/scheduled_posts_providers.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/widgets/library/draft_status_badge.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';
import 'package:openvine/widgets/video_clip/clip_thumbnail_image.dart';
import 'package:openvine/widgets/video_metadata/schedule_date_time_sheet.dart';
import 'package:openvine/widgets/video_metadata/scheduled_time_format.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// The Scheduled tab: a page that wires [ScheduledPostsBloc] to the
/// account's outbox and coordinator, re-keyed when either changes identity.
class ScheduledTab extends ConsumerWidget {
  const ScheduledTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(scheduledPostsRepositoryProvider);
    final coordinator = ref.watch(scheduledPostCoordinatorProvider);
    final draftService = ref.watch(draftStorageServiceProvider);
    if (repository == null || coordinator == null) {
      return const _ScheduledEmptyState();
    }
    return BlocProvider(
      key: ValueKey((repository, coordinator)),
      create: (_) => ScheduledPostsBloc(
        repository: repository,
        coordinator: coordinator,
        draftService: draftService,
      )..add(const ScheduledPostsStarted()),
      child: const ScheduledTabView(),
    );
  }
}

/// The list itself, given a [ScheduledPostsBloc] and a
/// [BackgroundPublishBloc]. Public so a widget test can pump it without a
/// signed-in outbox behind [ScheduledTab].
@visibleForTesting
class ScheduledTabView extends StatelessWidget {
  const ScheduledTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ScheduledPostsBloc, ScheduledPostsState>(
      listenWhen: (previous, current) =>
          previous.actionCount != current.actionCount,
      listener: (context, state) {
        final l10n = context.l10n;
        final label = switch (state.lastAction) {
          ScheduledPostsActionOutcome.none => null,
          ScheduledPostsActionOutcome.cancelled =>
            l10n.libraryScheduledCancelledSnackbar,
          ScheduledPostsActionOutcome.rescheduled =>
            l10n.libraryScheduledRescheduledSnackbar,
          ScheduledPostsActionOutcome.publishedNow =>
            l10n.libraryScheduledPublishedNowSnackbar,
          ScheduledPostsActionOutcome.retryQueued =>
            l10n.libraryScheduledRetryQueuedSnackbar,
          ScheduledPostsActionOutcome.alreadyPublished =>
            l10n.libraryScheduledAlreadyPublishedSnackbar,
          ScheduledPostsActionOutcome.unavailable =>
            l10n.libraryScheduledUnavailableSnackbar,
          ScheduledPostsActionOutcome.failed =>
            l10n.libraryScheduledActionFailedSnackbar,
        };
        if (label == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: VineTheme.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            content: DivineSnackbarContainer(label: label),
          ),
        );
      },
      builder: (context, state) {
        final uploads = context
            .select<BackgroundPublishBloc, _ScheduledUploads>(
              (bloc) => _ScheduledUploads.fromState(bloc.state),
            )
            .drafts;

        if (state.status != ScheduledPostsStatus.loaded && uploads.isEmpty) {
          return Center(
            child: DivineCircularProgressIndicator(
              color: context.vineColors.accentPositive,
            ),
          );
        }
        if (state.isEmpty && uploads.isEmpty) {
          return const _ScheduledEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<ScheduledPostsBloc>().add(
              const ScheduledPostsRefreshRequested(),
            );
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              for (final draft in uploads) _UploadingTile(draft: draft),
              for (final item in state.items)
                _ScheduledPostTile(
                  item: item,
                  busy: state.busyEventId == item.eventId,
                ),
              for (final entry in state.remotePosts)
                _RemotePostTile(
                  entry: entry,
                  busy: state.busyEventId == entry.eventId,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The in-flight uploads of scheduled posts, as an [Equatable] so the
/// selector above only rebuilds when that set changes.
class _ScheduledUploads extends Equatable {
  const _ScheduledUploads(this.drafts);

  factory _ScheduledUploads.fromState(BackgroundPublishState state) =>
      _ScheduledUploads([
        for (final upload in state.uploads)
          if (upload.result == null && upload.draft.scheduledAt != null)
            upload.draft,
      ]);

  final List<DivineVideoDraft> drafts;

  @override
  List<Object?> get props => [drafts];
}

class _ScheduledEmptyState extends StatelessWidget {
  const _ScheduledEmptyState();

  @override
  Widget build(BuildContext context) {
    return EmptyLibraryState(
      icon: DivineIconName.clockCountdown,
      title: context.l10n.libraryScheduledEmptyTitle,
      subtitle: context.l10n.libraryScheduledEmptySubtitle,
      showRecordButton: false,
    );
  }
}

/// A row for a post whose media is still uploading.
class _UploadingTile extends StatelessWidget {
  const _UploadingTile({required this.draft});

  final DivineVideoDraft draft;

  @override
  Widget build(BuildContext context) {
    final scheduledAt = draft.scheduledAt;
    return _ScheduledRow(
      thumbnail: _Thumbnail(localPath: draft.coverThumbnailPath),
      title: draft.title,
      subtitle: scheduledAt == null
          ? null
          : context.l10n.libraryScheduledGoesOutAt(
              formatScheduledDateTime(context, scheduledAt),
            ),
      badge: DraftStatusBadge(
        label: context.l10n.libraryScheduledBadgeUploading,
        tone: DraftStatusBadgeTone.muted,
      ),
      trailing: SizedBox.square(
        dimension: 24,
        child: DivineCircularProgressIndicator(
          color: context.vineColors.accentPositive,
          strokeWidth: 2,
        ),
      ),
    );
  }
}

/// A row for one of this device's scheduled posts.
class _ScheduledPostTile extends StatelessWidget {
  const _ScheduledPostTile({required this.item, required this.busy});

  final ScheduledPostItem item;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (badgeLabel, tone) = switch (item.status) {
      ScheduledPostStatus.scheduled => (
        l10n.libraryScheduledBadgeScheduled,
        DraftStatusBadgeTone.positive,
      ),
      ScheduledPostStatus.pendingSubmit => (
        l10n.libraryScheduledBadgeWaitingForServer,
        DraftStatusBadgeTone.muted,
      ),
      ScheduledPostStatus.failed => (
        l10n.libraryScheduledBadgeFailed,
        DraftStatusBadgeTone.warning,
      ),
      ScheduledPostStatus.published || ScheduledPostStatus.cancelled => (
        l10n.libraryScheduledBadgeScheduled,
        DraftStatusBadgeTone.positive,
      ),
    };
    final title = item.title.isEmpty ? l10n.draftUntitled : item.title;
    return _ScheduledRow(
      thumbnail: _Thumbnail(
        localPath: item.draft?.coverThumbnailPath,
        url: item.thumbnailUrl,
      ),
      title: title,
      subtitle: l10n.libraryScheduledGoesOutAt(
        formatScheduledDateTime(context, item.publishAt),
      ),
      badge: DraftStatusBadge(label: badgeLabel, tone: tone),
      trailing: busy
          ? SizedBox.square(
              dimension: 24,
              child: DivineCircularProgressIndicator(
                color: context.vineColors.accentPositive,
                strokeWidth: 2,
              ),
            )
          : DivineIconButton(
              icon: DivineIconName.dotsThreeVertical,
              type: DivineIconButtonType.tertiary,
              size: DivineIconButtonSize.small,
              semanticLabel: l10n.libraryScheduledMoreActionsSemanticLabel(
                title,
              ),
              onPressed: () => _openActions(context, title),
            ),
    );
  }

  Future<void> _openActions(BuildContext context, String title) async {
    final l10n = context.l10n;
    final bloc = context.read<ScheduledPostsBloc>();
    final failed = item.status == ScheduledPostStatus.failed;
    await VineBottomSheetActionMenu.show(
      context: context,
      title: Text(
        title,
        style: VineTheme.titleSmallFont(color: context.vineColors.primaryText),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      options: [
        if (failed)
          VineBottomSheetActionData(
            iconPath: DivineIconName.arrowsClockwise.assetPath,
            label: l10n.libraryScheduledActionRetry,
            onTap: () => bloc.add(ScheduledPostsRetryRequested(item.eventId)),
          ),
        VineBottomSheetActionData(
          iconPath: DivineIconName.clockCountdown.assetPath,
          label: l10n.libraryScheduledActionReschedule,
          onTap: () => _reschedule(context, bloc),
        ),
        VineBottomSheetActionData(
          iconPath: DivineIconName.paperPlaneTilt.assetPath,
          label: l10n.libraryScheduledActionPublishNow,
          onTap: () =>
              bloc.add(ScheduledPostsPublishNowRequested(item.eventId)),
        ),
        VineBottomSheetActionData(
          iconPath: DivineIconName.x.assetPath,
          label: l10n.libraryScheduledActionCancel,
          isDestructive: true,
          onTap: () => _confirmCancel(context, bloc),
        ),
      ],
    );
  }

  Future<void> _reschedule(
    BuildContext context,
    ScheduledPostsBloc bloc,
  ) async {
    final picked = await ScheduleDateTimeSheet.show(
      context,
      initialTime: item.publishAt,
    );
    if (picked == null) return;
    bloc.add(ScheduledPostsRescheduleRequested(item.eventId, picked));
  }

  Future<void> _confirmCancel(
    BuildContext context,
    ScheduledPostsBloc bloc,
  ) async {
    final l10n = context.l10n;
    final confirmed = await VineBottomSheetPrompt.show<bool>(
      context: context,
      sticker: DivineStickerName.alert,
      title: l10n.libraryScheduledCancelTitle,
      subtitle: l10n.libraryScheduledCancelMessage,
      primaryButtonText: l10n.libraryScheduledCancelConfirm,
      secondaryButtonText: l10n.libraryScheduledCancelKeep,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );
    if (confirmed != true) return;
    bloc.add(ScheduledPostsCancelRequested(item.eventId));
  }
}

/// A row for a post the relay holds that was scheduled from another device.
class _RemotePostTile extends StatelessWidget {
  const _RemotePostTile({required this.entry, required this.busy});

  final RemoteScheduledPost entry;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = l10n.libraryScheduledRemoteTitle;
    return _ScheduledRow(
      thumbnail: const _Thumbnail(),
      title: title,
      subtitle: l10n.libraryScheduledGoesOutAt(
        formatScheduledDateTime(context, entry.publishAt),
      ),
      badge: DraftStatusBadge(label: l10n.libraryScheduledBadgeScheduled),
      trailing: busy
          ? SizedBox.square(
              dimension: 24,
              child: DivineCircularProgressIndicator(
                color: context.vineColors.accentPositive,
                strokeWidth: 2,
              ),
            )
          : DivineIconButton(
              icon: DivineIconName.dotsThreeVertical,
              type: DivineIconButtonType.tertiary,
              size: DivineIconButtonSize.small,
              semanticLabel: l10n.libraryScheduledMoreActionsSemanticLabel(
                title,
              ),
              onPressed: () => _openActions(context, title),
            ),
    );
  }

  Future<void> _openActions(BuildContext context, String title) async {
    final l10n = context.l10n;
    final bloc = context.read<ScheduledPostsBloc>();
    await VineBottomSheetActionMenu.show(
      context: context,
      title: Text(
        title,
        style: VineTheme.titleSmallFont(color: context.vineColors.primaryText),
      ),
      options: [
        VineBottomSheetActionData(
          iconPath: DivineIconName.x.assetPath,
          label: l10n.libraryScheduledActionCancel,
          isDestructive: true,
          onTap: () =>
              bloc.add(ScheduledPostsCancelRemoteRequested(entry.eventId)),
        ),
      ],
    );
  }
}

class _ScheduledRow extends StatelessWidget {
  const _ScheduledRow({
    required this.thumbnail,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.trailing,
  });

  final Widget thumbnail;
  final String title;
  final String? subtitle;
  final Widget badge;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 72,
      contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 10, 0),
      leading: thumbnail,
      title: Row(
        children: [
          Flexible(
            child: Text(
              title.isEmpty ? context.l10n.draftUntitled : title,
              style: VineTheme.titleSmallFont(
                color: context.vineColors.primaryText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          badge,
        ],
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: VineTheme.bodySmallFont(
                color: context.vineColors.primaryText,
              ),
            ),
      trailing: trailing,
    );
  }
}

/// The 40 px cover: the draft's local thumbnail while it exists, else the
/// published thumbnail URL from the event, else a placeholder.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.localPath, this.url});

  final String? localPath;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final placeholder = DivineIcon(
      icon: DivineIconName.filmSlate,
      color: context.vineColors.secondaryText,
      size: 20,
    );
    final Widget image;
    if (localPath != null) {
      image = ClipThumbnailImage(
        path: localPath!,
        fit: BoxFit.cover,
        placeholder: placeholder,
      );
    } else if (url != null) {
      image = VineCachedImage(
        imageUrl: url!,
        memCacheWidth: 120,
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => placeholder,
      );
    } else {
      image = placeholder;
    }
    return Container(
      width: 40,
      height: 40,
      decoration: ShapeDecoration(
        color: context.vineColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      foregroundDecoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(color: context.vineColors.disabled),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: image,
        ),
      ),
    );
  }
}
