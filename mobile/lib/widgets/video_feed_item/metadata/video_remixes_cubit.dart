// ABOUTME: Cubit reading the videos that use a clip of a video, for the info
// ABOUTME: sheet's Remixes section, through VideoResponsesRepository.

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:video_responses_repository/video_responses_repository.dart';

/// State for [VideoRemixesCubit].
class VideoRemixesState extends Equatable {
  const VideoRemixesState({this.remixes = const [], this.isLoading = true});

  /// The videos that use a clip of the video, the newest first.
  final List<VideoEvent> remixes;

  /// Whether the relay read is still in progress.
  final bool isLoading;

  @override
  List<Object?> get props => [remixes, isLoading];
}

/// Reads the videos whose `clip-source` credit names the video at
/// [addressableId], through [VideoResponsesRepository.fetchRemixesOf].
///
/// [filter], the viewer's, leaves out remixes by accounts they blocked or
/// muted, deleted ones and ones their content filters hide, and puts on the
/// rest the content warnings their settings call for.
///
/// A video with no address has no remixes to read. A read that fails gives
/// no remixes, so the section stays hidden rather than showing an error.
class VideoRemixesCubit extends Cubit<VideoRemixesState> {
  VideoRemixesCubit({
    required VideoResponsesRepository videoResponsesRepository,
    required String? addressableId,
    required List<VideoEvent> Function(List<VideoEvent> remixes) filter,
  }) : _videoResponsesRepository = videoResponsesRepository,
       _addressableId = addressableId,
       _filter = filter,
       super(const VideoRemixesState()) {
    unawaited(_fetch());
  }

  final VideoResponsesRepository _videoResponsesRepository;
  final String? _addressableId;
  final List<VideoEvent> Function(List<VideoEvent> remixes) _filter;

  Future<void> _fetch() async {
    final addressableId = _addressableId;
    if (addressableId == null || addressableId.isEmpty) {
      emit(const VideoRemixesState(isLoading: false));
      return;
    }
    try {
      final remixes = await _videoResponsesRepository.fetchRemixesOf(
        addressableId,
        filter: _filter,
      );
      if (isClosed) return;
      emit(VideoRemixesState(remixes: remixes, isLoading: false));
    } catch (e, stackTrace) {
      if (isClosed) return;
      addError(e, stackTrace);
      emit(const VideoRemixesState(isLoading: false));
    }
  }
}
