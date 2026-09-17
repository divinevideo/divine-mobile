// ABOUTME: Tests for AudioTimingCubit - audio timing state and playback.
// ABOUTME: Covers initialization, offset updates, playback lifecycle,
// ABOUTME: and start offset calculation using mocktail AudioClipPlayer mocks.

import 'dart:async';
import 'dart:ui' show Size;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_editor/audio_timing/audio_timing_cubit.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:sound_service/sound_service.dart';

class _MockAudioClipPlayer extends Mock implements AudioClipPlayer {}

/// Mock [ProVideoEditor] that returns canned metadata. Allows overriding
/// the duration returned by [getMetadata] per test.
class _MockProVideoEditor extends ProVideoEditor {
  _MockProVideoEditor({
    this.metadataDuration = const Duration(seconds: 30),
    this.throwOnGetMetadata = false,
  });

  final Duration metadataDuration;
  final bool throwOnGetMetadata;

  int getMetadataCallCount = 0;
  EditorVideo? lastMetadataSource;

  @override
  void initializeStream() {
    // Intentional no-op: testing stub for ProVideoEditor.
  }

  @override
  Future<VideoMetadata> getMetadata(
    EditorVideo value, {
    bool checkStreamingOptimization = false,
    NativeLogLevel? nativeLogLevel,
  }) async {
    getMetadataCallCount++;
    lastMetadataSource = value;
    if (throwOnGetMetadata) {
      throw Exception('mock failure');
    }
    return VideoMetadata(
      duration: metadataDuration,
      extension: 'mp3',
      fileSize: 1024,
      resolution: Size.zero,
      rotation: 0,
      bitrate: 128000,
    );
  }
}

/// Creates a test [AudioEvent] with optional overrides.
AudioEvent _createTestSound({
  String id = 'test_sound_id',
  double? duration = 20,
  Duration startOffset = Duration.zero,
  String? url = 'https://example.com/audio.mp3',
}) {
  return AudioEvent(
    id: id,
    pubkey: 'test_pubkey',
    createdAt: 0,
    duration: duration,
    startOffset: startOffset,
    url: url,
  );
}

