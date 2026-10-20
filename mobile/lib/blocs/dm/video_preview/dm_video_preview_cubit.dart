// ABOUTME: Cubit for the frame a video DM's card shows, read from the video
// ABOUTME: this device keeps; a request's card waits until it is played.

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/services/dm_video_store.dart';

/// Whether a video DM's card has a frame to show.
enum DmVideoPreviewStatus {
  /// Reading the frame, downloading the video first when allowed.
  loading,

  /// [DmVideoPreviewState.framePath] holds the frame.
  ready,

  /// No frame: the video is not kept yet, or no frame could be read.
  none,
}

/// [DmVideoPreviewCubit] state.
class DmVideoPreviewState extends Equatable {
  /// Creates a [DmVideoPreviewState].
  const DmVideoPreviewState({
    this.status = DmVideoPreviewStatus.loading,
    this.framePath,
  });

  /// Whether there is a frame to show.
  final DmVideoPreviewStatus status;

  /// Path of the kept frame while [status] is [DmVideoPreviewStatus.ready].
  final String? framePath;

  @override
  List<Object?> get props => [status, framePath];
}

/// Finds the frame one video DM's card shows.
///
/// With [download] the video is downloaded and decrypted when it is not kept
/// yet, unless it is too big to fetch without a tap. Without it, which is how
/// a message request's card works, only a video already kept is used. Either
/// way, a card left without a frame picks it up as soon as the user plays the
/// video and the store keeps it. Without [decode], for a sender the user
/// blocked, only a frame read before is shown.
class DmVideoPreviewCubit extends Cubit<DmVideoPreviewState>
    with CloseGuardedEmit<DmVideoPreviewState> {
  /// Creates a [DmVideoPreviewCubit] for [message].
  ///
  /// It starts with a frame [store] already knows, so a card built again,
  /// such as one scrolled back into view, shows it from its first frame.
  DmVideoPreviewCubit({
    required DmMessage message,
    required DmVideoStore? store,
    required bool download,
    required bool decode,
  }) : _message = message,
       _store = store,
       _download = download,
       _decode = decode,
       super(_initialState(store?.knownPreviewPathFor(message)));

  static DmVideoPreviewState _initialState(String? knownFramePath) =>
      knownFramePath == null
      ? const DmVideoPreviewState()
      : DmVideoPreviewState(
          status: DmVideoPreviewStatus.ready,
          framePath: knownFramePath,
        );

  final DmMessage _message;

  /// Null when no account is signed in: videos are kept per account.
  final DmVideoStore? _store;
  final bool _download;
  final bool _decode;
  StreamSubscription<String>? _keptVideos;

  /// Reads the frame, downloading the video first when allowed.
  Future<void> load() async {
    final store = _store;
    if (store == null) {
      emitIfOpen(const DmVideoPreviewState(status: DmVideoPreviewStatus.none));
      return;
    }
    try {
      final frame = await store.previewFor(
        _message,
        download: _download,
        decode: _decode,
        stillWanted: () => !isClosed,
      );
      if (frame != null) {
        emitIfOpen(
          DmVideoPreviewState(
            status: DmVideoPreviewStatus.ready,
            framePath: frame.path,
          ),
        );
        return;
      }
      emitIfOpen(const DmVideoPreviewState(status: DmVideoPreviewStatus.none));
      if (!isClosed) _waitForKeptVideo(store);
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(const DmVideoPreviewState(status: DmVideoPreviewStatus.none));
      // A tap on play still keeps the video, so wait for it as above.
      if (!isClosed) _waitForKeptVideo(store);
    }
  }

  /// Reads the frame again once this message's video is kept, which happens
  /// when the user plays it.
  void _waitForKeptVideo(DmVideoStore store) {
    _keptVideos ??= store.kept
        .where((messageId) => messageId == _message.id)
        .listen((_) {
          unawaited(_keptVideos?.cancel());
          _keptVideos = null;
          unawaited(load());
        });
  }

  @override
  Future<void> close() async {
    await _keptVideos?.cancel();
    return super.close();
  }
}
