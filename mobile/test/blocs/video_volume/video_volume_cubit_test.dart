import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake [SystemVolumeListener] that exposes a [StreamController] so tests
/// can push system volume values and drive the real cubit path end-to-end.
class _FakeSystemVolumeListener implements SystemVolumeListener {
  final StreamController<double> controller = StreamController<double>();

  @override
  StreamSubscription<double> listen(void Function(double volume) onData) {
    return controller.stream.listen(onData);
  }

  @override
  void hideSystemUI() {
    // No-op in tests.
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoVolumeCubit, () {
    late SharedPreferences prefs;
    late _FakeSystemVolumeListener fakeVolumeListener;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      fakeVolumeListener = _FakeSystemVolumeListener();
    });

    VideoVolumeCubit buildCubit() => VideoVolumeCubit(
      sharedPreferences: prefs,
      systemVolumeListener: fakeVolumeListener,
    );

    group('initial state', () {
      test('defaults volume to 1.0', () {
        final cubit = buildCubit();
        addTearDown(cubit.close);

        expect(cubit.state.volume, equals(1.0));
        expect(cubit.state.isMuted, isFalse);
      });

      test('reads persisted volume from SharedPreferences', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'video_playback_volume': 0.0,
        });
        final prefsWithValue = await SharedPreferences.getInstance();

        final cubit = VideoVolumeCubit(
          sharedPreferences: prefsWithValue,
          systemVolumeListener: fakeVolumeListener,
        );
        addTearDown(cubit.close);

        expect(cubit.state.volume, equals(0.0));
        expect(cubit.state.isMuted, isTrue);
      });
    });

    group('onPlaybackVolumeChanged', () {
      blocTest<VideoVolumeCubit, VideoVolumeState>(
        'emits new volume',
        build: buildCubit,
        act: (cubit) => cubit.onPlaybackVolumeChanged(0),
        expect: () => const [VideoVolumeState(volume: 0)],
      );

      blocTest<VideoVolumeCubit, VideoVolumeState>(
        'does not emit when volume is unchanged',
        build: buildCubit,
        act: (cubit) => cubit.onPlaybackVolumeChanged(1),
        expect: () => const <VideoVolumeState>[],
      );

      test('persists volume to SharedPreferences', () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);

        cubit.onPlaybackVolumeChanged(0);

        // Allow the async _persist to complete.
        await pumpEventQueue();

        expect(prefs.getDouble('video_playback_volume'), equals(0.0));
      });
    });

    group('system volume bridge', () {
      blocTest<VideoVolumeCubit, VideoVolumeState>(
        'mutes when system volume drops to zero',
        build: buildCubit,
        act: (cubit) => fakeVolumeListener.controller.add(0),
        expect: () => const [VideoVolumeState(volume: 0)],
      );

      blocTest<VideoVolumeCubit, VideoVolumeState>(
        'unmutes when system volume rises above zero',
        build: buildCubit,
        seed: () => const VideoVolumeState(volume: 0),
        act: (cubit) => fakeVolumeListener.controller.add(0.5),
        expect: () => const [VideoVolumeState()],
      );

      blocTest<VideoVolumeCubit, VideoVolumeState>(
        'no-ops when system volume changes but state unchanged',
        build: buildCubit,
        act: (cubit) => fakeVolumeListener.controller.add(0.5),
        expect: () => const <VideoVolumeState>[],
      );

      blocTest<VideoVolumeCubit, VideoVolumeState>(
        'no-ops when already muted and system is zero',
        build: buildCubit,
        seed: () => const VideoVolumeState(volume: 0),
        act: (cubit) => fakeVolumeListener.controller.add(0),
        expect: () => const <VideoVolumeState>[],
      );

      test('persists when muting', () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);

        fakeVolumeListener.controller.add(0);
        await pumpEventQueue();

        expect(prefs.getDouble('video_playback_volume'), equals(0.0));
      });

      test('persists when unmuting', () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);

        cubit.onPlaybackVolumeChanged(0);
        await pumpEventQueue();

        fakeVolumeListener.controller.add(0.7);
        await pumpEventQueue();

        expect(prefs.getDouble('video_playback_volume'), equals(1.0));
      });
    });

    group('close', () {
      test('can be called without error', () async {
        final cubit = buildCubit();
        await expectLater(cubit.close(), completes);
      });
    });
  });
}
