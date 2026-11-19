// ABOUTME: Resolves announcement detail from the trusted catalog snapshot.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/utils/detached_future.dart';

enum AnnouncementDetailStatus { loading, ready, unavailable, failed }

typedef AnnouncementDetailState = ({
  AnnouncementDetailStatus status,
  AnnouncementNotification? announcement,
});

/// Keeps detail in sync with catalog hydration, refresh, and expiry.
class AnnouncementDetailCubit extends Cubit<AnnouncementDetailState> {
  AnnouncementDetailCubit({
    required String announcementId,
    required AnnouncementsRepository repository,
  }) : _announcementId = announcementId,
       _repository = repository,
       super(_resolve(repository, announcementId)) {
    _subscription = repository.watchSnapshot().listen((_) {
      // The stream initially replays an empty list before any catalog exists.
      // Read the repository's current decision so that replay cannot clear a
      // newer snapshot that has already loaded.
      if (!isClosed && repository.hasCatalog) {
        emit(_resolve(repository, announcementId));
      }
    });
    runDetached(
      refresh(),
      'refresh announcement detail',
      logName: 'AnnouncementDetailCubit',
      category: LogCategory.ui,
    );
  }

  final String _announcementId;
  final AnnouncementsRepository _repository;
  late final StreamSubscription<List<AnnouncementNotification>> _subscription;

  Future<void> refresh() async {
    if (isClosed) return;
    if (state.status == AnnouncementDetailStatus.failed) {
      emit((status: AnnouncementDetailStatus.loading, announcement: null));
    }
    await _repository.refresh();
    if (isClosed) return;
    emit(
      _repository.hasCatalog
          ? _resolve(_repository, _announcementId)
          : (status: AnnouncementDetailStatus.failed, announcement: null),
    );
  }

  static AnnouncementDetailState _resolve(
    AnnouncementsRepository repository,
    String announcementId,
  ) {
    if (!repository.hasCatalog) {
      return (status: AnnouncementDetailStatus.loading, announcement: null);
    }
    for (final item in repository.items) {
      if (item.announcementId == announcementId) {
        return (status: AnnouncementDetailStatus.ready, announcement: item);
      }
    }
    return (status: AnnouncementDetailStatus.unavailable, announcement: null);
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
