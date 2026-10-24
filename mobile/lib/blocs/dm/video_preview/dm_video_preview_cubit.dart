// ABOUTME: Cubit for the frame a trusted sender's video DM card shows, read
// ABOUTME: from the video this device keeps, and whether it stays blurred.

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/services/dm_video_preview_memory.dart';
import 'package:openvine/services/dm_video_store.dart';

/// Whether a video DM's card has a frame to show.
enum DmVideoPreviewStatus {
  /// Reading the frame, downloading the video first when needed.
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
    this.blurred = false,
    this.frameBlurhash,
  });

  /// Whether there is a frame to show.
  final DmVideoPreviewStatus status;

  /// Path of the kept frame while [status] is [DmVideoPreviewStatus.ready].
  final String? framePath;

  /// Whether the card shows a blurhash instead of its frame until its video
  /// is played.
  final bool blurred;

  /// A blurhash read from the kept frame, for a blurred card whose sender
  /// sent none.
  final String? frameBlurhash;

  /// A copy with [blurred] or [frameBlurhash] replaced.
  DmVideoPreviewState copyWith({bool? blurred, String? frameBlurhash}) =>
      DmVideoPreviewState(
        status: status,
        framePath: framePath,
        blurred: blurred ?? this.blurred,
        frameBlurhash: frameBlurhash ?? this.frameBlurhash,
      );

  @override
  List<Object?> get props => [status, framePath, blurred, frameBlurhash];
}

/// Finds the frame one video DM's card shows, for a sender the user trusts.
///
/// The video is downloaded and decrypted when it is not kept yet, unless it
/// is too big to fetch without a tap. A card left without a frame picks it up
/// as soon as the user plays the video and the store keeps it.
///
/// A card that blurs until played stays [DmVideoPreviewState.blurred] until
/// [DmVideoPreviewMemory] records a play. Meanwhile, when the sender sent no
/// blurhash, it reads one from the kept frame for the card to show instead.
class DmVideoPreviewCubit extends Cubit<DmVideoPreviewState>
    with CloseGuardedEmit<DmVideoPreviewState> {
  /// Creates a [DmVideoPreviewCubit] for [message].
  ///
  /// It starts with a frame [store] already knows, so a card built again,
  /// such as one scrolled back into view, shows it from its first frame.
  /// With [blurUntilPlayed] it starts blurred unless [memory] has already
  /// seen the video played, with any blurhash [memory] already read.
  DmVideoPreviewCubit({
    required DmMessage message,
    required DmVideoStore? store,
    DmVideoPreviewMemory? memory,
    bool blurUntilPlayed = false,
  }) : _message = message,
       _store = store,
       _memory = memory,
       super(
         _initialState(
           store?.knownPreviewPathFor(message),
           blurred:
               blurUntilPlayed && !(memory?.isWatched(message.id) ?? false),
           frameBlurhash: memory?.knownFrameBlurhashFor(message.id),
         ),
       ) {
    if (state.blurred) {
      _plays = memory?.watched
          .where((messageId) => messageId == _message.id)
          .listen((_) => _unblur());
    }
  }

  static DmVideoPreviewState _initialState(
    String? knownFramePath, {
    required bool blurred,
    required String? frameBlurhash,
  }) => DmVideoPreviewState(
    status: knownFramePath == null
        ? DmVideoPreviewStatus.loading
        : DmVideoPreviewStatus.ready,
    framePath: knownFramePath,
    blurred: blurred,
    frameBlurhash: blurred ? frameBlurhash : null,
  );

  final DmMessage _message;

  /// Null when no account is signed in, as videos are kept per account, or
  /// on the web, which has no folder for them.
  final DmVideoStore? _store;

  /// Null when no account is signed in.
  final DmVideoPreviewMemory? _memory;
  StreamSubscription<String>? _keptVideos;
  StreamSubscription<String>? _plays;

  /// Reads the frame, downloading the video first when needed.
  Future<void> load() async {
    final store = _store;
    if (store == null) {
      emitIfOpen(_withFrame(null));
      return;
    }
    final String? framePath;
    try {
      final frame = await store.previewFor(
        _message,
        stillWanted: () => !isClosed,
      );
      framePath = frame?.path;
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(_withFrame(null));
      // A tap on play still keeps the video, so wait for it as below.
      if (!isClosed) _waitForKeptVideo(store);
      return;
    }
    emitIfOpen(_withFrame(framePath));
    if (framePath != null) {
      await _readFrameBlurhash(framePath);
    } else if (!isClosed) {
      _waitForKeptVideo(store);
    }
  }

  /// [state] with [framePath] as its frame, or with none when it is null.
  DmVideoPreviewState _withFrame(String? framePath) => DmVideoPreviewState(
    status: framePath == null
        ? DmVideoPreviewStatus.none
        : DmVideoPreviewStatus.ready,
    framePath: framePath,
    blurred: state.blurred,
    frameBlurhash: state.frameBlurhash,
  );

  /// Reads a blurhash from the kept frame for a blurred card whose sender
  /// sent none, so the card never has to paint the frame itself.
  Future<void> _readFrameBlurhash(String framePath) async {
    final memory = _memory;
    final senderBlurhash = _message.fileMetadata?.blurhash;
    if (memory == null ||
        !state.blurred ||
        state.frameBlurhash != null ||
        (senderBlurhash != null && senderBlurhash.isNotEmpty)) {
      return;
    }
    final blurhash = await memory.frameBlurhashFor(
      messageId: _message.id,
      framePath: framePath,
    );
    if (blurhash != null) emitIfOpen(state.copyWith(frameBlurhash: blurhash));
  }

  void _unblur() {
    unawaited(_plays?.cancel());
    _plays = null;
    emitIfOpen(state.copyWith(blurred: false));
  }

  /// Reads the frame again once this message's video or frame is kept: when
  /// the user plays it, or when a decode that outlasted the card's wait ends.
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
    // Await the cancels after `super.close()`, not before: awaiting one first
    // yields a microtask in which a [load] whose download just finished
    // resumes, sees [isClosed] as false, and starts a wait nothing cancels.
    final keptVideos = _keptVideos?.cancel();
    final plays = _plays?.cancel();
    _keptVideos = null;
    _plays = null;
    await super.close();
    await keptVideos;
    await plays;
  }
}
