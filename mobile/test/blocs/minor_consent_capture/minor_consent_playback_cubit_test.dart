import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/minor_consent_capture/minor_consent_playback_cubit.dart';

void main() {
  group('MinorConsentPlaybackCubit', () {
    test(
      'requires the first rendered frame and cancels waiting when closed',
      () async {
        final cubit = MinorConsentPlaybackCubit();
        final frame = Completer<bool>();
        final loading = cubit.load(
          () async {},
          waitForFrame: () => frame.future,
        );
        await Future<void>.value();
        expect(cubit.state, MinorConsentPlaybackState.decoding);
        await cubit.close();
        await loading;
      },
    );

    test('an asynchronous decoder failure revokes readiness', () async {
      final errors = StreamController<bool>.broadcast();
      final cubit = MinorConsentPlaybackCubit();
      await cubit.load(() async {}, errors: () => errors.stream);
      expect(cubit.state, MinorConsentPlaybackState.ready);
      errors.add(true);
      await Future<void>.value();
      expect(cubit.state, MinorConsentPlaybackState.failure);
      await cubit.close();
      await errors.close();
    });

    test('a failed preview cannot be accepted and can be retried', () async {
      final cubit = MinorConsentPlaybackCubit();
      await cubit.load(() async => throw StateError('decoder unavailable'));
      expect(cubit.state, MinorConsentPlaybackState.failure);
      await cubit.load(() async {});
      expect(cubit.state, MinorConsentPlaybackState.ready);
      await cubit.close();
    });
  });
}