/// Creates a bundled test [AudioEvent].
AudioEvent _createBundledSound({
  double? duration = 20,
  Duration startOffset = Duration.zero,
}) {
  return AudioEvent(
    id: 'bundled_test_sound',
    pubkey: AudioEvent.bundledMarker,
    createdAt: 0,
    duration: duration,
    startOffset: startOffset,
    url: 'asset://assets/sounds/test.mp3',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(const AudioSourceConfig.network(''));
  });

  group(AudioTimingCubit, () {
    late _MockAudioClipPlayer mockClipPlayer;
    late _MockProVideoEditor mockProVideoEditor;

    setUp(() {
      mockClipPlayer = _MockAudioClipPlayer();
      mockProVideoEditor = _MockProVideoEditor();
      when(
        () => mockClipPlayer.completionStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockClipPlayer.setClip(any())).thenAnswer((_) async {});
      when(() => mockClipPlayer.play()).thenAnswer((_) async {});
      when(() => mockClipPlayer.pause()).thenAnswer((_) async {});
      when(() => mockClipPlayer.stop()).thenAnswer((_) async {});
      when(() => mockClipPlayer.seek(any())).thenAnswer((_) async {});
      when(() => mockClipPlayer.dispose()).thenAnswer((_) async {});
    });

    AudioTimingCubit buildCubit({
      AudioEvent? sound,
      ProVideoEditor? proVideoEditor,
    }) {
      return AudioTimingCubit(
        sound: sound ?? _createTestSound(),
        clipPlayer: mockClipPlayer,
        proVideoEditor: proVideoEditor ?? mockProVideoEditor,
      );
    }

    test('initial state is default $AudioTimingState', () async {
      final cubit = buildCubit();
      expect(cubit.state, equals(const AudioTimingState()));
      expect(cubit.state.startOffset, equals(0));
      expect(cubit.state.audioDuration, isNull);
      expect(cubit.state.isPlaying, isFalse);
      await cubit.close();
    });

    group('initialize', () {
      blocTest<AudioTimingCubit, AudioTimingState>(
        'emits state with audio duration and starts playback '
        'for network audio',
        build: buildCubit,
        act: (cubit) => cubit.initialize(),
        expect: () => [
          isA<AudioTimingState>()
              .having((s) => s.audioDuration, 'audioDuration', 20)
              .having((s) => s.startOffset, 'startOffset', 0),
          isA<AudioTimingState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isTrue,
          ),
        ],
        verify: (_) {
          verify(() => mockClipPlayer.setClip(any())).called(1);
          verify(() => mockClipPlayer.play()).called(1);
        },
      );

      blocTest<AudioTimingCubit, AudioTimingState>(
        'restores previous offset from sound startOffset',
        build: () => buildCubit(
          sound: _createTestSound(
            // minRemainingAudio = 0.5s, scrollable = 20 - 0.5 = 19.5s
            // For offset 0.5: startTime = 0.5 * 19.5 = 9.75s
            startOffset: const Duration(milliseconds: 9750),
          ),
        ),
        act: (cubit) => cubit.initialize(),
        expect: () => [
          isA<AudioTimingState>()
              .having((s) => s.audioDuration, 'audioDuration', 20)
              .having((s) => s.startOffset, 'startOffset', closeTo(0.5, 0.01)),
          isA<AudioTimingState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isTrue,
          ),
        ],
      );

      blocTest<AudioTimingCubit, AudioTimingState>(
        'uses offset 0 when audio is shorter than minRemainingAudio',
        build: () => buildCubit(
          sound: _createTestSound(duration: 0.3),
        ),
        act: (cubit) => cubit.initialize(),
        expect: () => [
          isA<AudioTimingState>()
              .having((s) => s.audioDuration, 'audioDuration', 0.3)
              .having((s) => s.startOffset, 'startOffset', 0),
          isA<AudioTimingState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isTrue,
          ),
        ],
      );

      blocTest<AudioTimingCubit, AudioTimingState>(
        'handles null duration gracefully',
        build: () => buildCubit(
          sound: _createTestSound(duration: null),
          // Force resolution to fail so audioDuration stays at 0.
          proVideoEditor: _MockProVideoEditor(throwOnGetMetadata: true),
        ),
        act: (cubit) => cubit.initialize(),
        expect: () => [
          isA<AudioTimingState>()
              .having((s) => s.audioDuration, 'audioDuration', 0)
              .having((s) => s.startOffset, 'startOffset', 0),
          // Still emits isPlaying since play() is called even though
          // setClippedAudioSource bails early for zero duration
          isA<AudioTimingState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isTrue,
          ),
        ],
      );

      blocTest<AudioTimingCubit, AudioTimingState>(
        'resolves missing duration via ProVideoEditor.getMetadata',
        build: () => buildCubit(
          sound: _createTestSound(duration: null),
          proVideoEditor: _MockProVideoEditor(
            metadataDuration: const Duration(seconds: 25),
          ),
        ),
        act: (cubit) => cubit.initialize(),
        expect: () => [
          isA<AudioTimingState>()
              .having((s) => s.audioDuration, 'audioDuration', 25)
              .having((s) => s.startOffset, 'startOffset', 0),
          isA<AudioTimingState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isTrue,
          ),
        ],
      );

      blocTest<AudioTimingCubit, AudioTimingState>(
        'falls back to 0 duration when ProVideoEditor.getMetadata throws',
        build: () => buildCubit(
          sound: _createTestSound(duration: null),
          proVideoEditor: _MockProVideoEditor(throwOnGetMetadata: true),
        ),
        act: (cubit) => cubit.initialize(),
        expect: () => [
          isA<AudioTimingState>()
              .having((s) => s.audioDuration, 'audioDuration', 0)
              .having((s) => s.startOffset, 'startOffset', 0),
          // Still emits isPlaying since play() is called even though
          // setClippedAudioSource bails early for zero duration
          isA<AudioTimingState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isTrue,
          ),
        ],
      );

      test(
        'skips ProVideoEditor lookup when sound has neither url nor asset',
        () async {
          final editor = _MockProVideoEditor();
          final cubit = buildCubit(
            sound: _createTestSound(duration: null, url: null),
            proVideoEditor: editor,
          );

          await cubit.initialize();

          expect(editor.getMetadataCallCount, equals(0));
          expect(cubit.state.audioDuration, equals(0));

          await cubit.close();
        },
      );

      test(
        'resolves imported-audio duration from a file source, not a URL',
        () async {
          final editor = _MockProVideoEditor(
            metadataDuration: const Duration(seconds: 12),
          );
          final cubit = buildCubit(
            // No duration → forces metadata resolution.
            sound: AudioEvent.fromLocalImport(
              id: '${AudioEvent.localImportMarker}_1',
              filePath: '/var/mobile/draft_audio/import.mp3',
              createdAt: 0,
              title: 'Imported',
              mimeType: 'audio/mpeg',
            ),
            proVideoEditor: editor,
          );

          await cubit.initialize();

          expect(editor.getMetadataCallCount, equals(1));
          expect(editor.lastMetadataSource?.hasFile, isTrue);
          expect(
            editor.lastMetadataSource?.file?.path,
            equals('/var/mobile/draft_audio/import.mp3'),
          );
          expect(cubit.state.audioDuration, equals(12));

          await cubit.close();
        },
      );

      blocTest<AudioTimingCubit, AudioTimingState>(
        'handles bundled sound with asset path',
        build: () => buildCubit(sound: _createBundledSound()),
        act: (cubit) => cubit.initialize(),
        expect: () => [
          isA<AudioTimingState>().having(
            (s) => s.audioDuration,
            'audioDuration',
            20,
          ),
          isA<AudioTimingState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isTrue,
          ),
        ],
        verify: (_) {
          verify(() => mockClipPlayer.setClip(any())).called(1);
          verify(() => mockClipPlayer.play()).called(1);
        },
      );
    });

    group('updateOffset', () {
      blocTest<AudioTimingCubit, AudioTimingState>(
        'emits state with updated offset',
        build: buildCubit,
        act: (cubit) => cubit.updateOffset(0.75),
        expect: () => [
          isA<AudioTimingState>().having(
            (s) => s.startOffset,
            'startOffset',
            0.75,
          ),
        ],
      );

      blocTest<AudioTimingCubit, AudioTimingState>(
        'clamps offset to 0.0 when negative',
        build: buildCubit,
        act: (cubit) => cubit.updateOffset(-0.5),
        expect: () => [
          isA<AudioTimingState>().having(
            (s) => s.startOffset,
            'startOffset',
            0,
          ),
        ],
      );

      blocTest<AudioTimingCubit, AudioTimingState>(
        'clamps offset to 1.0 when exceeding maximum',
        build: buildCubit,
        act: (cubit) => cubit.updateOffset(1.5),
        expect: () => [
          isA<AudioTimingState>().having(
            (s) => s.startOffset,
            'startOffset',
            1.0,
          ),
        ],
      );
    });

    group('pausePlayback', () {
      blocTest<AudioTimingCubit, AudioTimingState>(
        'pauses audio and emits isPlaying false',
        build: buildCubit,
        seed: () => const AudioTimingState(isPlaying: true),
        act: (cubit) => cubit.pausePlayback(),
        expect: () => [
          isA<AudioTimingState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isFalse,
          ),
        ],
        verify: (_) {
          verify(() => mockClipPlayer.pause()).called(1);
        },
      );
    });

    group('resumePlayback', () {
      blocTest<AudioTimingCubit, AudioTimingState>(
        'sets clipped source and plays audio',
        build: buildCubit,
        seed: () => const AudioTimingState(audioDuration: 20, startOffset: 0.5),
        act: (cubit) => cubit.resumePlayback(),
        expect: () => [
          isA<AudioTimingState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isTrue,
          ),
        ],
        verify: (_) {
          verify(() => mockClipPlayer.setClip(any())).called(1);
          verify(() => mockClipPlayer.play()).called(1);
        },
      );

      // Regression coverage for #4395: extracted audio is stored in
      // AudioEvent.url as a bare absolute path; it must be routed
      // through AudioSourceConfig.file, not .network.
      blocTest<AudioTimingCubit, AudioTimingState>(
        'uses AudioSourceConfig.file for a bare absolute path',
        build: () => buildCubit(
          sound: _createTestSound(
            url:
                '/var/mobile/Containers/Data/Application/'
                'tmp/extracted_audio_123.wav',
          ),
        ),
        seed: () => const AudioTimingState(audioDuration: 20),
        act: (cubit) => cubit.resumePlayback(),
        verify: (_) {
          final captured =
              verify(() => mockClipPlayer.setClip(captureAny())).captured.single
                  as AudioSourceConfig;
          expect(captured.isAsset, isFalse);
          expect(captured.isFile, isTrue);
          expect(captured.uri, startsWith('/var/mobile/'));
        },
      );

      blocTest<AudioTimingCubit, AudioTimingState>(
        'uses AudioSourceConfig.file for a file:// URI',
        build: () => buildCubit(
          sound: _createTestSound(url: 'file:///tmp/extracted_audio.wav'),
        ),
        seed: () => const AudioTimingState(audioDuration: 20),
        act: (cubit) => cubit.resumePlayback(),
        verify: (_) {
          final captured =
              verify(() => mockClipPlayer.setClip(captureAny())).captured.single
                  as AudioSourceConfig;
          expect(captured.isFile, isTrue);
          expect(captured.uri, '/tmp/extracted_audio.wav');
        },
      );

      blocTest<AudioTimingCubit, AudioTimingState>(
        'uses AudioSourceConfig.network for an https URL',
        build: () => buildCubit(sound: _createTestSound()),
        seed: () => const AudioTimingState(audioDuration: 20),
        act: (cubit) => cubit.resumePlayback(),
        verify: (_) {
          final captured =
              verify(() => mockClipPlayer.setClip(captureAny())).captured.single
                  as AudioSourceConfig;
          expect(captured.isAsset, isFalse);
          expect(captured.isFile, isFalse);
          expect(captured.uri, 'https://example.com/audio.mp3');
        },
      );

      blocTest<AudioTimingCubit, AudioTimingState>(
        'uses AudioSourceConfig.asset for a bundled sound',
        build: () => buildCubit(sound: _createBundledSound()),
        seed: () => const AudioTimingState(audioDuration: 20),
        act: (cubit) => cubit.resumePlayback(),
        verify: (_) {
          final captured =
              verify(() => mockClipPlayer.setClip(captureAny())).captured.single
                  as AudioSourceConfig;
          expect(captured.isAsset, isTrue);
          expect(captured.isFile, isFalse);
        },
      );
    });

    group('stopPlayback', () {
      blocTest<AudioTimingCubit, AudioTimingState>(
        'stops audio and emits isPlaying false',
        build: buildCubit,
        seed: () => const AudioTimingState(isPlaying: true),
        act: (cubit) => cubit.stopPlayback(),
        expect: () => [
          isA<AudioTimingState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isFalse,
          ),
        ],
        verify: (_) {
          verify(() => mockClipPlayer.stop()).called(1);
        },
      );
    });

    group('calculateStartOffset', () {
      test(
        'returns Duration.zero when audio is shorter than minRemaining',
        () async {
          final cubit = buildCubit(sound: _createTestSound(duration: 0.3));
          // audioDuration (0.3s) <= minRemainingAudioSecs (0.5s),
          // so scrollable = 0 → always zero
          cubit.emit(
            const AudioTimingState(audioDuration: 0.3, startOffset: 0.5),
          );

          expect(cubit.calculateStartOffset(), equals(Duration.zero));
          await cubit.close();
        },
      );

      test('returns correct offset for 20s audio at midpoint', () async {
        final cubit = buildCubit(sound: _createTestSound());
        // minRemaining = 0.5s, scrollable = 20 - 0.5 = 19.5s
        // At offset 0.5: startTime = 0.5 * 19.5 = 9.75s = 9750ms
        cubit.emit(const AudioTimingState(audioDuration: 20, startOffset: 0.5));

        expect(
          cubit.calculateStartOffset(),
          equals(const Duration(milliseconds: 9750)),
        );
        await cubit.close();
      });

      test('returns Duration.zero at offset 0', () async {
        final cubit = buildCubit(sound: _createTestSound());
        cubit.emit(const AudioTimingState(audioDuration: 20));

        expect(cubit.calculateStartOffset(), equals(Duration.zero));
        await cubit.close();
      });

      test('returns maximum offset at 1.0', () async {
        final cubit = buildCubit(sound: _createTestSound());
        // scrollable = 20 - 0.5 = 19.5s
        cubit.emit(const AudioTimingState(audioDuration: 20, startOffset: 1.0));

        expect(
          cubit.calculateStartOffset(),
          equals(const Duration(milliseconds: 19500)),
        );
        await cubit.close();
      });

      test(
        'allows start offset past audioDuration - maxDuration '
        '(short remainder)',
        () async {
          // 10s audio, video maxDuration = 6.3s.
          // Old behaviour capped startOffset at 10 - 6.3 = 3.7s.
          // New behaviour allows up to 10 - 0.5 = 9.5s, leaving 0.5s of
          // audio playback for the remainder of the video.
          final cubit = buildCubit(sound: _createTestSound(duration: 10));
          cubit.emit(
            const AudioTimingState(audioDuration: 10, startOffset: 1.0),
          );

          expect(
            cubit.calculateStartOffset(),
            equals(const Duration(milliseconds: 9500)),
          );
          await cubit.close();
        },
      );
    });

    group('player state changes', () {
      test('restarts playback when audio completes', () async {
        final completionController = StreamController<void>();

        when(
          () => mockClipPlayer.completionStream,
        ).thenAnswer((_) => completionController.stream);

        final cubit = buildCubit(sound: _createTestSound());
        await cubit.initialize();

        // Simulate audio completion
        completionController.add(null);

        // Allow the stream listener to process
        await Future<void>.delayed(Duration.zero);

        verify(() => mockClipPlayer.seek(Duration.zero)).called(1);
        // Initial play + restart play
        verify(() => mockClipPlayer.play()).called(2);

        await completionController.close();
        await cubit.close();
      });
    });

    group('close', () {
      test('disposes audio clip player', () async {
        final cubit = buildCubit();
        await cubit.close();

        verify(() => mockClipPlayer.dispose()).called(1);
      });
    });
  });

  group(AudioTimingState, () {
    test('supports value equality', () {
      expect(const AudioTimingState(), equals(const AudioTimingState()));
    });

    test('props are correct', () {
      expect(const AudioTimingState().props, equals([0.0, null, false]));
    });

    group('copyWith', () {
      test('returns same object when no parameters', () {
        const state = AudioTimingState(
          startOffset: 0.5,
          audioDuration: 20,
          isPlaying: true,
        );
        expect(state.copyWith(), equals(state));
      });

      test('replaces startOffset', () {
        const state = AudioTimingState(startOffset: 0.5);
        expect(
          state.copyWith(startOffset: 0.75),
          equals(const AudioTimingState(startOffset: 0.75)),
        );
      });

      test('replaces audioDuration', () {
        const state = AudioTimingState();
        expect(
          state.copyWith(audioDuration: 15),
          equals(const AudioTimingState(audioDuration: 15)),
        );
      });

      test('replaces isPlaying', () {
        const state = AudioTimingState();
        expect(
          state.copyWith(isPlaying: true),
          equals(const AudioTimingState(isPlaying: true)),
        );
      });
    });
  });
}
