// ABOUTME: Screen for displaying and posting comments on videos with threaded reply support
// ABOUTME: Uses BLoC pattern with Nostr Kind 1111 (NIP-22) events for comments

import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' hide NIP71VideoKinds;
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/comments/comment_composer/comment_composer_bloc.dart';
import 'package:openvine/blocs/comments/comment_reactions/comment_reactions_bloc.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_bloc.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_helpers.dart';
import 'package:openvine/blocs/comments/comments_surface_performance_telemetry.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_reply_context.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/video_reply_context_provider.dart';
import 'package:openvine/screens/comments/widgets/widgets.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/utils/pause_aware_modals.dart';

/// Maps any of the three per-bloc errors to a localized user-facing string.
///
/// Kept as plain top-level functions taking [AppLocalizations] so the snackbar
/// `BlocListener` callbacks can dispatch in one line without re-reading
/// `context.l10n` on every emit.
String _listErrorToString(AppLocalizations l10n, CommentsListError error) {
  return switch (error) {
    CommentsListError.loadFailed => l10n.commentsErrorLoadFailed,
  };
}

String _composerErrorToString(AppLocalizations l10n, ComposerError error) {
  return switch (error) {
    ComposerError.notAuthenticated => l10n.commentsErrorNotAuthenticatedComment,
    ComposerError.postCommentFailed => l10n.commentsErrorPostCommentFailed,
    ComposerError.postReplyFailed => l10n.commentsErrorPostReplyFailed,
    ComposerError.editFailed => l10n.commentsErrorEditFailed,
  };
}

String _reactionsErrorToString(AppLocalizations l10n, ReactionsError error) {
  return switch (error) {
    ReactionsError.notAuthenticated =>
      l10n.commentsErrorNotAuthenticatedInteract,
    ReactionsError.voteFailed => l10n.commentsErrorVoteFailed,
    ReactionsError.reportFailed => l10n.commentsErrorReportFailed,
    ReactionsError.blockFailed => l10n.commentsErrorBlockFailed,
    ReactionsError.deleteCommentFailed => l10n.commentsErrorDeleteFailed,
  };
}

/// Normalizes comment text for duplicate detection: trims, collapses internal
/// whitespace, and lowercases. The real #5854 duplicates differ only in
/// whitespace ("box of  krayshawns" vs "box of krayshawns"), so an exact-match
/// guard would leak — this catches them.
String _normalizeCommentText(String text) =>
    text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Returns true only for the resend window #5854 needs to suppress: an
/// in-flight optimistic reply by the same author, to the same parent, with the
/// same normalized text. Top-level comments and confirmed comments are allowed
/// so intentional repeated reactions are not silently dropped.
bool isDuplicatePendingReplySubmission({
  required Iterable<Comment> comments,
  required String content,
  required String authorPubkey,
  String? parentCommentId,
}) {
  if (parentCommentId == null) return false;

  final normalized = _normalizeCommentText(content);
  return comments.any(
    (c) =>
        c.id.startsWith(commentPlaceholderIdPrefix) &&
        c.authorPubkey == authorPubkey &&
        c.replyToEventId == parentCommentId &&
        _normalizeCommentText(c.content) == normalized,
  );
}

/// Dynamic title widget that shows comment count and a "# new" pill
/// when real-time comments arrive.
/// Initially shows the count from video metadata, then updates to loaded count.
class _CommentsTitle extends StatelessWidget {
  const _CommentsTitle({
    required this.initialCount,
    required this.onNewCommentsPillTap,
  });

  final int initialCount;

