// ABOUTME: Tests for the caption generation service.
// ABOUTME: Covers the server-merge path, on-device fallback, timeouts, mapping.

import 'dart:async';

import 'package:caption_generator/caption_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/audio_extraction_service.dart';
import 'package:openvine/services/video_editor/caption_generation_service.dart';
import 'package:openvine/services/video_editor/caption_remote_transcriber.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockAudioExtractionService extends Mock
    implements AudioExtractionService {}

class _MockCaptionGenerator extends Mock implements CaptionGenerator {}

class _MockCaptionRemoteTranscriber extends Mock
    implements CaptionRemoteTranscriber {}

const _mergedPath = '/tmp/merged.wav';

DivineVideoClip _clip(
  String id, {
  Duration duration = const Duration(seconds: 3),
  Duration trimStart = Duration.zero,
  Duration trimEnd = Duration.zero,
  double volume = 1,
  double? playbackSpeed,
  bool withVideo = true,
}) => DivineVideoClip(
  id: id,
  // A network-only video has no local file, so it cannot be transcribed.
  video: withVideo
      ? EditorVideo.file('/tmp/$id.mp4')
      : EditorVideo.network('https://example.com/$id.mp4'),
  duration: duration,
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
  trimStart: trimStart,
  trimEnd: trimEnd,
  volume: volume,
  playbackSpeed: playbackSpeed,
);

AudioExtractionResult _extraction(String path) => AudioExtractionResult(
  audioFilePath: path,
  duration: 3,
  fileSize: 1,
  sha256Hash: 'hash',
  mimeType: 'audio/wav',
);

CaptionSegment _word(String text, int startMs, int endMs) => CaptionSegment(
  text: text,
  start: Duration(milliseconds: startMs),
  end: Duration(milliseconds: endMs),
);

AudioMergeSegmentOffset _offset(int startMs, int durationMs) =>
    AudioMergeSegmentOffset(
      outputStart: Duration(milliseconds: startMs),
      outputDuration: Duration(milliseconds: durationMs),
    );

