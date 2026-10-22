// ABOUTME: Unit tests for RecordVoiceOverRecorderService: start/stop/dispose
// ABOUTME: forwarding, system-pause filtering and amplitude normalization.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/video_editor/voice_over_recorder_service.dart';
import 'package:record/record.dart';

class _MockAudioRecorder extends Mock implements AudioRecorder {}

void main() {
  setUpAll(() {
    registerFallbackValue(const RecordConfig());
    registerFallbackValue(Duration.zero);
  });

  group(RecordVoiceOverRecorderService, () {
    late _MockAudioRecorder recorder;
    late RecordVoiceOverRecorderService service;

    setUp(() {
      recorder = _MockAudioRecorder();
      service = RecordVoiceOverRecorderService(recorder: recorder);
    });

    test('start forwards the path and a mono config to the recorder', () async {
      when(
        () => recorder.start(any(), path: any(named: 'path')),
      ).thenAnswer((_) async {});

      await service.start('/tmp/take.m4a');

      final captured = verify(
        () => recorder.start(captureAny(), path: '/tmp/take.m4a'),
      ).captured;
      final config = captured.single as RecordConfig;
      expect(config.numChannels, equals(1));
    });

    test('stop returns the recorder-written path', () async {
      when(() => recorder.stop()).thenAnswer((_) async => '/tmp/take.m4a');

      expect(await service.stop(), equals('/tmp/take.m4a'));
      verify(() => recorder.stop()).called(1);
    });

    test('dispose releases the recorder', () async {
      when(() => recorder.dispose()).thenAnswer((_) async {});

      await service.dispose();

      verify(() => recorder.dispose()).called(1);
    });

    test(
      'start translates a recorder failure into a typed exception',
      () async {
        final cause = StateError('mic busy');
        when(
          () => recorder.start(any(), path: any(named: 'path')),
        ).thenThrow(cause);

        await expectLater(
          service.start('/tmp/take.m4a'),
          throwsA(
            isA<VoiceOverRecorderException>().having(
              (e) => e.cause,
              'cause',
              same(cause),
            ),
          ),
        );
      },
    );

    test('stop translates a recorder failure into a typed exception', () async {
      when(() => recorder.stop()).thenThrow(StateError('not recording'));

      await expectLater(
        service.stop(),
        throwsA(isA<VoiceOverRecorderException>()),
      );
    });

    test(
      'dispose translates a recorder failure into a typed exception',
      () async {
        when(
          () => recorder.dispose(),
        ).thenThrow(StateError('already disposed'));

        await expectLater(
          service.dispose(),
          throwsA(isA<VoiceOverRecorderException>()),
        );
      },
    );

    group('systemPauses', () {
      // The recorder reports its own start and stop on the same stream, so
      // passing those through would end every take as it begins.
      test('emits only when the recorder is paused', () async {
        when(recorder.onStateChanged).thenAnswer(
          (_) => Stream.fromIterable(const [
            RecordState.record,
            RecordState.pause,
            RecordState.stop,
          ]),
        );

        expect(await service.systemPauses.toList(), hasLength(1));
      });
    });

    group('amplitudeStream normalization', () {
      Future<List<double>> normalize(List<double> dbValues) {
        when(() => recorder.onAmplitudeChanged(any())).thenAnswer(
          (_) => Stream<Amplitude>.fromIterable(
            dbValues.map((db) => Amplitude(current: db, max: 0)),
          ),
        );
        return service.amplitudeStream.toList();
      }

      test('maps 0 dBFS to the loudest level (1.0)', () async {
        expect(await normalize([0]), [closeTo(1, 0.0001)]);
      });

      test('maps the -45 dBFS floor to silence (0.0)', () async {
        expect(await normalize([-45]), [closeTo(0, 0.0001)]);
      });

      test('clamps levels below the floor to 0.0', () async {
        expect(await normalize([-60]), [closeTo(0, 0.0001)]);
      });

      test('clamps positive levels to 1.0', () async {
        expect(await normalize([5]), [closeTo(1, 0.0001)]);
      });

      test('maps the midpoint of the range to ~0.5', () async {
        expect(await normalize([-22.5]), [closeTo(0.5, 0.0001)]);
      });

      test('treats NaN as silence', () async {
        expect(await normalize([double.nan]), [closeTo(0, 0.0001)]);
      });

      test('treats infinite values as silence', () async {
        expect(
          await normalize([double.negativeInfinity]),
          [closeTo(0, 0.0001)],
        );
      });
    });
  });
}