  /// Called when the user taps the "# new" pill.
  final VoidCallback onNewCommentsPillTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommentsListBloc, CommentsListState>(
      buildWhen: (prev, next) =>
          prev.commentsById.length != next.commentsById.length ||
          prev.status != next.status ||
          prev.newCommentCount != next.newCommentCount,
      builder: (context, state) {
        // Use loaded count if available, otherwise use initial count.
        final count = state.status == CommentsStatus.success
            ? state.commentsById.length
            : initialCount;

        return Semantics(
          // The sheet has no close button, so this is also the drag anchor
          // a UI test grabs to pull the sheet down. Without its own node the
          // title's text merges into the whole-sheet container and any
          // gesture anchored on it starts from the middle of the list.
          identifier: SemanticIds.commentsSheetTitle,
          container: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Flexible(
                child: Text(
                  context.l10n.commentsHeaderCount(count),
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.onSurface,
                  ),
                  maxLines: 1,
                  softWrap: false,
                  overflow: .fade,
                ),
              ),
              if (state.newCommentCount > 0)
                NewCommentsPill(
                  count: state.newCommentCount,
                  onTap: () {
                    onNewCommentsPillTap();
                    context.read<CommentsListBloc>().add(
                      const NewCommentsAcknowledged(),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Container for the comments bottom sheet. Not instantiable — use
/// [CommentsScreen.show] to present the sheet.
abstract final class CommentsScreen {
  /// Shows comments as a modal bottom sheet overlay.
  ///
  /// Wires three BLoCs ([CommentsListBloc], [CommentComposerBloc],
  /// [CommentReactionsBloc]) via [MultiBlocProvider] and adds [BlocListener]s
  /// that bridge composer and reactions outbox signals into list-bloc store
  /// mutations.
  static Future<void> show(
    BuildContext context,
    VideoEvent video, {
    int? initialCommentCount,
    ValueChanged<int>? onCommentCountChanged,
  }) {
    final container = ProviderScope.containerOf(context, listen: false);
    final draggableController = DraggableScrollableController();

    // Synchronously available repositories / services.
    final commentsRepository = container.read(commentsRepositoryProvider);
    final authService = container.read(authServiceProvider);
    final likesRepository = container.read(likesRepositoryProvider);
    final contentBlocklistRepository = container.read(
      contentBlocklistRepositoryProvider,
    );
    final contentReportingServiceFuture = container.read(
      contentReportingServiceProvider.future,
    );
    final profileRepository = container.read(profileRepositoryProvider);
    final followRepository = container.read(followRepositoryProvider);
    final showVideoReplies = container.read(
      isFeatureEnabledProvider(FeatureFlag.videoReplies),
    );
    final seedCommentCount = initialCommentCount ?? liveCommentCountSeed(video);
    final surfaceTelemetry =
        CommentsSurfacePerformanceTelemetry.withTracker(
          container.read(surfacePerformanceTrackerProvider),
        )..start(
          videoRepliesEnabled: showVideoReplies,
          initialCount: seedCommentCount,
        );

    // The draggable scroll controller is created inside buildScrollBody but
    // is also needed by the title's "new comments" pill (which lives above
    // the scrollable region). Share it through a closure-captured holder.
    ScrollController? activeScrollController;

    return context
        .showVideoPausingVineBottomSheet<void>(
          snap: true,
          snapSizes: _CommentsSheetSizing.snapSizes,
          initialChildSize: _CommentsSheetSizing.initial,
          minChildSize: _CommentsSheetSizing.min,
          maxChildSize: _CommentsSheetSizing.max,
          draggableController: draggableController,
          // Wrap the whole sheet subtree in a MultiBlocProvider so every slot
          // (title, trailing, bottomInput, buildScrollBody) shares the same
          // three blocs. BlocProvider owns lifecycle — it closes each BLoC
          // automatically when the sheet is disposed, so we don't need a manual
          // try/finally around the await.
          contentWrapper: (context, child) => MultiBlocProvider(
            providers: [
              BlocProvider<CommentsListBloc>(
                create: (_) => CommentsListBloc(
                  commentsRepository: commentsRepository,
                  rootEventId: video.id,
                  rootEventKind: NIP71VideoKinds.addressableShortVideo,
                  rootAuthorPubkey: video.pubkey,
                  rootAddressableId: video.addressableId,
                  initialTotalCount: seedCommentCount,
                  includeVideoReplies: showVideoReplies,
                )..add(const CommentsLoadRequested()),
              ),
              BlocProvider<CommentComposerBloc>(
                create: (innerContext) {
                  // Captured at create-time. CommentsListBloc is provided above
                  // in the same MultiBlocProvider so it's available here via
                  // inheritance; the reference is stable for the sheet's life.
                  // The callback re-reads `state.commentsById` on every search
                  // so suggestions reflect the latest loaded comments.
                  final listBloc = innerContext.read<CommentsListBloc>();
                  return CommentComposerBloc(
                    commentsRepository: commentsRepository,
                    authService: authService,
                    rootEventId: video.id,
                    rootEventKind: NIP71VideoKinds.addressableShortVideo,
                    rootAuthorPubkey: video.pubkey,
                    rootAddressableId: video.addressableId,
                    profileRepository: profileRepository,
                    mentionCandidatePubkeysProvider: () => <String>[
                      // Thread participants first — restored after the split
                      // (pre-split CommentsBloc seeded these from state.commentsById).
                      ...listBloc.state.commentsById.values.map(
                        (c) => c.authorPubkey,
                      ),
                      ...followRepository.followingPubkeys,
                    ],
                    // Live duplicate check against the canonical store so a
                    // re-sent reply doesn't publish a duplicate (#5854).
                    isDuplicateSubmission:
                        ({
                          required String content,
                          required String authorPubkey,
                          String? parentCommentId,
                        }) {
                          return isDuplicatePendingReplySubmission(
                            comments: listBloc.state.commentsById.values,
                            content: content,
                            authorPubkey: authorPubkey,
                            parentCommentId: parentCommentId,
                          );
                        },
                  );
                },
              ),
              BlocProvider<CommentReactionsBloc>(
                create: (_) => CommentReactionsBloc(
                  authService: authService,
                  likesRepository: likesRepository,
                  commentsRepository: commentsRepository,
                  contentReportingServiceFuture: contentReportingServiceFuture,
                  contentBlocklistRepository: contentBlocklistRepository,
                  rootEventId: video.id,
                  rootAddressableId: video.addressableId,
                ),
              ),
            ],
            child: OutboxBridges(
              onCommentCountChanged: onCommentCountChanged,
              currentUserPubkey: authService.currentPublicKeyHex,
              child: child,
            ),
          ),
          title: _CommentsTitle(
            initialCount: seedCommentCount ?? 0,
            onNewCommentsPillTap: () {
              final controller = activeScrollController;
              if (controller != null && controller.hasClients) {
                controller.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            },
          ),
          trailing: const _CommentsSortToggle(),
          // Wrap the input so the keyboard is dropped the instant the sheet
          // starts dismissing (drag / scrim / back), otherwise iOS leaves it
          // stranded over the feed below (#5604).
          bottomInput: UnfocusOnSheetDismiss(
            child: MainCommentInput(draggableController: draggableController),
          ),
          buildScrollBody: (scrollController) {
            activeScrollController = scrollController;
            return CommentsSheetLoadTelemetry(
              telemetry: surfaceTelemetry,
              child: _CommentsScreenBody(
                videoEvent: video,
                sheetScrollController: scrollController,
              ),
            );
          },
        )
        .whenComplete(() {
          surfaceTelemetry.completeDismissed();
          disposeCommentsSheetController(draggableController);
        });
  }
}

/// Disposes the comments sheet's [DraggableScrollableController] safely.
///
/// The sheet future resolves at pop-start — before the sheet unmounts and
/// detaches the controller — so a focus-driven expand
/// ([_MainCommentInputState._expandSheetForKeyboard]) may still be animating.
/// `DraggableScrollableController.dispose` does not stop that animation, so its
/// ticks would keep calling `notifyListeners` on the disposed controller and
/// trip the "used after disposed" assert while the sheet animates out. Cancel
/// any in-flight animation first — `jumpTo` is the documented cancel path — so
/// nothing ticks after disposal.
///
/// Public-by-test only: production callers should use [CommentsScreen.show].
@visibleForTesting
void disposeCommentsSheetController(DraggableScrollableController controller) {
  if (controller.isAttached) {
    controller.jumpTo(controller.size);
  }
  controller.dispose();
}

abstract final class _CommentsSheetSizing {
  static const min = 0.5;
  static const initial = 0.7;
  static const max = 0.93;
  static const List<double> snapSizes = [initial, max];
  static const focusExpandDuration = Duration(milliseconds: 250);
}

/// Wires the composer / reactions outbox signals into [CommentsListBloc] store
/// mutations. Also triggers a vote-count batch fetch on the reactions bloc
/// every time the loaded-comment set changes.
///
/// Public-by-test only: it has no callers outside `CommentsScreen.show` but is
/// exposed via [visibleForTesting] so the bridge wiring can be exercised
/// directly with mock blocs.
@visibleForTesting
class OutboxBridges extends StatelessWidget {
  const OutboxBridges({
    required this.onCommentCountChanged,
    required this.child,
    this.currentUserPubkey,
    super.key,
  });

  final ValueChanged<int>? onCommentCountChanged;

  /// Signed-in pubkey, used to author the in-flight video-reply placeholder.
  ///
  /// `null` while signed out, which also means no video reply can be
  /// publishing, so the placeholder bridge is skipped entirely.
  final String? currentUserPubkey;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Notify host about comment-count changes for the trailing badge in
        // the parent video feed.
        BlocListener<CommentsListBloc, CommentsListState>(
          listenWhen: (prev, next) =>
              prev.commentsById.length != next.commentsById.length,
          listener: (_, state) {
            onCommentCountChanged?.call(state.commentsById.length);
          },
        ),
        // When new non-placeholder ids appear in the store, fetch their vote
        // counts. Only the DIFF is requested (not the whole set) so a
        // viral-video feed doesn't redundantly hammer the relay with the
        // same N-1 already-known ids on every emit. The handler is
        // restartable, so a slower in-flight fetch can't clobber a fresher
        // one — see CommentReactionsBloc.on<CommentVoteCountsFetchRequested>.
        BlocListener<CommentsListBloc, CommentsListState>(
          listenWhen: (prev, next) =>
              !_idSetsEqual(prev.commentsById, next.commentsById),
          listener: (ctx, state) {
            final prevKeys = ctx
                .read<CommentReactionsBloc>()
                .state
                .commentUpvoteCounts
                .keys
                .toSet();
            final newIds = state.commentsById.keys
                .where(
                  (id) =>
                      !id.startsWith(commentPlaceholderIdPrefix) &&
                      !prevKeys.contains(id),
                )
                .toList();
            if (newIds.isEmpty) return;
            // Video replies are addressable; their votes are only reachable by
            // coordinate once the reply has been edited (#6124).
            final addressableIds = <String, String>{};
            for (final id in newIds) {
              final coordinate = state.commentsById[id]?.addressableId;
              if (coordinate != null && coordinate.isNotEmpty) {
                addressableIds[id] = coordinate;
              }
            }
            ctx.read<CommentReactionsBloc>().add(
              CommentVoteCountsFetchRequested(
                newIds,
                addressableIdsByCommentId: addressableIds,
              ),
            );
          },
        ),
        // Composer → ListBloc outbox bridge.
        BlocListener<CommentComposerBloc, CommentComposerState>(
          listenWhen: (prev, next) =>
              next.outbox != null && prev.outbox != next.outbox,
          listener: _bridgeComposerOutbox,
        ),
        // Reactions → ListBloc outbox bridge.
        BlocListener<CommentReactionsBloc, CommentReactionsState>(
          listenWhen: (prev, next) =>
              next.outbox != null && prev.outbox != next.outbox,
          listener: _bridgeReactionsOutbox,
        ),
      ],
      child: currentUserPubkey == null
          ? child
          : VideoReplyPlaceholderBridge(
              currentUserPubkey: currentUserPubkey!,
              child: child,
            ),
    );
  }

  static bool _idSetsEqual(Map<String, Object?> a, Map<String, Object?> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
    }
    return true;
  }

  static void _bridgeComposerOutbox(
    BuildContext ctx,
    CommentComposerState state,
  ) {
    final outbox = state.outbox;
    if (outbox == null) return;
    final listBloc = ctx.read<CommentsListBloc>();
    switch (outbox) {
      case ComposerOutboxInsertPlaceholder(:final placeholder):
        listBloc.add(OptimisticCommentInserted(placeholder));
      case ComposerOutboxConfirmPlaceholder(
        :final placeholderId,
        :final confirmed,
      ):
        listBloc.add(
          OptimisticCommentConfirmed(
            placeholderId: placeholderId,
            confirmed: confirmed,
          ),
        );
      case ComposerOutboxRollbackPlaceholder(:final placeholderId):
        listBloc.add(OptimisticCommentRolledBack(placeholderId));
      case ComposerOutboxReplaceComment(:final oldId, :final newComment):
        listBloc.add(
          CommentReplacedInStore(oldId: oldId, newComment: newComment),
        );
    }
    ctx.read<CommentComposerBloc>().add(const ComposerOutboxConsumed());
  }

  /// Whether [replyContext] targets the video this sheet is showing.
  ///
  /// Matches on the root event id, or on the addressable coordinate when the
  /// reply was recorded against one — a video reply carries both (`E` and `A`),
  /// and a sheet opened from a metadata-edited video can hold the newer id.
  @visibleForTesting
  static bool videoReplyTargetsRoot(
    VideoReplyContext replyContext, {
    required String rootEventId,
    String? rootAddressableId,
  }) {
    if (replyContext.rootEventId == rootEventId) return true;
    final coordinate = replyContext.rootAddressableId;
    return coordinate != null &&
        coordinate.isNotEmpty &&
        coordinate == rootAddressableId;
  }

  static void _bridgeReactionsOutbox(
    BuildContext ctx,
    CommentReactionsState state,
  ) {
    final outbox = state.outbox;
    if (outbox == null) return;
    final listBloc = ctx.read<CommentsListBloc>();
    switch (outbox) {
      case ReactionsOutboxRemoveComment(:final commentId):
        listBloc.add(CommentRemovedFromStore(commentId));
      case ReactionsOutboxRemoveByAuthor(:final authorPubkey):
        listBloc.add(CommentsRemovedByAuthorFromStore(authorPubkey));
    }
    ctx.read<CommentReactionsBloc>().add(const ReactionsOutboxConsumed());
  }
}

/// How long an in-flight video-reply placeholder stays up after a successful
/// publish, waiting for the relay echo to swap it for the canonical comment
/// before the bridge rolls it back. Widened from 5s because slow-network
/// echoes could exceed the old window and make the row disappear before it
/// re-appeared. Public-by-test only — tests pump exactly this duration.
@visibleForTesting
const Duration videoReplyRelayEchoGrace = Duration(seconds: 10);

/// Surfaces an in-flight video reply as a pending row on its destination sheet.
///
/// The video-reply flow publishes in the background and navigates to the root
/// video, so this sheet mounts *after* the publish starts and there is no
/// composer outbox to bridge — unlike a text reply, whose bloc is still alive
/// (#5862). The in-flight set lives in [BackgroundPublishBloc], so the
/// placeholder is derived from that state rather than from a one-shot event,
/// which also means it survives a sheet reopen mid-publish.
///
/// Public-by-test only: production callers reach it through [OutboxBridges].
@visibleForTesting
class VideoReplyPlaceholderBridge extends StatefulWidget {
  const VideoReplyPlaceholderBridge({
    required this.currentUserPubkey,
    required this.child,
    super.key,
  });

  final String currentUserPubkey;
  final Widget child;

  @override
  State<VideoReplyPlaceholderBridge> createState() =>
      _VideoReplyPlaceholderBridgeState();
}

class _VideoReplyPlaceholderBridgeState
    extends State<VideoReplyPlaceholderBridge> {
  /// Draft ids this bridge has already inserted a placeholder for.
  ///
  /// Guards re-insertion after the relay echo swaps the placeholder out: the
  /// echo lands while the upload is still registered, so a purely
  /// store-diffing sync would see the row missing and add it back.
  final Set<String> _inserted = {};
  final Set<String> _awaitingRelayEcho = {};
  final Map<String, Timer> _relayEchoGraceTimers = {};

  @override
  void dispose() {
    for (final timer in _relayEchoGraceTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // BlocListener fires on changes only, and the upload was registered before
    // this sheet mounted — so seed from the current state once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sync(context.read<BackgroundPublishBloc>().state);
    });
  }

  void _sync(BackgroundPublishState publishState) {
    if (!mounted) return;
    final listBloc = context.read<CommentsListBloc>();
    final listState = listBloc.state;

    final inFlightDraftIds = <String>{};
    for (final upload in publishState.uploads) {
      if (upload.result != null) continue;
      final replyContext = upload.draft.videoReplyContext;
      if (replyContext == null) continue;
      if (!OutboxBridges.videoReplyTargetsRoot(
        replyContext,
        rootEventId: listState.rootEventId,
        rootAddressableId: listState.rootAddressableId,
      )) {
        continue;
      }
      inFlightDraftIds.add(upload.draft.id);
      if (_inserted.add(upload.draft.id)) {
        listBloc.add(
          OptimisticCommentInserted(
            Comment(
              id: pendingVideoReplyId(upload.draft.id),
              content: upload.draft.description,
              authorPubkey: widget.currentUserPubkey,
              createdAt: DateTime.now(),
              rootEventId: listState.rootEventId,
              rootAuthorPubkey: listState.rootAuthorPubkey,
              rootAddressableId: listState.rootAddressableId,
              replyToEventId: replyContext.parentCommentId,
              replyToAuthorPubkey: replyContext.parentAuthorPubkey,
            ),
          ),
        );
      }
    }

    // Derived from recentlyPublished on every read, so hoist it rather than
    // rebuilding the set once per candidate below.
    final succeededIds = publishState.recentlySucceededIds;

    for (final draftId in succeededIds) {
      if (!_inserted.contains(draftId)) continue;
      _awaitingRelayEcho.add(draftId);
      _relayEchoGraceTimers.putIfAbsent(
        draftId,
        () => Timer(videoReplyRelayEchoGrace, () {
          if (!mounted) return;
          _awaitingRelayEcho.remove(draftId);
          _inserted.remove(draftId);
          _relayEchoGraceTimers.remove(draftId);
          context.read<CommentsListBloc>().add(
            OptimisticCommentRolledBack(pendingVideoReplyId(draftId)),
          );
        }),
      );
    }

    // A successful publish leaves the upload set before the relay echo is
    // guaranteed to reach this sheet. Keep those placeholders briefly so the
    // normal author+content echo swap can replace them without a disappearance
    // or a self-authored "new comment" pill. Failed and vanished uploads still
    // roll back immediately.
    for (final draftId in _inserted.difference(inFlightDraftIds)) {
      if (_awaitingRelayEcho.contains(draftId) ||
          succeededIds.contains(draftId)) {
        continue;
      }
      _inserted.remove(draftId);
      _relayEchoGraceTimers.remove(draftId)?.cancel();
      listBloc.add(OptimisticCommentRolledBack(pendingVideoReplyId(draftId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BackgroundPublishBloc, BackgroundPublishState>(
      listener: (_, state) => _sync(state),
      child: widget.child,
    );
  }
}

/// Tracks perceived comments-sheet visibility and initial data completion.
///
/// Public-by-test only: production callers should use [CommentsScreen.show].
@visibleForTesting
class CommentsSheetLoadTelemetry extends StatefulWidget {
  const CommentsSheetLoadTelemetry({
    required this.telemetry,
    required this.child,
    super.key,
  });

  final CommentsSurfacePerformanceTelemetry telemetry;
  final Widget child;

  @override
  State<CommentsSheetLoadTelemetry> createState() =>
      _CommentsSheetLoadTelemetryState();
}

class _CommentsSheetLoadTelemetryState
    extends State<CommentsSheetLoadTelemetry> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.telemetry.markVisible();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CommentsListBloc, CommentsListState>(
      listenWhen: (prev, next) =>
          prev.status == CommentsStatus.loading &&
          (next.status == CommentsStatus.success ||
              next.status == CommentsStatus.failure),
      listener: (_, state) {
        switch (state.status) {
          case CommentsStatus.success:
            unawaited(
              widget.telemetry.completeDataLoaded(
                itemCount: state.commentsById.length,
                hasMore: state.hasMoreContent,
                sortMode: state.sortMode.name,
              ),
            );
          case CommentsStatus.failure:
            unawaited(widget.telemetry.completeFailure());
          case CommentsStatus.initial:
          case CommentsStatus.loading:
            break;
        }
      },
      child: widget.child,
    );
  }
}

/// Body widget with per-bloc error listeners that surface snackbars.
class _CommentsScreenBody extends StatelessWidget {
  const _CommentsScreenBody({
    required this.videoEvent,
    required this.sheetScrollController,
  });

  final VideoEvent videoEvent;
  final ScrollController sheetScrollController;

  void _snack(BuildContext ctx, String message) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final showVideoReplies = ref.watch(
          isFeatureEnabledProvider(FeatureFlag.videoReplies),
        );
        return MultiBlocListener(
          listeners: [
            BlocListener<CommentsListBloc, CommentsListState>(
              listenWhen: (prev, next) =>
                  prev.error != next.error && next.error != null,
              listener: (ctx, state) {
                _snack(ctx, _listErrorToString(ctx.l10n, state.error!));
                ctx.read<CommentsListBloc>().add(
                  const CommentsListErrorCleared(),
                );
              },
            ),
            BlocListener<CommentComposerBloc, CommentComposerState>(
              listenWhen: (prev, next) =>
                  prev.error != next.error && next.error != null,
              listener: (ctx, state) {
                _snack(ctx, _composerErrorToString(ctx.l10n, state.error!));
                ctx.read<CommentComposerBloc>().add(
                  const CommentComposerErrorCleared(),
                );
              },
            ),
            BlocListener<CommentReactionsBloc, CommentReactionsState>(
              listenWhen: (prev, next) =>
                  prev.error != next.error && next.error != null,
              listener: (ctx, state) {
                _snack(ctx, _reactionsErrorToString(ctx.l10n, state.error!));
                ctx.read<CommentReactionsBloc>().add(
                  const CommentReactionsErrorCleared(),
                );
              },
            ),
          ],
          child: SizedBox(
            child: CommentsList(
              showClassicVineNotice: videoEvent.isOriginalVine,
              scrollController: sheetScrollController,
              showVideoReplies: showVideoReplies,
            ),
          ),
        );
      },
    );
  }
}

/// Main comment input widget that reads from [CommentComposerBloc] state.
///
/// Public-by-test only: production callers should use [CommentsScreen.show].
@visibleForTesting
class MainCommentInput extends ConsumerStatefulWidget {
  const MainCommentInput({required this.draggableController, super.key});

