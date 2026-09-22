import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/extensions/video_editor_history_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

class _MockStateManager extends Mock implements StateManager {}

DivineVideoClip _clip(
  String id, {
  Duration duration = const Duration(seconds: 3),
}) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/tmp/$id.mp4'),
  duration: duration,
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
);

void main() {
  late _MockProImageEditorState editor;
  late _MockStateManager stateManager;

  setUp(() {
    editor = _MockProImageEditorState();
    stateManager = _MockStateManager();

    when(() => editor.stateManager).thenReturn(stateManager);
    // No burned-in caption layers by default; setCaptionCueTimeline looks
    // here to keep a matching layer's timing in sync.
    when(() => editor.activeLayers).thenReturn(<Layer>[]);
    when(
      () => editor.addHistory(
        layers: any(named: 'layers'),
        filters: any(named: 'filters'),
        meta: any(named: 'meta'),
        newLayer: any(named: 'newLayer'),
        transformConfigs: any(named: 'transformConfigs'),
        tuneAdjustments: any(named: 'tuneAdjustments'),
        blur: any(named: 'blur'),
        heroScreenshotRequired: any(named: 'heroScreenshotRequired'),
        blockCaptureScreenshot: any(named: 'blockCaptureScreenshot'),
      ),
    ).thenAnswer((_) {});
    when(() => editor.setState(any())).thenAnswer((invocation) {
      final callback = invocation.positionalArguments.single as VoidCallback;
      callback();
    });
  });

  group('VideoEditorExtensions', () {
    test('setClipState carries current timeline markers by default', () {
      when(() => stateManager.activeMeta).thenReturn({
        VideoEditorConstants.timelineMarkersStateHistoryKey: [1200, 2400],
      });

      editor.setClipState([_clip('clip-1')]);

      final meta =
          verify(
                () => editor.addHistory(meta: captureAny(named: 'meta')),
              ).captured.single
              as Map<String, dynamic>;

      expect(
        meta[VideoEditorConstants.timelineMarkersStateHistoryKey],
        equals([1200, 2400]),
      );
      expect(
        meta[VideoEditorConstants.clipsStateHistoryKey],
        isA<List<dynamic>>().having((clips) => clips.length, 'length', 1),
      );
    });

    test('setClipAndAudioState carries current markers atomically', () {
      final audio = AudioEvent(id: 'audio-1', pubkey: 'pub', createdAt: 1);
      when(() => stateManager.activeMeta).thenReturn({
        VideoEditorConstants.timelineMarkersStateHistoryKey: [1500],
      });

      editor.setClipAndAudioState(
        clips: [_clip('clip-1')],
        audioTracks: [audio],
      );

      final meta =
          verify(
                () => editor.addHistory(meta: captureAny(named: 'meta')),
              ).captured.single
              as Map<String, dynamic>;

      expect(
        meta[VideoEditorConstants.timelineMarkersStateHistoryKey],
        equals([1500]),
      );
      expect(
        meta[VideoEditorConstants.audioStateHistoryKey],
        equals([audio.toJson()]),
      );
      expect(
        meta[VideoEditorConstants.clipsStateHistoryKey],
        isA<List<dynamic>>().having((clips) => clips.length, 'length', 1),
      );
    });

    group('setLengthenedClipState', () {
      // #6401 on the content-added path: a sound clamped to a 3s composition
      // when it was added, then the user shoots more stills from the editor's
      // camera (or merges a set in from the clips picker) and the composition
      // becomes 6s. Without the grow, publish muxes a 6s video with 3s audio.
      final covering = AudioEvent(
        id: 'sound-1',
        pubkey: 'bundled',
        createdAt: 0,
        url: 'asset://sounds/loop.mp3',
        duration: 30,
        endTime: const Duration(seconds: 3),
      );

      List<AudioEvent> capturedAudio() {
        final meta =
            verify(
                  () => editor.addHistory(meta: captureAny(named: 'meta')),
                ).captured.single
                as Map<String, dynamic>;
        final raw =
            meta[VideoEditorConstants.audioStateHistoryKey] as List<dynamic>;
        return raw
            .cast<Map<String, dynamic>>()
            .map(AudioEvent.fromJson)
            .toList();
      }

      test('grows a sound that covered the old end onto the added clip', () {
        when(() => stateManager.activeMeta).thenReturn({
          VideoEditorConstants.audioStateHistoryKey: [covering.toJson()],
        });

        editor.setLengthenedClipState(
          previousClips: [_clip('clip-1')],
          clips: [_clip('clip-1'), _clip('clip-2')],
        );

        expect(capturedAudio().single.endTime, const Duration(seconds: 6));
      });

      test('leaves a sound the user trimmed short of the old end', () {
        final trimmed = AudioEvent(
          id: 'sound-1',
          pubkey: 'bundled',
          createdAt: 0,
          url: 'asset://sounds/loop.mp3',
          duration: 30,
          endTime: const Duration(seconds: 1),
        );
        when(() => stateManager.activeMeta).thenReturn({
          VideoEditorConstants.audioStateHistoryKey: [trimmed.toJson()],
        });

        editor.setLengthenedClipState(
          previousClips: [_clip('clip-1')],
          clips: [_clip('clip-1'), _clip('clip-2')],
        );

        expect(capturedAudio().single.endTime, const Duration(seconds: 1));
      });

      test('writes no audio key when the composition has no sound', () {
        when(() => stateManager.activeMeta).thenReturn({});

        editor.setLengthenedClipState(
          previousClips: [_clip('clip-1')],
          clips: [_clip('clip-1'), _clip('clip-2')],
        );

        final meta =
            verify(
                  () => editor.addHistory(meta: captureAny(named: 'meta')),
                ).captured.single
                as Map<String, dynamic>;
        expect(
          meta.containsKey(VideoEditorConstants.audioStateHistoryKey),
          isFalse,
        );
      });

      test(
        'appends the sounds that arrived with the edit after the grown ones',
        () {
          // A clip sampled into stills brings its own audio; it lands in the
          // same entry as the stills, ungrown, so one undo removes both.
          final arrived = AudioEvent(
            id: 'local_extracted_1',
            pubkey: '',
            createdAt: 0,
            url: '/documents/audio/sampled.m4a',
            duration: 3,
            startTime: const Duration(seconds: 3),
            endTime: const Duration(seconds: 5),
          );
          when(() => stateManager.activeMeta).thenReturn({
            VideoEditorConstants.audioStateHistoryKey: [covering.toJson()],
          });

          editor.setLengthenedClipState(
            previousClips: [_clip('clip-1')],
            clips: [_clip('clip-1'), _clip('clip-2')],
            addedAudioTracks: [arrived],
          );

          final audio = capturedAudio();
          expect(audio.map((a) => a.id), ['sound-1', 'local_extracted_1']);
          expect(audio.first.endTime, const Duration(seconds: 6));
          expect(audio.last.startTime, const Duration(seconds: 3));
          expect(audio.last.endTime, const Duration(seconds: 5));
        },
      );

      test(
        'writes the audio key for an arriving sound over a silent timeline',
        () {
          final arrived = AudioEvent(
            id: 'local_extracted_1',
            pubkey: '',
            createdAt: 0,
            url: '/documents/audio/sampled.m4a',
            duration: 3,
            startTime: const Duration(seconds: 3),
            endTime: const Duration(seconds: 5),
          );
          when(() => stateManager.activeMeta).thenReturn({});

          editor.setLengthenedClipState(
            previousClips: [_clip('clip-1')],
            clips: [_clip('clip-1'), _clip('clip-2')],
            addedAudioTracks: [arrived],
          );

          expect(capturedAudio().single.id, 'local_extracted_1');
        },
      );
    });

    test('setClipState updates current markers when skipping history', () {
      final activeMeta = <String, dynamic>{
        VideoEditorConstants.timelineMarkersStateHistoryKey: [900],
      };
      when(() => stateManager.activeMeta).thenReturn(activeMeta);

      editor.setClipState([_clip('clip-1')], skipUpdateHistory: true);

      expect(
        activeMeta[VideoEditorConstants.timelineMarkersStateHistoryKey],
        equals([900]),
      );
      expect(
        activeMeta[VideoEditorConstants.clipsStateHistoryKey],
        isA<List<dynamic>>().having((clips) => clips.length, 'length', 1),
      );
      verifyNever(() => editor.addHistory(meta: any(named: 'meta')));
    });
  });

  group('buildAppendedAudioMeta', () {
    final existing = AudioEvent(id: 'existing', pubkey: 'p', createdAt: 1);
    final incoming = AudioEvent(id: 'incoming', pubkey: 'p', createdAt: 2);

    test('appends new tracks after existing ones and carries other meta', () {
      final meta = buildAppendedAudioMeta(
        activeMeta: {
          VideoEditorConstants.timelineMarkersStateHistoryKey: [1200],
        },
        existingTracks: [existing],
        newTracks: [incoming],
      );

      expect(
        meta[VideoEditorConstants.timelineMarkersStateHistoryKey],
        equals([1200]),
      );
      expect(
        meta[VideoEditorConstants.audioStateHistoryKey],
        equals([existing.toJson(), incoming.toJson()]),
      );
    });

    test('overwrites any prior audio key in activeMeta', () {
      final meta = buildAppendedAudioMeta(
        activeMeta: {
          VideoEditorConstants.audioStateHistoryKey: ['stale'],
        },
        existingTracks: [existing],
        newTracks: [incoming],
      );

      expect(
        meta[VideoEditorConstants.audioStateHistoryKey],
        equals([existing.toJson(), incoming.toJson()]),
      );
    });

    test('keeps the existing tracks when no new tracks are appended', () {
      final meta = buildAppendedAudioMeta(
        activeMeta: const {},
        existingTracks: [existing],
        newTracks: const [],
      );

      expect(
        meta[VideoEditorConstants.audioStateHistoryKey],
        equals([existing.toJson()]),
      );
    });
  });

  group('captions', () {
    const cue = CaptionCue(
      id: 'cue-1',
      text: 'Hello.',
      start: Duration(milliseconds: 500),
      end: Duration(milliseconds: 2000),
    );
    const track = CaptionTrack(
      presetId: 'classic',
      languageTag: 'en-US',
      cues: [cue],
    );

    Map<String, dynamic> capturedHistoryMeta() =>
        verify(
              () => editor.addHistory(meta: captureAny(named: 'meta')),
            ).captured.single
            as Map<String, dynamic>;

    test('setCaptionState writes the track as one history entry', () {
      when(() => stateManager.activeMeta).thenReturn({'other': 1});

      editor.setCaptionState(track);

      final meta = capturedHistoryMeta();
      expect(
        meta[VideoEditorConstants.captionsStateHistoryKey],
        equals(track.toJson()),
      );
      expect(meta['other'], equals(1));
    });

    test('setCaptionState with null removes the track', () {
      when(() => stateManager.activeMeta).thenReturn({
        VideoEditorConstants.captionsStateHistoryKey: track.toJson(),
      });

      editor.setCaptionState(null);

      final meta = capturedHistoryMeta();
      expect(
        meta.containsKey(VideoEditorConstants.captionsStateHistoryKey),
        isFalse,
      );
    });

    test('captionTrack getter restores the track and null on malformed', () {
      when(() => stateManager.activeMeta).thenReturn({
        VideoEditorConstants.captionsStateHistoryKey: track.toJson(),
      });
      expect(stateManager.captionTrack, equals(track));

      when(() => stateManager.activeMeta).thenReturn({
        VideoEditorConstants.captionsStateHistoryKey: {'presetId': 42},
      });
      expect(stateManager.captionTrack, isNull);

      when(() => stateManager.activeMeta).thenReturn({});
      expect(stateManager.captionTrack, isNull);

      // A nested non-map cue throws a TypeError inside fromJson; the getter
      // must normalize any parse failure (not only FormatException) to null.
      when(() => stateManager.activeMeta).thenReturn({
        VideoEditorConstants.captionsStateHistoryKey: {
          'presetId': 'classic',
          'languageTag': 'en-US',
          'cues': ['not-a-map'],
        },
      });
      expect(stateManager.captionTrack, isNull);
    });

    test('removeCaptionCue drops an overlay cue in one history entry', () {
      when(() => stateManager.activeMeta).thenReturn({
        VideoEditorConstants.captionsStateHistoryKey: track.toJson(),
      });

      editor.removeCaptionCue('cue-1');

      final captured = verify(
        () => editor.addHistory(
          layers: captureAny(named: 'layers'),
          meta: captureAny(named: 'meta'),
        ),
      ).captured;
      expect(captured.first as List<Layer>, isEmpty);
      final meta = captured.last as Map<String, dynamic>;
      final updated = CaptionTrack.fromJson(
        meta[VideoEditorConstants.captionsStateHistoryKey]
            as Map<Object?, Object?>,
      );
      expect(updated.cues, isEmpty);
    });

    test('removeCaptionCue drops a burn-in cue and its layer together', () {
      final captionLayer = TextLayer(
        text: 'Hello.',
        meta: {
          VideoEditorConstants.captionCueMetaKey: true,
          VideoEditorConstants.captionCueIdMetaKey: 'cue-1',
        },
      );
      final otherLayer = TextLayer(text: 'keep');
      when(() => editor.activeLayers).thenReturn([captionLayer, otherLayer]);
      when(() => stateManager.activeMeta).thenReturn({
        VideoEditorConstants.captionsStateHistoryKey: track.toJson(),
      });

      editor.removeCaptionCue('cue-1');

      final captured = verify(
        () => editor.addHistory(
          layers: captureAny(named: 'layers'),
          meta: captureAny(named: 'meta'),
        ),
      ).captured;
      // The caption layer is dropped; the unrelated layer is kept.
      expect(captured.first, equals([otherLayer]));
      final meta = captured.last as Map<String, dynamic>;
      final updated = CaptionTrack.fromJson(
        meta[VideoEditorConstants.captionsStateHistoryKey]
            as Map<Object?, Object?>,
      );
      expect(updated.cues, isEmpty);
    });

    test('removeCaptionCue is a no-op when nothing matches', () {
      when(() => stateManager.activeMeta).thenReturn({
        VideoEditorConstants.captionsStateHistoryKey: track.toJson(),
      });

      editor.removeCaptionCue('missing');

      verifyNever(
        () => editor.addHistory(
          layers: any(named: 'layers'),
          meta: any(named: 'meta'),
        ),
      );
    });

    test('setCaptionCueTimeline retimes the cue as a history entry', () {
      when(() => stateManager.activeMeta).thenReturn({
        VideoEditorConstants.captionsStateHistoryKey: track.toJson(),
      });

      editor.setCaptionCueTimeline(
        cueId: 'cue-1',
        startTime: const Duration(milliseconds: 800),
      );

      final meta = capturedHistoryMeta();
      final updated = CaptionTrack.fromJson(
        meta[VideoEditorConstants.captionsStateHistoryKey]
            as Map<Object?, Object?>,
      );
      expect(
        updated.cues.single.start,
        equals(const Duration(milliseconds: 800)),
      );
      expect(
        updated.cues.single.end,
        equals(const Duration(milliseconds: 2000)),
      );
    });

    test(
      'setCaptionCueTimeline retimes a burn-in cue layer and meta atomically '
      'without mutating the current history entry',
      () {
        final captionLayer = TextLayer(
          text: 'Hello.',
          meta: {
            VideoEditorConstants.captionCueMetaKey: true,
            VideoEditorConstants.captionCueIdMetaKey: 'cue-1',
          },
          startTime: const Duration(milliseconds: 500),
          endTime: const Duration(milliseconds: 2000),
        );
        final otherLayer = TextLayer(text: 'keep');
        when(
          () => editor.activeLayers,
        ).thenReturn([captionLayer, otherLayer]);
        when(() => stateManager.activeMeta).thenReturn({
          VideoEditorConstants.captionsStateHistoryKey: track.toJson(),
        });

        editor.setCaptionCueTimeline(
          cueId: 'cue-1',
          startTime: const Duration(milliseconds: 800),
          endTime: const Duration(milliseconds: 2500),
        );

        final captured = verify(
          () => editor.addHistory(
            layers: captureAny(named: 'layers'),
            meta: captureAny(named: 'meta'),
          ),
        ).captured;

        // The new entry carries a retimed COPY of the burn-in layer plus the
        // updated caption meta in one undo step.
        final layers = captured.first as List<Layer>;
        final retimed = layers.firstWhere(
          (l) => l.meta?[VideoEditorConstants.captionCueIdMetaKey] == 'cue-1',
        );
        expect(retimed, isNot(same(captionLayer)));
        expect(retimed.startTime, equals(const Duration(milliseconds: 800)));
        expect(retimed.endTime, equals(const Duration(milliseconds: 2500)));
        expect(layers, contains(otherLayer));

        final meta = captured.last as Map<String, dynamic>;
        final updated = CaptionTrack.fromJson(
          meta[VideoEditorConstants.captionsStateHistoryKey]
              as Map<Object?, Object?>,
        );
        expect(
          updated.cues.single.start,
          equals(const Duration(milliseconds: 800)),
        );
        expect(
          updated.cues.single.end,
          equals(const Duration(milliseconds: 2500)),
        );

        // The previous entry's layer is left untouched, so undo restores the
        // burned-in text and the CC track at the same (old) timing.
        expect(
          captionLayer.startTime,
          equals(const Duration(milliseconds: 500)),
        );
        expect(
          captionLayer.endTime,
          equals(const Duration(milliseconds: 2000)),
        );
      },
    );

    test('setCaptionCueTimeline mutates meta in-place during drags', () {
      final activeMeta = <String, dynamic>{
        VideoEditorConstants.captionsStateHistoryKey: track.toJson(),
      };
      when(() => stateManager.activeMeta).thenReturn(activeMeta);

      editor.setCaptionCueTimeline(
        cueId: 'cue-1',
        endTime: const Duration(milliseconds: 1500),
        skipUpdateHistory: true,
      );

      verifyNever(() => editor.addHistory(meta: any(named: 'meta')));
      final updated = CaptionTrack.fromJson(
        activeMeta[VideoEditorConstants.captionsStateHistoryKey]
            as Map<Object?, Object?>,
      );
      expect(
        updated.cues.single.end,
        equals(const Duration(milliseconds: 1500)),
      );
    });

    test('setCaptionCueTimeline stores the given range verbatim', () {
      when(() => stateManager.activeMeta).thenReturn({
        VideoEditorConstants.captionsStateHistoryKey: track.toJson(),
      });

      // Minimum-duration and collision policy live in resolveCaptionTrim at
      // the interaction layer; the store write must not second-guess it by
      // moving the fixed opposite edge.
      editor.setCaptionCueTimeline(
        cueId: 'cue-1',
        endTime: const Duration(milliseconds: 510),
      );

      final meta = capturedHistoryMeta();
      final updated = CaptionTrack.fromJson(
        meta[VideoEditorConstants.captionsStateHistoryKey]
            as Map<Object?, Object?>,
      );
      expect(
        updated.cues.single.end,
        equals(const Duration(milliseconds: 510)),
      );
    });

    test('setCaptionCueTimeline ignores unknown cues and missing tracks', () {
      when(() => stateManager.activeMeta).thenReturn({
        VideoEditorConstants.captionsStateHistoryKey: track.toJson(),
      });
      editor.setCaptionCueTimeline(cueId: 'nope', startTime: Duration.zero);

      when(() => stateManager.activeMeta).thenReturn({});
      editor.setCaptionCueTimeline(cueId: 'cue-1', startTime: Duration.zero);

      verifyNever(() => editor.addHistory(meta: any(named: 'meta')));
    });
  });
}
