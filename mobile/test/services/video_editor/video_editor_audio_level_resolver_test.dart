// ABOUTME: Tests which sounds an audio visualizer follows and how their band
// ABOUTME: energies are read, cached and added up on the exported video.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/video_editor_audio_level_resolver.dart';
import 'package:openvine/services/video_editor/video_editor_beat_resolver.dart';
import 'package:openvine/utils/audio_band_energies.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../helpers/audio_samples.dart';

Duration _ms(int milliseconds) => Duration(milliseconds: milliseconds);

/// The band a 1 kHz tone falls into.
const _toneBand = 25;

AudioEvent _sound(
  String id, {
  Duration startTime = Duration.zero,
  Duration? endTime,
  double volume = 1,
  Duration fadeIn = Duration.zero,
  Duration fadeOut = Duration.zero,
}) => AudioEvent(
  id: id,
  pubkey: 'a' * 64,
  createdAt: 1735689600,
  url: '/tmp/$id.mp3',
  duration: 30,
  startTime: startTime,
  endTime: endTime,
  volume: volume,
  fadeInDuration: fadeIn,
  fadeOutDuration: fadeOut,
);

DivineVideoClip _clip(
  String id, {
  Duration duration = const Duration(seconds: 2),
  double volume = 1,
}) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('${Directory.systemTemp.path}/$id.mp4'),
  duration: duration,
  recordedAt: DateTime(2026),
  targetAspectRatio: model.AspectRatio.vertical,
  originalAspectRatio: 9 / 16,
  volume: volume,
);

/// A part of a file holding a steady 1 kHz tone, from [from] to [to] in the
/// file, played at [at] on the video.
AudioLevelPart _part({
  Duration from = Duration.zero,
  Duration to = const Duration(seconds: 1),
  Duration at = Duration.zero,
  double speed = 1,
  double volume = 1,
  Duration fadeIn = Duration.zero,
  Duration fadeOut = Duration.zero,
  String file = 'tone',
}) => AudioLevelPart(
  source: BeatSourcePart(
    media: EditorVideo.file('${Directory.systemTemp.path}/$file.m4a'),
    fileLength: const Duration(seconds: 30),
    from: from,
    to: to,
    at: at,
    speed: speed,
  ),
  volume: volume,
  fadeIn: fadeIn,
  fadeOut: fadeOut,
);

/// Extracts a steady 1 kHz tone of the stretch it is asked for, and records
/// every extraction.
class _ToneFile {
  final reads = <AudioExtractConfigs>[];

  Future<Uint8List> call(AudioExtractConfigs configs) async {
    reads.add(configs);
    final from = configs.startTime ?? Duration.zero;
    final to = configs.endTime ?? const Duration(seconds: 30);
    final samples = silentAudio(to - from);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = 0.5 * math.sin(2 * math.pi * 1000 * i / testSampleRate);
    }
    return wavBytes(samples);
  }
}

double _energy(Float32List mix, int row, [int band = _toneBand]) =>
    mix[row * audioBandCount + band];