  final DraggableScrollableController draggableController;

  @override
  ConsumerState<MainCommentInput> createState() => _MainCommentInputState();
}

class _MainCommentInputState extends ConsumerState<MainCommentInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  /// Guards against restarting the expand animation on every intermediate
  /// frame while it is climbing. Reset by [_expandWindowTimer], never by the
  /// [DraggableScrollableController.animateTo] future — see
  /// [_expandSheetForKeyboard].
  bool _isExpanding = false;
  Timer? _expandWindowTimer;

  @override
  void initState() {
    super.initState();
    final state = context.read<CommentComposerBloc>().state;
    _controller = TextEditingController(text: state.mainInputText);
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChanged);
    widget.draggableController.addListener(_handleSheetSizeChanged);
  }

  @override
  void dispose() {
    _expandWindowTimer?.cancel();
    widget.draggableController.removeListener(_handleSheetSizeChanged);
    _focusNode.removeListener(_handleFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      _expandSheetForKeyboard();
    }
  }

  void _handleSheetSizeChanged() {
    final controller = widget.draggableController;
    if (!_focusNode.hasFocus ||
        !controller.isAttached ||
        controller.size >= _CommentsSheetSizing.initial) {
      return;
    }

    _expandSheetForKeyboard();
  }

  void _expandSheetForKeyboard() {
    if (_isExpanding) return;
    final controller = widget.draggableController;
    if (!controller.isAttached || controller.size >= _CommentsSheetSizing.max) {
      return;
    }

    _isExpanding = true;
    controller.animateTo(
      _CommentsSheetSizing.max,
      duration: _CommentsSheetSizing.focusExpandDuration,
      curve: Curves.easeOut,
    );

    // The future from `animateTo` never completes when a user drag cancels the
    // animation (the underlying TickerFuture only resolves its `orCancel`
    // path), so releasing the latch on that future would strand `_isExpanding`
    // and silently disable the re-clamp for the rest of the sheet session.
    // Release it on a duration-matched timer instead, then re-check so a drag
    // that left the focused sheet below the safe size gets clamped back up.
    _expandWindowTimer?.cancel();
    _expandWindowTimer = Timer(
      _CommentsSheetSizing.focusExpandDuration,
      _onExpandWindowElapsed,
    );
  }

  void _onExpandWindowElapsed() {
    if (!mounted) return;
    _isExpanding = false;
    _handleSheetSizeChanged();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CommentComposerBloc, CommentComposerState>(
      listenWhen: (prev, next) =>
          prev.activeReplyCommentId != next.activeReplyCommentId ||
          prev.activeEditCommentId != next.activeEditCommentId,
      listener: (context, state) {
        // Focus input when reply or edit is activated.
        if (state.activeReplyCommentId != null ||
            state.activeEditCommentId != null) {
          _focusNode.requestFocus();
        }
      },
      buildWhen: (prev, next) =>
          prev.mainInputText != next.mainInputText ||
          prev.replyInputText != next.replyInputText ||
          prev.activeReplyCommentId != next.activeReplyCommentId ||
          prev.activeEditCommentId != next.activeEditCommentId ||
          prev.editInputText != next.editInputText ||
          prev.mentionSuggestions != next.mentionSuggestions,
      builder: (context, state) {
        final isReplyMode = state.activeReplyCommentId != null;
        final isEditMode = state.activeEditCommentId != null;
        final inputText = isEditMode
            ? state.editInputText
            : isReplyMode
            ? state.replyInputText
            : state.mainInputText;

        // Sync controller with state.
        if (_controller.text != inputText) {
          _controller.text = inputText;
          _controller.selection = TextSelection.collapsed(
            offset: inputText.length,
          );
        }

        // Get display name of user being replied to.
        String? replyToDisplayName;
        String? replyToAuthorPubkey;
        if (isReplyMode) {
          final listState = context.read<CommentsListBloc>().state;
          final replyComment =
              listState.commentsById[state.activeReplyCommentId!];
          if (replyComment != null) {
            replyToAuthorPubkey = replyComment.authorPubkey;
            final profile = ref
                .watch(userProfileReactiveProvider(replyToAuthorPubkey))
                .value;
            replyToDisplayName =
                profile?.bestDisplayName ??
                UserProfile.generatedNameFor(replyToAuthorPubkey);
          }
        }

        return CommentInput(
          controller: _controller,
          focusNode: _focusNode,
          replyToDisplayName: replyToDisplayName,
          isEditing: isEditMode,
          mentionSuggestions: state.mentionSuggestions,
          onMentionQuery: (query) {
            if (query.isEmpty) {
              context.read<CommentComposerBloc>().add(
                const MentionSuggestionsCleared(),
              );
            } else {
              context.read<CommentComposerBloc>().add(
                MentionSearchRequested(query),
              );
            }
          },
          onMentionSelected: (pubkey, displayName, start, end) {
            context.read<CommentComposerBloc>()
              ..add(
                MentionRegistered(
                  displayName: displayName,
                  pubkey: pubkey,
                  start: start,
                  end: end,
                ),
              )
              ..add(const MentionSuggestionsCleared());
          },
          onVideoReplyPressed:
              ref.watch(isFeatureEnabledProvider(FeatureFlag.videoReplies))
              ? () => _openVideoReplyCamera(context, state, replyToAuthorPubkey)
              : null,
          onChanged: (text) {
            context.read<CommentComposerBloc>().add(
              CommentTextChanged(text, commentId: state.activeReplyCommentId),
            );
          },
          onSubmit: () {
            final composer = context.read<CommentComposerBloc>();
            if (isEditMode) {
              composer.add(const CommentEditSubmitted());
            } else if (isReplyMode) {
              // Guard against the parent comment having been removed from the
              // store between reply-mode entry and submit (block-by-author
              // cleanup, kind-5 delete, or list still loading). Submitting
              // with parentAuthorPubkey=null produces a malformed NIP-22
              // reply (E tag without matching P tag). Cancel reply mode
              // instead so the user can re-target a still-visible comment.
              if (replyToAuthorPubkey == null) {
                composer.add(CommentReplyToggled(state.activeReplyCommentId!));
                return;
              }
              composer.add(
                CommentSubmitted(
                  parentCommentId: state.activeReplyCommentId,
                  parentAuthorPubkey: replyToAuthorPubkey,
                ),
              );
            } else {
              composer.add(const CommentSubmitted());
            }
          },
          onCancelReply: () {
            context.read<CommentComposerBloc>().add(
              CommentReplyToggled(state.activeReplyCommentId!),
            );
          },
          onCancelEdit: () {
            context.read<CommentComposerBloc>().add(
              const CommentEditModeCancelled(),
            );
          },
        );
      },
    );
  }

  void _openVideoReplyCamera(
    BuildContext context,
    CommentComposerState state,
    String? replyToAuthorPubkey,
  ) {
    final listState = context.read<CommentsListBloc>().state;
    final replyContextNotifier = ref.read(videoReplyContextProvider.notifier);
    replyContextNotifier.set(
      VideoReplyContext(
        rootEventId: listState.rootEventId,
        rootEventKind: listState.rootEventKind,
        rootAuthorPubkey: listState.rootAuthorPubkey,
        rootAddressableId: listState.rootAddressableId,
        parentCommentId: state.activeReplyCommentId,
        parentAuthorPubkey: replyToAuthorPubkey,
      ),
    );
    unawaited(
      context
          .push(
            VideoRecorderScreen.pathForEntryPoint(
              CreationEntryPoint.videoReply,
            ),
          )
          .then((_) => replyContextNotifier.clear()),
    );
  }
}

