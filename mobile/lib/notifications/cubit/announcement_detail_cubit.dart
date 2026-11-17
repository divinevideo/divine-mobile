// ABOUTME: Keeps announcement detail in sync with the trusted catalog snapshot.
// ABOUTME: Removal and expiry in the repository clear already-open detail pages.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';

/// Resolves one announcement from the current catalog, including cold hydration.
class AnnouncementDetailCubit extends Cubit<AnnouncementNotification?> {
  AnnouncementDetailCubit({
    required String announcementId,
    required List<AnnouncementNotification> initialItems,
    required Stream<List<AnnouncementNotification>> snapshots,
    Future<void> Function()? refresh,
  }) : super(_find(initialItems, announcementId)) {
    _subscription = snapshots.listen((items) {
      if (!isClosed) emit(_find(items, announcementId));
    });
    if (refresh != null) unawaited(_refresh(refresh));
  }

  Future<void> _refresh(Future<void> Function() refresh) async {
    try {
      await refresh();
    } on Exception {
      // The repository retains its last trusted catalog while offline.
    }
  }

  late final StreamSubscription<List<AnnouncementNotification>> _subscription;

  static AnnouncementNotification? _find(
    List<AnnouncementNotification> items,
    String announcementId,
  ) {
    for (final item in items) {
      if (item.announcementId == announcementId) return item;
    }
    return null;
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