void main() {
  group('audioLevelSourcesFor', () {
    test('follows every sound, voice-overs included, and the clips', () {
      final parts = audioLevelSourcesFor(
        sounds: [
          _sound('music', volume: 0.5, fadeIn: _ms(300), fadeOut: _ms(400)),
          _sound('${AudioEvent.voiceOverIdPrefix}_1', startTime: _ms(1000)),
        ],
        clips: [_clip('a', volume: 2)],
        videoEnd: _ms(2000),
      );

      expect(parts, hasLength(3));
      expect(parts[0].volume, 0.5);
      expect(parts[0].fadeIn, _ms(300));
      expect(parts[0].fadeOut, _ms(400));
      expect(parts[1].source.at, _ms(1000));
      expect(parts[2].volume, 2);
      expect(parts[2].source.to, _ms(2000));
    });

    test('leaves out silent sounds, muted clips and sounds after the end', () {
      final parts = audioLevelSourcesFor(
        sounds: [
          _sound('muted', volume: 0),
          _sound('late', startTime: _ms(3000)),
        ],
        clips: [_clip('a', volume: 0)],
        videoEnd: _ms(2000),
      );

      expect(parts, isEmpty);
    });
  });

  group('withLocalNetworkSounds', () {
    test('reads a network sound from its local copy', () async {
      final network = AudioLevelPart(
        source: BeatSourcePart(
          media: EditorVideo.network('https://media.example/song'),
          fileLength: const Duration(seconds: 30),
          from: _ms(1000),
          to: _ms(4000),
          at: _ms(500),
          speed: 1.5,
        ),
        volume: 0.5,
        fadeIn: _ms(100),
        fadeOut: _ms(200),
      );
      final local = _part();
      final requested = <String>[];

      final parts = await withLocalNetworkSounds(
        [network, local],
        localPathFor: (url) async {
          requested.add(url);
          return '/tmp/song.mp3';
        },
      );

      expect(requested, ['https://media.example/song']);
      expect(parts[0].source.media.file?.path, '/tmp/song.mp3');
      expect(parts[0].source.media.networkUrl, isNull);
      expect(
        (
          parts[0].source.fileLength,
          parts[0].source.from,
          parts[0].source.to,
          parts[0].source.at,
          parts[0].source.speed,
        ),
        (const Duration(seconds: 30), _ms(1000), _ms(4000), _ms(500), 1.5),
      );
      expect(
        (parts[0].volume, parts[0].fadeIn, parts[0].fadeOut),
        (0.5, _ms(100), _ms(200)),
      );
      expect(parts[1], same(local));
    });
  });

  group('audioEnergiesOnExport', () {
    final song = AudioEvent(
      id: 'song',
      pubkey: 'a' * 64,
      createdAt: 1735689600,
      url: 'https://media.example/song',
      duration: 30,
    );

    test('reads a network sound from its downloaded copy', () async {
      final file = _ToneFile();
      final downloads = <String>[];

      final energies = await audioEnergiesOnExport(
        sounds: [song],
        clips: const [],
        videoEnd: _ms(1000),
        localPathFor: (url) async {
          downloads.add(url);
          return '/tmp/song.m4a';
        },
        resolver: VideoEditorAudioLevelResolver(extractAudio: file.call),
      );

      expect(downloads, ['https://media.example/song']);
      expect(file.reads.single.video.file?.path, '/tmp/song.m4a');
      expect(file.reads.single.video.networkUrl, isNull);
      expect(_energy(energies!, 30), greaterThan(0));
    });

    test('leaves out a sound that cannot be downloaded', () async {
      final file = _ToneFile();

      final energies = await audioEnergiesOnExport(
        sounds: [song],
        clips: [_clip('a', duration: const Duration(seconds: 1))],
        videoEnd: _ms(1000),
        localPathFor: (url) async => throw Exception('offline'),
        resolver: VideoEditorAudioLevelResolver(extractAudio: file.call),
      );

      expect(file.reads.single.video.file?.path, endsWith('a.mp4'));
      expect(_energy(energies!, 30), greaterThan(0));
    });
  });

  group(VideoEditorAudioLevelResolver, () {
    late _ToneFile file;
    late VideoEditorAudioLevelResolver resolver;

    setUp(() {
      file = _ToneFile();
      resolver = VideoEditorAudioLevelResolver(extractAudio: file.call);
    });

    group('energiesOnOutput', () {
      test('has a row every 60th of a second of the video', () async {
        final mix = resolver.energiesOnOutput(const [], videoEnd: _ms(1500));

        expect(mix.length, 90 * audioBandCount);
      });

      test('places a part where it plays on the video', () async {
        final part = _part(at: _ms(1000));
        await resolver.read([part]);
        final mix = resolver.energiesOnOutput([part], videoEnd: _ms(3000));

        expect(_energy(mix, 30), 0);
        expect(_energy(mix, 90), greaterThan(0));
        expect(_energy(mix, 150), 0);
      });

      test('plays a sped up part in less time', () async {
        final part = _part(to: _ms(2000), speed: 2);
        await resolver.read([part]);
        final mix = resolver.energiesOnOutput([part], videoEnd: _ms(2000));

        expect(_energy(mix, 30), greaterThan(0));
        expect(_energy(mix, 90), 0);
      });

      test('counts a part by the square of its volume', () async {
        final quiet = _part();
        final loud = _part(volume: 2);
        await resolver.read([quiet]);
        final one = resolver.energiesOnOutput([quiet], videoEnd: _ms(1000));
        final two = resolver.energiesOnOutput([loud], videoEnd: _ms(1000));

        expect(_energy(two, 30), closeTo(4 * _energy(one, 30), 1e-3));
      });

      test('adds up parts that play at once', () async {
        final a = _part();
        final b = _part(file: 'other');
        await resolver.read([a, b]);
        final one = resolver.energiesOnOutput([a], videoEnd: _ms(1000));
        final both = resolver.energiesOnOutput([a, b], videoEnd: _ms(1000));

        expect(_energy(both, 30), closeTo(2 * _energy(one, 30), 1e-3));
      });

      test('fades a part in and out', () async {
        final part = _part(fadeIn: _ms(500), fadeOut: _ms(500));
        await resolver.read([part]);
        final steady = resolver.energiesOnOutput([
          _part(),
        ], videoEnd: _ms(1000));
        final faded = resolver.energiesOnOutput([part], videoEnd: _ms(1000));

        // A quarter into the fade in, the sound plays at a quarter of its
        // volume, a sixteenth of its energy.
        expect(
          _energy(faded, 7),
          closeTo(_energy(steady, 7) * math.pow(7 / 30, 2), 1e-3),
        );
        expect(_energy(faded, 30), closeTo(_energy(steady, 30), 1e-3));
        expect(_energy(faded, 55), lessThan(_energy(steady, 55) / 10));
      });

      test('adds nothing for a part that was not read', () {
        final mix = resolver.energiesOnOutput([_part()], videoEnd: _ms(1000));

        expect(mix.every((energy) => energy == 0), isTrue);
      });
    });

    group('read', () {
      test(
        'reads a stretch once, wherever and however fast it plays',
        () async {
          await resolver.read([_part()]);
          await resolver.read([_part(at: _ms(500), volume: 2, speed: 1.5)]);

          expect(file.reads, hasLength(1));
          expect(resolver.hasRead([_part(at: _ms(200))]), isTrue);
          expect(resolver.hasRead([_part(to: _ms(900))]), isFalse);
        },
      );

      test('reads a little around the stretch, never past the file', () async {
        await resolver.read([
          _part(from: _ms(1000), to: _ms(2000)),
          AudioLevelPart(
            source: BeatSourcePart(
              media: EditorVideo.file('${Directory.systemTemp.path}/end.m4a'),
              fileLength: _ms(3000),
              from: _ms(2000),
              to: _ms(3000),
              at: Duration.zero,
            ),
          ),
        ]);

        expect(file.reads[0].startTime, _ms(950));
        expect(file.reads[0].endTime, _ms(2050));
        expect(file.reads[1].endTime, _ms(3000));
      });

      test('takes a clip without sound as silent', () async {
        final silent = VideoEditorAudioLevelResolver(
          extractAudio: (_) async => throw const AudioNoTrackException(),
        );

        await silent.read([_part()]);

        expect(silent.hasRead([_part()]), isTrue);
        expect(
          silent
              .energiesOnOutput([_part()], videoEnd: _ms(1000))
              .every((energy) => energy == 0),
          isTrue,
        );
      });

      test('reads the other parts when one fails to read', () async {
        final mixed = VideoEditorAudioLevelResolver(
          extractAudio: (configs) async {
            if (configs.video.networkUrl != null) {
              throw Exception('Failed to load video');
            }
            return file(configs);
          },
        );
        final unreachable = AudioLevelPart(
          source: BeatSourcePart(
            media: EditorVideo.network('https://media.example/song'),
            fileLength: const Duration(seconds: 30),
            from: Duration.zero,
            to: const Duration(seconds: 1),
            at: Duration.zero,
          ),
        );

        await mixed.read([unreachable, _part()]);

        expect(mixed.hasRead([_part()]), isTrue);
        // Not remembered as silent, so the next read tries it again.
        expect(mixed.hasRead([unreachable]), isFalse);
        expect(
          _energy(
            mixed.energiesOnOutput([unreachable, _part()], videoEnd: _ms(1000)),
            30,
          ),
          greaterThan(0),
        );
      });

      test(
        'throws when the platform returns no audio for any part',
        () async {
          final empty = VideoEditorAudioLevelResolver(
            extractAudio: (_) async =>
                throw ArgumentError('Failed to extract audio from video'),
          );

          await expectLater(
            empty.read([_part(), _part(file: 'other')]),
            throwsA(
              isA<AudioLevelReadException>().having(
                (error) => error.cause,
                'cause',
                isA<ArgumentError>(),
              ),
            ),
          );
        },
      );

      test('lets a programming error through as itself', () async {
        final broken = VideoEditorAudioLevelResolver(
          extractAudio: (_) async => throw RangeError.index(3, const [1]),
        );

        await expectLater(broken.read([_part()]), throwsA(isA<RangeError>()));
      });

      test(
        'throws when nothing could be read, and tries again later',
        () async {
          var fail = true;
          final flaky = VideoEditorAudioLevelResolver(
            extractAudio: (configs) async {
              if (fail) throw PlatformException(code: 'EXTRACT_FAILED');
              return file(configs);
            },
          );

          await expectLater(
            flaky.read([_part()]),
            throwsA(
              isA<AudioLevelReadException>().having(
                (error) => error.cause,
                'cause',
                isA<PlatformException>(),
              ),
            ),
          );
          expect(flaky.hasRead([_part()]), isFalse);

          fail = false;
          await flaky.read([_part()]);
          expect(flaky.hasRead([_part()]), isTrue);
        },
      );
    });
  });
}
