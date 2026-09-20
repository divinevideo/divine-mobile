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
  const VideoRepostersState({this.pubkeys = const [], this.isLoading = true});

  /// Pubkeys of users who reposted this video.
  final List<String> pubkeys;

  /// Whether the relay query is still in progress.
  final bool isLoading;

  @override
  List<Object?> get props => [pubkeys, isLoading];
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

  Future<void> _fetch() async {
    if (_videoId.isEmpty) {
      if (isClosed) return;
      emit(const VideoRepostersState(isLoading: false));
      return;
    }
    try {
      final pubkeys = await _repostsRepository.fetchEventReposters(
        eventId: _videoId,
        addressableId: _addressableId,
      );
      if (isClosed) return;
      emit(VideoRepostersState(pubkeys: pubkeys, isLoading: false));
    } catch (e, stackTrace) {
      if (isClosed) return;
      addError(e, stackTrace);
      emit(const VideoRepostersState(isLoading: false));
    }
  }
}