/// Sort toggle button that cycles: New → Top → Old → New.
class _CommentsSortToggle extends StatelessWidget {
  const _CommentsSortToggle();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<CommentsListBloc, CommentsListState, CommentsSortMode>(
      selector: (state) => state.sortMode,
      builder: (context, sortMode) {
        final l10n = context.l10n;
        final (icon, label) = switch (sortMode) {
          CommentsSortMode.newest => (Icons.schedule, l10n.commentsSortNew),
          CommentsSortMode.topEngagement => (
            Icons.local_fire_department,
            l10n.commentsSortTop,
          ),
          CommentsSortMode.oldest => (Icons.history, l10n.commentsSortOld),
        };

        return Semantics(
          identifier: 'comments_sorting',
          button: true,
          label: l10n.commentsSortSemanticLabel,
          child: GestureDetector(
            onTap: () {
              final nextMode = switch (sortMode) {
                CommentsSortMode.newest => CommentsSortMode.topEngagement,
                CommentsSortMode.topEngagement => CommentsSortMode.oldest,
                CommentsSortMode.oldest => CommentsSortMode.newest,
              };
              context.read<CommentsListBloc>().add(
                CommentsSortModeChanged(nextMode),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.vineColors.containerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: context.vineColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: VineTheme.labelMediumFont(
                      color: context.vineColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
