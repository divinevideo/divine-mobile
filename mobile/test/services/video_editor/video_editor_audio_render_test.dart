// ABOUTME: Unit tests for building and resolving render audio tracks.
// ABOUTME: Covers timing, diagnostics, skip-on-failure, and empty fallback.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/video_editor/video_editor_audio_render.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// An [EditorAudio] whose [safeFilePath] always fails, standing in for a track
/// whose source cannot be resolved (e.g. a failed network download).
class _UnresolvableAudio extends EditorAudio {
  _UnresolvableAudio() : super(networkUrl: 'https://example.com/missing.mp3');

  @override
  Future<String> safeFilePath({String? fileExtension}) async {
    throw const FileSystemException('cannot resolve audio for render');
  }
}

AudioTrack _fileTrack({
  required String id,
  required String path,
  Duration startTime = const Duration(seconds: 1),
  Duration endTime = const Duration(seconds: 4),
  Duration audioStartTime = const Duration(milliseconds: 250),
  Duration audioEndTime = const Duration(seconds: 3),
  double volume = 0.5,
  bool loop = true,
}) {
  return AudioTrack(
    id: id,
    title: id,
    subtitle: 'test',
    duration: const Duration(seconds: 3),
    audio: EditorAudio.file(File(path)),
    startTime: startTime,
    endTime: endTime,
    audioStartTime: audioStartTime,
    audioEndTime: audioEndTime,
    volume: volume,
    loop: loop,
  );
}

AudioTrack _unresolvableTrack(String id) {
  return AudioTrack(
    id: id,
    title: id,
    subtitle: 'test',
    duration: const Duration(seconds: 3),
    audio: _UnresolvableAudio(),
  );
}

