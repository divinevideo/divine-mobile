// ABOUTME: Unit tests for VoiceEffectBloc: looping auditions of every
// ABOUTME: setting, baking the kept one into a re-identified track, failures.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart'
    show AudioEvent, AudioSourceKind, VoiceEffect;
import 'package:openvine/blocs/video_editor/voice_effect/voice_effect_bloc.dart';
import 'package:openvine/blocs/video_editor/voice_effect/voice_effect_preset.dart';
import 'package:openvine/services/video_editor/voice_effect_service.dart';
import 'package:sound_service/sound_service.dart';

class _MockVoiceEffectService extends Mock implements VoiceEffectService {}

class _MockAudioClipPlayer extends Mock implements AudioClipPlayer {}

const _take = '/docs/voice_over_recordings/voice_over_1.m4a';
const _robotTake = '/docs/voice_over_recordings/voice_over_1_p0_r100_e0.wav';
const _robot = VoiceEffect(robot: 100);
const VoiceEffectSource _takeSource = (kind: AudioSourceKind.file, path: _take);

const _songUrl = 'https://blossom.example/abc';
const VoiceEffectSource _songSource = (
  kind: AudioSourceKind.network,
  path: _songUrl,
);
const _robotSongCopy = '/docs/voice_effect_audio/abc_p0_r100_e0.wav';
const _songId =
    'a1b2c3d4e5f6a7b8c9d0a1b2c3d4e5f6a7b8c9d0a1b2c3d4e5f6a7b8c9d0a1b2-100';

final _now = DateTime.fromMicrosecondsSinceEpoch(1700000000000000);

/// A take on the timeline from 1 s to 3 s, playing its source from 0.5 s.
AudioEvent _recording() => AudioEvent(
  id: 'local_import_voice_over_1-100-0',
  pubkey: 'local_import',
  createdAt: 1700000000,
  url: _take,
  mimeType: 'audio/mp4',
  startOffset: const Duration(milliseconds: 500),
  startTime: const Duration(seconds: 1),
  endTime: const Duration(seconds: 3),
);

/// A published sound on the timeline from 1 s to 3 s, playing from 0.5 s.
AudioEvent _song() => AudioEvent(
  id: _songId,
  pubkey: 'creator',
  createdAt: 1700000000,
  url: _songUrl,
  mimeType: 'audio/mpeg',
  startOffset: const Duration(milliseconds: 500),
  startTime: const Duration(seconds: 1),
  endTime: const Duration(seconds: 3),
);

AudioEvent _robotSong() => _song().copyWith(
  id: '${_songId}_fx42',
  url: _robotSongCopy,
  mimeType: 'audio/wav',
  voiceEffect: _robot,
  originalUrl: _songUrl,
  originalMimeType: 'audio/mpeg',
);

AudioEvent _robotRecording() => _recording().copyWith(
  id: 'local_import_voice_over_1-100-0_fx42',
  url: _robotTake,
  mimeType: 'audio/wav',
  voiceEffect: _robot,
  originalUrl: _take,
);

