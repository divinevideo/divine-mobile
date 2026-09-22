// ABOUTME: BLoC behind the Library's Scheduled tab (#3538): lists the
// ABOUTME: account's scheduled posts and runs cancel / reschedule / publish
// ABOUTME: now / retry through the coordinator.

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:db_client/db_client.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/repositories/scheduled_posts_repository.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/schedule_api_client.dart';
import 'package:openvine/services/scheduled_post_coordinator.dart';

part 'scheduled_posts_event.dart';
part 'scheduled_posts_state.dart';

class ScheduledPostsBloc
    extends Bloc<ScheduledPostsEvent, ScheduledPostsState> {
  ScheduledPostsBloc({
    required ScheduledPostsRepository repository,
    required ScheduledPostCoordinator coordinator,
    required DraftStorageService draftService,
  }) : _repository = repository,
       _coordinator = coordinator,
       _draftService = draftService,
       super(const ScheduledPostsState()) {
    on<ScheduledPostsStarted>(_onStarted, transformer: restartable());
    on<ScheduledPostsRefreshRequested>(_onRefresh, transformer: droppable());
    on<_ScheduledPostsOutboxChanged>(
      _onOutboxChanged,
      transformer: restartable(),
    );
    on<ScheduledPostsActionEvent>(_onAction, transformer: sequential());
  }

  final ScheduledPostsRepository _repository;
  final ScheduledPostCoordinator _coordinator;
  final DraftStorageService _draftService;

  Future<void> _onStarted(
    ScheduledPostsStarted event,
    Emitter<ScheduledPostsState> emit,
  ) async {
    emit(state.copyWith(status: ScheduledPostsStatus.loading));
    unawaited(_coordinator.sweep(force: true));
    await Future.wait([
      emit.onEach<List<ScheduledPost>>(
        _repository.watch(),
        // The outbox can notify after close(); `Bloc.close` shuts the event
        // controller before draining, so a bare add would throw.
        onData: (posts) => addIfOpen(_ScheduledPostsOutboxChanged(posts)),
      ),
      emit.onEach<void>(
        _coordinator.serverOnlyChanges,
        onData: (_) => emit(state.copyWith(remotePosts: _remotePosts())),
      ),
    ]);
  }

  Future<void> _onRefresh(
    ScheduledPostsRefreshRequested event,
    Emitter<ScheduledPostsState> emit,
  ) async {
    await _coordinator.sweep(force: true);
    emit(state.copyWith(remotePosts: _remotePosts()));
  }

  Future<void> _onOutboxChanged(
    _ScheduledPostsOutboxChanged event,
    Emitter<ScheduledPostsState> emit,
  ) async {
    final items = <ScheduledPostItem>[];
    for (final post in event.posts) {
      // Terminal rows are retired by the coordinator; until then they would
      // only flash a stale badge.
      if (post.status == ScheduledPostStatus.published ||
          post.status == ScheduledPostStatus.cancelled) {
        continue;
      }
      final draft = await _draftService.getDraftById(post.draftId);
      items.add(ScheduledPostItem(post: post, draft: draft));
    }
    emit(
      state.copyWith(
        status: ScheduledPostsStatus.loaded,
        items: items,
        remotePosts: _remotePosts(),
      ),
    );
  }

  Future<void> _onAction(
    ScheduledPostsActionEvent event,
    Emitter<ScheduledPostsState> emit,
  ) async {
    emit(state.copyWith(busyEventId: event.eventId));
    final outcome = switch (event) {
      ScheduledPostsCancelRequested(:final eventId) =>
        await _coordinator.cancel(eventId),
      ScheduledPostsRescheduleRequested(:final eventId, :final publishAt) =>
        await _coordinator.reschedule(eventId, publishAt),
      ScheduledPostsPublishNowRequested(:final eventId) =>
        await _coordinator.publishNow(eventId),
      ScheduledPostsRetryRequested(:final eventId) => await _coordinator.retry(
        eventId,
      ),
      ScheduledPostsCancelRemoteRequested(:final eventId) =>
        await _coordinator.cancelRemote(eventId),
    };
    emit(
      state.copyWith(
        clearBusyEventId: true,
        lastAction: _outcomeFor(event, outcome),
        actionCount: state.actionCount + 1,
        remotePosts: _remotePosts(),
      ),
    );
  }

  List<RemoteScheduledPost> _remotePosts() => [
    for (final entry in _coordinator.serverOnlyPosts)
      RemoteScheduledPost.fromServerEntry(entry),
  ];

  ScheduledPostsActionOutcome _outcomeFor(
    ScheduledPostsActionEvent event,
    ScheduledPostActionOutcome outcome,
  ) {
    return switch (outcome) {
      ScheduledPostActionOutcome.alreadyPublished =>
        ScheduledPostsActionOutcome.alreadyPublished,
      ScheduledPostActionOutcome.unavailable =>
        ScheduledPostsActionOutcome.unavailable,
      ScheduledPostActionOutcome.failed => ScheduledPostsActionOutcome.failed,
      ScheduledPostActionOutcome.done => switch (event) {
        ScheduledPostsCancelRequested() ||
        ScheduledPostsCancelRemoteRequested() =>
          ScheduledPostsActionOutcome.cancelled,
        ScheduledPostsRescheduleRequested() =>
          ScheduledPostsActionOutcome.rescheduled,
        ScheduledPostsPublishNowRequested() =>
          ScheduledPostsActionOutcome.publishedNow,
        ScheduledPostsRetryRequested() =>
          ScheduledPostsActionOutcome.retryQueued,
      },
    };
  }
}
