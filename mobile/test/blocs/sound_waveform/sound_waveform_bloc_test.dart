// ABOUTME: Tests for SoundWaveformBloc - waveform extraction from audio.
// ABOUTME: Covers initial state, extract events, clear events, and state transitions.

import 'dart:io';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/sound_waveform/sound_waveform_bloc.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:sound_service/sound_service.dart';

class _MockRemoteAudioCache extends Mock implements RemoteAudioCache {}

/// The file [_MockRemoteAudioCache] hands out for every sound.
final _cachedFile = File('/cache/sound.m4a');

/// A piece of a waveform stream covering samples from [start] on, of a
/// sound [samples] samples long at one sample a second.
WaveformChunk _chunk(
  int start,
  List<double> left, {
  List<double>? right,
  int samples = 4,
  bool isComplete = false,
}) => WaveformChunk(
  leftChannel: Float32List.fromList(left),
  rightChannel: right == null ? null : Float32List.fromList(right),
  startIndex: start,
  progress: (start + left.length) / samples,
  sampleRate: 44100,
  totalDuration: Duration(seconds: samples),
  samplesPerSecond: 1,
  isComplete: isComplete,
);

class _MockProVideoEditor extends ProVideoEditor {
  bool shouldThrowError = false;
  Duration waveformDuration = const Duration(seconds: 5);
  late Float32List leftChannel;
  Float32List? rightChannel;

  /// The source the bloc built from the extract event's [AudioSourceKind].
  /// Captured so tests can assert the file-vs-network mapping rather than
  /// just the resulting state.
  EditorVideo? lastWaveformSource;

  /// How many points per piece the bloc asked the editor for.
  int? lastChunkSize;

  /// What [getWaveformStream] sends, by default the whole waveform at once.
  List<WaveformChunk>? chunks;

  /// Called before each piece is sent, with the piece's index.
  void Function(int index)? beforeChunk;
  Object? streamError;

  _MockProVideoEditor() {
    // Default waveform data
    leftChannel = Float32List.fromList([0.1, 0.5, 0.9, 0.3, 0.7]);
    rightChannel = Float32List.fromList([0.2, 0.6, 0.8, 0.4, 0.6]);
  }

  @override
  Stream<dynamic> initializeStream() {
    return const Stream.empty();
  }