void main() {
  group(VoiceEffectBloc, () {
    late _MockVoiceEffectService service;
    late _MockAudioClipPlayer player;
    late StreamController<void> completions;

    VoiceEffectBloc build(AudioEvent track) => VoiceEffectBloc(
      track: track,
      service: service,
      player: player,
      clock: () => _now,
    );

    void stubAudition(String path) => when(
      () => service.renderAudition(
        source: any(named: 'source'),
        effect: any(named: 'effect'),
        noiseReduction: any(named: 'noiseReduction'),
        start: any(named: 'start'),
        length: any(named: 'length'),
      ),
    ).thenAnswer((_) async => path);

    setUpAll(() {
      registerFallbackValue(VoiceEffect.none);
      registerFallbackValue(const AudioSourceConfig.file(''));
      registerFallbackValue(Duration.zero);
      registerFallbackValue(_takeSource);
    });

    setUp(() {
      service = _MockVoiceEffectService();
      player = _MockAudioClipPlayer();
      completions = StreamController<void>.broadcast();
      when(() => player.completionStream).thenAnswer((_) => completions.stream);
      when(() => player.setClip(any())).thenAnswer((_) async {});
      when(() => player.play()).thenAnswer((_) async {});
      when(() => player.stop()).thenAnswer((_) async {});
      when(() => player.seek(any())).thenAnswer((_) async {});
      when(() => player.dispose()).thenAnswer((_) async {});
      when(() => service.discardAudition(any())).thenAnswer((_) async {});
      when(() => service.clearAuditions()).thenAnswer((_) async {});
    });

    tearDown(() => completions.close());

    group(VoiceEffectSettingsChanged, () {
      blocTest<VoiceEffectBloc, VoiceEffectState>(
        'loops the take itself over its stretch of the timeline when nothing '
        'is applied',
        build: () => build(_recording()),
        act: (bloc) => bloc.add(const VoiceEffectSettingsChanged()),
        verify: (_) {
          final config =
              verify(() => player.setClip(captureAny())).captured.single
                  as AudioSourceConfig;
          expect(config.uri, _take);
          expect(config.start, const Duration(milliseconds: 500));
          expect(config.end, const Duration(milliseconds: 2500));
          verify(() => player.play()).called(1);
          verifyNever(
            () => service.renderAudition(
              source: any(named: 'source'),
              effect: any(named: 'effect'),
              noiseReduction: any(named: 'noiseReduction'),
              start: any(named: 'start'),
              length: any(named: 'length'),
            ),
          );
        },
      );

      blocTest<VoiceEffectBloc, VoiceEffectState>(
        'loops the file a processed track already plays without rendering it',
        build: () => build(_robotRecording()),
        act: (bloc) => bloc.add(const VoiceEffectSettingsChanged()),
        verify: (_) {
          final config =
              verify(() => player.setClip(captureAny())).captured.single
                  as AudioSourceConfig;
          expect(config.uri, _robotTake);
          verifyNever(
            () => service.renderAudition(
              source: any(named: 'source'),
              effect: any(named: 'effect'),
              noiseReduction: any(named: 'noiseReduction'),
              start: any(named: 'start'),
              length: any(named: 'length'),
            ),
          );
        },
      );

      blocTest<VoiceEffectBloc, VoiceEffectState>(
        'renders a picked preset and loops it',
        setUp: () => stubAudition('/tmp/audition_1.wav'),
        build: () => build(_recording()),
        act: (bloc) => bloc.add(
          VoiceEffectSettingsChanged(
            effect: VoiceEffectPreset.robot.effect,
          ),
        ),
        verify: (bloc) {
          expect(bloc.state.effect, _robot);
          expect(bloc.state.preset, VoiceEffectPreset.robot);
          expect(bloc.state.auditionPath, '/tmp/audition_1.wav');
          final config =
              verify(() => player.setClip(captureAny())).captured.single
                  as AudioSourceConfig;
          expect(config.uri, '/tmp/audition_1.wav');
          // Rendered from the stretch the track plays, so it loops whole.
          expect(config.start, isNull);
          expect(config.end, isNull);
          verify(
            () => service.renderAudition(
              source: _takeSource,
              effect: _robot,
              noiseReduction: false,
              start: const Duration(milliseconds: 500),
              length: const Duration(seconds: 2),
            ),
          ).called(1);
        },
      );

      blocTest<VoiceEffectBloc, VoiceEffectState>(
        'streams a published sound over its stretch when nothing is applied',
        build: () => build(_song()),
        act: (bloc) => bloc.add(const VoiceEffectSettingsChanged()),
        verify: (_) {
          final config =
              verify(() => player.setClip(captureAny())).captured.single
                  as AudioSourceConfig;
          expect(config.uri, _songUrl);
          expect(config.isFile, isFalse);
          expect(config.isAsset, isFalse);
          expect(config.start, const Duration(milliseconds: 500));
          expect(config.end, const Duration(milliseconds: 2500));
        },
      );

      blocTest<VoiceEffectBloc, VoiceEffectState>(
        'renders a published sound from its network address',
        setUp: () => stubAudition('/tmp/audition_1.wav'),
        build: () => build(_song()),
        act: (bloc) =>
            bloc.add(const VoiceEffectSettingsChanged(effect: _robot)),
        verify: (_) {
          verify(
            () => service.renderAudition(
              source: _songSource,
              effect: _robot,
              noiseReduction: false,
              start: const Duration(milliseconds: 500),
              length: const Duration(seconds: 2),
            ),
          ).called(1);
        },
      );

      blocTest<VoiceEffectBloc, VoiceEffectState>(
        'renders a slider only once it is let go, and discards the audition '
        'it replaces',
        setUp: () {
          var count = 0;
          when(
            () => service.renderAudition(
              source: any(named: 'source'),
              effect: any(named: 'effect'),
              noiseReduction: any(named: 'noiseReduction'),
              start: any(named: 'start'),
              length: any(named: 'length'),
            ),
          ).thenAnswer((_) async => '/tmp/audition_${++count}.wav');
        },
        build: () => build(_recording()),
        act: (bloc) async {
          bloc.add(const VoiceEffectSettingsChanged(effect: _robot));
          await pumpEventQueue();
          bloc
            ..add(
              const VoiceEffectSettingsChanged(
                effect: VoiceEffect(robot: 100, echo: 20),
                audition: false,
              ),
            )
            ..add(
              const VoiceEffectSettingsChanged(
                effect: VoiceEffect(robot: 100, echo: 40),
                audition: false,
              ),
            );
          await pumpEventQueue();
          bloc.add(
            const VoiceEffectSettingsChanged(
              effect: VoiceEffect(robot: 100, echo: 40),
            ),
          );
        },
        verify: (bloc) {
          expect(bloc.state.preset, isNull);
          expect(bloc.state.auditionPath, '/tmp/audition_2.wav');
          verify(
            () => service.renderAudition(
              source: any(named: 'source'),
              effect: any(named: 'effect'),
              noiseReduction: any(named: 'noiseReduction'),
              start: any(named: 'start'),
              length: any(named: 'length'),
            ),
          ).called(2);
          verify(() => service.discardAudition('/tmp/audition_1.wav'))
              .called(1);
        },
      );

      blocTest<VoiceEffectBloc, VoiceEffectState>(
        'drops an audition a newer setting overtook while it rendered',
        setUp: () {
          final slow = Completer<String>();
          when(
            () => service.renderAudition(
              source: any(named: 'source'),
              effect: _robot,
              noiseReduction: any(named: 'noiseReduction'),
              start: any(named: 'start'),
              length: any(named: 'length'),
            ),
          ).thenAnswer((_) => slow.future);
          when(
            () => service.renderAudition(
              source: any(named: 'source'),
              effect: const VoiceEffect(echo: 80),
              noiseReduction: any(named: 'noiseReduction'),
              start: any(named: 'start'),
              length: any(named: 'length'),
            ),
          ).thenAnswer((_) async {
            slow.complete('/tmp/stale.wav');
            return '/tmp/fresh.wav';
          });
        },
        build: () => build(_recording()),
        act: (bloc) async {
          bloc.add(const VoiceEffectSettingsChanged(effect: _robot));
          await pumpEventQueue();
          bloc.add(
            const VoiceEffectSettingsChanged(effect: VoiceEffect(echo: 80)),
          );
        },
        verify: (bloc) {
          expect(bloc.state.auditionPath, '/tmp/fresh.wav');
          final played = verify(
            () => player.setClip(captureAny()),
          ).captured.cast<AudioSourceConfig>().map((c) => c.uri);
          expect(played, ['/tmp/fresh.wav']);
          verify(() => service.discardAudition('/tmp/stale.wav')).called(1);
        },
      );

      test(
        'records the audition without waiting for playback to end',
        () async {
          stubAudition('/tmp/audition_1.wav');
          final playing = Completer<void>();
          when(() => player.play()).thenAnswer((_) => playing.future);
          final bloc = build(_recording())
            ..add(const VoiceEffectSettingsChanged(effect: _robot));
          addTearDown(bloc.close);
          await pumpEventQueue();

          expect(bloc.state.auditionPath, '/tmp/audition_1.wav');
          expect(playing.isCompleted, isFalse);
          playing.complete();
        },
      );

      test(
        'does not discard the newer audition when an older load finishes',
        () async {
          final oldLoading = Completer<void>();
          var count = 0;
          when(
            () => service.renderAudition(
              source: any(named: 'source'),
              effect: any(named: 'effect'),
              noiseReduction: any(named: 'noiseReduction'),
              start: any(named: 'start'),
              length: any(named: 'length'),
            ),
          ).thenAnswer((_) async => '/tmp/audition_${++count}.wav');
          when(() => player.setClip(any())).thenAnswer((invocation) {
            final config =
                invocation.positionalArguments.single as AudioSourceConfig;
            return config.uri == '/tmp/audition_1.wav'
                ? oldLoading.future
                : Future<void>.value();
          });
          final bloc = build(_recording())
            ..add(const VoiceEffectSettingsChanged(effect: _robot));
          addTearDown(bloc.close);
          await pumpEventQueue();
          bloc.add(
            const VoiceEffectSettingsChanged(effect: VoiceEffect(echo: 80)),
          );
          await pumpEventQueue();
          expect(bloc.state.auditionPath, '/tmp/audition_2.wav');

          oldLoading.complete();
          await pumpEventQueue();

          expect(bloc.state.auditionPath, '/tmp/audition_2.wav');
          verify(() => player.play()).called(1);
          verify(() => service.discardAudition('/tmp/audition_1.wav'))
              .called(1);
          verifyNever(() => service.discardAudition('/tmp/audition_2.wav'));
        },
      );

      blocTest<VoiceEffectBloc, VoiceEffectState>(
        'reports a take it cannot render',
        setUp: () => when(
          () => service.renderAudition(
            source: any(named: 'source'),
            effect: any(named: 'effect'),
            noiseReduction: any(named: 'noiseReduction'),
            start: any(named: 'start'),
            length: any(named: 'length'),
          ),
        ).thenThrow(const VoiceEffectException('decode failed')),
        build: () => build(_recording()),
        act: (bloc) =>
            bloc.add(const VoiceEffectSettingsChanged(effect: _robot)),
        verify: (bloc) {
          expect(bloc.state.status, VoiceEffectStatus.failure);
        },
        errors: () => [isA<VoiceEffectException>()],
      );
    });

    group('audition loop', () {
      blocTest<VoiceEffectBloc, VoiceEffectState>(
        'starts the audition over each time it ends',
        build: () => build(_recording()),
        act: (bloc) async {
          bloc.add(const VoiceEffectSettingsChanged());
          await pumpEventQueue();
          completions.add(null);
          await pumpEventQueue();
        },
        verify: (_) {
          verify(() => player.seek(Duration.zero)).called(1);
          verify(() => player.play()).called(2);
        },
      );
    });

    group(VoiceEffectApplyRequested, () {
      blocTest<VoiceEffectBloc, VoiceEffectState>(
        'finishes without a result when nothing changed',
        build: () => build(_recording()),
        act: (bloc) => bloc.add(const VoiceEffectApplyRequested()),
        verify: (bloc) {
          expect(bloc.state.status, VoiceEffectStatus.done);
          expect(bloc.state.result, isNull);
          verify(() => player.stop()).called(1);
        },
      );

      blocTest<VoiceEffectBloc, VoiceEffectState>(
        'puts the processed take on the track under a new id',
        setUp: () {
          stubAudition('/tmp/audition_1.wav');
          when(
            () => service.process(
              source: _takeSource,
              effect: _robot,
              noiseReduction: true,
            ),
          ).thenAnswer((_) async => (path: _robotTake, mimeType: 'audio/wav'));
        },
        build: () => build(_recording()),
        act: (bloc) async {
          bloc.add(
            const VoiceEffectSettingsChanged(
              effect: _robot,
              noiseReduction: true,
            ),
          );
          await pumpEventQueue();
          bloc.add(const VoiceEffectApplyRequested());
        },
        verify: (bloc) {
          final result = bloc.state.result!;
          expect(bloc.state.status, VoiceEffectStatus.done);
          expect(
            result.id,
            'local_import_voice_over_1-100-0_fx${_now.microsecondsSinceEpoch}',
          );
          expect(result.url, _robotTake);
          expect(result.mimeType, 'audio/wav');
          expect(result.originalUrl, _take);
          expect(result.originalMimeType, 'audio/mp4');
          expect(result.voiceEffect, _robot);
          expect(result.noiseReduction, isTrue);
          expect(result.endTime, const Duration(seconds: 3));
        },
      );

      blocTest<VoiceEffectBloc, VoiceEffectState>(
        'switches a processed track back to the take as recorded',
        build: () => build(_robotRecording()),
        act: (bloc) async {
          bloc.add(
            const VoiceEffectSettingsChanged(
              effect: VoiceEffect.none,
              audition: false,
            ),
          );
          await pumpEventQueue();
          bloc.add(const VoiceEffectApplyRequested());
        },
        verify: (bloc) {
          final result = bloc.state.result!;
          expect(result.url, _take);
          // Taken from the file name: the copy predates originalMimeType.
          expect(result.mimeType, 'audio/mp4');
          expect(result.originalUrl, isNull);
          expect(result.hasVoiceProcessing, isFalse);
          verifyNever(
            () => service.process(
              source: any(named: 'source'),
              effect: any(named: 'effect'),
              noiseReduction: any(named: 'noiseReduction'),
            ),
          );
          // The earlier pick's suffix is replaced, not stacked.
          expect(
            result.id,
            'local_import_voice_over_1-100-0_fx${_now.microsecondsSinceEpoch}',
          );
        },
      );

      blocTest<VoiceEffectBloc, VoiceEffectState>(
        'bakes a published sound into a processed copy and keeps its address',
        setUp: () =>
            when(
              () => service.process(
                source: _songSource,
                effect: _robot,
                noiseReduction: false,
              ),
            ).thenAnswer(
              (_) async => (path: _robotSongCopy, mimeType: 'audio/wav'),
            ),
        build: () => build(_song()),
        act: (bloc) async {
          bloc.add(
            const VoiceEffectSettingsChanged(effect: _robot, audition: false),
          );
          await pumpEventQueue();
          bloc.add(const VoiceEffectApplyRequested());
        },
        verify: (bloc) {
          final result = bloc.state.result!;
          expect(result.id, '${_songId}_fx${_now.microsecondsSinceEpoch}');
          expect(result.url, _robotSongCopy);
          expect(result.mimeType, 'audio/wav');
          expect(result.originalUrl, _songUrl);
          expect(result.originalMimeType, 'audio/mpeg');
          expect(result.attributionEventId, _songId.split('-').first);
        },
      );

      blocTest<VoiceEffectBloc, VoiceEffectState>(
        'bakes a processed sound again from the sound it came from',
        setUp: () =>
            when(
              () => service.process(
                source: _songSource,
                effect: const VoiceEffect(echo: 80),
                noiseReduction: false,
              ),
            ).thenAnswer(
              (_) async => (
                path: '/docs/voice_effect_audio/echo.wav',
                mimeType: 'audio/wav',
              ),
            ),
        build: () => build(_robotSong()),
        act: (bloc) async {
          bloc.add(
            const VoiceEffectSettingsChanged(
              effect: VoiceEffect(echo: 80),
              audition: false,
            ),
          );
          await pumpEventQueue();
          bloc.add(const VoiceEffectApplyRequested());
        },
        verify: (bloc) {
          final result = bloc.state.result!;
          expect(result.url, '/docs/voice_effect_audio/echo.wav');
          expect(result.originalUrl, _songUrl);
          expect(result.originalMimeType, 'audio/mpeg');
        },
      );

      blocTest<VoiceEffectBloc, VoiceEffectState>(
        'switches a processed published sound back to its address and MIME '
        'type',
        build: () => build(_robotSong()),
        act: (bloc) async {
          bloc.add(
            const VoiceEffectSettingsChanged(
              effect: VoiceEffect.none,
              audition: false,
            ),
          );
          await pumpEventQueue();
          bloc.add(const VoiceEffectApplyRequested());
        },
        verify: (bloc) {
          final result = bloc.state.result!;
          expect(result.url, _songUrl);
          expect(result.mimeType, 'audio/mpeg');
          expect(result.originalUrl, isNull);
          expect(result.originalMimeType, isNull);
          expect(result.playsProcessedCopy, isFalse);
          expect(result.resolvedSource, _songSource);
        },
      );

      blocTest<VoiceEffectBloc, VoiceEffectState>(
        'keeps the pick and reports a failure when processing fails',
        setUp: () => when(
          () => service.process(
            source: any(named: 'source'),
            effect: any(named: 'effect'),
            noiseReduction: any(named: 'noiseReduction'),
          ),
        ).thenThrow(const VoiceEffectException('decode failed')),
        build: () => build(_recording()),
        act: (bloc) async {
          bloc.add(
            const VoiceEffectSettingsChanged(
              effect: VoiceEffect(echo: 80),
              audition: false,
            ),
          );
          await pumpEventQueue();
          bloc.add(const VoiceEffectApplyRequested());
        },
        verify: (bloc) {
          expect(bloc.state.status, VoiceEffectStatus.failure);
          expect(bloc.state.effect, const VoiceEffect(echo: 80));
          expect(bloc.state.result, isNull);
        },
        errors: () => [isA<VoiceEffectException>()],
      );

      test(
        'does not play an audition that finishes loading after Done',
        () async {
          stubAudition('/tmp/audition_1.wav');
          final loading = Completer<void>();
          final processing = Completer<ProcessedAudio>();
          when(() => player.setClip(any())).thenAnswer((_) => loading.future);
          when(
            () => service.process(
              source: _takeSource,
              effect: _robot,
              noiseReduction: false,
            ),
          ).thenAnswer((_) => processing.future);
          final bloc = build(_recording())
            ..add(const VoiceEffectSettingsChanged(effect: _robot));
          addTearDown(bloc.close);
          await pumpEventQueue();

          bloc.add(const VoiceEffectApplyRequested());
          await pumpEventQueue();
          expect(bloc.state.isApplying, isTrue);
          verify(() => player.stop()).called(1);
          loading.complete();
          await pumpEventQueue();

          verifyNever(() => player.play());
          verify(() => service.discardAudition('/tmp/audition_1.wav'))
              .called(1);
          processing.complete((path: _robotTake, mimeType: 'audio/wav'));
          await pumpEventQueue();
          expect(bloc.state.result?.url, _robotTake);
        },
      );

      test(
        'does not restart after Done overtakes a pending loop seek',
        () async {
          final seeking = Completer<void>();
          final processing = Completer<ProcessedAudio>();
          stubAudition('/tmp/audition_1.wav');
          when(() => player.seek(any())).thenAnswer((_) => seeking.future);
          when(
            () => service.process(
              source: any(named: 'source'),
              effect: any(named: 'effect'),
              noiseReduction: any(named: 'noiseReduction'),
            ),
          ).thenAnswer((_) => processing.future);
          final bloc = build(_recording())
            ..add(const VoiceEffectSettingsChanged(effect: _robot));
          addTearDown(bloc.close);
          await pumpEventQueue();
          completions.add(null);
          await pumpEventQueue();
          verify(() => player.seek(Duration.zero)).called(1);

          bloc.add(const VoiceEffectApplyRequested());
          await pumpEventQueue();
          expect(bloc.state.isApplying, isTrue);
          seeking.complete();
          await pumpEventQueue();

          verify(() => player.play()).called(1);
          processing.complete((path: _robotTake, mimeType: 'audio/wav'));
          await pumpEventQueue();
        },
      );

      blocTest<VoiceEffectBloc, VoiceEffectState>(
        'resumes the picked audition when saving fails',
        setUp: () {
          stubAudition('/tmp/audition_1.wav');
          when(
            () => service.process(
              source: any(named: 'source'),
              effect: any(named: 'effect'),
              noiseReduction: any(named: 'noiseReduction'),
            ),
          ).thenThrow(const VoiceEffectException('write failed'));
        },
        build: () => build(_recording()),
        act: (bloc) async {
          bloc.add(const VoiceEffectSettingsChanged(effect: _robot));
          await pumpEventQueue();
          bloc.add(const VoiceEffectApplyRequested());
        },
        verify: (bloc) {
          expect(bloc.state.status, VoiceEffectStatus.failure);
          expect(bloc.state.auditionPath, '/tmp/audition_1.wav');
          verify(() => player.play()).called(2);
        },
        errors: () => [isA<VoiceEffectException>()],
      );

      test('drops an audition that finishes rendering while Done stops the '
          'player', () async {
        final rendering = Completer<String>();
        final stopping = Completer<void>();
        when(
          () => service.renderAudition(
            source: any(named: 'source'),
            effect: any(named: 'effect'),
            noiseReduction: any(named: 'noiseReduction'),
            start: any(named: 'start'),
            length: any(named: 'length'),
          ),
        ).thenAnswer((_) => rendering.future);
        when(() => player.stop()).thenAnswer((_) => stopping.future);
        when(
          () => service.process(
            source: _takeSource,
            effect: _robot,
            noiseReduction: false,
          ),
        ).thenAnswer((_) async => (path: _robotTake, mimeType: 'audio/wav'));
        final bloc = build(_recording())
          ..add(const VoiceEffectSettingsChanged(effect: _robot));
        addTearDown(bloc.close);
        await pumpEventQueue();

        bloc.add(const VoiceEffectApplyRequested());
        await pumpEventQueue();
        rendering.complete('/tmp/audition_1.wav');
        await pumpEventQueue();
        stopping.complete();
        await pumpEventQueue();

        expect(bloc.state.status, VoiceEffectStatus.done);
        verifyNever(() => player.setClip(any()));
        verify(() => service.discardAudition('/tmp/audition_1.wav')).called(1);
      });
    });

    group('close', () {
      test(
        'does not play an audition that finishes loading after close',
        () async {
          stubAudition('/tmp/audition_1.wav');
          final loading = Completer<void>();
          when(() => player.setClip(any())).thenAnswer((_) => loading.future);
          final bloc = build(_recording())
            ..add(const VoiceEffectSettingsChanged(effect: _robot));
          await pumpEventQueue();

          await bloc.close();
          loading.complete();
          await pumpEventQueue();

          verifyNever(() => player.play());
          verify(() => service.discardAudition('/tmp/audition_1.wav'))
              .called(1);
        },
      );

      test('releases the player and every audition', () async {
        await build(_recording()).close();

        verify(() => player.dispose()).called(1);
        verify(() => service.clearAuditions()).called(1);
      });

      test(
        'drops an audition that finishes rendering as the sheet closes',
        () async {
          final rendering = Completer<String>();
          final disposing = Completer<void>();
          when(
            () => service.renderAudition(
              source: any(named: 'source'),
              effect: any(named: 'effect'),
              noiseReduction: any(named: 'noiseReduction'),
              start: any(named: 'start'),
              length: any(named: 'length'),
            ),
          ).thenAnswer((_) => rendering.future);
          when(() => player.dispose()).thenAnswer((_) => disposing.future);
          final bloc = build(_recording())
            ..add(const VoiceEffectSettingsChanged(effect: _robot));
          await pumpEventQueue();

          final closing = bloc.close();
          await pumpEventQueue();
          rendering.complete('/tmp/audition_1.wav');
          await pumpEventQueue();
          disposing.complete();
          await closing;

          verifyNever(() => player.setClip(any()));
          verify(() => service.discardAudition('/tmp/audition_1.wav'))
              .called(1);
        },
      );
    });
  });
}
