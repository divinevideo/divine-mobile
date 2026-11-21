// ABOUTME: Resolves announcement detail from the trusted catalog snapshot.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/utils/detached_future.dart';

/// Lookup state of one announcement in the trusted catalog.
enum AnnouncementDetailStatus {
  /// No answer yet: no catalog has loaded, or the endpoint has not yet
  /// answered for a cached catalog that lacks the announcement.
  loading,

  /// The announcement is current and eligible.
  ready,

  /// The endpoint answered without the announcement, or it expired or was
  /// withdrawn while shown.
  unavailable,

  /// The endpoint did not answer, so the announcement's absence is unknown.
  failed,
}

typedef AnnouncementDetailState = ({
  AnnouncementDetailStatus status,
  AnnouncementNotification? announcement,
});

/// Keeps detail in sync with catalog hydration, refresh, and expiry.
///
/// A cached catalog can predate the announcement a push links to, so the
/// announcement is reported unavailable only when the endpoint answered
/// without it, or when it leaves a catalog that showed it.
class AnnouncementDetailCubit extends Cubit<AnnouncementDetailState> {
  /// Resolves [announcementId] from [repository] now and starts a refresh.
  AnnouncementDetailCubit({
    required String announcementId,
    required AnnouncementsRepository repository,
  }) : _announcementId = announcementId,
       _repository = repository,
       super(_ready(_find(repository, announcementId)) ?? _loading) {
    _subscription = repository.watchSnapshot().listen((_) {
      // The stream initially replays an empty list before any catalog exists.
      // Read the repository's current decision so that replay cannot clear a
      // newer snapshot that has already loaded.
      if (isClosed || !repository.hasCatalog) return;
      final ready = _ready(_find(repository, announcementId));
      if (ready != null) {
        emit(ready);
      } else if (state.status == AnnouncementDetailStatus.ready) {
        emit(_unavailable);
      }
    });
    runDetached(
      refresh(),
      'refresh announcement detail',
      logName: 'AnnouncementDetailCubit',
      category: LogCategory.ui,
    );
  }

  static const AnnouncementDetailState _loading = (
    status: AnnouncementDetailStatus.loading,
    announcement: null,
  );
  static const AnnouncementDetailState _unavailable = (
    status: AnnouncementDetailStatus.unavailable,
    announcement: null,
  );
  static const AnnouncementDetailState _failed = (
    status: AnnouncementDetailStatus.failed,
    announcement: null,
  );

  final String _announcementId;
  final AnnouncementsRepository _repository;
  late final StreamSubscription<List<AnnouncementNotification>> _subscription;

  /// Refetches the catalog and re-resolves the announcement; backs the retry
  /// button.
  Future<void> refresh() async {
    if (isClosed) return;
    if (state.status == AnnouncementDetailStatus.failed) emit(_loading);
    final answered = await _repository.refresh();
    if (isClosed) return;
    final ready = _ready(_find(_repository, _announcementId));
    if (ready != null) {
      emit(ready);
    } else if (answered ||
        state.status == AnnouncementDetailStatus.ready ||
        state.status == AnnouncementDetailStatus.unavailable) {
      // An answer confirms absence; without one, a shown announcement can
      // only have expired.
      emit(_unavailable);
    } else {
      emit(_failed);
    }
  }

  static AnnouncementNotification? _find(
    AnnouncementsRepository repository,
    String announcementId,
  ) {
    if (!repository.hasCatalog) return null;
    for (final item in repository.items) {
      if (item.announcementId == announcementId) return item;
    }
    return null;
  }

  static AnnouncementDetailState? _ready(AnnouncementNotification? item) =>
      item == null
      ? null
      : (status: AnnouncementDetailStatus.ready, announcement: item);

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