  @override
  Stream<WaveformChunk> getWaveformStream(
    WaveformConfigs configs, {
    NativeLogLevel? nativeLogLevel,
  }) async* {
    lastWaveformSource = configs.video;
    lastChunkSize = configs.chunkSize;
    if (shouldThrowError) {
      throw Exception('Waveform extraction failed');
    }
    final chunks =
        this.chunks ??
        [
          WaveformChunk(
            leftChannel: leftChannel,
            rightChannel: rightChannel,
            startIndex: 0,
            progress: 1,
            sampleRate: 44100,
            totalDuration: waveformDuration,
            samplesPerSecond: leftChannel.length ~/ waveformDuration.inSeconds,
            isComplete: true,
          ),
        ];
    for (final (index, chunk) in chunks.indexed) {
      beforeChunk?.call(index);
      yield chunk;
    }
    if (streamError case final error?) throw error;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockProVideoEditor mockProVideoEditor;
  late ProVideoEditor originalProVideoEditor;
  late _MockRemoteAudioCache remoteAudioCache;
  late DateTime Function() clockNow;

  setUpAll(() => registerFallbackValue(Uri()));

  setUp(() {
    originalProVideoEditor = ProVideoEditor.instance;
    mockProVideoEditor = _MockProVideoEditor();
    ProVideoEditor.instance = mockProVideoEditor;
    remoteAudioCache = _MockRemoteAudioCache();
    when(
      () => remoteAudioCache.fileFor(any()),
    ).thenAnswer((_) async => _cachedFile);
  });

  tearDown(() {
    ProVideoEditor.instance = originalProVideoEditor;
  });

  group(SoundWaveformBloc, () {
    SoundWaveformBloc buildBloc() {
      return SoundWaveformBloc(remoteAudioCache: remoteAudioCache);
    }

    test('initial state is $SoundWaveformInitial', () async {
      final bloc = buildBloc();
      expect(bloc.state, isA<SoundWaveformInitial>());
      await bloc.close();
    });

    group(SoundWaveformExtract, () {
      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'emits [$SoundWaveformLoading, $SoundWaveformLoaded] '
        'when extraction succeeds',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const SoundWaveformExtract(
            path: 'https://example.com/audio.mp3',
            soundId: 'test-sound-id',
          ),
        ),
        expect: () => [isA<SoundWaveformLoading>(), isA<SoundWaveformLoaded>()],
      );

      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'loaded state contains correct waveform data',
        build: buildBloc,
        setUp: () {
          mockProVideoEditor.leftChannel = Float32List.fromList([0.1, 0.2]);
          mockProVideoEditor.rightChannel = Float32List.fromList([0.3, 0.4]);
          mockProVideoEditor.waveformDuration = const Duration(seconds: 10);
        },
        act: (bloc) => bloc.add(
          const SoundWaveformExtract(
            path: 'https://example.com/audio.mp3',
            soundId: 'test-sound-id',
          ),
        ),
        verify: (bloc) {
          final state = bloc.state as SoundWaveformLoaded;
          expect(state.leftChannel, equals(Float32List.fromList([0.1, 0.2])));
          expect(state.rightChannel, equals(Float32List.fromList([0.3, 0.4])));
          expect(state.duration, equals(const Duration(seconds: 10)));
        },
      );

      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'emits [$SoundWaveformLoading, $SoundWaveformError] '
        'when extraction fails',
        setUp: () {
          mockProVideoEditor.shouldThrowError = true;
        },
        build: buildBloc,
        act: (bloc) => bloc.add(
          const SoundWaveformExtract(
            path: 'https://example.com/audio.mp3',
            soundId: 'test-sound-id',
          ),
        ),
        expect: () => [isA<SoundWaveformLoading>(), isA<SoundWaveformError>()],
        errors: () => [isA<Exception>()],
      );

      // The failure detail belongs in the error stream, never in state
      // (`state_management.md`). This pins both halves: `addError` still
      // carries the underlying exception text, and the emitted state is
      // value-equal to a bare `SoundWaveformError()` — so nothing about the
      // exception leaked into it.
      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'reports the failure through addError and keeps it out of state',
        setUp: () {
          mockProVideoEditor.shouldThrowError = true;
        },
        build: buildBloc,
        act: (bloc) => bloc.add(
          const SoundWaveformExtract(
            path: 'https://example.com/audio.mp3',
            soundId: 'test-sound-id',
          ),
        ),
        expect: () => [
          isA<SoundWaveformLoading>(),
          const SoundWaveformError(),
        ],
        errors: () => [
          isA<Exception>().having(
            (error) => error.toString(),
            'toString',
            contains('Waveform extraction failed'),
          ),
        ],
      );

