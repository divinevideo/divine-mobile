// ABOUTME: Tests for SoundSpeedRampRenderService: which window of a ramped
// ABOUTME: sound it bakes, how it caches the file, and how it cleans up.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/extensions/audio_event_speed.dart';
import 'package:openvine/services/video_editor/sound_speed_ramp_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockProVideoEditor extends Mock implements ProVideoEditor {}

const _ramp = VideoSpeedRamp([
  VideoSpeedRampPoint(position: 0, speed: 2),
  VideoSpeedRampPoint(position: 1, speed: 0.5),
]);

void main() {
  group(SoundSpeedRampRenderService, () {
    late _MockProVideoEditor editor;
    late Directory directory;
    late SoundSpeedRampRenderService service;
    late List<AudioMergeConfigs> merges;
    Completer<void>? holdMerge;

    /// A sound whose window from 1 s to 4 s plays along [_ramp] from 2 s.
    AudioEvent rampedSound({String url = '/tmp/song.wav'}) => AudioEvent(
      id: 'sound',
      pubkey: 'pubkey',
      createdAt: 0,
      url: url,
      startOffset: const Duration(seconds: 2),
      startTime: const Duration(seconds: 1),
      endTime: const Duration(seconds: 4),
    ).withSpeedRamp(_ramp);

    setUpAll(() {
      registerFallbackValue(AudioMergeConfigs(segments: const []));
    });

    setUp(() {
      editor = _MockProVideoEditor();
      directory = Directory.systemTemp.createTempSync('sound_ramp_test_');
      merges = [];
      holdMerge = null;
      when(() => editor.mergeAudioToFile(any(), any())).thenAnswer((
        invocation,
      ) async {
        merges.add(invocation.positionalArguments[1] as AudioMergeConfigs);
        await holdMerge?.future;
        final path = invocation.positionalArguments[0] as String;
        File(path).writeAsBytesSync(const [1, 2, 3]);
        return AudioMergeResult(
          outputPath: path,
          segments: const [],
          totalDuration: const Duration(seconds: 3),
        );
      });
      service = SoundSpeedRampRenderService(
        proVideoEditor: editor,
        directory: () async => directory,
      );
    });

    tearDown(() {
      service.clear();
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    group('render', () {
      test('bakes the stretch of the sound the window plays', () async {
        final sound = rampedSound();

        final path = await service.render(sound);

        expect(path, isNotNull);
        expect(File(path!).existsSync(), isTrue);
        final segment = merges.single.segments.single;
        expect(segment.video, EditorVideo.file('/tmp/song.wav'));
        expect(segment.startTime, const Duration(seconds: 2));
        expect(segment.endTime, segment.startTime + sound.playedSourceSpan!);
        expect(segment.speedRamp, _ramp);
        expect(segment.speed, 1);
      });

      test('renders a sound once however often it is asked for', () async {
        holdMerge = Completer<void>();
        final first = service.render(rampedSound());
        final second = service.render(rampedSound());
        holdMerge!.complete();

        expect(await first, await second);
        expect(await service.render(rampedSound()), await first);
        expect(service.cached(rampedSound()), await first);
        expect(merges, hasLength(1));
      });

      test('renders again for another window or another ramp', () async {
        final first = await service.render(rampedSound());
        final longer = await service.render(
          rampedSound().copyWith(endTime: const Duration(seconds: 5)),
        );
        final flatter = await service.render(
          rampedSound().withSpeedRamp(
            const VideoSpeedRamp([
              VideoSpeedRampPoint(position: 0, speed: 1.5),
              VideoSpeedRampPoint(position: 1, speed: 0.5),
            ]),
          ),
        );

        expect({first, longer, flatter}, hasLength(3));
        expect(merges, hasLength(3));
      });

      test('keeps only the windows used most recently', () async {
        AudioEvent endingAt(int seconds) =>
            rampedSound().copyWith(endTime: Duration(seconds: seconds));
        final oldest = await service.render(endingAt(2));
        final keep = await service.render(endingAt(3));
        for (
          var i = 0;
          i < SoundSpeedRampRenderService.maxCachedFiles - 1;
          i++
        ) {
          await service.render(endingAt(10 + i));
        }

        // Asked for again, so it outlives the files rendered after it.
        expect(service.cached(endingAt(3)), keep);
        await service.render(endingAt(30));
        await pumpEventQueue();

        expect(service.cached(endingAt(2)), isNull);
        expect(File(oldest!).existsSync(), isFalse);
        expect(service.cached(endingAt(3)), keep);
        expect(File(keep!).existsSync(), isTrue);
      });

      test('has nothing to render for a sound without a ramp', () async {
        final constant = rampedSound().withSpeedRamp(null);

        expect(await service.render(constant), isNull);
        expect(service.cached(constant), isNull);
        verifyNever(() => editor.mergeAudioToFile(any(), any()));
      });

      test('gives up on a failed render and tries again later', () async {
        when(
          () => editor.mergeAudioToFile(any(), any()),
        ).thenThrow(Exception('decoder gone'));

        expect(await service.render(rampedSound()), isNull);
        expect(await service.render(rampedSound()), isNull);
        verify(() => editor.mergeAudioToFile(any(), any())).called(2);
      });
    });

    group('cached', () {
      test('never starts a render', () {
        expect(service.cached(rampedSound()), isNull);
        verifyNever(() => editor.mergeAudioToFile(any(), any()));
      });
    });

    group('clear', () {
      test('forgets and deletes every rendered window', () async {
        final path = await service.render(rampedSound());

        service.clear();
        await pumpEventQueue();

        expect(service.cached(rampedSound()), isNull);
        expect(File(path!).existsSync(), isFalse);
      });

      test('drops a render that lands after it', () async {
        holdMerge = Completer<void>();
        final render = service.render(rampedSound());
        await pumpEventQueue();

        service.clear();
        holdMerge!.complete();

        expect(await render, isNull);
        expect(service.cached(rampedSound()), isNull);
        expect(
          directory
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => !file.path.endsWith('.tmp.wav')),
          isEmpty,
        );
      });
    });
  });
}
