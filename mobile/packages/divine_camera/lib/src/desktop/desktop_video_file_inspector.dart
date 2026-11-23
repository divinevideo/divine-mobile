import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart';

/// Media information read from the completed file, rather than its preview.
class DesktopVideoMetadata {
  /// Creates metadata from the media runtime's demuxed tracks.
  const DesktopVideoMetadata({
    required this.duration,
    required this.width,
    required this.height,
    required this.hasAudio,
  });

  /// Duration of the media file.
  final Duration duration;

  /// Display width after applying its rotation metadata.
  final int width;

  /// Display height after applying its rotation metadata.
  final int height;

  /// Whether the file contains a real audio track.
  final bool hasAudio;
}

/// Owns short-lived, muted media readers for desktop capture validation.
class DesktopVideoFileInspector {
  /// Creates an inspector with injectable native runtime dependencies.
  DesktopVideoFileInspector({
    Player Function()? playerFactory,
    void Function()? runtimeInitializer,
    Timer Function(Duration, void Function())? timerFactory,
  }) : createPlayer = playerFactory ?? Player.new,
       initializeRuntime = runtimeInitializer ?? MediaKit.ensureInitialized,
       _createTimer = timerFactory ?? Timer.new;

  /// Factory for each independently owned metadata reader.
  final Player Function() createPlayer;

  /// Initializes the platform media runtime before constructing a reader.
  final void Function() initializeRuntime;
  final Timer Function(Duration, void Function()) _createTimer;

  final _pending = <Future<void>, void Function()>{};

  /// Cancels unfinished reads and waits for their native readers to close.
  Future<void> cancelPending() async {
    final pending = Map<Future<void>, void Function()>.of(_pending);
    for (final cancel in pending.values) {
      cancel();
    }
    await Future.wait(pending.keys);
  }

  /// Reads only a local capture file and releases the reader before returning.
  Future<DesktopVideoMetadata> inspect(String path) async {
    final file = File(path).absolute;
    if (!file.existsSync() || file.lengthSync() == 0) {
      throw const FormatException('The recording file is empty or missing.');
    }
    initializeRuntime();
    final player = createPlayer();
    final result = Completer<DesktopVideoMetadata>();
    var duration = Duration.zero;
    var tracks = const Tracks();
    var closed = false;
    void collect() {
      if (closed || result.isCompleted || duration <= Duration.zero) return;
      for (final video in tracks.video) {
        if (video.id == 'auto' || video.id == 'no' || video.albumart == true) {
          continue;
        }
        final width = video.w;
        final height = video.h;
        if (width == null || width <= 0 || height == null || height <= 0) {
          continue;
        }
        final rotated = (video.rotate ?? 0) % 180 != 0;
        result.complete(
          DesktopVideoMetadata(
            duration: duration,
            width: rotated ? height : width,
            height: rotated ? width : height,
            hasAudio: tracks.audio.any(
              (track) => track.id != 'auto' && track.id != 'no',
            ),
          ),
        );
        return;
      }
    }

    void fail(Object error, StackTrace stackTrace) {
      if (!closed && !result.isCompleted) {
        result.completeError(error, stackTrace);
      }
    }

    final released = Completer<void>();
    _pending[released.future] = () => fail(
      StateError('Recording inspection was cancelled.'),
      StackTrace.current,
    );

    final durationEvents = player.stream.duration.listen((value) {
      duration = value;
      collect();
    }, onError: fail);
    final trackEvents = player.stream.tracks.listen((value) {
      tracks = value;
      collect();
    }, onError: fail);
    final errors = player.stream.error.listen(
      (message) => fail(StateError(message), StackTrace.current),
      onError: fail,
    );
    final timer = _createTimer(const Duration(seconds: 10), () {
      fail(
        const FormatException('The recording has no readable video metadata.'),
        StackTrace.current,
      );
    });
    try {
      unawaited(
        Future<void>.sync(() async {
          await player.setAudioTrack(AudioTrack.no());
          await player.open(Media(file.uri.toString()), play: false);
          if (closed) return;
          duration = player.state.duration;
          tracks = player.state.tracks;
          collect();
        }).then<void>((_) {}, onError: fail),
      );
      return await result.future;
    } finally {
      closed = true;
      timer.cancel();
      try {
        await Future.wait([
          durationEvents.cancel(),
          trackEvents.cancel(),
          errors.cancel(),
        ]);
      } finally {
        try {
          await player.dispose();
        } finally {
          _pending.remove(released.future);
          released.complete();
        }
      }
    }
  }
}