      // The mapping at sound_waveform_bloc.dart:36-40 turns each
      // AudioSourceKind into the matching EditorVideo source. These tests
      // assert the built source (not just the resulting state) so a regression
      // that maps file → network (issue #5579) fails loudly.
      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'builds an asset source for asset-kind extraction',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const SoundWaveformExtract(
            path: 'assets/sounds/test.mp3',
            soundId: 'bundled-sound-id',
            kind: AudioSourceKind.asset,
          ),
        ),
        expect: () => [isA<SoundWaveformLoading>(), isA<SoundWaveformLoaded>()],
        verify: (_) {
          final source = mockProVideoEditor.lastWaveformSource;
          expect(source?.hasAssetPath, isTrue);
          expect(source?.assetPath, equals('assets/sounds/test.mp3'));
          expect(source?.hasFile, isFalse);
          expect(source?.hasNetworkUrl, isFalse);
        },
      );

      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'builds a file source for file-kind extraction',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const SoundWaveformExtract(
            path: '/var/mobile/Containers/Data/draft_audio/import.mp3',
            soundId: 'local_import_1',
            kind: AudioSourceKind.file,
          ),
        ),
        expect: () => [isA<SoundWaveformLoading>(), isA<SoundWaveformLoaded>()],
        verify: (_) {
          final source = mockProVideoEditor.lastWaveformSource;
          expect(source?.hasFile, isTrue);
          expect(
            source?.file?.path,
            equals('/var/mobile/Containers/Data/draft_audio/import.mp3'),
          );
          expect(source?.hasNetworkUrl, isFalse);
          expect(source?.hasAssetPath, isFalse);
        },
      );

      // Handed the URL, the editor downloads the sound again on every read;
      // a preview or an earlier screen usually has its file already.
      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'reads a network sound from the file the cache keeps for it',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const SoundWaveformExtract(
            path: 'https://example.com/audio.mp3',
            soundId: 'remote-sound-id',
          ),
        ),
        expect: () => [isA<SoundWaveformLoading>(), isA<SoundWaveformLoaded>()],
        verify: (_) {
          verify(
            () => remoteAudioCache.fileFor(
              Uri.parse('https://example.com/audio.mp3'),
            ),
          ).called(1);
          final source = mockProVideoEditor.lastWaveformSource;
          expect(source?.hasFile, isTrue);
          expect(source?.file?.path, _cachedFile.path);
          expect(source?.hasNetworkUrl, isFalse);
        },
      );

      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'reports a sound that could not be downloaded',
        setUp: () => when(() => remoteAudioCache.fileFor(any())).thenThrow(
          RemoteAudioDownloadException(
            Uri.parse('https://example.com/audio.mp3'),
            statusCode: 404,
          ),
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(
          const SoundWaveformExtract(
            path: 'https://example.com/audio.mp3',
            soundId: 'remote-sound-id',
          ),
        ),
        expect: () => [
          isA<SoundWaveformLoading>(),
          const SoundWaveformError(),
        ],
        errors: () => [isA<RemoteAudioDownloadException>()],
      );
    });

    group('$SoundWaveformExtract as the sound is read', () {
      const longSound = SoundWaveformExtract(
        path: '/sounds/song.m4a',
        soundId: 'song',
        kind: AudioSourceKind.file,
      );

      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'shows the waveform as it is read, from the start',
        setUp: () => mockProVideoEditor.chunks = [
          _chunk(0, [0.1, 0.2], right: [0.3, 0.4]),
          _chunk(2, [0.5, 0.6], right: [0.7, 0.8], isComplete: true),
        ],
        build: buildBloc,
        act: (bloc) => bloc.add(longSound),
        expect: () => [
          const SoundWaveformLoading(),
          SoundWaveformLoaded(
            leftChannel: Float32List.fromList([0.1, 0.2, 0, 0]),
            rightChannel: Float32List.fromList([0.3, 0.4, 0, 0]),
            duration: const Duration(seconds: 4),
            isComplete: false,
            readFraction: 0.5,
          ),
          SoundWaveformLoaded(
            leftChannel: Float32List.fromList([0.1, 0.2, 0.5, 0.6]),
            rightChannel: Float32List.fromList([0.3, 0.4, 0.7, 0.8]),
            duration: const Duration(seconds: 4),
          ),
        ],
      );

      // The editor reads faster than the screen redraws, and every state is a
      // copy of all samples.
      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'emits pieces that arrive at once together',
        setUp: () => mockProVideoEditor.chunks = [
          _chunk(0, [0.1]),
          _chunk(1, [0.2]),
          _chunk(2, [0.3]),
          _chunk(3, [0.4], isComplete: true),
        ],
        // A clock that never moves: every piece arrives at the same moment.
        build: () => withClock(Clock.fixed(DateTime(2026)), buildBloc),
        act: (bloc) => bloc.add(longSound),
        expect: () => [
          const SoundWaveformLoading(),
          isA<SoundWaveformLoaded>().having(
            (state) => state.readFraction,
            'readFraction',
            0.25,
          ),
          isA<SoundWaveformLoaded>()
              .having((state) => state.isComplete, 'isComplete', isTrue)
              .having((state) => state.readFraction, 'readFraction', 1),
        ],
      );

      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'emits each piece that arrives two frames after the last one',
        setUp: () {
          var now = DateTime(2026);
          mockProVideoEditor
            ..chunks = [
              _chunk(0, [0.1]),
              _chunk(1, [0.2]),
              _chunk(2, [0.3]),
              _chunk(3, [0.4], isComplete: true),
            ]
            ..beforeChunk = (_) =>
                now = now.add(const Duration(milliseconds: 40));
          clockNow = () => now;
        },
        build: () => withClock(Clock(() => clockNow()), buildBloc),
        act: (bloc) => bloc.add(longSound),
        expect: () => [
          const SoundWaveformLoading(),
          for (final read in [0.25, 0.5, 0.75])
            isA<SoundWaveformLoaded>().having(
              (state) => state.readFraction,
              'readFraction',
              read,
            ),
          isA<SoundWaveformLoaded>().having(
            (state) => state.isComplete,
            'isComplete',
            isTrue,
          ),
        ],
      );

      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'asks the editor for pieces of a quarter second',
        build: buildBloc,
        act: (bloc) => bloc.add(longSound),
        verify: (_) => expect(mockProVideoEditor.lastChunkSize, 12),
      );

      // The editor ends a waveform where the decoded audio ends, which can
      // be a little short of the duration in the file's header.
      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'ends the waveform where the last piece ends',
        setUp: () => mockProVideoEditor.chunks = [
          _chunk(0, [0.1, 0.2]),
          _chunk(2, [0.5], isComplete: true),
        ],
        build: buildBloc,
        act: (bloc) => bloc.add(longSound),
        skip: 2,
        expect: () => [
          SoundWaveformLoaded(
            leftChannel: Float32List.fromList([0.1, 0.2, 0.5]),
            duration: const Duration(seconds: 4),
          ),
        ],
      );

      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'reports a stream that fails partway',
        setUp: () => mockProVideoEditor
          ..chunks = [
            _chunk(0, [0.1, 0.2]),
          ]
          ..streamError = Exception('decoder died'),
        build: buildBloc,
        act: (bloc) => bloc.add(longSound),
        expect: () => [
          const SoundWaveformLoading(),
          isA<SoundWaveformLoaded>().having(
            (state) => state.isComplete,
            'isComplete',
            isFalse,
          ),
          const SoundWaveformError(),
        ],
        errors: () => [isA<Exception>()],
      );
    });

    group('$SoundWaveformExtract.forSound', () {
      test('returns a file-kind event for imported audio', () {
        final sound = AudioEvent.fromLocalImport(
          id: '${AudioEvent.localImportMarker}_1',
          filePath: '/var/mobile/Containers/Data/draft_audio/import.mp3',
          createdAt: 0,
          title: 'Imported',
          mimeType: 'audio/mpeg',
        );

        final event = SoundWaveformExtract.forSound(sound);

        expect(event, isNotNull);
        expect(event!.kind, AudioSourceKind.file);
        expect(event.path, sound.localFilePath);
      });

      test('returns an asset-kind event for bundled sounds', () {
        final sound = AudioEvent.fromBundledSound(
          VineSound(
            id: 'wednesday',
            title: 'Wednesday',
            assetPath: 'assets/sounds/wednesday.mp3',
            duration: const Duration(seconds: 6),
          ),
        );

        final event = SoundWaveformExtract.forSound(sound);

        expect(event, isNotNull);
        expect(event!.kind, AudioSourceKind.asset);
        expect(event.path, sound.assetPath);
      });

      test('returns a network-kind event for remote sounds', () {
        final sound = AudioEvent(
          id: 'remote',
          pubkey: 'abc',
          createdAt: 0,
          url: 'https://example.com/audio.mp3',
        );

        final event = SoundWaveformExtract.forSound(sound);

        expect(event, isNotNull);
        expect(event!.kind, AudioSourceKind.network);
        expect(event.path, 'https://example.com/audio.mp3');
      });

      test('returns null when the sound has no usable source', () {
        final sound = AudioEvent(id: 'no-source', pubkey: 'abc', createdAt: 0);

        expect(SoundWaveformExtract.forSound(sound), isNull);
      });
    });

    group(SoundWaveformClear, () {
      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'emits [$SoundWaveformInitial] when clearing from loaded state',
        build: buildBloc,
        seed: () => SoundWaveformLoaded(
          leftChannel: Float32List.fromList([0.1, 0.5]),
          rightChannel: Float32List.fromList([0.2, 0.6]),
          duration: const Duration(seconds: 5),
        ),
        act: (bloc) => bloc.add(const SoundWaveformClear()),
        expect: () => [isA<SoundWaveformInitial>()],
      );

      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'emits [$SoundWaveformInitial] when clearing from loading state',
        build: buildBloc,
        seed: () => const SoundWaveformLoading(),
        act: (bloc) => bloc.add(const SoundWaveformClear()),
        expect: () => [isA<SoundWaveformInitial>()],
      );

      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'emits [$SoundWaveformInitial] when clearing from error state',
        build: buildBloc,
        seed: () => const SoundWaveformError(),
        act: (bloc) => bloc.add(const SoundWaveformClear()),
        expect: () => [isA<SoundWaveformInitial>()],
      );

      blocTest<SoundWaveformBloc, SoundWaveformState>(
        'emits [$SoundWaveformInitial] when clearing from initial state',
        build: buildBloc,
        act: (bloc) => bloc.add(const SoundWaveformClear()),
        expect: () => [isA<SoundWaveformInitial>()],
      );
    });
  });

  group('$SoundWaveformEvent equality', () {
    test('$SoundWaveformExtract events with same props are equal', () {
      const event1 = SoundWaveformExtract(path: 'test.mp3', soundId: 'sound-1');
      const event2 = SoundWaveformExtract(path: 'test.mp3', soundId: 'sound-1');
      expect(event1, equals(event2));
      expect(event1.props, equals(event2.props));
    });

    test('$SoundWaveformExtract events with different props are not equal', () {
      const event1 = SoundWaveformExtract(
        path: 'test1.mp3',
        soundId: 'sound-1',
      );
      const event2 = SoundWaveformExtract(
        path: 'test2.mp3',
        soundId: 'sound-2',
      );
      expect(event1, isNot(equals(event2)));
    });

    test('$SoundWaveformExtract kind prop affects equality', () {
      const event1 = SoundWaveformExtract(path: 'test.mp3', soundId: 'sound-1');
      const event2 = SoundWaveformExtract(
        path: 'test.mp3',
        soundId: 'sound-1',
        kind: AudioSourceKind.asset,
      );
      expect(event1, isNot(equals(event2)));
    });

    test('$SoundWaveformClear events are equal', () {
      const event1 = SoundWaveformClear();
      const event2 = SoundWaveformClear();
      expect(event1, equals(event2));
    });
  });

  group('$SoundWaveformState equality', () {
    test('$SoundWaveformInitial states are equal', () {
      const state1 = SoundWaveformInitial();
      const state2 = SoundWaveformInitial();
      expect(state1, equals(state2));
    });

    test('$SoundWaveformLoading states are equal', () {
      const state1 = SoundWaveformLoading();
      const state2 = SoundWaveformLoading();
      expect(state1, equals(state2));
    });

    test('$SoundWaveformLoaded states with same data are equal', () {
      final leftChannel = Float32List.fromList([0.1, 0.5]);
      final rightChannel = Float32List.fromList([0.2, 0.6]);
      const duration = Duration(seconds: 5);

      final state1 = SoundWaveformLoaded(
        leftChannel: leftChannel,
        rightChannel: rightChannel,
        duration: duration,
      );
      final state2 = SoundWaveformLoaded(
        leftChannel: leftChannel,
        rightChannel: rightChannel,
        duration: duration,
      );
      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));
    });

    test(
      '$SoundWaveformLoaded states with different duration are not equal',
      () {
        final leftChannel = Float32List.fromList([0.1, 0.5]);

        final state1 = SoundWaveformLoaded(
          leftChannel: leftChannel,
          duration: const Duration(seconds: 5),
        );
        final state2 = SoundWaveformLoaded(
          leftChannel: leftChannel,
          duration: const Duration(seconds: 10),
        );
        expect(state1, isNot(equals(state2)));
      },
    );

    test('$SoundWaveformLoaded states with different waveform data '
        'are not equal', () {
      final state1 = SoundWaveformLoaded(
        leftChannel: Float32List.fromList([0.1, 0.5]),
        duration: const Duration(seconds: 5),
      );
      final state2 = SoundWaveformLoaded(
        leftChannel: Float32List.fromList([0.9, 0.3]),
        duration: const Duration(seconds: 5),
      );
      expect(state1, isNot(equals(state2)));
    });

    test('$SoundWaveformLoaded states still being read are not equal to '
        'whole ones', () {
      final leftChannel = Float32List.fromList([0.1, 0.5]);

      final state1 = SoundWaveformLoaded(
        leftChannel: leftChannel,
        duration: const Duration(seconds: 5),
        isComplete: false,
      );
      final state2 = SoundWaveformLoaded(
        leftChannel: leftChannel,
        duration: const Duration(seconds: 5),
      );
      expect(state1, isNot(equals(state2)));
    });

    test('$SoundWaveformLoaded states read to different points '
        'are not equal', () {
      final leftChannel = Float32List.fromList([0.1, 0.5]);

      expect(
        SoundWaveformLoaded(
          leftChannel: leftChannel,
          duration: const Duration(seconds: 5),
          isComplete: false,
          readFraction: 0.5,
        ),
        isNot(
          equals(
            SoundWaveformLoaded(
              leftChannel: leftChannel,
              duration: const Duration(seconds: 5),
              isComplete: false,
              readFraction: 0.25,
            ),
          ),
        ),
      );
    });

    test('$SoundWaveformError states are equal regardless of cause', () {
      const state1 = SoundWaveformError();
      const state2 = SoundWaveformError();
      expect(state1, equals(state2));
    });
  });
}
