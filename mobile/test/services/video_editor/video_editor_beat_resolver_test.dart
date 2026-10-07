import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/services/video_editor/video_editor_beat_resolver.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../helpers/audio_samples.dart';

Duration _ms(int milliseconds) => Duration(milliseconds: milliseconds);

AudioEvent _sound(
  String id, {
  Duration startTime = Duration.zero,
  Duration startOffset = Duration.zero,
  Duration? endTime,
  double? duration = 30,
  double volume = 1,
}) => AudioEvent(
  id: id,
  pubkey: 'a' * 64,
  createdAt: 1735689600,
  url: '/tmp/$id.mp3',
  duration: duration,
  startTime: startTime,
  startOffset: startOffset,
  endTime: endTime,
  volume: volume,
);

DivineVideoClip _clip(
  String id, {
  Duration duration = const Duration(seconds: 3),
  Duration trimStart = Duration.zero,
  double volume = 1,
  double? playbackSpeed,
  bool reversed = false,
  ClipTransition? transition,
}) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('${Directory.systemTemp.path}/$id.mp4'),
  duration: duration,
  recordedAt: DateTime(2026),
  targetAspectRatio: model.AspectRatio.vertical,
  originalAspectRatio: 9 / 16,
  trimStart: trimStart,
  volume: volume,
  playbackSpeed: playbackSpeed,
  reversed: reversed,
  transition: transition,
);

/// Extracts a drum loop with a kick every half second from 0.25 s into the
/// file, and records every extraction.
class _DrumLoopFile {
  final reads = <AudioExtractConfigs>[];

  Future<Uint8List> call(AudioExtractConfigs configs) async {
    reads.add(configs);
    return drumLoopWav(configs);
  }
}

