// ABOUTME: Cubit for fetching pubkeys of users who reposted a video.
// ABOUTME: Delegates to RepostsRepository.fetchEventReposters so the metadata
// ABOUTME: sheet's "Reposted by" chips match the engagement-list screen
// ABOUTME: (Kind 6+16, Kind 5 deletion filter, dual e+a tag query).

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reposts_repository/reposts_repository.dart';

/// State for [VideoRepostersCubit].
class VideoRepostersState extends Equatable {
  const VideoRepostersState({
    this.pubkeys = const [],
    this.isLoading = true,
    this.isComplete = true,
  });

  /// Pubkeys of users who reposted this video.
  final List<String> pubkeys;

  /// Whether the relay query is still in progress.
  final bool isLoading;

  /// Whether the relays finished the read behind [pubkeys].
  ///
  /// `false` when the read stopped before every relay answered, or failed:
  /// [pubkeys] then holds only the people found so far, and an empty list
  /// does not mean nobody reposted (#10846).
  final bool isComplete;

  @override
  List<Object?> get props => [pubkeys, isLoading, isComplete];
}

/// Fetches the pubkeys of users who reposted a video.
///
/// Queries Nostr relays via [RepostsRepository.fetchEventReposters] for NIP-18
/// repost events (kind 6 and kind 16) that reference the target event. When
/// the video has an addressable identifier (Kind 30000+ events with a d-tag),
/// the query merges results across both the `e` and `a` tags so addressable
/// reposts aren't missed.
class VideoRepostersCubit extends Cubit<VideoRepostersState> {
  VideoRepostersCubit({
    required RepostsRepository repostsRepository,
    required String videoId,
    String? addressableId,
  }) : _repostsRepository = repostsRepository,
       _videoId = videoId,
       _addressableId = addressableId,
       super(const VideoRepostersState()) {
    unawaited(_fetch());
  }

  final RepostsRepository _repostsRepository;
  final String _videoId;
  final String? _addressableId;

  /// Reads the reposters again, for a row whose last read did not finish.
  ///
  /// Ignored while a read is in flight.
  void retry() {
    if (isClosed || state.isLoading) return;
    emit(const VideoRepostersState());
    unawaited(_fetch());
  }

  Future<void> _fetch() async {
    if (_videoId.isEmpty) {
      if (isClosed) return;
      emit(const VideoRepostersState(isLoading: false));
      return;
    }
    try {
      final page = await _repostsRepository.fetchEventReposters(
        eventId: _videoId,
        addressableId: _addressableId,
      );
      if (isClosed) return;
      emit(
        VideoRepostersState(
          pubkeys: page.pubkeys,
          isLoading: false,
          isComplete: page.isComplete,
        ),
      );
    } catch (e, stackTrace) {
      if (isClosed) return;
      addError(e, stackTrace);
      emit(const VideoRepostersState(isLoading: false, isComplete: false));
    }
  }
}
