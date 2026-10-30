import 'package:divine_video_player/divine_video_player.dart';
import 'package:divine_video_player/src/linux/linux_video_player_backend.dart';
import 'package:divine_video_player/src/web/web_video_player_backend.dart';
import 'package:divine_video_player/src/web/web_video_player_backend_factory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DivineVideoPlayerController controller;

  setUp(() async {
    DivineVideoPlayerController.resetIdCounterForTesting();
    DivineVideoPlayerController.debugForceLinuxBackend = null;
    DivineVideoPlayerController.linuxBackendFactory = _FakeLinuxBackend.new;
    DivineVideoPlayerController.debugForceWebBackend = null;
    DivineVideoPlayerController.webBackendFactory = _FakeWebBackend.new;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('divine_video_player'),
          (call) async => null,
        );

    controller = DivineVideoPlayerController();
    await controller.initialize();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          MethodChannel('divine_video_player/player_${controller.playerId}'),
          (call) async => null,
        );
  });

  tearDown(() {
    DivineVideoPlayerController.debugForceLinuxBackend = null;
    DivineVideoPlayerController.linuxBackendFactory =
        MediaKitLinuxVideoPlayerBackend.new;
    DivineVideoPlayerController.debugForceWebBackend = null;
    DivineVideoPlayerController.webBackendFactory =
        createDefaultWebVideoPlayerBackend;
    _FakeLinuxBackend.instance = null;
    _FakeWebBackend.instance = null;
  });

  Future<DivineVideoPlayerController> initLinuxController({
    bool firstFrameRendered = false,
  }) async {
    DivineVideoPlayerController.debugForceLinuxBackend = true;
    final linuxController = DivineVideoPlayerController();
    await linuxController.initialize();
    _FakeLinuxBackend.instance!.emitState(
      DivineVideoPlayerState(
        status: PlaybackStatus.ready,
        clipCount: 1,
        isFirstFrameRendered: firstFrameRendered,
      ),
    );
    return linuxController;
  }

  Future<DivineVideoPlayerController> initWebController({
    bool firstFrameRendered = false,
  }) async {
    DivineVideoPlayerController.debugForceWebBackend = true;
    final webController = DivineVideoPlayerController();
    await webController.initialize();
    _FakeWebBackend.instance!.emitState(
      DivineVideoPlayerState(
        status: PlaybackStatus.ready,
        clipCount: 1,
        isFirstFrameRendered: firstFrameRendered,
      ),
    );
    return webController;
  }

  /// A texture-backed controller whose native side reports [state], through
  /// [events] when given so a test can report more states.
  Future<DivineVideoPlayerController> initTextureController(
    Map<Object?, Object?> state, {
    _StateStreamHandler? events,
  }) async {
    final nextId = DivineVideoPlayerController.nextId;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('divine_video_player'), (
          call,
        ) async {
          if (call.method != 'create') return null;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            ..setMockMethodCallHandler(
              MethodChannel('divine_video_player/player_$nextId'),
              (call) async => null,
            )
            ..setMockStreamHandler(
              EventChannel('divine_video_player/player_$nextId/events'),
              events ?? _StateStreamHandler(state),
            );
          return <Object?, Object?>{'textureId': 99};
        });
    final textureController = DivineVideoPlayerController(useTexture: true);
    await textureController.initialize();
    return textureController;
  }

  group(DivineVideoPlayer, () {
    testWidgets('renders Linux backend view on Linux', (tester) async {
      final linuxController = await initLinuxController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DivineVideoPlayer(controller: linuxController),
        ),
      );

      expect(find.text('Linux player view'), findsOneWidget);
    });

    testWidgets('renders Web backend view on web', (tester) async {
      final webController = await initWebController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DivineVideoPlayer(controller: webController),
        ),
      );

      expect(find.text('Web player view'), findsOneWidget);
    });

    testWidgets('renders Text for unsupported fuchsia', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DivineVideoPlayer(controller: controller),
        ),
      );

      expect(find.text('Platform not supported'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('renders Text for unsupported windows', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DivineVideoPlayer(controller: controller),
        ),
      );

      expect(find.text('Platform not supported'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
      'renders PlatformViewLink for Android',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: DivineVideoPlayer(controller: controller),
          ),
        );

        expect(find.byType(PlatformViewLink), findsOneWidget);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'renders UiKitView for iOS',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: DivineVideoPlayer(controller: controller),
          ),
        );

        expect(find.byType(UiKitView), findsOneWidget);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'renders AppKitView for macOS',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: DivineVideoPlayer(controller: controller),
          ),
        );

        expect(find.byType(AppKitView), findsOneWidget);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'renders Texture when useTexture is true and textureId is set',
      (tester) async {
        final nextId = DivineVideoPlayerController.nextId;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player'),
              (call) async {
                if (call.method == 'create') {
                  TestDefaultBinaryMessengerBinding
                      .instance
                      .defaultBinaryMessenger
                      .setMockMethodCallHandler(
                        MethodChannel('divine_video_player/player_$nextId'),
                        (call) async => null,
                      );

                  TestDefaultBinaryMessengerBinding
                      .instance
                      .defaultBinaryMessenger
                      .setMockStreamHandler(
                        EventChannel(
                          'divine_video_player/player_$nextId/events',
                        ),
                        _FirstFrameStreamHandler(),
                      );

                  return <Object?, Object?>{'textureId': 42};
                }
                return null;
              },
            );

        final textureController = DivineVideoPlayerController(
          useTexture: true,
        );
        await textureController.initialize();

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: DivineVideoPlayer(controller: textureController),
          ),
        );

        expect(find.byType(Texture), findsOneWidget);
        expect(find.byType(RotatedBox), findsNothing);
        expect(find.byType(ClipRect), findsNothing);
      },
    );

    testWidgets(
      'wraps Texture in RotatedBox when state.rotationDegrees is non-zero',
      (tester) async {
        final textureController = await initTextureController({
          ..._playingState,
          'videoWidth': 1080,
          'videoHeight': 1920,
          'rotationDegrees': 90,
        });

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: DivineVideoPlayer(controller: textureController),
          ),
        );
        // Allow the StreamBuilder to receive the initial event.
        await tester.pump();

        expect(find.byType(Texture), findsOneWidget);
        final rotatedBox = tester.widget<RotatedBox>(find.byType(RotatedBox));
        // 90 degrees / 90 = 1 quarter turn.
        expect(rotatedBox.quarterTurns, equals(1));
      },
    );

    group('texture crop', () {
      testWidgets('draws only the cropped part of a padded texture', (
        tester,
      ) async {
        final textureController = await initTextureController({
          ..._playingState,
          'videoWidth': 1080,
          'videoHeight': 1920,
          'textureCrop': [0.0, 0.0, 1080 / 1088, 1.0],
        });

        await tester.pumpWidget(
          Center(
            child: SizedBox(
              width: 108,
              height: 192,
              child: DivineVideoPlayer(controller: textureController),
            ),
          ),
        );
        await tester.pump();

        final box = tester.getRect(find.byType(DivineVideoPlayer));
        final texture = tester.getRect(find.byType(Texture));
        expect(texture.topLeft, equals(box.topLeft));
        expect(texture.size.width, moreOrLessEquals(108 * 1088 / 1080));
        expect(texture.size.height, equals(192));
        expect(
          find.ancestor(
            of: find.byType(Texture),
            matching: find.byType(ClipRect),
          ),
          findsOneWidget,
        );
      });

      testWidgets('follows the crop of the next clip', (tester) async {
        final first = {
          ..._playingState,
          'videoWidth': 1080,
          'videoHeight': 1920,
          'textureCrop': [0.0, 0.0, 1080 / 1088, 1.0],
        };
        final events = _StateStreamHandler(first);
        final textureController = await initTextureController(
          first,
          events: events,
        );
        await tester.pumpWidget(
          Center(
            child: SizedBox(
              width: 108,
              height: 192,
              child: DivineVideoPlayer(controller: textureController),
            ),
          ),
        );
        await tester.pump();
        expect(
          tester.getSize(find.byType(Texture)).width,
          moreOrLessEquals(108 * 1088 / 1080),
        );

        events.emit({
          ...first,
          'textureCrop': [0.0, 0.0, 1080 / 1152, 1.0],
        });
        await tester.pumpAndSettle();

        expect(
          tester.getSize(find.byType(Texture)).width,
          moreOrLessEquals(108 * 1152 / 1080),
        );
      });

      testWidgets('crops in the texture orientation, inside the rotation', (
        tester,
      ) async {
        final textureController = await initTextureController({
          ..._playingState,
          'videoWidth': 1080,
          'videoHeight': 1920,
          'rotationDegrees': 90,
          'textureCrop': [0.0, 4 / 1088, 1.0, 1084 / 1088],
        });

        await tester.pumpWidget(
          Center(
            child: SizedBox(
              width: 108,
              height: 192,
              child: DivineVideoPlayer(controller: textureController),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.descendant(
            of: find.byType(RotatedBox),
            matching: find.byType(ClipRect),
          ),
          findsOneWidget,
        );
        final texture = tester.renderObject<RenderBox>(find.byType(Texture));
        expect(texture.size.width, equals(192));
        expect(texture.size.height, moreOrLessEquals(108 * 1088 / 1080));
        final offset = (texture.parentData! as BoxParentData).offset;
        expect(offset.dx, equals(0));
        expect(offset.dy, moreOrLessEquals(-4 / 1080 * 108));
      });
    });

    testWidgets('does not render Stack when placeholder is null', (
      tester,
    ) async {
      final linuxController = await initLinuxController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DivineVideoPlayer(controller: linuxController),
        ),
      );

      expect(find.byType(Stack), findsNothing);
    });

    testWidgets('renders placeholder over surface before first frame', (
      tester,
    ) async {
      final linuxController = await initLinuxController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DivineVideoPlayer(
            controller: linuxController,
            placeholder: const Text('Loading...'),
          ),
        ),
      );

      // The placeholder is layered over the live surface (both present).
      expect(find.text('Linux player view'), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('hides placeholder after first frame rendered', (tester) async {
      final freshController = await initLinuxController(
        firstFrameRendered: true,
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DivineVideoPlayer(
            controller: freshController,
            placeholder: const Text('Loading...'),
          ),
        ),
      );

      // Allow the FutureBuilder to rebuild after the future completes.
      await tester.pump();

      expect(find.text('Loading...'), findsNothing);
    });

    testWidgets(
      'crossFadePlaceholder keeps placeholder when first frame already '
      'rendered, then fades it out',
      (tester) async {
        // First frame is already rendered at mount — the default would
        // hard-cut to surface, but crossFadePlaceholder keeps it for a fade.
        final freshController = await initLinuxController(
          firstFrameRendered: true,
        );

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: DivineVideoPlayer(
              controller: freshController,
              placeholder: const Text('Loading...'),
              crossFadePlaceholder: true,
            ),
          ),
        );

        // Placeholder is shown fully opaque despite the frame being ready.
        expect(find.text('Loading...'), findsOneWidget);
        expect(
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
          1.0,
        );

        // The already-complete future resolves and starts the fade-out.
        await tester.pump();
        expect(
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
          0.0,
        );

        // Once the fade completes the placeholder is removed from the tree.
        await tester.pumpAndSettle();
        expect(find.text('Loading...'), findsNothing);
      },
    );

    testWidgets(
      'fades placeholder out (starting fully opaque) and removes it once '
      'first frame arrives',
      (tester) async {
        final linuxController = await initLinuxController();

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: DivineVideoPlayer(
              controller: linuxController,
              placeholder: const Text('Loading...'),
            ),
          ),
        );

        // The placeholder starts FULLY opaque (not fading in), so it is
        // actually visible before the first frame swaps it out.
        expect(find.text('Loading...'), findsOneWidget);
        expect(
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
          1.0,
        );

        // First frame arrives after mount.
        _FakeLinuxBackend.instance!.emitState(
          const DivineVideoPlayerState(
            status: PlaybackStatus.ready,
            clipCount: 1,
            isFirstFrameRendered: true,
          ),
        );
        // First pump resolves the firstFrameRendered future (setState);
        // second pump rebuilds and starts the fade-out.
        await tester.pump();
        await tester.pump();

        // Fade started: target opacity is 0 but the placeholder is still
        // mounted (mid fade), not hard-cut away.
        expect(find.text('Loading...'), findsOneWidget);
        expect(
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
          0.0,
        );

        // Once the fade completes the placeholder is removed from the tree.
        await tester.pumpAndSettle();
        expect(find.text('Loading...'), findsNothing);
      },
    );

    testWidgets('skips placeholder fade when animations are disabled', (
      tester,
    ) async {
      final linuxController = await initLinuxController();

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: DivineVideoPlayer(
              controller: linuxController,
              placeholder: const Text('Loading...'),
            ),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
      expect(find.byType(AnimatedOpacity), findsOneWidget);

      _FakeLinuxBackend.instance!.emitState(
        const DivineVideoPlayerState(
          status: PlaybackStatus.ready,
          clipCount: 1,
          isFirstFrameRendered: true,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Loading...'), findsNothing);
      expect(find.byType(AnimatedOpacity), findsNothing);
    });

    testWidgets(
      'is a one-shot: does not re-show the placeholder after setClips '
      'reloads the same controller',
      (tester) async {
        final linuxController = await initLinuxController(
          firstFrameRendered: true,
        );

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: DivineVideoPlayer(
              controller: linuxController,
              placeholder: const Text('Loading...'),
              crossFadePlaceholder: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Loading...'), findsNothing);

        // Reloading clips on the SAME controller resets firstFrameRendered,
        // but the overlay must stay gone — re-showing the thumbnail on every
        // in-place clip swap (trim/reorder/speed) would flash stale content
        // over the editor preview.
        await linuxController.setClips(const [VideoClip(uri: '/next.mp4')]);
        _FakeLinuxBackend.instance!.emitState(
          const DivineVideoPlayerState(
            status: PlaybackStatus.ready,
            clipCount: 1,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Loading...'), findsNothing);
      },
    );

    testWidgets('restarts the fade when the controller instance changes', (
      tester,
    ) async {
      final firstController = await initLinuxController(
        firstFrameRendered: true,
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DivineVideoPlayer(
            controller: firstController,
            placeholder: const Text('Loading...'),
            crossFadePlaceholder: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Loading...'), findsNothing);

      // A genuinely different controller (e.g. account switch) that has not
      // rendered its first frame yet must bring the placeholder back.
      final secondController = await initLinuxController();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DivineVideoPlayer(
            controller: secondController,
            placeholder: const Text('Loading...'),
            crossFadePlaceholder: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Loading...'), findsOneWidget);
    });
  });
}

class _FakeLinuxBackend implements LinuxVideoPlayerBackend {
  _FakeLinuxBackend() {
    instance = this;
  }

  static _FakeLinuxBackend? instance;

  late void Function(DivineVideoPlayerState state) _onStateChanged;

  @override
  Future<void> initialize({
    required void Function(DivineVideoPlayerState state) onStateChanged,
    required void Function(Object error) onError,
  }) async {
    _onStateChanged = onStateChanged;
  }

  void emitState(DivineVideoPlayerState state) => _onStateChanged(state);

  @override
  Widget buildView() => const Text('Linux player view');

  @override
  Future<void> dispose() async {}

  @override
  Future<void> jumpToClip(int index) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> removeAllAudioTracks() async {}

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  Future<void> setAudioTrackVolume(int index, double volume) async {}

  @override
  Future<void> setAudioTracks(List<AudioTrack> tracks) async {}

  @override
  Future<void> setClips(
    List<VideoClip> clips, {
    Duration? startPosition,
  }) async {}

  @override
  Future<void> setLooping({required bool looping}) async {}

  @override
  Future<void> setPlaybackSpeed(double speed) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}
}

class _FakeWebBackend implements WebVideoPlayerBackend {
  _FakeWebBackend() {
    instance = this;
  }

  static _FakeWebBackend? instance;

  late void Function(DivineVideoPlayerState state) _onStateChanged;

  @override
  Future<void> initialize({
    required void Function(DivineVideoPlayerState state) onStateChanged,
    required void Function(Object error) onError,
  }) async {
    _onStateChanged = onStateChanged;
  }

  void emitState(DivineVideoPlayerState state) => _onStateChanged(state);

  @override
  Widget buildView() => const Text('Web player view');

  @override
  Future<void> dispose() async {}

  @override
  Future<void> jumpToClip(int index) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> removeAllAudioTracks() async {}

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  Future<void> setAudioTrackVolume(int index, double volume) async {}

  @override
  Future<void> setAudioTracks(List<AudioTrack> tracks) async {}

  @override
  Future<void> setClips(
    List<VideoClip> clips, {
    Duration? startPosition,
  }) async {}

  @override
  Future<void> setLooping({required bool looping}) async {}

  @override
  Future<void> setPlaybackSpeed(double speed) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}
}

class _FirstFrameStreamHandler extends MockStreamHandler {
  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    events.success(<Object?, Object?>{
      'status': 'playing',
      'positionMs': 0,
      'durationMs': 1000,
      'bufferedPositionMs': 500,
      'currentClipIndex': 0,
      'clipCount': 1,
      'isLooping': false,
      'volume': 1.0,
      'playbackSpeed': 1.0,
      'isFirstFrameRendered': true,
      'videoWidth': 1920,
      'videoHeight': 1080,
    });
  }

  @override
  void onCancel(Object? arguments) {}
}

const _playingState = <Object?, Object?>{
  'status': 'playing',
  'positionMs': 0,
  'durationMs': 1000,
  'bufferedPositionMs': 0,
  'currentClipIndex': 0,
  'clipCount': 1,
  'isLooping': false,
  'volume': 1.0,
  'playbackSpeed': 1.0,
  'isFirstFrameRendered': true,
};

class _StateStreamHandler extends MockStreamHandler {
  _StateStreamHandler(this.state);

  final Map<Object?, Object?> state;

  late MockStreamHandlerEventSink _events;

  /// Reports a further state from the native side.
  void emit(Map<Object?, Object?> next) => _events.success(next);

  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    _events = events;
    events.success(state);
  }

  @override
  void onCancel(Object? arguments) {}
}
