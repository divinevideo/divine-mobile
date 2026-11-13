// ABOUTME: Cubit for the list detail manage-posts mode: tracks which posts
// ABOUTME: are selected and removes them from the list one by one.

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/curated_list_manage_posts/curated_list_manage_posts_state.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:unified_logger/unified_logger.dart';

export 'package:openvine/blocs/curated_list_manage_posts/curated_list_manage_posts_state.dart';

/// Drives the manage-posts mode of the curated list detail screen.
///
/// One instance lives for one manage-mode session: created when the owner
/// enters the mode, closed when they leave it, so the [CuratedListService]
/// captured here cannot outlive the auth session it was read under.
class CuratedListManagePostsCubit extends Cubit<CuratedListManagePostsState>
    with CloseGuardedEmit<CuratedListManagePostsState> {
  /// Creates the cubit for one manage-mode session on [listId].
  ///
  /// With [resolveVideoAddresses], removal also finds a post where the list
  /// holds it by the event id of an older version (#7135).
  CuratedListManagePostsCubit({
    required CuratedListService service,
    required String listId,
    CuratedListVideoAddressResolver? resolveVideoAddresses,
  }) : _service = service,
       _listId = listId,
       _resolveVideoAddresses = resolveVideoAddresses,
       super(const CuratedListManagePostsState());

  final CuratedListService _service;
  final String _listId;
  final CuratedListVideoAddressResolver? _resolveVideoAddresses;

  /// Toggle whether [videoEventId] is selected for removal.
  ///
  /// Pass the post's [videoAddress] when it has one, so removal also finds
  /// the post where the list holds it by that coordinate (#7135). Ignored
  /// while a removal is running so the batch stays what the user confirmed.
  void togglePost(String videoEventId, {String? videoAddress}) {
    if (state.status == CuratedListManagePostsStatus.removing) return;
    final next = Set<String>.from(state.selectedVideoIds);
    final addresses = Map<String, String>.from(state.selectedVideoAddresses);
    if (next.add(videoEventId)) {
      if (videoAddress != null) addresses[videoEventId] = videoAddress;
    } else {
      next.remove(videoEventId);
      addresses.remove(videoEventId);
    }
    emit(
      state.copyWith(
        status: CuratedListManagePostsStatus.selecting,
        selectedVideoIds: next,
        selectedVideoAddresses: addresses,
      ),
    );
  }

  /// Remove every selected post from the list, one at a time, under each
  /// name the list holds it by: its coordinate, its event id, and the event
  /// id of an older version once a lookup has placed it.
  ///
  /// [CuratedListService.removeVideoFromList] serializes mutations per list,
  /// so the loop awaits each call rather than firing them concurrently. Ends
  /// in [CuratedListManagePostsStatus.success] when no selected post remains
  /// in the list, or [CuratedListManagePostsStatus.failure] when any does.
  Future<void> removeSelected() async {
    if (state.status != CuratedListManagePostsStatus.selecting ||
        state.selectedVideoIds.isEmpty) {
      return;
    }

    emit(state.copyWith(status: CuratedListManagePostsStatus.removing));

    final selected = [
      for (final videoEventId in state.selectedVideoIds)
        CuratedListVideo(
          eventId: videoEventId,
          address: state.selectedVideoAddresses[videoEventId],
        ),
    ];
    final addressByEventId = await _lookUpOlderVersions(selected);
    final list = _service.getListById(_listId);
    // Two selected tiles can be versions of one video, which the list holds
    // under the same names; each name is removed once.
    final references = {
      if (list != null)
        for (final video in selected)
          ...video.referencesIn(list, addressByEventId: addressByEventId),
    };
    for (final reference in references) {
      try {
        await _service.removeVideoFromList(_listId, reference);
      } catch (e, stackTrace) {
        // Expected domain/network failure — surfaced via status, not
        // Crashlytics, per the reportable-error decision matrix.
        addError(e, stackTrace);
      }
    }

    // The returned bool is ambiguous: a failed publish has already committed
    // the removal locally and queued a republish, so counting it as failed
    // would contradict the refreshed grid. Membership after the batch is the
    // truth the user sees — derive the counts from it. A missing list means
    // nothing is left to hold the posts.
    final remaining = _service.getListById(_listId);
    final failed = remaining == null
        ? 0
        : selected
              .where(
                (video) =>
                    video.isIn(remaining, addressByEventId: addressByEventId),
              )
              .length;
    final removed = selected.length - failed;

    emitIfOpen(
      state.copyWith(
        status: failed > 0
            ? CuratedListManagePostsStatus.failure
            : CuratedListManagePostsStatus.success,
        selectedVideoIds: const {},
        selectedVideoAddresses: const {},
        removedCount: removed,
        failedCount: failed,
      ),
    );
  }

  /// The coordinate of each event-id item in the list that may be an older
  /// version of a selected post, from one lookup.
  ///
  /// Best effort: without a resolver, a selected post with a coordinate, or
  /// an answer, removal goes by the names it already knows.
  Future<Map<String, String>> _lookUpOlderVersions(
    List<CuratedListVideo> selected,
  ) async {
    final resolve = _resolveVideoAddresses;
    final list = _service.getListById(_listId);
    if (resolve == null ||
        list == null ||
        selected.every((video) => video.address == null)) {
      return const {};
    }
    final eventIds = CuratedListVideo.eventIdItemsOf(
      [list],
      except: {for (final video in selected) video.eventId},
    );
    if (eventIds.isEmpty) return const {};
    try {
      return await resolve(eventIds);
    } on Object catch (error) {
      Log.warning(
        'Could not look up the videos of ${eventIds.length} list items: '
        '$error',
        name: 'CuratedListManagePostsCubit',
        category: LogCategory.ui,
      );
      return const {};
    }
  }
}
