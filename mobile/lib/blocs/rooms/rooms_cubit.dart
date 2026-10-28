// ABOUTME: Adapts verified room activity and per-account unread state for Messages.
// ABOUTME: Owns its listener; the session provider owns the shared repositories.

import 'dart:async';

import 'package:concord_repository/concord_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';

class RoomsCubit extends Cubit<Map<String, RoomActivitySummary>>
    with CloseGuardedEmit<Map<String, RoomActivitySummary>> {
  RoomsCubit(this._repository) : super(_repository.summaries) {
    _updates = _repository.changes.listen((_) {
      emitIfOpen(_repository.summaries);
    });
  }

  final RoomActivityRepository _repository;
  late final StreamSubscription<void> _updates;

  Future<void> start() => _repository.start();

  @override
  Future<void> close() async {
    await _updates.cancel();
    return super.close();
  }
}
