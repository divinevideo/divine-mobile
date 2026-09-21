// ABOUTME: Unit tests for building and resolving render audio tracks.
// ABOUTME: Covers timing, diagnostics, fail-on-unavailable, and empty fallback.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:models/models.dart';
import 'package:openvine/services/video_editor/render_audio_fetcher.dart';
import 'package:openvine/services/video_editor/video_editor_audio_render.dart';
import 'package:openvine/services/video_editor/video_render_failures.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:unified_logger/unified_logger.dart';

const _missingUrl = 'https://example.com/missing';

/// A fetcher whose every network request answers 404, standing in for a
/// sound whose blob is gone. No retries, so the test does not wait on the
/// backoff ladder.
RenderAudioFetcher _missingBlobFetcher(Directory tempDir) => RenderAudioFetcher(
  clientFactory: () =>
      MockClient((request) async => http.Response('gone', 404)),
  tempDirectory: tempDir,
  baseDelay: Duration.zero,
);

/// A fetcher that serves a small WAV body for every request.
RenderAudioFetcher _servingFetcher(Directory tempDir) => RenderAudioFetcher(
  clientFactory: () => MockClient(
    (request) async => http.Response.bytes(
      [...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WAVE'.codeUnits, 1, 2, 3, 4],
      200,
    ),
  ),
  tempDirectory: tempDir,
  baseDelay: Duration.zero,
);

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

AudioTrack _networkTrack(String id, {String url = _missingUrl}) {
  return AudioTrack(
    id: id,
    title: id,
    subtitle: 'test',
    duration: const Duration(seconds: 3),
    audio: EditorAudio.network(url),
    startTime: Duration.zero,
    endTime: const Duration(seconds: 3),
  );
}

void main() {
  late LogCaptureService capture;
  late Directory tempDir;

  setUp(() async {
    capture = LogCaptureService();
    await capture.clearAllLogs();
    tempDir = Directory.systemTemp.createTempSync('audio_render_test');
  });

  tearDown(() async {
    await capture.clearAllLogs();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

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
      expect(
        log.message,
        contains('composition=[0ms, 30000ms], source=[12000ms, unbounded]'),
      );
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
      expect(
        log.message,
        contains('composition=[1300ms, 20000ms], source=[0ms, unbounded]'),
      );
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
      'fails the render when a sound cannot be fetched instead of shipping '
      'the video without it',
      () async {
        await expectLater(
          resolveRenderAudioTracks(
            [
              _fileTrack(id: 'good', path: '/tmp/good.mp3'),
              _networkTrack('bad'),
            ],
            logName: 'test',
            fetcher: _missingBlobFetcher(tempDir),
          ),
          throwsA(
            isA<VideoRenderFailedException>()
                .having(
                  (e) => e.reason,
                  'reason',
                  VideoRenderFailureReason.audioUnavailable,
                )
                .having(
                  (e) => e.cause,
                  'cause',
                  isA<RenderAudioFetchException>(),
                ),
          ),
        );
      },
    );

    test(
      'reports every materialized sound file for cleanup',
      () async {
        final tempFilePaths = <String>[];
        final result = await resolveRenderAudioTracks(
          [
            _networkTrack('song', url: 'https://example.com/song'),
            _fileTrack(id: 'local', path: '/tmp/local.mp3'),
          ],
          logName: 'test',
          fetcher: _servingFetcher(tempDir),
          tempFilePaths: tempFilePaths,
        );

        expect(result, hasLength(2));
        expect(result.first.path, endsWith('.wav'));
        expect(File(result.first.path).existsSync(), isTrue);
        expect(
          tempFilePaths,
          [result.first.path],
          reason: 'the static file belongs to the caller',
        );
      },
    );

    test('reports an in-memory sound file for cleanup', () async {
      final tempFilePaths = <String>[];
      final result = await resolveRenderAudioTracks(
        [
          AudioTrack(
            id: 'memory',
            title: 'memory',
            subtitle: 'test',
            duration: const Duration(seconds: 3),
            audio: EditorAudio.memory(Uint8List.fromList([1, 2, 3, 4])),
            startTime: Duration.zero,
            endTime: const Duration(seconds: 3),
          ),
        ],
        logName: 'test',
        tempFilePaths: tempFilePaths,
      );
      addTearDown(() {
        final file = File(result.single.path);
        if (file.existsSync()) file.deleteSync();
      });

      expect(tempFilePaths, [result.single.path]);
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
