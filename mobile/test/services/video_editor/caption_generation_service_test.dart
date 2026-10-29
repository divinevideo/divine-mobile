// ABOUTME: Tests for the caption generation service.
// ABOUTME: Covers the server-merge path, on-device fallback, timeouts, mapping.

import 'dart:async';

import 'package:caption_generator/caption_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AudioEvent, VoiceEffect;
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

const _takeId = '${AudioEvent.voiceOverIdPrefix}_1';
const _extractedId = '${AudioEvent.localExtractedMarker}_1';

/// A 10 s sound at [url] that plays from [startTime] to [endTime].
AudioEvent _track(
  String id, {
  required String url,
  required Duration startTime,
  required Duration endTime,
  Duration startOffset = Duration.zero,
  double volume = 1,
  double playbackSpeed = 1,
  String? originalUrl,
  VoiceEffect voiceEffect = VoiceEffect.none,
  bool noiseReduction = false,
  String? anchorClipId,
}) => AudioEvent(
  id: id,
  pubkey: '',
  createdAt: 0,
  url: url,
  originalUrl: originalUrl,
  duration: 10,
  startTime: startTime,
  endTime: endTime,
  startOffset: startOffset,
  volume: volume,
  playbackSpeed: playbackSpeed,
  voiceEffect: voiceEffect,
  noiseReduction: noiseReduction,
  anchorClipId: anchorClipId,
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

    void stubGenerator(
      List<CaptionSegment> words, {
      bool requireOnDeviceRecognition = false,
    }) {
      when(
        () => generator.generateCaptions(
          audioPath: any(named: 'audioPath'),
          localeIdentifier: any(named: 'localeIdentifier'),
          requireOnDeviceRecognition: requireOnDeviceRecognition,
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
          // a is at 0s and c is at 6s. A word lying mostly in a, with its tail
          // across the a/c merge boundary, must stay inside a's span, not
          // spill its tail into the muted gap.
          stubMerge([_offset(0, 3000), _offset(3000, 3000)]);
          final service = buildService(
            remote: remoteReturning([_word('boundary', 2800, 3100)]),
          );

          final outcome = await service.generateForClips(
            clips: [_clip('a'), _clip('muted', volume: 0), _clip('c')],
            localeIdentifier: 'en-US',
          );

          final cue = (outcome as CaptionsGenerated).cues.single;
          expect(cue.text, equals('boundary'));
          expect(cue.start, equals(const Duration(milliseconds: 2800)));
          // Clamped to clip a's timeline end (3s); never into the gap [3s,6s).
          expect(cue.end, equals(const Duration(seconds: 3)));
        },
      );

      test(
        'gives a cue starting just before a boundary to the source it lies in',
        () async {
          // The server times this cue 50ms early: it starts at the end of a
          // but lies almost entirely in c, which plays after the muted gap.
          stubMerge([_offset(0, 3000), _offset(3000, 3000)]);
          final service = buildService(
            remote: remoteReturning([_word('Late.', 2950, 3700)]),
          );

          final outcome = await service.generateForClips(
            clips: [_clip('a'), _clip('muted', volume: 0), _clip('c')],
            localeIdentifier: 'en-US',
          );

          final cue = (outcome as CaptionsGenerated).cues.single;
          expect(cue.start, equals(const Duration(seconds: 6)));
          expect(cue.end, equals(const Duration(milliseconds: 6700)));
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

      test('transcribes a speed ramp as recorded and moves its words through '
          'the ramp', () async {
        // 3 s of footage: the first 1.5 s at 2× (0.75 s), the rest at 0.5×.
        const ramp = VideoSpeedRamp([
          VideoSpeedRampPoint(position: 0, speed: 2),
          VideoSpeedRampPoint(position: 0.5, speed: 2),
          VideoSpeedRampPoint(position: 0.5000001, speed: 0.5),
          VideoSpeedRampPoint(position: 1, speed: 0.5),
        ]);
        stubExtraction();
        // Spoken 2 s into the footage: 0.5 s into the slow half.
        stubGenerator([_word('Slow.', 2000, 2500)]);

        final outcome = await buildService().generateForClips(
          clips: [_clip('a').copyWith(speedRamp: ramp)],
          localeIdentifier: 'en-US',
        );

        verify(
          () => extraction.extractAudio(videoPath: '/tmp/a.mp4', speed: 1),
        ).called(1);
        final cue = (outcome as CaptionsGenerated).cues.single;
        // 0.75 s for the fast half, then 1 s for the first 0.5 s of slow.
        expect((cue.start.inMilliseconds - 1750).abs(), lessThanOrEqualTo(2));
        expect((cue.end.inMilliseconds - 2750).abs(), lessThanOrEqualTo(2));
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

    group('speech tracks', () {
      List<AudioMergeSegment> capturedSegments() =>
          verify(
                () => extraction.mergeClipAudio(
                  segments: captureAny(named: 'segments'),
                  sampleRate: any(named: 'sampleRate'),
                  channels: any(named: 'channels'),
                ),
              ).captured.single
              as List<AudioMergeSegment>;

      test('keeps anchored speech outside its audible clip window', () async {
        stubMerge([
          _offset(0, 1000),
          _offset(1000, 2000),
          _offset(3000, 1000),
        ]);
        final service = buildService(
          remote: remoteReturning([
            _word('Before.', 200, 600),
            _word('Clip.', 1200, 1600),
            _word('After.', 3200, 3600),
          ]),
        );

        final outcome = await service.generateForClips(
          clips: [
            _clip('lead', duration: const Duration(seconds: 2), volume: 0),
            _clip(
              'source',
              duration: const Duration(seconds: 4),
              trimStart: const Duration(seconds: 1),
              trimEnd: const Duration(seconds: 1),
            ),
            _clip('tail', duration: const Duration(seconds: 2), volume: 0),
          ],
          audioTracks: [
            _track(
              _extractedId,
              url: '/tmp/extracted.wav',
              startTime: const Duration(seconds: 1),
              endTime: const Duration(seconds: 5),
              anchorClipId: 'source',
            ),
          ],
          localeIdentifier: 'en-US',
        );

        final cues = (outcome as CaptionsGenerated).cues;
        expect(
          cues.map((cue) => (cue.text, cue.start, cue.end)),
          equals([
            (
              'Before.',
              const Duration(milliseconds: 1200),
              const Duration(milliseconds: 1600),
            ),
            (
              'Clip.',
              const Duration(milliseconds: 2200),
              const Duration(milliseconds: 2600),
            ),
            (
              'After.',
              const Duration(milliseconds: 4200),
              const Duration(milliseconds: 4600),
            ),
          ]),
        );
        final segments = capturedSegments();
        expect(segments, hasLength(3));
        expect(segments.first.startTime, Duration.zero);
        expect(segments.first.endTime, const Duration(seconds: 1));
        expect(segments.last.startTime, const Duration(seconds: 3));
        expect(segments.last.endTime, const Duration(seconds: 4));
      });

      test('merges a voice-over take as recorded, where it plays', () async {
        stubMerge([_offset(0, 6000), _offset(6000, 2000)]);
        final service = buildService(
          remote: remoteReturning([_word('Narrated.', 6500, 7000)]),
        );

        final outcome = await service.generateForClips(
          clips: [_clip('a', duration: const Duration(seconds: 6))],
          audioTracks: [
            _track(
              _takeId,
              url: '/tmp/take_clean.m4a',
              originalUrl: '/tmp/take.m4a',
              noiseReduction: true,
              startTime: const Duration(seconds: 2),
              endTime: const Duration(seconds: 4),
              startOffset: const Duration(seconds: 1),
              playbackSpeed: 2,
            ),
          ],
          localeIdentifier: 'en-US',
        );

        final take = capturedSegments().last;
        expect(take.video.file?.path, equals('/tmp/take.m4a'));
        expect(take.startTime, equals(const Duration(seconds: 1)));
        // 2 s of timeline at 2× plays 4 s of the take.
        expect(take.endTime, equals(const Duration(seconds: 5)));
        expect(take.speed, equals(2));
        final cue = (outcome as CaptionsGenerated).cues.single;
        expect(cue.start, equals(const Duration(milliseconds: 2500)));
        expect(cue.end, equals(const Duration(seconds: 3)));
      });

      test('on-device keeps only the unique anchored speech windows', () async {
        stubExtraction();
        stubGenerator(const []);
        when(
          () => generator.generateCaptions(
            audioPath: '/tmp/extracted.wav.wav',
            localeIdentifier: any(named: 'localeIdentifier'),
          ),
        ).thenAnswer(
          (_) async => [
            _word('Before.', 200, 600),
            _word('Repeated.', 1200, 1600),
            _word('After.', 3200, 3600),
          ],
        );

        final outcome = await buildService().generateForClips(
          clips: [
            _clip('lead', duration: const Duration(seconds: 2), volume: 0),
            _clip(
              'source',
              duration: const Duration(seconds: 4),
              trimStart: const Duration(seconds: 1),
              trimEnd: const Duration(seconds: 1),
            ),
            _clip('tail', duration: const Duration(seconds: 2), volume: 0),
          ],
          audioTracks: [
            _track(
              _extractedId,
              url: '/tmp/extracted.wav',
              startTime: const Duration(seconds: 1),
              endTime: const Duration(seconds: 5),
              anchorClipId: 'source',
            ),
          ],
          localeIdentifier: 'en-US',
        );

        expect(
          (outcome as CaptionsGenerated).cues.map(
            (cue) => (cue.text, cue.start),
          ),
          equals([
            ('Before.', const Duration(milliseconds: 1200)),
            ('After.', const Duration(milliseconds: 4200)),
          ]),
        );
      });

      test(
        'transcribes extracted sound in place of its muted clip',
        () async {
          stubMerge([_offset(0, 3000)]);
          final service = buildService(
            remote: remoteReturning([_word('Hi.', 100, 600)]),
          );

          final outcome = await service.generateForClips(
            clips: [_clip('a', volume: 0)],
            audioTracks: [
              _track(
                _extractedId,
                url: '/tmp/extracted.wav',
                startTime: Duration.zero,
                endTime: const Duration(seconds: 3),
                anchorClipId: 'a',
              ),
            ],
            localeIdentifier: 'en-US',
          );

          expect(
            capturedSegments().single.video.file?.path,
            equals('/tmp/extracted.wav'),
          );
          final cue = (outcome as CaptionsGenerated).cues.single;
          expect(cue.start, equals(const Duration(milliseconds: 100)));
        },
      );

      test('leaves out music and muted takes', () async {
        stubMerge([_offset(0, 3000)]);
        final service = buildService(remote: remoteReturning(const []));

        await service.generateForClips(
          clips: [_clip('a')],
          audioTracks: [
            _track(
              '${AudioEvent.localImportMarker}_song',
              url: '/tmp/song.mp3',
              startTime: Duration.zero,
              endTime: const Duration(seconds: 3),
            ),
            _track(
              _takeId,
              url: '/tmp/take.m4a',
              startTime: Duration.zero,
              endTime: const Duration(seconds: 3),
              volume: 0,
            ),
          ],
          localeIdentifier: 'en-US',
        );

        expect(
          capturedSegments().single.video.file?.path,
          equals('/tmp/a.mp4'),
        );
      });

      test('stops a take where the video ends', () async {
        stubMerge([_offset(0, 3000), _offset(3000, 1000)]);
        final service = buildService(remote: remoteReturning(const []));

        await service.generateForClips(
          clips: [_clip('a')],
          audioTracks: [
            _track(
              _takeId,
              url: '/tmp/take.m4a',
              startTime: const Duration(seconds: 2),
              endTime: const Duration(seconds: 5),
            ),
          ],
          localeIdentifier: 'en-US',
        );

        expect(
          capturedSegments().last.endTime,
          equals(const Duration(seconds: 1)),
        );
      });

      test('lets one cue run across takes laid back to back', () async {
        stubMerge([_offset(0, 1500), _offset(1500, 2000)]);
        final service = buildService(
          remote: remoteReturning([_word('Eins. Zwei.', 200, 3000)]),
        );

        final outcome = await service.generateForClips(
          clips: [_clip('a', volume: 0, duration: const Duration(seconds: 6))],
          audioTracks: [
            _track(
              '${_takeId}_a',
              url: '/tmp/take1.m4a',
              startTime: Duration.zero,
              endTime: const Duration(milliseconds: 1500),
            ),
            _track(
              '${_takeId}_b',
              url: '/tmp/take2.m4a',
              startTime: const Duration(milliseconds: 1500),
              endTime: const Duration(milliseconds: 3500),
            ),
          ],
          localeIdentifier: 'en-US',
        );

        final cue = (outcome as CaptionsGenerated).cues.single;
        expect(cue.start, equals(const Duration(milliseconds: 200)));
        expect(cue.end, equals(const Duration(seconds: 3)));
      });

      test(
        'never ends a cue before it starts across overlapping takes',
        () async {
          // Within the back-to-back tolerance, the second take starts 50 ms
          // before the first ends, so mapping each end through its own take
          // would put the end before the start.
          stubMerge([_offset(0, 2000), _offset(2000, 2050)]);
          final service = buildService(
            remote: remoteReturning([_word('Hm.', 1990, 2030)]),
          );

          final outcome = await service.generateForClips(
            clips: [
              _clip('a', volume: 0, duration: const Duration(seconds: 6)),
            ],
            audioTracks: [
              _track(
                '${_takeId}_a',
                url: '/tmp/take1.m4a',
                startTime: Duration.zero,
                endTime: const Duration(milliseconds: 2000),
              ),
              _track(
                '${_takeId}_b',
                url: '/tmp/take2.m4a',
                startTime: const Duration(milliseconds: 1950),
                endTime: const Duration(milliseconds: 4000),
              ),
            ],
            localeIdentifier: 'en-US',
          );

          final cue = (outcome as CaptionsGenerated).cues.single;
          expect(cue.end, greaterThanOrEqualTo(cue.start));
          // It belongs to the second take, which it overlaps most.
          expect(cue.start, equals(const Duration(milliseconds: 1950)));
          expect(cue.end, equals(const Duration(milliseconds: 1980)));
        },
      );

      test(
        'leaves out extracted sound anchored to a clip that plays its own',
        () async {
          stubMerge([_offset(0, 3000), _offset(3000, 2000)]);
          final service = buildService(remote: remoteReturning(const []));

          await service.generateForClips(
            clips: [_clip('a')],
            audioTracks: [
              _track(
                '${_extractedId}_anchored',
                url: '/tmp/anchored.wav',
                startTime: Duration.zero,
                endTime: const Duration(seconds: 3),
                anchorClipId: 'a',
              ),
              // Moved away from its clip, it plays the speech a second time.
              _track(
                '${_extractedId}_moved',
                url: '/tmp/moved.wav',
                startTime: const Duration(seconds: 1),
                endTime: const Duration(seconds: 3),
              ),
            ],
            localeIdentifier: 'en-US',
          );

          expect(
            capturedSegments().map((segment) => segment.video.file?.path),
            equals(['/tmp/a.mp4', '/tmp/moved.wav']),
          );
        },
      );

      group('with a voice effect', () {
        AudioEvent robotTake() => _track(
          _takeId,
          url: '/tmp/take_robot.m4a',
          originalUrl: '/tmp/take.m4a',
          voiceEffect: const VoiceEffect(robot: 100),
          startTime: const Duration(seconds: 2),
          endTime: const Duration(seconds: 4),
        );

        test(
          'keeps strict local recognition when retrying the locale',
          () async {
            stubMerge([_offset(0, 6000)]);
            stubExtraction();
            when(
              () => generator.generateCaptions(
                audioPath: any(named: 'audioPath'),
                localeIdentifier: any(named: 'localeIdentifier'),
                requireOnDeviceRecognition: true,
              ),
            ).thenThrow(
              const SpeechRecognizerUnavailableException('Unavailable locally'),
            );
            final service = buildService(
              remote: remoteReturning([_word('Clip talk.', 4500, 5000)]),
            );

            final outcome = await service.generateForClips(
              clips: [_clip('a', duration: const Duration(seconds: 6))],
              audioTracks: [robotTake()],
              localeIdentifier: 'en-US',
            );

            expect(
              (outcome as CaptionsGenerated).cues.single.text,
              equals('Clip talk.'),
            );
            final locales = verify(
              () => generator.generateCaptions(
                audioPath: any(named: 'audioPath'),
                localeIdentifier: captureAny(named: 'localeIdentifier'),
                requireOnDeviceRecognition: true,
              ),
            ).captured;
            expect(locales, equals(['en-US', null]));
          },
        );

        test('recognizes the take on the device, next to the server', () async {
          stubMerge([_offset(0, 6000)]);
          stubExtraction();
          stubGenerator(
            [_word('Narrated.', 500, 1000)],
            requireOnDeviceRecognition: true,
          );
          final service = buildService(
            remote: remoteReturning([_word('Clip talk.', 4500, 5000)]),
          );

          final outcome = await service.generateForClips(
            clips: [_clip('a', duration: const Duration(seconds: 6))],
            audioTracks: [robotTake()],
            localeIdentifier: 'en-US',
          );

          expect(
            capturedSegments().single.video.file?.path,
            equals('/tmp/a.mp4'),
          );
          verify(
            () => extraction.extractAudio(videoPath: '/tmp/take.m4a', speed: 1),
          ).called(1);
          final cues = (outcome as CaptionsGenerated).cues;
          expect(
            cues.map((cue) => (cue.text, cue.start)),
            equals([
              ('Narrated.', const Duration(milliseconds: 2500)),
              ('Clip talk.', const Duration(milliseconds: 4500)),
            ]),
          );
        });

        test('one failed take does not discard another take', () async {
          stubMerge([_offset(0, 6000)]);
          stubExtraction();
          stubGenerator(
            [_word('Kept.', 100, 400)],
            requireOnDeviceRecognition: true,
          );
          when(
            () => generator.generateCaptions(
              audioPath: '/tmp/take.m4a.wav',
              localeIdentifier: any(named: 'localeIdentifier'),
              requireOnDeviceRecognition: true,
            ),
          ).thenThrow(const SpeechNotAuthorizedException());
          final service = buildService(
            remote: remoteReturning([_word('Clip.', 4500, 5000)]),
          );

          final outcome = await service.generateForClips(
            clips: [_clip('a', duration: const Duration(seconds: 6))],
            audioTracks: [
              robotTake(),
              robotTake().copyWith(
                id: '${_takeId}_second',
                url: '/tmp/second_robot.m4a',
                originalUrl: '/tmp/second.m4a',
                startTime: const Duration(seconds: 4),
                endTime: const Duration(seconds: 6),
              ),
            ],
            localeIdentifier: 'en-US',
          );

          expect(
            (outcome as CaptionsGenerated).cues.map((cue) => cue.text),
            equals(['Kept.', 'Clip.']),
          );
        });

        test(
          'sends nothing to the server when the take is all there is',
          () async {
            stubExtraction();
            stubGenerator(
              [_word('Narrated.', 500, 1000)],
              requireOnDeviceRecognition: true,
            );
            final remote = remoteReturning(const []);

            final outcome = await buildService(remote: remote).generateForClips(
              clips: [
                _clip('a', volume: 0, duration: const Duration(seconds: 6)),
              ],
              audioTracks: [robotTake()],
              localeIdentifier: 'en-US',
            );

            verifyNever(
              () => remote.transcribe(
                audioPath: any(named: 'audioPath'),
                localeIdentifier: any(named: 'localeIdentifier'),
              ),
            );
            expect(
              (outcome as CaptionsGenerated).cues.single.text,
              equals('Narrated.'),
            );
          },
        );

        test(
          'keeps the server captions when the device cannot recognize the take',
          () async {
            stubMerge([_offset(0, 6000)]);
            stubExtraction();
            when(
              () => generator.generateCaptions(
                audioPath: any(named: 'audioPath'),
                localeIdentifier: any(named: 'localeIdentifier'),
                requireOnDeviceRecognition: true,
              ),
            ).thenThrow(const SpeechNotAuthorizedException());
            final service = buildService(
              remote: remoteReturning([_word('Clip talk.', 4500, 5000)]),
            );

            final outcome = await service.generateForClips(
              clips: [_clip('a', duration: const Duration(seconds: 6))],
              audioTracks: [robotTake()],
              localeIdentifier: 'en-US',
            );

            expect(
              (outcome as CaptionsGenerated).cues.single.text,
              equals('Clip talk.'),
            );
          },
        );
      });

      test('keeps a voice-over over clip speech in its own cues', () async {
        stubMerge([_offset(0, 6000), _offset(6000, 2000)]);
        final service = buildService(
          remote: remoteReturning([
            _word('Clip', 1000, 1300),
            _word('talk.', 1350, 1600),
            _word('Voice', 6000, 6300),
            _word('over.', 6350, 6600),
          ]),
        );

        final outcome = await service.generateForClips(
          clips: [_clip('a', duration: const Duration(seconds: 6))],
          audioTracks: [
            _track(
              _takeId,
              url: '/tmp/take.m4a',
              startTime: const Duration(seconds: 1),
              endTime: const Duration(seconds: 3),
            ),
          ],
          localeIdentifier: 'en-US',
        );

        final cues = (outcome as CaptionsGenerated).cues;
        expect(
          cues.map((cue) => cue.text),
          unorderedEquals(['Clip talk.', 'Voice over.']),
        );
      });

      test(
        'on-device, windows the take and shifts it to where it plays',
        () async {
          stubExtraction();
          when(
            () => generator.generateCaptions(
              audioPath: '/tmp/take.m4a.wav',
              localeIdentifier: any(named: 'localeIdentifier'),
            ),
          ).thenAnswer(
            (_) async => [_word('Cut', 0, 800), _word('Kept.', 1200, 1800)],
          );

          final outcome = await buildService().generateForClips(
            clips: [
              _clip('a', volume: 0, duration: const Duration(seconds: 6)),
            ],
            audioTracks: [
              _track(
                _takeId,
                url: '/tmp/take_robot.m4a',
                originalUrl: '/tmp/take.m4a',
                startTime: const Duration(seconds: 2),
                endTime: const Duration(seconds: 4),
                startOffset: const Duration(seconds: 1),
              ),
            ],
            localeIdentifier: 'en-US',
          );

          verify(
            () => extraction.extractAudio(videoPath: '/tmp/take.m4a', speed: 1),
          ).called(1);
          final cue = (outcome as CaptionsGenerated).cues.single;
          expect(cue.text, equals('Kept.'));
          expect(cue.start, equals(const Duration(milliseconds: 2200)));
          expect(cue.end, equals(const Duration(milliseconds: 2800)));
        },
      );
    });

    test('leaves server cues without word timings', () async {
      stubMerge([_offset(0, 3000)]);
      final service = buildService(
        remote: remoteReturning([_word('Hi there.', 0, 900)]),
      );

      final outcome = await service.generateForClips(
        clips: [_clip('a')],
        localeIdentifier: 'en-US',
      );

      // The server only times whole cues, so the words are spread over the
      // cue's window whenever they are read, including after a trim.
      final cue = (outcome as CaptionsGenerated).cues.single;
      expect(cue.words, isEmpty);
      expect(cue.wordTimings, [_word('Hi', 0, 225), _word('there.', 225, 900)]);
      expect(
        cue.withTiming(end: const Duration(milliseconds: 450)).wordTimings,
        [_word('Hi', 0, 113), _word('there.', 113, 450)],
      );
    });
  });
}
