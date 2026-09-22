// ABOUTME: "Scheduled" section at the top of the Drafts tab (#3538),
// ABOUTME: with cancel, change time, post now and retry per row.

import 'package:db_client/db_client.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/drafts_library/drafts_library_bloc.dart';
import 'package:openvine/blocs/scheduled_posts/scheduled_posts_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/providers/scheduled_posts_providers.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/widgets/library/draft_status_badge.dart';
import 'package:openvine/widgets/video_clip/clip_thumbnail_image.dart';
import 'package:openvine/widgets/video_metadata/schedule_date_time_sheet.dart';
import 'package:openvine/widgets/video_metadata/scheduled_time_format.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Provides [ScheduledPostsBloc] to its subtree when the account has an
/// outbox, and tells [builder] whether it did.
///
/// The readiness gate hands over a repository only once the session can sign,
/// so `available` is false on a cold start and while signed out. A caller must
/// not build [ScheduledSectionSliver] then — it looks the bloc up and would
/// throw.
class ScheduledPostsScope extends ConsumerWidget {
  const ScheduledPostsScope({required this.builder, super.key});

  final Widget Function(BuildContext context, {required bool available})
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(scheduledPostsRepositoryProvider);
    final coordinator = ref.watch(scheduledPostCoordinatorProvider);
    final draftService = ref.watch(draftStorageServiceProvider);
    if (repository == null || coordinator == null) {
      return builder(context, available: false);
    }
    return BlocProvider(
      key: ValueKey((repository, coordinator)),
      create: (_) => ScheduledPostsBloc(
        repository: repository,
        coordinator: coordinator,
        draftService: draftService,
      )..add(const ScheduledPostsStarted()),
      child: ScheduledPostsDraftsRefresher(
        child: Builder(
          builder: (context) => builder(context, available: true),
        ),
      ),
    );
  }
}

/// Reloads the drafts list once a publish stops being in flight.
///
/// A finished publish reclaims the draft it was copied from, after the list
/// has already loaded — `DraftsTab._openDraft` reloads on the way back from
/// the editor and admits it can lose that race. Scheduling makes the stale
/// row visible, because the creator lands on this list and stays there, so
/// the draft sits next to the scheduled post it became.
@visibleForTesting
class ScheduledPostsDraftsRefresher extends StatelessWidget {
  const ScheduledPostsDraftsRefresher({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<BackgroundPublishBloc, BackgroundPublishState>(
      listenWhen: (previous, current) =>
          previous.uploads.length > current.uploads.length,
      listener: (context, _) => context.read<DraftsLibraryBloc>().add(
        const DraftsLibraryLoadRequested(),
      ),
      child: child,
    );
  }
}

/// The section itself, as a sliver so it scrolls with the drafts under it.
///
/// Renders nothing at all until there is something to show: no header, no
/// spinner and no empty state. A creator who never schedules anything never
/// sees that the feature exists from here.
///
/// Requires a [ScheduledPostsBloc] above it — [ScheduledPostsScope] only
/// provides one when the account can schedule, so callers pass
/// [SliverToBoxAdapter] with nothing in it instead of this widget when it
/// cannot.
@visibleForTesting
class ScheduledSectionSliver extends StatelessWidget {
  const ScheduledSectionSliver({super.key});

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
        // A cancelled post is parked back as a draft, and a published one is
        // reclaimed — neither reaches the drafts list on its own.
        context.read<DraftsLibraryBloc>().add(
          const DraftsLibraryLoadRequested(),
        );
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

        // The outbox row is written as soon as the event is signed, while the
        // upload is still listed as in flight until the publish bloc settles.
        // Both describe the same post, so the durable row wins and the
        // in-flight tile only covers what has not reached the outbox yet.
        final enqueued = {for (final item in state.items) item.draftId};
        final rows = <Widget>[
          for (final draft in uploads)
            if (!enqueued.contains(draft.id)) _UploadingTile(draft: draft),
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
        ];
        if (rows.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        // The closing "Drafts" label belongs to the list below, but it is
        // rendered from here because it exists only while this section does:
        // without upcoming posts there is one list and it needs no label.
        return SliverList.list(
          children: [
            const _SectionHeader(_SectionHeaderKind.scheduled),
            ...rows,
            const _SectionHeader(_SectionHeaderKind.drafts),
          ],
        );
      },
    );
  }
}

enum _SectionHeaderKind { scheduled, drafts }

/// The small label that names a run of rows, with a rule under the last
/// scheduled row so the two groups do not read as one list.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.kind);

  final _SectionHeaderKind kind;

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      _SectionHeaderKind.scheduled => context.l10n.libraryScheduledSectionTitle,
      _SectionHeaderKind.drafts => context.l10n.libraryTabDrafts,
    };
    final title = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: VineTheme.labelMediumFont(
          color: context.vineColors.secondaryText,
        ),
      ),
    );
    if (kind == _SectionHeaderKind.scheduled) return title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Divider(height: 1, color: context.vineColors.disabled),
        ),
        title,
      ],
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
    // Inside a section headed "Scheduled", a "Scheduled" badge on every row
    // says nothing — only the states that deviate from it earn one.
    final (badgeLabel, tone) = switch (item.status) {
      ScheduledPostStatus.pendingSubmit => (
        l10n.libraryScheduledBadgeWaitingForServer,
        DraftStatusBadgeTone.muted,
      ),
      ScheduledPostStatus.failed => (
        l10n.libraryScheduledBadgeFailed,
        DraftStatusBadgeTone.warning,
      ),
      ScheduledPostStatus.scheduled ||
      ScheduledPostStatus.published ||
      ScheduledPostStatus.cancelled => (null, DraftStatusBadgeTone.positive),
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
      badge: badgeLabel == null
          ? null
          : DraftStatusBadge(label: badgeLabel, tone: tone),
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
              type: DivineIconButtonType.ghostSecondary,
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
              type: DivineIconButtonType.ghostSecondary,
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
    required this.trailing,
    this.badge,
  });

  final Widget thumbnail;
  final String title;
  final String? subtitle;

  /// Shown after the title when the row deviates from plain "scheduled".
  final Widget? badge;
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
          if (badge != null) ...[const SizedBox(width: 8), badge!],
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
