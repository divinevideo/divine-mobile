// ABOUTME: Presentation controller for an independent Classics playback session.
// ABOUTME: Exposes replayable feed streams without sharing the Explore grid.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:videos_repository/videos_repository.dart';

/// Controls one route's Classics playback queue.
class ClassicsFeedCubit extends Cubit<ClassicFeedSessionState> {
  ClassicsFeedCubit({required ClassicFeedSession session})
    : _session = session,
      super(session.state) {
    _subscription = session.stream.listen((next) {
      if (!isClosed) emit(next);
    });
    unawaited(session.loadInitial());
  }

  final ClassicFeedSession _session;
  StreamSubscription<ClassicFeedSessionState>? _subscription;

  /// Replays the selected video, then adapted queue updates.
  Stream<List<VideoEvent>> get videos => _session.stream.map((s) => s.videos);

  /// Replays the current pagination availability.
  Stream<bool> get hasMore => _session.stream.map((s) => s.hasMore).distinct();

  /// Records a reached playback position without blocking navigation.
  void activate(int index) => _session.activate(index);

  /// Resolves player-side filtering by stable video identity.
  void activateVideo(VideoEvent video) => _session.activateVideo(video);

  /// Asks the repository for another page.
  Future<void> loadMore() async => _session.loadMore();

  @override
  Future<void> close() async {
    // Stop feedback and close presentation immediately, then await all drains.
    final cleanup = <Future<void>?>[
      _subscription?.cancel(),
      _session.dispose(),
      super.close(),
    ];
    await Future.wait(cleanup.nonNulls);
  }
}