void main() {
  setUpAll(() => registerFallbackValue(<AudioMergeSegment>[]));

  group(CaptionGenerationService, () {
    late _MockAudioExtractionService extraction;
    late _MockCaptionGenerator generator;

    setUp(() {
      extraction = _MockAudioExtractionService();
      generator = _MockCaptionGenerator();
      when(() => extraction.cleanupAudioFile(any())).thenAnswer((_) async {});
    });

    CaptionGenerationService buildService({
      CaptionRemoteTranscriber? remote,
      Duration? remoteTimeout,
      Duration? onDeviceClipTimeout,
    }) => CaptionGenerationService(
      audioExtractionService: extraction,
      captionGenerator: generator,
      remoteTranscriber: remote,
      remoteTimeout: remoteTimeout ?? const Duration(seconds: 60),
      onDeviceClipTimeout: onDeviceClipTimeout ?? const Duration(seconds: 30),
    );

    /// Stubs the merge to return [offsets] (one per included clip, in order).
    void stubMerge(List<AudioMergeSegmentOffset> offsets) {
      when(
        () => extraction.mergeClipAudio(
          segments: any(named: 'segments'),
          sampleRate: any(named: 'sampleRate'),
          channels: any(named: 'channels'),
        ),
      ).thenAnswer(
        (_) async => AudioMergeResult(
          outputPath: _mergedPath,
          segments: offsets,
          totalDuration: offsets.fold(
            Duration.zero,
            (sum, offset) => sum + offset.outputDuration,
          ),
        ),
      );
    }

    void stubExtraction() {
      when(
        () => extraction.extractAudio(
          videoPath: any(named: 'videoPath'),
          speed: any(named: 'speed'),
        ),
      ).thenAnswer(
        (invocation) async =>
            _extraction('${invocation.namedArguments[#videoPath]}.wav'),
      );
    }

    void stubGenerator(List<CaptionSegment> words) {
      when(
        () => generator.generateCaptions(
          audioPath: any(named: 'audioPath'),
          localeIdentifier: any(named: 'localeIdentifier'),
        ),
      ).thenAnswer((_) async => words);
    }

    _MockCaptionRemoteTranscriber remoteReturning(List<CaptionSegment> words) {
      final remote = _MockCaptionRemoteTranscriber();
      when(
        () => remote.transcribe(
          audioPath: any(named: 'audioPath'),
          localeIdentifier: any(named: 'localeIdentifier'),
        ),
      ).thenAnswer((_) async => words);
      return remote;
    }

    group('server merge path', () {
      test('uses the server merge and never touches on-device', () async {
        stubMerge([_offset(0, 3000)]);
        final service = buildService(
          remote: remoteReturning([_word('Hi.', 0, 500)]),
        );

        final outcome = await service.generateForClips(
          clips: [_clip('a')],
          localeIdentifier: 'en-US',
        );

        expect((outcome as CaptionsGenerated).cues.single.text, equals('Hi.'));
        verifyNever(
          () => extraction.extractAudio(
            videoPath: any(named: 'videoPath'),
            speed: any(named: 'speed'),
          ),
        );
        verifyNever(
          () => generator.generateCaptions(
            audioPath: any(named: 'audioPath'),
            localeIdentifier: any(named: 'localeIdentifier'),
          ),
        );
      });

      test('maps words from consecutive clips onto the timeline', () async {
        stubMerge([_offset(0, 3000), _offset(3000, 3000)]);
        final service = buildService(
          remote: remoteReturning([
            _word('First.', 0, 500),
            _word('Second.', 3100, 3700),
          ]),
        );

        final outcome = await service.generateForClips(
          clips: [_clip('a'), _clip('b')],
          localeIdentifier: 'en-US',
        );

        final cues = (outcome as CaptionsGenerated).cues;
        expect(cues, hasLength(2));
        expect(cues.first.start, equals(Duration.zero));
        expect(cues.last.text, equals('Second.'));
        expect(cues.last.start, equals(const Duration(milliseconds: 3100)));
      });

      test(
        'builds a merge segment from the clip trim window and speed',
        () async {
          stubMerge([_offset(0, 1000)]);
          final service = buildService(remote: remoteReturning(const []));

          await service.generateForClips(
            clips: [
              _clip(
                'a',
                duration: const Duration(seconds: 5),
                trimStart: const Duration(seconds: 1),
                trimEnd: const Duration(seconds: 1),
                playbackSpeed: 2,
              ),
            ],
            localeIdentifier: 'en-US',
          );

          final captured =
              verify(
                    () => extraction.mergeClipAudio(
                      segments: captureAny(named: 'segments'),
                      sampleRate: 16000,
                      channels: 1,
                    ),
                  ).captured.single
                  as List<AudioMergeSegment>;
          final segment = captured.single;
          expect(segment.startTime, equals(const Duration(seconds: 1)));
          // endTime is the source-end position: duration - trimEnd = 5s - 1s.
          expect(segment.endTime, equals(const Duration(seconds: 4)));
          expect(segment.speed, equals(2));
        },
      );

      test('shifts words past a skipped clip using the offset map', () async {
        // The muted clip is excluded from the merge but still occupies 3s.
        stubMerge([_offset(0, 3000)]);
        final service = buildService(
          remote: remoteReturning([_word('Hi.', 100, 600)]),
        );

        final outcome = await service.generateForClips(
          clips: [_clip('muted', volume: 0), _clip('voiced')],
          localeIdentifier: 'en-US',
        );

        final cues = (outcome as CaptionsGenerated).cues;
        expect(cues.single.start, equals(const Duration(milliseconds: 3100)));

        final captured =
            verify(
                  () => extraction.mergeClipAudio(
                    segments: captureAny(named: 'segments'),
                    sampleRate: any(named: 'sampleRate'),
                    channels: any(named: 'channels'),
                  ),
                ).captured.single
                as List<AudioMergeSegment>;
        expect(captured, hasLength(1));
      });

      test(
        'clamps a word crossing a compacted boundary out of the skipped gap',
        () async {
          // Clips a and c are audible; the muted clip between them is dropped
          // from the merge but still occupies 3s of timeline. In the merged
          // audio a and c are contiguous ([0,3s) and [3s,6s)); on the timeline
          // a is at 0s and c is at 6s. A word straddling the a/c merge boundary
          // must stay inside a's span, not spill its tail into the muted gap.
          stubMerge([_offset(0, 3000), _offset(3000, 3000)]);
          final service = buildService(
            remote: remoteReturning([_word('boundary', 2900, 3200)]),
          );

          final outcome = await service.generateForClips(
            clips: [_clip('a'), _clip('muted', volume: 0), _clip('c')],
            localeIdentifier: 'en-US',
          );

          final cue = (outcome as CaptionsGenerated).cues.single;
          expect(cue.text, equals('boundary'));
          expect(cue.start, equals(const Duration(milliseconds: 2900)));
          // Clamped to clip a's timeline end (3s); never into the gap [3s,6s).
          expect(cue.end, equals(const Duration(seconds: 3)));
        },
      );

      test('returns empty when the server finds no speech', () async {
        stubMerge([_offset(0, 3000)]);
        final service = buildService(remote: remoteReturning(const []));

        final outcome = await service.generateForClips(
          clips: [_clip('a')],
          localeIdentifier: 'en-US',
        );

        expect(outcome, isA<CaptionsEmpty>());
        // A "no speech" server result is authoritative — no on-device retry.
        verifyNever(
          () => extraction.extractAudio(
            videoPath: any(named: 'videoPath'),
            speed: any(named: 'speed'),
          ),
        );
      });

      test('cleans up the merged WAV after a server run', () async {
        stubMerge([_offset(0, 3000)]);
        final service = buildService(
          remote: remoteReturning([_word('Hi.', 0, 500)]),
        );

        await service.generateForClips(
          clips: [_clip('a')],
          localeIdentifier: 'en-US',
        );

        verify(() => extraction.cleanupAudioFile(_mergedPath)).called(1);
      });
    });

    group('falls back to on-device', () {
      test('when the server call fails', () async {
        stubMerge([_offset(0, 3000)]);
        stubExtraction();
        stubGenerator([_word('Local.', 0, 500)]);
        final remote = _MockCaptionRemoteTranscriber();
        when(
          () => remote.transcribe(
            audioPath: any(named: 'audioPath'),
            localeIdentifier: any(named: 'localeIdentifier'),
          ),
        ).thenThrow(const CaptionRemoteTranscriptionException('boom'));

        final outcome = await buildService(remote: remote).generateForClips(
          clips: [_clip('a')],
          localeIdentifier: 'en-US',
        );

        expect(
          (outcome as CaptionsGenerated).cues.single.text,
          equals('Local.'),
        );
        verify(
          () => extraction.extractAudio(
            videoPath: '/tmp/a.mp4',
            speed: any(named: 'speed'),
          ),
        ).called(1);
      });

      test('when the merge fails', () async {
        when(
          () => extraction.mergeClipAudio(
            segments: any(named: 'segments'),
            sampleRate: any(named: 'sampleRate'),
            channels: any(named: 'channels'),
          ),
        ).thenThrow(const AudioExtractionException('Failed to merge audio'));
        stubExtraction();
        stubGenerator([_word('Local.', 0, 500)]);

        final outcome = await buildService(
          remote: remoteReturning(const []),
        ).generateForClips(clips: [_clip('a')], localeIdentifier: 'en-US');

        expect(
          (outcome as CaptionsGenerated).cues.single.text,
          equals('Local.'),
        );
        verify(
          () => extraction.extractAudio(
            videoPath: '/tmp/a.mp4',
            speed: any(named: 'speed'),
          ),
        ).called(1);
      });

      test('when the server call times out', () async {
        stubMerge([_offset(0, 3000)]);
        stubExtraction();
        stubGenerator([_word('Local.', 0, 500)]);
        final remote = _MockCaptionRemoteTranscriber();
        when(
          () => remote.transcribe(
            audioPath: any(named: 'audioPath'),
            localeIdentifier: any(named: 'localeIdentifier'),
          ),
        ).thenAnswer((_) => Completer<List<CaptionSegment>>().future);

        final outcome =
            await buildService(
              remote: remote,
              remoteTimeout: const Duration(milliseconds: 20),
            ).generateForClips(
              clips: [_clip('a')],
              localeIdentifier: 'en-US',
            );

        expect(
          (outcome as CaptionsGenerated).cues.single.text,
          equals('Local.'),
        );
      });
    });

    group('on-device only', () {
      test('transcribes each clip and shifts onto the timeline', () async {
        stubExtraction();
        when(
          () => generator.generateCaptions(
            audioPath: '/tmp/a.mp4.wav',
            localeIdentifier: any(named: 'localeIdentifier'),
          ),
        ).thenAnswer((_) async => [_word('First.', 0, 500)]);
        when(
          () => generator.generateCaptions(
            audioPath: '/tmp/b.mp4.wav',
            localeIdentifier: any(named: 'localeIdentifier'),
          ),
        ).thenAnswer((_) async => [_word('Second.', 100, 700)]);

        final outcome = await buildService().generateForClips(
          clips: [_clip('a'), _clip('b')],
          localeIdentifier: 'en-US',
        );

        final cues = (outcome as CaptionsGenerated).cues;
        expect(cues, hasLength(2));
        expect(cues.first.start, equals(Duration.zero));
        expect(cues.last.text, equals('Second.'));
        expect(cues.last.start, equals(const Duration(milliseconds: 3100)));
      });

      test('windows words to the clip trim range and shifts them', () async {
        stubExtraction();
        stubGenerator([_word('Cut', 0, 800), _word('Kept.', 1200, 1800)]);

        final outcome = await buildService().generateForClips(
          clips: [_clip('a', trimStart: const Duration(seconds: 1))],
          localeIdentifier: 'en-US',
        );

        final cues = (outcome as CaptionsGenerated).cues;
        expect(cues.single.text, equals('Kept.'));
        expect(cues.single.start, equals(const Duration(milliseconds: 200)));
        expect(cues.single.end, equals(const Duration(milliseconds: 800)));
      });

      test('extracts at the clip playback speed', () async {
        stubExtraction();
        stubGenerator([_word('Fast.', 0, 400)]);

        await buildService().generateForClips(
          clips: [_clip('a', playbackSpeed: 2)],
          localeIdentifier: 'en-US',
        );

        verify(
          () => extraction.extractAudio(videoPath: '/tmp/a.mp4', speed: 2),
        ).called(1);
      });

      test('skips muted clips and clips without a local file', () async {
        final outcome = await buildService().generateForClips(
          clips: [_clip('muted', volume: 0), _clip('remote', withVideo: false)],
          localeIdentifier: 'en-US',
        );

        expect(outcome, isA<CaptionsEmpty>());
        verifyNever(
          () => extraction.extractAudio(
            videoPath: any(named: 'videoPath'),
            speed: any(named: 'speed'),
          ),
        );
      });

      test('skips clips without an audio track and keeps going', () async {
        when(
          () => extraction.extractAudio(
            videoPath: '/tmp/silent.mp4',
            speed: any(named: 'speed'),
          ),
        ).thenThrow(const AudioExtractionException('Video has no audio track'));
        when(
          () => extraction.extractAudio(
            videoPath: '/tmp/voiced.mp4',
            speed: any(named: 'speed'),
          ),
        ).thenAnswer((_) async => _extraction('/tmp/voiced.mp4.wav'));
        when(
          () => generator.generateCaptions(
            audioPath: '/tmp/voiced.mp4.wav',
            localeIdentifier: any(named: 'localeIdentifier'),
          ),
        ).thenAnswer((_) async => [_word('Hello.', 0, 500)]);

        final outcome = await buildService().generateForClips(
          clips: [_clip('silent'), _clip('voiced')],
          localeIdentifier: 'en-US',
        );

        final cues = (outcome as CaptionsGenerated).cues;
        // The silent clip still occupies its 3s on the timeline.
        expect(cues.single.start, equals(const Duration(seconds: 3)));
      });

      test('fails on other extraction errors', () async {
        when(
          () => extraction.extractAudio(
            videoPath: any(named: 'videoPath'),
            speed: any(named: 'speed'),
          ),
        ).thenThrow(const AudioExtractionException('Extraction failed'));

        final outcome = await buildService().generateForClips(
          clips: [_clip('a')],
          localeIdentifier: 'en-US',
        );

        expect(
          (outcome as CaptionsFailed).reason,
          equals(CaptionGenerationFailure.failed),
        );
      });

      test('fails gracefully when on-device throws an untyped error', () async {
        stubExtraction();
        when(
          () => generator.generateCaptions(
            audioPath: any(named: 'audioPath'),
            localeIdentifier: any(named: 'localeIdentifier'),
          ),
        ).thenThrow(Exception('missing plugin'));

        final outcome = await buildService().generateForClips(
          clips: [_clip('a')],
          localeIdentifier: 'en-US',
        );

        expect(
          (outcome as CaptionsFailed).reason,
          equals(CaptionGenerationFailure.failed),
        );
      });

      test(
        'retries without a language when the recognizer rejects it',
        () async {
          stubExtraction();
          // The explicit language is rejected; the language-less retry (device
          // default) succeeds.
          when(
            () => generator.generateCaptions(
              audioPath: any(named: 'audioPath'),
              localeIdentifier: 'en-US',
            ),
          ).thenThrow(
            const SpeechRecognizerUnavailableException('no language'),
          );
          when(
            () => generator.generateCaptions(
              audioPath: any(named: 'audioPath'),
              localeIdentifier: any(named: 'localeIdentifier', that: isNull),
            ),
          ).thenAnswer((_) async => [_word('Default.', 0, 500)]);

          final outcome = await buildService().generateForClips(
            clips: [_clip('a'), _clip('b')],
            localeIdentifier: 'en-US',
          );

          final cues = (outcome as CaptionsGenerated).cues;
          expect(cues.first.text, equals('Default.'));
          // Only the first clip pays the rejected explicit-language attempt; the
          // second goes straight to the device default.
          verify(
            () => generator.generateCaptions(
              audioPath: any(named: 'audioPath'),
              localeIdentifier: 'en-US',
            ),
          ).called(1);
        },
      );

      test('fails when on-device transcription times out', () async {
        stubExtraction();
        when(
          () => generator.generateCaptions(
            audioPath: any(named: 'audioPath'),
            localeIdentifier: any(named: 'localeIdentifier'),
          ),
        ).thenAnswer((_) => Completer<List<CaptionSegment>>().future);

        final outcome =
            await buildService(
              onDeviceClipTimeout: const Duration(milliseconds: 20),
            ).generateForClips(
              clips: [_clip('a')],
              localeIdentifier: 'en-US',
            );

        expect(
          (outcome as CaptionsFailed).reason,
          equals(CaptionGenerationFailure.failed),
        );
      });

      group('maps transcription exceptions to failure reasons', () {
        final cases = <CaptionGenerationException, CaptionGenerationFailure>{
          const SpeechRecognizerUnavailableException('no recognizer'):
              CaptionGenerationFailure.recognizerUnavailable,
          const SpeechNotAuthorizedException():
              CaptionGenerationFailure.notAuthorized,
          const UnsupportedAudioFormatException('bad wav'):
              CaptionGenerationFailure.unsupportedAudio,
          const TranscriptionFailedException('boom'):
              CaptionGenerationFailure.failed,
        };

        for (final MapEntry(key: exception, value: reason) in cases.entries) {
          test(reason.name, () async {
            stubExtraction();
            when(
              () => generator.generateCaptions(
                audioPath: any(named: 'audioPath'),
                localeIdentifier: any(named: 'localeIdentifier'),
              ),
            ).thenThrow(exception);

            final outcome = await buildService().generateForClips(
              clips: [_clip('a')],
              localeIdentifier: 'en-US',
            );

            expect((outcome as CaptionsFailed).reason, equals(reason));
            // The extracted WAV is cleaned up even on failure.
            verify(
              () => extraction.cleanupAudioFile('/tmp/a.mp4.wav'),
            ).called(1);
          });
        }
      });

      test('cleans up the extracted WAV after a successful run', () async {
        stubExtraction();
        stubGenerator([_word('Hello.', 0, 500)]);

        await buildService().generateForClips(
          clips: [_clip('a')],
          localeIdentifier: 'en-US',
        );

        verify(() => extraction.cleanupAudioFile('/tmp/a.mp4.wav')).called(1);
      });

      test('returns empty when no speech is recognized', () async {
        stubExtraction();
        stubGenerator(const []);

        final outcome = await buildService().generateForClips(
          clips: [_clip('a')],
          localeIdentifier: 'en-US',
        );

        expect(outcome, isA<CaptionsEmpty>());
      });

      test('groups words into sentence cues', () async {
        stubExtraction();
        stubGenerator([
          _word('Hello', 0, 400),
          _word('there.', 450, 900),
          _word('Bye.', 1000, 1400),
        ]);

        final outcome = await buildService().generateForClips(
          clips: [_clip('a')],
          localeIdentifier: 'en-US',
        );

        final cues = (outcome as CaptionsGenerated).cues;
        expect(cues, hasLength(2));
        expect(cues.first.text, equals('Hello there.'));
        expect(cues.last.text, equals('Bye.'));
      });

      test('keeps the recognized timing of every word', () async {
        stubExtraction();
        stubGenerator([_word('Hello', 0, 400), _word('there.', 450, 900)]);

        final outcome = await buildService().generateForClips(
          clips: [_clip('a')],
          localeIdentifier: 'en-US',
        );

        expect((outcome as CaptionsGenerated).cues.single.words, [
          _word('Hello', 0, 400),
          _word('there.', 450, 900),
        ]);
      });
    });

    test('spreads the words of a server cue over its time', () async {
      stubMerge([_offset(0, 3000)]);
      final service = buildService(
        remote: remoteReturning([_word('Hi there.', 0, 900)]),
      );

      final outcome = await service.generateForClips(
        clips: [_clip('a')],
        localeIdentifier: 'en-US',
      );

      // The server only times whole cues; each word gets a share by length.
      expect((outcome as CaptionsGenerated).cues.single.words, [
        _word('Hi', 0, 225),
        _word('there.', 225, 900),
      ]);
    });
  });
}