void main() {
  group('beatSourceFor', () {
    test('takes the first music, not a voice-over, for the stretch it '
        'plays', () {
      final parts = beatSourceFor(
        sounds: [
          _sound('${AudioEvent.voiceOverIdPrefix}_1'),
          _sound(
            'later',
            startTime: _ms(2000),
            endTime: _ms(3000),
          ),
          _sound(
            'music',
            startTime: _ms(1000),
            startOffset: _ms(4000),
            endTime: _ms(3000),
          ),
        ],
        clips: [_clip('a')],
        videoEnd: _ms(6000),
      );

      expect(parts, hasLength(1));
      expect(parts.single.media, EditorVideo.file(File('/tmp/music.mp3')));
      expect(parts.single.from, _ms(4000));
      expect(parts.single.to, _ms(6000));
      expect(parts.single.at, _ms(1000));
      expect(parts.single.onEditorTimeline, isFalse);
    });

    test('plays a sound without an end to the end of the video, but not past '
        'the end of its file', () {
      final toVideoEnd = beatSourceFor(
        sounds: [_sound('music')],
        clips: const [],
        videoEnd: _ms(6000),
      ).single;
      final toFileEnd = beatSourceFor(
        sounds: [_sound('music', duration: 2.5)],
        clips: const [],
        videoEnd: _ms(6000),
      ).single;

      expect(toVideoEnd.to, _ms(6000));
      expect(toFileEnd.to, _ms(2500));
    });

    test('takes the sound of the clips that are not muted when there is no '
        'music', () {
      final parts = beatSourceFor(
        sounds: [_sound('quiet', volume: 0)],
        clips: [
          _clip('a', trimStart: _ms(500)),
          _clip('muted', volume: 0),
          _clip('fast', playbackSpeed: 2),
        ],
        videoEnd: _ms(6000),
      );

      expect(
        [for (final part in parts) (part.from, part.to, part.at)],
        [
          (_ms(500), _ms(3000), Duration.zero),
          (Duration.zero, _ms(3000), _ms(5500)),
        ],
      );
      expect(parts.last.speed, 2);
      expect(parts.every((part) => !part.onEditorTimeline), isTrue);
    });

    test('is empty when nothing makes a sound', () {
      expect(
        beatSourceFor(
          sounds: [_sound('quiet', volume: 0)],
          clips: [_clip('muted', volume: 0)],
          videoEnd: _ms(3000),
        ),
        isEmpty,
      );
    });
  });

  group(VideoEditorBeatResolver, () {
    late _DrumLoopFile file;
    late VideoEditorBeatResolver resolver;

    setUp(() {
      file = _DrumLoopFile();
      resolver = VideoEditorBeatResolver(extractAudio: file.call);
    });

    /// How far [actual] lies from [expected], at the worst beat.
    Duration worstMiss(List<Duration> actual, List<Duration> expected) {
      expect(actual, hasLength(expected.length));
      var worst = Duration.zero;
      for (var i = 0; i < actual.length; i++) {
        final miss = (actual[i] - expected[i]).abs();
        if (miss > worst) worst = miss;
      }
      return worst;
    }

    test('places the beats of music from where it plays, within its '
        'window', () async {
      final parts = beatSourceFor(
        sounds: [
          _sound(
            'music',
            startTime: _ms(1000),
            startOffset: _ms(4000),
            endTime: _ms(3000),
          ),
        ],
        clips: const [],
        videoEnd: _ms(6000),
      );
      await resolver.read(parts);
      final beats = resolver.beatsOnOutput(
        parts,
        TransitionTimelineMap.fromClips(const []),
        videoEnd: _ms(6000),
      );

      // Kicks at 4.25, 4.75, … s of the file play from 1 s on.
      expect(
        worstMiss(beats, [_ms(1250), _ms(1750), _ms(2250), _ms(2750)]),
        lessThanOrEqualTo(_ms(15)),
      );
    });

    test('places the beats of a clip played twice as fast, after the clip '
        'before it', () async {
      final clips = [
        _clip('muted', volume: 0, duration: _ms(1000)),
        _clip('fast', playbackSpeed: 2, duration: _ms(4000)),
      ];
      final parts = beatSourceFor(
        sounds: const [],
        clips: clips,
        videoEnd: _ms(3000),
      );
      await resolver.read(parts);
      final beats = resolver.beatsOnOutput(
        parts,
        TransitionTimelineMap.fromClips(clips),
        videoEnd: _ms(3000),
      );

      // Kicks every half second of the file land every quarter second after
      // the first clip's second.
      expect(
        worstMiss(beats, [
          for (var kick = 250; kick < 4000; kick += 500) _ms(1000 + kick ~/ 2),
        ]),
        lessThanOrEqualTo(_ms(15)),
      );
    });

    test('uses the playback order of an already reversed clip file', () async {
      final clips = [_clip('reversed', duration: _ms(2800), reversed: true)];
      final parts = beatSourceFor(
        sounds: const [],
        clips: clips,
        videoEnd: _ms(2800),
      );
      await resolver.read(parts);
      final beats = resolver.beatsOnOutput(
        parts,
        TransitionTimelineMap.fromClips(clips),
        videoEnd: _ms(2800),
      );
      expect(
        worstMiss(beats, [for (var t = 250; t < 2800; t += 500) _ms(t)]),
        lessThanOrEqualTo(_ms(15)),
      );
    });

    test(
      'places both sides of an overlap in real audio playback time',
      () async {
        final clips = [
          _clip(
            'a',
            transition: const ClipTransition(
              type: ClipTransitionType.dissolve,
            ),
          ),
          _clip('b'),
        ];
        final parts = beatSourceFor(
          sounds: const [],
          clips: clips,
          videoEnd: _ms(5500),
        );
        await resolver.read(parts);
        final beats = resolver.beatsOnOutput(
          parts,
          TransitionTimelineMap.fromClips(clips),
          videoEnd: _ms(5500),
        );
        expect(
          worstMiss(beats, [
            _ms(250),
            _ms(750),
            _ms(1250),
            _ms(1750),
            _ms(2250),
            _ms(2750),
            _ms(2750),
            _ms(3250),
            _ms(3750),
            _ms(4250),
            _ms(4750),
            _ms(5250),
          ]),
          lessThanOrEqualTo(_ms(15)),
        );
      },
    );

    test(
      'does not move audio for a dip transition at the loop point',
      () async {
        final clips = [
          _clip(
            'a',
            transition: const ClipTransition(
              type: ClipTransitionType.fadeToBlack,
            ),
          ),
        ];
        final parts = beatSourceFor(
          sounds: const [],
          clips: clips,
          videoEnd: _ms(3000),
        );
        await resolver.read(parts);
        final beats = resolver.beatsOnOutput(
          parts,
          TransitionTimelineMap.fromClips(clips),
          videoEnd: _ms(3000),
        );
        expect(
          worstMiss(beats, [for (var t = 250; t < 3000; t += 500) _ms(t)]),
          lessThanOrEqualTo(_ms(15)),
        );
      },
    );

    test('moves the first head to the final loop-restart blend', () async {
      final clips = [
        _clip(
          'a',
          transition: const ClipTransition(
            type: ClipTransitionType.dissolve,
          ),
        ),
      ];
      final parts = beatSourceFor(
        sounds: const [],
        clips: clips,
        videoEnd: _ms(2500),
      );
      await resolver.read(parts);
      final beats = resolver.beatsOnOutput(
        parts,
        TransitionTimelineMap.fromClips(clips),
        videoEnd: _ms(2500),
      );
      expect(
        worstMiss(beats, [
          _ms(250),
          _ms(750),
          _ms(1250),
          _ms(1750),
          _ms(2250),
          _ms(2250),
        ]),
        lessThanOrEqualTo(_ms(15)),
      );
    });

    test('skips a clip it cannot read, and throws when it can read none, so '
        'a later read tries again', () async {
      final clips = [_clip('silent'), _clip('loud')];
      final parts = beatSourceFor(
        sounds: const [],
        clips: clips,
        videoEnd: _ms(6000),
      );
      final halfReadable = VideoEditorBeatResolver(
        extractAudio: (configs) async {
          if (configs.video == clips.first.video) {
            throw PlatformException(code: 'NO_AUDIO');
          }
          return drumLoopWav(configs);
        },
      );
      final unreadable = VideoEditorBeatResolver(
        extractAudio: (_) async => throw PlatformException(code: 'NO_AUDIO'),
      );

      await halfReadable.read(parts);
      final beats = halfReadable.beatsOnOutput(
        parts,
        TransitionTimelineMap.fromClips(clips),
        videoEnd: _ms(6000),
      );

      // Only the second clip's kicks, from 3 s on.
      expect(beats, isNotEmpty);
      expect(beats.every((beat) => beat >= _ms(3000)), isTrue);
      await expectLater(
        unreadable.read(parts),
        throwsA(isA<PlatformException>()),
      );
      expect(unreadable.hasRead(parts), isFalse);
    });

    test('reads each stretch once, from a little around it but never past the '
        'end of the file', () async {
      final parts = beatSourceFor(
        sounds: [
          _sound('music', startOffset: _ms(8000), duration: 12),
        ],
        clips: const [],
        videoEnd: _ms(3000),
      );

      expect(resolver.hasRead(parts), isFalse);
      await resolver.read(parts);
      await resolver.read(parts);

      expect(resolver.hasRead(parts), isTrue);
      expect(file.reads, hasLength(1));
      expect(file.reads.single.format, AudioFormat.wav);
      expect(file.reads.single.startTime, _ms(7000));
      expect(file.reads.single.endTime, _ms(12000));
    });

    test(
      'shares an extraction while the same stretch is still being read',
      () async {
        final wav = Completer<Uint8List>();
        var reads = 0;
        final shared = VideoEditorBeatResolver(
          extractAudio: (_) {
            reads++;
            return wav.future;
          },
        );
        final parts = beatSourceFor(
          sounds: [_sound('music')],
          clips: const [],
          videoEnd: _ms(3000),
        );
        final first = shared.read(parts);
        final second = shared.read(parts);
        expect(reads, 1);
        wav.complete(
          drumLoopWav(AudioExtractConfigs(video: parts.single.media)),
        );
        await Future.wait([first, second]);
        expect(shared.hasRead(parts), isTrue);
      },
    );
  });
}
