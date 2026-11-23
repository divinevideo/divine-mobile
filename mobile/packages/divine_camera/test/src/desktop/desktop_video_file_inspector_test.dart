import 'dart:async';
import 'dart:io';

import 'package:divine_camera/src/desktop/desktop_video_file_inspector.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  group('DesktopVideoFileInspector', () {
    late Directory directory;
    late File file;
    late _MetadataPlayer native;
    late DesktopVideoFileInspector inspector;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('capture-probe-');
      file = await File('${directory.path}/take.mp4').writeAsBytes([1]);
      native = _MetadataPlayer();
      inspector = DesktopVideoFileInspector(
        runtimeInitializer: () {},
        playerFactory: () => Player(platformPlayer: native),
      );
    });
    tearDown(() async {
      if (!native.disposedByOwner) await native.dispose();
      await directory.delete(recursive: true);
    });

    test('times out unreadable metadata and releases its reader', () async {
      final time = FakeAsync();
      native.deferMetadata = true;
      inspector = DesktopVideoFileInspector(
        runtimeInitializer: () {},
        playerFactory: () => Player(platformPlayer: native),
        timerFactory: (duration, callback) =>
            time.run((_) => Timer(duration, callback)),
      );
      final checked = expectLater(
        inspector.inspect(file.path),
        throwsFormatException,
      );
      await native.openEntered.future;
      expect(time.pendingTimers, hasLength(1));

      time.elapse(const Duration(seconds: 10));
      await checked;

      expect(native.disposedByOwner, isTrue);
      expect(time.pendingTimers, isEmpty);
    });

    for (final streamError in [false, true]) {
      test(
        'releases a reader after a decoder error (stream: $streamError)',
        () async {
          native.deferMetadata = true;
          final reading = inspector.inspect(file.path);
          final rejected = expectLater(reading, throwsStateError);
          await native.openEntered.future;
          native.emitDecoderError(streamError: streamError);
          await rejected;

          expect(native.disposedByOwner, isTrue);
        },
      );
    }

    test('waits past placeholder and incomplete video tracks', () async {
      native.deferMetadata = true;
      final reading = inspector.inspect(file.path);
      await native.openEntered.future;
      await pumpEventQueue();
      native
        ..emitDuration(const Duration(milliseconds: 740))
        ..emitTracks(
          const Tracks(
            video: [
              VideoTrack('auto', null, null),
              VideoTrack('no', null, null),
              VideoTrack('cover', null, null, albumart: true, w: 128, h: 128),
              VideoTrack('pending', null, null),
            ],
          ),
        );
      await pumpEventQueue();
      expect(native.disposedByOwner, isFalse);
      native.publishMetadata();

      expect((await reading).width, 1280);
      expect(native.disposedByOwner, isTrue);
    });

    test('reports encoded rotation and absence of an audio track', () async {
      native
        ..rotation = 90
        ..hasAudio = false;

      final metadata = await inspector.inspect(file.path);

      expect(metadata.width, 720);
      expect(metadata.height, 1280);
      expect(metadata.hasAudio, isFalse);
    });

    test('cancels an unfinished read and releases its native reader', () async {
      native.deferMetadata = true;
      final reading = inspector.inspect(file.path);
      final cancelled = expectLater(reading, throwsStateError);
      await native.openEntered.future;
      try {
        await inspector.cancelPending();
      } finally {
        if (!native.disposedByOwner) native.publishMetadata();
        await cancelled;
      }

      expect(native.disposedByOwner, isTrue);
    });

    test('does not construct a reader for missing or empty files', () async {
      await expectLater(
        inspector.inspect('${directory.path}/missing.mp4'),
        throwsFormatException,
      );
      await file.writeAsBytes([]);
      await expectLater(inspector.inspect(file.path), throwsFormatException);

      expect(native.openedUri, isNull);
    });

    test('releases a reader after a native open failure', () async {
      native.openError = StateError('Unreadable capture');

      await expectLater(inspector.inspect(file.path), throwsStateError);

      expect(native.disposedByOwner, isTrue);
    });

    test('waits for metadata delivered after opening the file', () async {
      native.deferMetadata = true;
      final reading = inspector.inspect(file.path);
      final checked = expectLater(
        reading,
        completion(isA<DesktopVideoMetadata>()),
      );
      await native.openEntered.future;
      await pumpEventQueue();
      if (!native.disposedByOwner) native.publishMetadata();
      await checked;

      expect((await reading).duration, const Duration(milliseconds: 740));
      expect(native.disposedByOwner, isTrue);
    });

    test('reads file metadata and releases its muted reader', () async {
      final metadata = await inspector.inspect(file.path);

      expect(metadata.duration, const Duration(milliseconds: 740));
      expect(metadata.width, 1280);
      expect(metadata.height, 720);
      expect(metadata.hasAudio, isTrue);
      expect(native.openedUri, Media(file.absolute.path).uri);
      expect(native.startedPlayback, isFalse);
      expect(native.audioDisabled, isTrue);
      expect(native.disposedByOwner, isTrue);
    });
  });
}

class _MetadataPlayer extends PlatformPlayer {
  _MetadataPlayer() : super(configuration: const PlayerConfiguration());

  String? openedUri;
  bool? startedPlayback;
  bool audioDisabled = false;
  bool disposedByOwner = false;
  bool deferMetadata = false;
  bool hasAudio = true;
  int rotation = 0;
  Error? openError;
  final openEntered = Completer<void>();

  void emitDecoderError({required bool streamError}) {
    if (streamError) {
      tracksController.addError(StateError('Synthetic decoder error'));
    } else {
      errorController.add('Synthetic decoder error');
    }
  }

  void emitDuration(Duration value) => durationController.add(value);

  void emitTracks(Tracks value) => tracksController.add(value);

  @override
  Future<void> setAudioTrack(AudioTrack track) async {
    audioDisabled = track.id == 'no';
  }

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    if (openError case final error?) throw error;
    openedUri = (playable as Media).uri;
    startedPlayback = play;
    if (!deferMetadata) publishMetadata();
    openEntered.complete();
  }

  void publishMetadata() {
    state = state.copyWith(
      duration: const Duration(milliseconds: 740),
      tracks: Tracks(
        video: [VideoTrack('1', null, null, w: 1280, h: 720, rotate: rotation)],
        audio: hasAudio
            ? const [AudioTrack('2', null, null)]
            : const [
                AudioTrack('auto', null, null),
                AudioTrack('no', null, null),
              ],
      ),
    );
    durationController.add(state.duration);
    tracksController.add(state.tracks);
  }

  @override
  Future<void> dispose() async {
    disposedByOwner = true;
    await super.dispose();
  }
}