void main() {
  late LogCaptureService capture;

  setUp(() async {
    capture = LogCaptureService();
    await capture.clearAllLogs();
  });

  tearDown(() => capture.clearAllLogs());

  group('buildRenderAudioTracks', () {
    AudioEvent sound({
      Duration startOffset = Duration.zero,
      Duration startTime = Duration.zero,
      Duration? endTime,
    }) => AudioEvent(
      id: 'selected-sound',
      pubkey: 'a' * 64,
      createdAt: 1735689600,
      url: '/tmp/selected-sound.mp3',
      duration: 30,
      startOffset: startOffset,
      startTime: startTime,
      endTime: endTime,
    );

    test('recorder-selected sound starts at composition zero while preserving '
        'the chosen source offset', () {
      final tracks = buildRenderAudioTracks(
        metaTracks: const [],
        selectedSound: sound(
          startOffset: const Duration(seconds: 12),
          startTime: const Duration(milliseconds: 1300),
          endTime: const Duration(seconds: 20),
        ),
        logName: 'recorder-render',
      );

      expect(tracks, hasLength(1));
      expect(tracks.single.startTime, Duration.zero);
      expect(tracks.single.endTime, const Duration(seconds: 30));
      expect(tracks.single.audioStartTime, const Duration(seconds: 12));
      final log = capture.getRecentLogs(limit: 1).single;
      expect(log.name, 'recorder-render');
      expect(log.level, LogLevel.warning);
      expect(log.message, contains('Prepared selected-sound fallback'));
    });

    test('timeline timing wins over the recorder-selected fallback', () {
      final tracks = buildRenderAudioTracks(
        metaTracks: [
          sound(
            startTime: const Duration(milliseconds: 1300),
            endTime: const Duration(seconds: 20),
          ),
        ],
        selectedSound: sound(startOffset: const Duration(seconds: 12)),
        logName: 'timeline-render',
      );

      expect(tracks, hasLength(1));
      expect(tracks.single.startTime, const Duration(milliseconds: 1300));
      expect(tracks.single.endTime, const Duration(seconds: 20));
      expect(tracks.single.audioStartTime, Duration.zero);
      final log = capture.getRecentLogs(limit: 1).single;
      expect(log.name, 'timeline-render');
      expect(log.level, LogLevel.warning);
      expect(log.message, contains('Prepared timeline'));
    });
  });

  group('resolveRenderAudioTracks', () {
    test('returns an empty list for empty input', () async {
      final result = await resolveRenderAudioTracks(
        const <AudioTrack>[],
        logName: 'test',
      );

      expect(result, isEmpty);
    });

    test(
      'resolves a file-backed track to a VideoAudioTrack preserving timing, '
      'volume, and loop',
      () async {
        final result = await resolveRenderAudioTracks(
          [_fileTrack(id: 'a', path: '/tmp/a.mp3')],
          logName: 'test',
        );

        expect(result, hasLength(1));
        final track = result.single;
        expect(track.path, equals('/tmp/a.mp3'));
        expect(track.startTime, equals(const Duration(seconds: 1)));
        expect(track.endTime, equals(const Duration(seconds: 4)));
        expect(
          track.audioStartTime,
          equals(const Duration(milliseconds: 250)),
        );
        expect(track.audioEndTime, equals(const Duration(seconds: 3)));
        expect(track.volume, equals(0.5));
        expect(track.loop, isTrue);
      },
    );

    test(
      'skips a track that cannot be resolved while keeping the resolvable ones',
      () async {
        final result = await resolveRenderAudioTracks(
          [
            _unresolvableTrack('bad'),
            _fileTrack(id: 'good', path: '/tmp/good.mp3'),
          ],
          logName: 'test',
        );

        expect(result, hasLength(1));
        expect(result.single.path, equals('/tmp/good.mp3'));
      },
    );

    test('returns an empty list when no requested track resolves', () async {
      final result = await resolveRenderAudioTracks(
        [_unresolvableTrack('bad-1'), _unresolvableTrack('bad-2')],
        logName: 'test',
      );

      expect(result, isEmpty);
    });

    test(
      'clamps a track window that outlasts the video to the video duration',
      () async {
        // A full-length song (endTime 4s) muxed onto a ~1s stop-motion video
        // must not outlast the video track, or iOS freezes the last frame.
        final result = await resolveRenderAudioTracks(
          [
            _fileTrack(
              id: 'song',
              path: '/tmp/song.mp3',
              startTime: Duration.zero,
            ),
          ],
          logName: 'test',
          videoDuration: const Duration(seconds: 1),
        );

        expect(result.single.startTime, equals(Duration.zero));
        expect(result.single.endTime, equals(const Duration(seconds: 1)));
      },
    );

    test('keeps source offset separate from composition placement for a short '
        'stop-motion render', () async {
      final built = buildRenderAudioTracks(
        metaTracks: const [],
        selectedSound: AudioEvent(
          id: 'stop-motion-sound',
          pubkey: 'b' * 64,
          createdAt: 1735689600,
          url: '/tmp/stop-motion-sound.mp3',
          duration: 30,
          startOffset: const Duration(seconds: 12),
        ),
        logName: 'test',
      );

      final result = await resolveRenderAudioTracks(
        built,
        logName: 'test',
        videoDuration: const Duration(milliseconds: 1400),
      );

      expect(result, hasLength(1));
      expect(result.single.startTime, Duration.zero);
      expect(result.single.endTime, const Duration(milliseconds: 1400));
      expect(result.single.audioStartTime, const Duration(seconds: 12));
    });

    test(
      'captures resolved timing without exposing the local source path',
      () async {
        await resolveRenderAudioTracks(
          [
            _fileTrack(
              id: 'diagnostic-track',
              path: '/private/user-name/selected-sound.mp3',
              startTime: Duration.zero,
              endTime: const Duration(seconds: 30),
              audioStartTime: const Duration(seconds: 12),
              audioEndTime: const Duration(seconds: 20),
            ),
          ],
          logName: 'test-audio-render',
          videoDuration: const Duration(milliseconds: 1400),
        );

        final log = capture.getRecentLogs(limit: 1).single;
        expect(log.name, 'test-audio-render');
        expect(log.level, LogLevel.warning);
        expect(log.category, LogCategory.video);
        expect(
          log.message,
          contains(
            'composition=[0ms, 1400ms], source=[12000ms, 20000ms], '
            'videoDuration=1400ms',
          ),
        );
        expect(log.message, isNot(contains('/private/user-name')));
      },
    );

    test('leaves a track shorter than the video untouched', () async {
      final result = await resolveRenderAudioTracks(
        [
          _fileTrack(
            id: 'short',
            path: '/tmp/short.mp3',
            endTime: const Duration(seconds: 2),
          ),
        ],
        logName: 'test',
        videoDuration: const Duration(seconds: 6),
      );

      expect(result.single.startTime, equals(const Duration(seconds: 1)));
      expect(result.single.endTime, equals(const Duration(seconds: 2)));
    });
  });

  group('clampAudioWindowToVideo', () {
    test('returns the window unchanged when videoDuration is null', () {
      final result = clampAudioWindowToVideo(
        startTime: const Duration(seconds: 1),
        endTime: const Duration(seconds: 9),
        videoDuration: null,
      );

      expect(result?.startTime, equals(const Duration(seconds: 1)));
      expect(result?.endTime, equals(const Duration(seconds: 9)));
    });

    test('leaves a null endTime null (means "play to end of video")', () {
      final result = clampAudioWindowToVideo(
        startTime: Duration.zero,
        endTime: null,
        videoDuration: const Duration(seconds: 1),
      );

      expect(result, isNotNull);
      expect(result?.endTime, isNull);
    });

    test('drops a track whose whole window starts past the video', () {
      // Clamping both ends would collapse this to a zero-length
      // [1s, 1s] window, which VideoAudioTrack asserts against.
      final result = clampAudioWindowToVideo(
        startTime: const Duration(seconds: 5),
        endTime: const Duration(seconds: 9),
        videoDuration: const Duration(seconds: 1),
      );

      expect(result, isNull);
    });

    test('drops a track starting exactly at the video end', () {
      final result = clampAudioWindowToVideo(
        startTime: const Duration(seconds: 1),
        endTime: const Duration(seconds: 9),
        videoDuration: const Duration(seconds: 1),
      );

      expect(result, isNull);
    });

    test('keeps a window that still has video left to play over', () {
      final result = clampAudioWindowToVideo(
        startTime: const Duration(milliseconds: 500),
        endTime: const Duration(seconds: 9),
        videoDuration: const Duration(seconds: 1),
      );

      expect(result?.startTime, equals(const Duration(milliseconds: 500)));
      expect(result?.endTime, equals(const Duration(seconds: 1)));
    });
  });
}
