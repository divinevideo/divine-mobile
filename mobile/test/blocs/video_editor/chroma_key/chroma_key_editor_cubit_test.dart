import 'dart:async';
import 'dart:ui';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/chroma_key/chroma_key_editor_cubit.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group(ChromaKeyEditorCubit, () {
    final video = EditorVideo.file('/a/clip.mp4');

    const measured = ChromaKeyDetection(
      color: Color(0xFF19A55B),
      similarity: 0.1,
      coverage: 0.8,
      spread: 0.02,
    );

    // `detectOnOpen` defaults to off here so each test drives the measurement
    // it is about; the on-open group turns it back on.
    ChromaKeyEditorCubit build({
      ClipChromaKey? initialChromaKey,
      ChromaKeyDetectFn? detect,
      bool detectOnOpen = false,
    }) {
      return ChromaKeyEditorCubit(
        video: video,
        initialChromaKey: initialChromaKey,
        detect: detect ?? (_) async => throw UnimplementedError(),
        detectOnOpen: detectOnOpen,
      );
    }

    test('starts from the green preset when the clip has no key', () {
      final cubit = build();
      addTearDown(cubit.close);

      expect(cubit.state.chromaKey.key, const ChromaKey.greenScreen());
      expect(
        cubit.state.backgroundType,
        ClipChromaKeyBackgroundType.transparent,
      );
    });

    test("starts from the clip's existing key", () {
      const existing = ClipChromaKey(
        key: ChromaKey(color: Color(0xFF0000FF), similarity: 0.42),
      );
      final cubit = build(initialChromaKey: existing);
      addTearDown(cubit.close);

      expect(cubit.state.chromaKey, existing);
    });

    group('detect on open', () {
      test('measures the screen with no user action', () async {
        final cubit = build(
          detect: (_) async => measured,
          detectOnOpen: true,
        );
        addTearDown(cubit.close);

        // The screen has to open on a cutout rather than an inert panel, so
        // the measurement starts with the cubit and not with a button tap.
        expect(cubit.state.isDetecting, isTrue);
        await pumpEventQueue();

        expect(cubit.state.chromaKey.key.color, const Color(0xFF19A55B));
        expect(cubit.state.chromaKey.key.similarity, 0.1);
        expect(cubit.state.detectionStatus, ChromaKeyDetectionStatus.idle);
      });

      test('reports a failure and leaves a usable key behind', () async {
        final cubit = build(
          detect: (_) async =>
              throw const ChromaKeyDetectionException('no screen'),
          detectOnOpen: true,
        );
        addTearDown(cubit.close);
        await pumpEventQueue();

        expect(cubit.state.detectionStatus, ChromaKeyDetectionStatus.failure);
        // Failing on open must not strand the user: the preset key the colour
        // swatch and the sliders act on is still there to adjust by hand.
        expect(cubit.state.chromaKey.key, const ChromaKey.greenScreen());
      });

      test('leaves a clip that already has a key alone', () async {
        var calls = 0;
        const existing = ClipChromaKey(
          key: ChromaKey(color: Color(0xFF0000FF), similarity: 0.42),
        );
        final cubit = build(
          initialChromaKey: existing,
          detect: (_) async {
            calls++;
            return measured;
          },
          detectOnOpen: true,
        );
        addTearDown(cubit.close);
        await pumpEventQueue();

        // Re-opening a keyed clip would otherwise overwrite the tuning the
        // user already settled on.
        expect(calls, isZero);
        expect(cubit.state.chromaKey, existing);
      });

      test(
        'the manual control re-measures after the open attempt failed',
        () async {
          var calls = 0;
          final cubit = build(
            detect: (_) async {
              calls++;
              if (calls == 1) {
                throw const ChromaKeyDetectionException('no screen');
              }
              return measured;
            },
            detectOnOpen: true,
          );
          addTearDown(cubit.close);
          await pumpEventQueue();
          expect(cubit.state.detectionStatus, ChromaKeyDetectionStatus.failure);

          // Re-running after moving the clip or changing the light is still the
          // user's call, so the on-open pass must not consume the one attempt.
          await cubit.detectFromFootage();

          expect(calls, 2);
          expect(cubit.state.chromaKey.key.color, const Color(0xFF19A55B));
          expect(cubit.state.detectionStatus, ChromaKeyDetectionStatus.idle);
        },
      );

      test('drops a measurement that lands after the screen closed', () async {
        final gate = Completer<ChromaKeyDetection>();
        final cubit = build(detect: (_) => gate.future, detectOnOpen: true);
        expect(cubit.state.isDetecting, isTrue);

        // The measurement is in flight while the user backs out; resuming into
        // a closed cubit would throw instead of being dropped.
        await cubit.close();
        gate.complete(measured);
        await pumpEventQueue();

        expect(
          cubit.state.detectionStatus,
          ChromaKeyDetectionStatus.detecting,
        );
        expect(cubit.state.chromaKey.key, const ChromaKey.greenScreen());
      });
    });

    group('detectFromFootage', () {
      blocTest<ChromaKeyEditorCubit, ChromaKeyEditorState>(
        'adopts the measured colour and similarity',
        build: () => build(
          detect: (_) async => const ChromaKeyDetection(
            color: Color(0xFF19A55B),
            similarity: 0.1,
            coverage: 0.8,
            spread: 0.02,
          ),
        ),
        act: (cubit) => cubit.detectFromFootage(),
        expect: () => [
          isA<ChromaKeyEditorState>().having(
            (s) => s.detectionStatus,
            'detectionStatus',
            ChromaKeyDetectionStatus.detecting,
          ),
          isA<ChromaKeyEditorState>()
              .having(
                (s) => s.chromaKey.key.color,
                'color',
                const Color(0xFF19A55B),
              )
              .having((s) => s.chromaKey.key.similarity, 'similarity', 0.1)
              .having(
                (s) => s.detectionStatus,
                'detectionStatus',
                ChromaKeyDetectionStatus.idle,
              ),
        ],
      );

      blocTest<ChromaKeyEditorCubit, ChromaKeyEditorState>(
        'leaves smoothness, spill and the background to the user',
        build: () => build(
          initialChromaKey: const ClipChromaKey(
            key: ChromaKey(
              smoothness: 0.2,
              spill: 0.9,
              backgroundColor: Color(0xFF112233),
            ),
          ),
          detect: (_) async => const ChromaKeyDetection(
            color: Color(0xFF19A55B),
            similarity: 0.1,
            coverage: 0.8,
            spread: 0.02,
          ),
        ),
        act: (cubit) => cubit.detectFromFootage(),
        verify: (cubit) {
          // A measurement knows nothing about how soft the edge should be or
          // what belongs behind the subject — overwriting those would throw
          // the user's work away every time they re-measure.
          expect(cubit.state.chromaKey.key.smoothness, 0.2);
          expect(cubit.state.chromaKey.key.spill, 0.9);
          expect(
            cubit.state.chromaKey.key.backgroundColor,
            const Color(0xFF112233),
          );
        },
      );

      blocTest<ChromaKeyEditorCubit, ChromaKeyEditorState>(
        'reports a failure without touching the key when no screen is found',
        build: () => build(
          detect: (_) async =>
              throw const ChromaKeyDetectionException('no screen'),
        ),
        act: (cubit) => cubit.detectFromFootage(),
        errors: () => [isA<ChromaKeyDetectionException>()],
        verify: (cubit) {
          expect(
            cubit.state.detectionStatus,
            ChromaKeyDetectionStatus.failure,
          );
          // The user can still set the key by hand, so the preset it started
          // from has to survive the failed measurement.
          expect(cubit.state.chromaKey.key, const ChromaKey.greenScreen());
        },
      );

      blocTest<ChromaKeyEditorCubit, ChromaKeyEditorState>(
        'keeps the backdrop clip across a measurement',
        build: () => build(
          initialChromaKey: const ClipChromaKey(
            key: ChromaKey.greenScreen(),
            backgroundVideoPath: '/a/backdrop.mp4',
          ),
          detect: (_) async => const ChromaKeyDetection(
            color: Color(0xFF19A55B),
            similarity: 0.1,
            coverage: 0.8,
            spread: 0.02,
          ),
        ),
        act: (cubit) => cubit.detectFromFootage(),
        verify: (cubit) => expect(
          cubit.state.chromaKey.backgroundVideoPath,
          '/a/backdrop.mp4',
        ),
      );

      blocTest<ChromaKeyEditorCubit, ChromaKeyEditorState>(
        'ignores a second request while one is in flight',
        build: () => build(
          detect: (_) async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return const ChromaKeyDetection(
              color: Color(0xFF19A55B),
              similarity: 0.1,
              coverage: 0.8,
              spread: 0.02,
            );
          },
        ),
        act: (cubit) async {
          final first = cubit.detectFromFootage();
          await cubit.detectFromFootage();
          await first;
        },
        // detecting, then the single result — a second `detecting` emission
        // would mean two decodes were kicked off for one tap.
        expect: () => [
          isA<ChromaKeyEditorState>().having(
            (s) => s.detectionStatus,
            'detectionStatus',
            ChromaKeyDetectionStatus.detecting,
          ),
          isA<ChromaKeyEditorState>().having(
            (s) => s.detectionStatus,
            'detectionStatus',
            ChromaKeyDetectionStatus.idle,
          ),
        ],
      );
    });

    group('background', () {
      test('switching to a colour clears an image', () {
        final cubit = build(
          initialChromaKey: ClipChromaKey(
            key: ChromaKey(backgroundImage: EditorLayerImage.file('/a.png')),
          ),
        );
        addTearDown(cubit.close);

        cubit.useColorBackground(const Color(0xFF445566));

        expect(cubit.state.backgroundType, ClipChromaKeyBackgroundType.color);
        expect(cubit.state.chromaKey.key.backgroundImage, isNull);
      });

      test('switching to a clip clears a colour fill', () {
        final cubit = build(
          initialChromaKey: const ClipChromaKey(
            key: ChromaKey(backgroundColor: Color(0xFF445566)),
          ),
        );
        addTearDown(cubit.close);

        cubit.useVideoBackground('/a/backdrop.mp4');

        expect(cubit.state.backgroundType, ClipChromaKeyBackgroundType.video);
        expect(cubit.state.chromaKey.key.backgroundColor, isNull);
      });

      test('switching to nothing clears every fill', () {
        final cubit = build(
          initialChromaKey: const ClipChromaKey(
            key: ChromaKey(backgroundColor: Color(0xFF445566)),
            backgroundVideoPath: '/a/backdrop.mp4',
          ),
        );
        addTearDown(cubit.close);

        cubit.useTransparentBackground();

        expect(
          cubit.state.backgroundType,
          ClipChromaKeyBackgroundType.transparent,
        );
        expect(cubit.state.chromaKey.backgroundVideoPath, isNull);
      });
    });

    group('tuning', () {
      test('the sliders and the colour keep a backdrop clip', () {
        final cubit = build(
          initialChromaKey: const ClipChromaKey(
            key: ChromaKey.greenScreen(),
            backgroundVideoPath: '/a/backdrop.mp4',
          ),
        );
        addTearDown(cubit.close);

        cubit
          ..setSimilarity(0.4)
          ..setSmoothness(0.3)
          ..setSpill(0.1)
          ..setKeyColor(const Color(0xFF00FF00));

        // The backdrop lives outside `ChromaKey`, so every tuning setter has to
        // carry it forward by hand. Rewriting one of them through `withKey`
        // would silently drop it and bake a black fill instead.
        expect(cubit.state.chromaKey.backgroundVideoPath, '/a/backdrop.mp4');
        expect(cubit.state.backgroundType, ClipChromaKeyBackgroundType.video);
        expect(cubit.state.chromaKey.key.similarity, 0.4);
        expect(cubit.state.chromaKey.key.smoothness, 0.3);
        expect(cubit.state.chromaKey.key.spill, 0.1);
        expect(cubit.state.chromaKey.key.color, const Color(0xFF00FF00));
      });
    });

    group('presets', () {
      test('blue keys tighter and despills more gently than green', () {
        final cubit = build();
        addTearDown(cubit.close);

        cubit.useBlueScreenPreset();
        final blue = cubit.state.chromaKey.key;
        cubit.useGreenScreenPreset();
        final green = cubit.state.chromaKey.key;

        // Denim, blue eyes and light blue shirts all crowd a blue screen, so
        // the blue preset has to be the more conservative of the two.
        expect(blue.similarity, lessThan(green.similarity));
        expect(blue.spill, lessThan(green.spill));
      });

      test('a preset keeps the chosen background', () {
        final cubit = build(
          initialChromaKey: const ClipChromaKey(
            key: ChromaKey(backgroundColor: Color(0xFF445566)),
          ),
        );
        addTearDown(cubit.close);

        cubit.useBlueScreenPreset();

        expect(
          cubit.state.chromaKey.key.backgroundColor,
          const Color(0xFF445566),
        );
      });

      test('a preset keeps a backdrop clip', () {
        final cubit = build(
          initialChromaKey: const ClipChromaKey(
            key: ChromaKey.greenScreen(),
            backgroundVideoPath: '/a/backdrop.mp4',
          ),
        );
        addTearDown(cubit.close);

        cubit.useBlueScreenPreset();

        expect(
          cubit.state.chromaKey.backgroundVideoPath,
          '/a/backdrop.mp4',
        );
      });
    });

    test('acknowledgeDetectionFailure clears the reported failure', () {
      final cubit = build(
        detect: (_) async =>
            throw const ChromaKeyDetectionException('no screen'),
      );
      addTearDown(cubit.close);

      return cubit.detectFromFootage().then((_) {
        expect(cubit.state.detectionStatus, ChromaKeyDetectionStatus.failure);
        cubit.acknowledgeDetectionFailure();
        expect(cubit.state.detectionStatus, ChromaKeyDetectionStatus.idle);
      });
    });
  });
}
