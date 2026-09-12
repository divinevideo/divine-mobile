import 'dart:async';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:divine_video_player/src/linux/linux_video_player_backend.dart';
import 'package:divine_video_player/src/web/web_video_player_backend_factory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_logger/unified_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DivineVideoPlayerController controller;
  late List<MethodCall> globalCalls;
  late List<MethodCall> playerCalls;

  /// The event channel stream controller — push events here to simulate
  /// native player state updates.
  late StreamController<Map<Object?, Object?>> eventController;

  setUp(() {
    DivineVideoPlayerController.resetIdCounterForTesting();
    DivineVideoPlayerController.debugForceLinuxBackend = null;
    DivineVideoPlayerController.linuxBackendFactory =
        MediaKitLinuxVideoPlayerBackend.new;
    DivineVideoPlayerController.debugForceWebBackend = null;
    DivineVideoPlayerController.webBackendFactory =
        createDefaultWebVideoPlayerBackend;
    globalCalls = <MethodCall>[];
    playerCalls = <MethodCall>[];
    eventController = StreamController<Map<Object?, Object?>>.broadcast();
    controller = DivineVideoPlayerController();
  });

  tearDown(() async {
    DivineVideoPlayerController.debugForceLinuxBackend = null;
    DivineVideoPlayerController.linuxBackendFactory =
        MediaKitLinuxVideoPlayerBackend.new;
    DivineVideoPlayerController.debugForceWebBackend = null;
    DivineVideoPlayerController.webBackendFactory =
        createDefaultWebVideoPlayerBackend;
    await eventController.close();
  });

  /// The most recent log line emitted by the exclusive-playback rule.
  LogEntry? latestExclusivePauseLog() {
    final matches = LogCaptureService().getRecentLogs().where(
      (entry) => entry.message.contains('exclusive playback pausing'),
    );
    return matches.isEmpty ? null : matches.last;
  }

  /// The most recent log line emitted when pausing a sibling threw.
  LogEntry? latestSiblingPauseFailureLog() {
    final matches = LogCaptureService().getRecentLogs().where(
      (entry) => entry.message.contains('failed to pause sibling player'),
    );
    return matches.isEmpty ? null : matches.last;
  }

  /// Registers platform channel mocks and initializes the controller.
  ///
  /// The event channel mock is set up inside the 'create' handler so that
  /// it is in place before [initialize] subscribes to
  /// `receiveBroadcastStream()`.
  Future<void> initController() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('divine_video_player'),
          (call) async {
            globalCalls.add(call);
            if (call.method == 'create') {
              final id = (call.arguments as Map)['id'] as int;

              // Register per-player method channel mock.
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                  .setMockMethodCallHandler(
                    MethodChannel('divine_video_player/player_$id'),
                    (call) async {
                      playerCalls.add(call);
                      return null;
                    },
                  );

              // Register event channel mock BEFORE initialize() subscribes.
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                  .setMockStreamHandler(
                    EventChannel('divine_video_player/player_$id/events'),
                    _TestStreamHandler(eventController),
                  );
            }
            return null;
          },
        );

    await controller.initialize();
  }

  group(DivineVideoPlayerController, () {
    group('before initialize', () {
      test('isInitialized is false', () {
        expect(controller.isInitialized, isFalse);
      });

      test('nextId returns current counter value', () {
        expect(DivineVideoPlayerController.nextId, isA<int>());
      });

      test('viewType is correct', () {
        expect(controller.viewType, equals('divine_video_player_view'));
      });

      test('initial state is default', () {
        expect(controller.state.status, equals(PlaybackStatus.idle));
        expect(controller.state.position, equals(Duration.zero));
      });

      test('play throws StateError', () {
        expect(() => controller.play(), throwsStateError);
      });

      test('pause throws StateError', () {
        expect(() => controller.pause(), throwsStateError);
      });

      test('stop throws StateError', () {
        expect(() => controller.stop(), throwsStateError);
      });

      test('seekTo throws StateError', () {
        expect(
          () => controller.seekTo(Duration.zero),
          throwsStateError,
        );
      });

      test('setVolume throws StateError', () {
        expect(() => controller.setVolume(1), throwsStateError);
      });

      test('setPlaybackSpeed throws StateError', () {
        expect(
          () => controller.setPlaybackSpeed(1),
          throwsStateError,
        );
      });

      test('setLooping throws StateError', () {
        expect(
          () => controller.setLooping(looping: true),
          throwsStateError,
        );
      });

      test('jumpToClip throws StateError', () {
        expect(() => controller.jumpToClip(0), throwsStateError);
      });

      test('setClips throws StateError', () {
        expect(() => controller.setClips([]), throwsStateError);
      });

      test('setAudioTracks throws StateError', () {
        expect(
          () => controller.setAudioTracks([]),
          throwsStateError,
        );
      });

      test('removeAllAudioTracks throws StateError', () {
        expect(
          () => controller.removeAllAudioTracks(),
          throwsStateError,
        );
      });

      test('setAudioTrackVolume throws StateError', () {
        expect(
          () => controller.setAudioTrackVolume(0, 1),
          throwsStateError,
        );
      });
    });

    group('initialize', () {
      test('sets isInitialized to true', () async {
        await initController();

        expect(controller.isInitialized, isTrue);
      });

      test('exposes playerId after initialization', () async {
        await initController();

        expect(controller.playerId, equals(0));
      });

      test("invokes 'create' on global channel", () async {
        await initController();

        expect(globalCalls, hasLength(1));
        expect(globalCalls.first.method, equals('create'));
        expect(
          globalCalls.first.arguments,
          containsPair('id', isA<int>()),
        );
      });

      test('passes debugLabel through create', () async {
        controller = DivineVideoPlayerController(debugLabel: 'cover');

        await initController();

        // The native half builds its own log prefix from this, so its lines
        // name the same screen the Dart lines do.
        expect(
          globalCalls.first.arguments,
          containsPair('debugLabel', 'cover'),
        );
      });

      test(
        'passes default useLegacySurface false through create',
        () async {
          controller = DivineVideoPlayerController(useTexture: true);

          await initController();

          expect(globalCalls, hasLength(1));
          expect(
            globalCalls.first.arguments,
            containsPair('useLegacySurface', isFalse),
          );
        },
      );

      test(
        'passes explicit useLegacySurface true through create',
        () async {
          controller = DivineVideoPlayerController(
            useTexture: true,
            useLegacySurface: true,
          );

          await initController();

          expect(globalCalls, hasLength(1));
          expect(
            globalCalls.first.arguments,
            containsPair('useLegacySurface', isTrue),
          );
        },
      );

      test(
        'passes default bufferProfile full through create',
        () async {
          await initController();

          expect(globalCalls, hasLength(1));
          expect(
            globalCalls.first.arguments,
            containsPair('bufferProfile', VideoBufferProfile.full.wireValue),
          );
        },
      );

      test(
        'passes explicit bufferProfile feed through create',
        () async {
          controller = DivineVideoPlayerController(
            bufferProfile: VideoBufferProfile.feed,
          );

          await initController();

          expect(globalCalls, hasLength(1));
          expect(
            globalCalls.first.arguments,
            containsPair('bufferProfile', VideoBufferProfile.feed.wireValue),
          );
        },
      );

      test('throws StateError if called twice', () async {
        await initController();

        expect(() => controller.initialize(), throwsStateError);
      });

      test('stores textureId when useTexture is true', () async {
        controller = DivineVideoPlayerController(useTexture: true);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player'),
              (call) async {
                globalCalls.add(call);
                if (call.method == 'create') {
                  final id = (call.arguments as Map)['id'] as int;

                  TestDefaultBinaryMessengerBinding
                      .instance
                      .defaultBinaryMessenger
                      .setMockMethodCallHandler(
                        MethodChannel('divine_video_player/player_$id'),
                        (call) async {
                          playerCalls.add(call);
                          return null;
                        },
                      );

                  TestDefaultBinaryMessengerBinding
                      .instance
                      .defaultBinaryMessenger
                      .setMockStreamHandler(
                        EventChannel(
                          'divine_video_player/player_$id/events',
                        ),
                        _TestStreamHandler(eventController),
                      );

                  return <Object?, Object?>{'textureId': 42};
                }
                return null;
              },
            );

        await controller.initialize();

        expect(controller.textureId, equals(42));
      });

      test('buildLinuxView throws when Linux backend is unavailable', () async {
        await initController();

        expect(controller.buildLinuxView, throwsStateError);
      });

      test('uses the Linux backend when forced for testing', () async {
        final fakeLinuxBackend = _ControllerFakeLinuxBackend();
        DivineVideoPlayerController.debugForceLinuxBackend = true;
        DivineVideoPlayerController.linuxBackendFactory = () =>
            fakeLinuxBackend;

        await controller.initialize();

        expect(controller.usesLinuxBackend, isTrue);
        expect(fakeLinuxBackend.initializeCalls, 1);
      });
    });

    group('playback methods', () {
      setUp(() async {
        await initController();
      });

      test('play invokes native method', () async {
        await controller.play();

        expect(playerCalls.last.method, equals('play'));
      });

      test('play pauses other live controllers before starting', () async {
        final otherController = DivineVideoPlayerController();
        addTearDown(otherController.dispose);
        await otherController.initialize();

        playerCalls.clear();

        await otherController.play();

        expect(playerCalls, hasLength(2));
        expect(playerCalls.first.method, equals('pause'));
        expect(playerCalls.last.method, equals('play'));
      });

      test('play continues when pausing another controller fails', () async {
        final otherController = DivineVideoPlayerController();
        addTearDown(otherController.dispose);
        await otherController.initialize();

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              MethodChannel(
                'divine_video_player/player_${controller.playerId}',
              ),
              (call) async {
                playerCalls.add(call);
                if (call.method == 'pause') {
                  throw PlatformException(code: 'pause_failed');
                }
                return null;
              },
            );
        playerCalls.clear();

        await otherController.play();

        expect(playerCalls, hasLength(2));
        expect(playerCalls.first.method, equals('pause'));
        expect(playerCalls.last.method, equals('play'));
      });

      test('names both players when pausing a sibling fails', () async {
        final other = DivineVideoPlayerController(debugLabel: 'editor');
        addTearDown(other.dispose);
        await other.initialize();

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              MethodChannel(
                'divine_video_player/player_${controller.playerId}',
              ),
              (call) async {
                if (call.method == 'pause') {
                  throw PlatformException(code: 'pause_failed');
                }
                return null;
              },
            );

        await other.play();

        final entry = latestSiblingPauseFailureLog();
        expect(entry, isNotNull);
        // Both halves matter: who tried to pause, and which player refused.
        expect(entry!.message, contains('Player ${other.playerId} (editor)'));
        expect(entry.message, contains('Player ${controller.playerId}'));
      });

      test('play leaves others alone when not exclusive', () async {
        final backdrop = DivineVideoPlayerController(exclusivePlayback: false);
        addTearDown(backdrop.dispose);
        await backdrop.initialize();

        playerCalls.clear();

        await backdrop.play();

        expect(playerCalls.map((call) => call.method), equals(['play']));
      });

      test('play does not pause a non-exclusive controller', () async {
        final backdrop = DivineVideoPlayerController(exclusivePlayback: false);
        addTearDown(backdrop.dispose);
        await backdrop.initialize();

        playerCalls.clear();

        await controller.play();

        expect(playerCalls.map((call) => call.method), equals(['play']));
      });

      test('play names the siblings the exclusive rule paused', () async {
        final editor = DivineVideoPlayerController(debugLabel: 'cover');
        addTearDown(editor.dispose);
        await editor.initialize();

        await editor.play();

        final entry = latestExclusivePauseLog();
        expect(entry, isNotNull);
        // The victim is identified so a stopped player in a bug report can be
        // traced back to the screen that stopped it.
        expect(entry!.message, contains('Player ${controller.playerId}'));
        expect(
          entry.message,
          contains('Player ${editor.playerId} (cover)'),
        );
      });

      test('play logs no sibling pause when it is the only player', () async {
        await controller.dispose();
        final solo = DivineVideoPlayerController(debugLabel: 'solo');
        addTearDown(solo.dispose);
        await solo.initialize();
        await LogCaptureService().clearAllLogs();

        await solo.play();

        expect(latestExclusivePauseLog(), isNull);
      });

      test('pause invokes native method', () async {
        await controller.pause();

        expect(playerCalls.last.method, equals('pause'));
      });

      test('stop invokes native method', () async {
        await controller.stop();

        expect(playerCalls.last.method, equals('stop'));
      });

      test('seekTo sends position in milliseconds', () async {
        await controller.seekTo(const Duration(seconds: 10));

        expect(playerCalls.last.method, equals('seekTo'));
        expect(
          playerCalls.last.arguments,
          containsPair('positionMs', 10000),
        );
      });

      test('setVolume clamps and sends value', () async {
        await controller.setVolume(0.5);

        expect(playerCalls.last.method, equals('setVolume'));
        expect(
          playerCalls.last.arguments,
          containsPair('volume', 0.5),
        );
      });

      test('setVolume updates controller state immediately', () async {
        await controller.setVolume(0.5);

        expect(controller.state.volume, equals(0.5));
      });

      test('setVolume clamps below 0', () async {
        await controller.setVolume(-1);

        expect(
          playerCalls.last.arguments,
          containsPair('volume', 0.0),
        );
      });

      test('setVolume clamps above 1', () async {
        await controller.setVolume(2);

        expect(
          playerCalls.last.arguments,
          containsPair('volume', 1.0),
        );
      });

      test(
        'setVolume on Linux emits exactly one backend-driven update',
        () async {
          final fakeLinuxBackend = _ControllerFakeLinuxBackend();
          final states = <DivineVideoPlayerState>[];
          controller = DivineVideoPlayerController();
          DivineVideoPlayerController.debugForceLinuxBackend = true;
          DivineVideoPlayerController.linuxBackendFactory = () =>
              fakeLinuxBackend;

          await controller.initialize();
          controller.stateStream.listen(states.add);

          await controller.setVolume(0.5);

          expect(fakeLinuxBackend.lastVolume, 0.5);
          expect(controller.state.volume, 0.5);
          expect(states, hasLength(1));
          expect(states.single.volume, 0.5);
        },
      );

      test('setPlaybackSpeed sends speed', () async {
        await controller.setPlaybackSpeed(2);

        expect(playerCalls.last.method, equals('setPlaybackSpeed'));
        expect(
          playerCalls.last.arguments,
          containsPair('speed', 2.0),
        );
      });

      test('setLooping sends looping flag', () async {
        await controller.setLooping(looping: true);

        expect(playerCalls.last.method, equals('setLooping'));
        expect(
          playerCalls.last.arguments,
          containsPair('looping', true),
        );
      });

      test('jumpToClip sends index', () async {
        await controller.jumpToClip(2);

        expect(playerCalls.last.method, equals('jumpToClip'));
        expect(
          playerCalls.last.arguments,
          containsPair('index', 2),
        );
      });
    });

    group('setSource and setClips', () {
      setUp(() async {
        await initController();
      });

      test('setSource delegates to setClips', () async {
        const clip = VideoClip(uri: '/test.mp4');
        await controller.setSource(clip);

        expect(playerCalls.last.method, equals('setClips'));
        final clips =
            (playerCalls.last.arguments as Map)['clips'] as List<dynamic>;
        expect(clips, hasLength(1));
      });

      test('setClips sends serialized clips', () async {
        const clips = [
          VideoClip(
            uri: '/a.mp4',
            start: Duration(seconds: 1),
            end: Duration(seconds: 5),
          ),
          VideoClip(uri: '/b.mp4'),
        ];
        await controller.setClips(clips);

        expect(playerCalls.last.method, equals('setClips'));
        final sent =
            (playerCalls.last.arguments as Map)['clips'] as List<dynamic>;
        expect(sent, hasLength(2));
      });

      test('setClips rejects an empty clip list', () async {
        expect(
          () => controller.setClips(const []),
          throwsArgumentError,
        );
        expect(playerCalls, isEmpty);
      });

      test(
        'setClips includes startPositionMs when startPosition > zero',
        () async {
          const clips = [VideoClip(uri: '/a.mp4')];
          await controller.setClips(
            clips,
            startPosition: const Duration(seconds: 3),
          );

          final args = playerCalls.last.arguments as Map;
          expect(args['startPositionMs'], equals(3000));
        },
      );

      test('setClips resets firstFrameCompleter when completed', () async {
        // Complete the firstFrameCompleter by sending a state event.
        eventController.add({
          'status': 'playing',
          'isFirstFrameRendered': true,
          'positionMs': 0,
          'durationMs': 10000,
        });
        await Future<void>.delayed(Duration.zero);

        // The future should be completed.
        expect(controller.firstFrameRendered, completes);

        // Now setClips should reset it.
        await controller.setClips([const VideoClip(uri: '/c.mp4')]);

        // The new future should NOT be completed yet.
        var completed = false;
        unawaited(
          controller.firstFrameRendered.then((_) => completed = true),
        );
        await Future<void>.delayed(Duration.zero);
        expect(completed, isFalse);
      });

      test('setClips delegates to the Linux backend when active', () async {
        final fakeLinuxBackend = _ControllerFakeLinuxBackend();
        controller = DivineVideoPlayerController();
        DivineVideoPlayerController.debugForceLinuxBackend = true;
        DivineVideoPlayerController.linuxBackendFactory = () =>
            fakeLinuxBackend;

        await controller.initialize();
        await controller.setClips(
          const [VideoClip(uri: '/linux.mp4')],
          startPosition: const Duration(seconds: 4),
        );

        expect(fakeLinuxBackend.lastClips, hasLength(1));
        expect(
          fakeLinuxBackend.lastStartPosition,
          const Duration(seconds: 4),
        );
      });

      test(
        'setClips swallows PlatformException with code CANCELLED',
        () async {
          final id = controller.playerId;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
                MethodChannel('divine_video_player/player_$id'),
                (call) async {
                  if (call.method == 'setClips') {
                    throw PlatformException(code: 'CANCELLED');
                  }
                  return null;
                },
              );

          // Must not throw.
          await expectLater(
            controller.setClips(const [VideoClip(uri: '/a.mp4')]),
            completes,
          );
        },
      );

      test(
        'setClips rethrows PlatformException with non-CANCELLED code',
        () async {
          final id = controller.playerId;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
                MethodChannel('divine_video_player/player_$id'),
                (call) async {
                  if (call.method == 'setClips') {
                    throw PlatformException(code: 'ERROR');
                  }
                  return null;
                },
              );

          await expectLater(
            controller.setClips(const [VideoClip(uri: '/a.mp4')]),
            throwsA(isA<PlatformException>()),
          );
        },
      );
    });

    group('audio tracks', () {
      setUp(() async {
        await initController();
      });

      test('setAudioTracks sends serialized tracks', () async {
        const tracks = [
          AudioTrack(
            uri: '/audio.mp3',
            volume: 0.5,
            videoStartTime: Duration(seconds: 2),
          ),
        ];
        await controller.setAudioTracks(tracks);

        expect(playerCalls.last.method, equals('setAudioTracks'));
        final sent =
            (playerCalls.last.arguments as Map)['tracks'] as List<dynamic>;
        expect(sent, hasLength(1));
      });

      test('removeAllAudioTracks invokes native method', () async {
        await controller.removeAllAudioTracks();

        expect(
          playerCalls.last.method,
          equals('removeAllAudioTracks'),
        );
      });

      test('setAudioTrackVolume sends index and clamped volume', () async {
        await controller.setAudioTrackVolume(1, 0.7);

        expect(
          playerCalls.last.method,
          equals('setAudioTrackVolume'),
        );
        expect(
          playerCalls.last.arguments,
          containsPair('index', 1),
        );
        expect(
          playerCalls.last.arguments,
          containsPair('volume', 0.7),
        );
      });

      test('setAudioTrackVolume clamps below 0', () async {
        await controller.setAudioTrackVolume(0, -5);

        expect(
          playerCalls.last.arguments,
          containsPair('volume', 0.0),
        );
      });

      test('setAudioTrackVolume clamps above 1', () async {
        await controller.setAudioTrackVolume(0, 10);

        expect(
          playerCalls.last.arguments,
          containsPair('volume', 1.0),
        );
      });

      test(
        'setAudioTrackVolume delegates to the Linux backend when active',
        () async {
          final fakeLinuxBackend = _ControllerFakeLinuxBackend();
          controller = DivineVideoPlayerController();
          DivineVideoPlayerController.debugForceLinuxBackend = true;
          DivineVideoPlayerController.linuxBackendFactory = () =>
              fakeLinuxBackend;

          await controller.initialize();
          await controller.setAudioTrackVolume(2, 1.5);

          expect(fakeLinuxBackend.lastAudioTrackIndex, 2);
          expect(fakeLinuxBackend.lastAudioTrackVolume, 1.5);
        },
      );
    });

    group('event handling', () {
      setUp(() async {
        await initController();
      });

      test('updates state from event', () async {
        eventController.add({
          'status': 'playing',
          'positionMs': 5000,
          'durationMs': 30000,
          'bufferedPositionMs': 10000,
          'currentClipIndex': 1,
          'clipCount': 3,
          'isLooping': false,
          'volume': 0.8,
          'playbackSpeed': 1.5,
          'isFirstFrameRendered': true,
          'videoWidth': 1920,
          'videoHeight': 1080,
        });
        await Future<void>.delayed(Duration.zero);

        expect(controller.state.status, equals(PlaybackStatus.playing));
        expect(
          controller.state.position,
          equals(const Duration(seconds: 5)),
        );
        expect(
          controller.state.duration,
          equals(const Duration(seconds: 30)),
        );
        expect(controller.state.currentClipIndex, equals(1));
        expect(controller.state.videoWidth, equals(1920));
      });

      test('emits state on stateStream', () async {
        final states = <DivineVideoPlayerState>[];
        controller.stateStream.listen(states.add);

        eventController.add({'status': 'playing', 'positionMs': 1000});
        await Future<void>.delayed(Duration.zero);

        eventController.add({'status': 'paused', 'positionMs': 2000});
        await Future<void>.delayed(Duration.zero);

        expect(states, hasLength(2));
        expect(states[0].status, equals(PlaybackStatus.playing));
        expect(states[1].status, equals(PlaybackStatus.paused));
      });

      test('completes firstFrameRendered on first frame', () async {
        var completed = false;
        unawaited(
          controller.firstFrameRendered.then((_) => completed = true),
        );

        eventController.add({
          'status': 'playing',
          'isFirstFrameRendered': true,
        });
        await Future<void>.delayed(Duration.zero);

        expect(completed, isTrue);
      });

      test(
        'does not double-complete firstFrameRendered',
        () async {
          eventController.add({
            'status': 'playing',
            'isFirstFrameRendered': true,
          });
          await Future<void>.delayed(Duration.zero);

          // Second event should not throw.
          eventController.add({
            'status': 'playing',
            'isFirstFrameRendered': true,
          });
          await Future<void>.delayed(Duration.zero);

          expect(controller.firstFrameRendered, completes);
        },
      );

      test('ignores non-Map events', () async {
        eventController.add(<Object?, Object?>{});
        await Future<void>.delayed(Duration.zero);

        // State should still be parsable (fromMap handles empty map).
        expect(controller.state.status, equals(PlaybackStatus.idle));
      });
    });

    group('error handling', () {
      setUp(() async {
        await initController();
      });

      test('handles event error by setting error status', () async {
        final states = <DivineVideoPlayerState>[];
        controller.stateStream.listen(states.add);

        eventController.addError('Test error');
        await Future<void>.delayed(Duration.zero);

        expect(states, hasLength(1));
        expect(states.first.status, equals(PlaybackStatus.error));
      });

      test('logs native errorMessage via developer.log', () async {
        final states = <DivineVideoPlayerState>[];
        controller.stateStream.listen(states.add);

        eventController.add(<Object?, Object?>{
          'status': 'error',
          'positionMs': 0,
          'durationMs': 0,
          'bufferedPositionMs': 0,
          'currentClipIndex': 0,
          'clipCount': 0,
          'isLooping': false,
          'volume': 1.0,
          'playbackSpeed': 1.0,
          'isFirstFrameRendered': false,
          'videoWidth': 0,
          'videoHeight': 0,
          'errorMessage': 'AVPlayer failed: codec not supported',
        });
        await Future<void>.delayed(Duration.zero);

        expect(states, hasLength(1));
        expect(states.first.status, equals(PlaybackStatus.error));
      });
    });

    group('dispose', () {
      test("invokes 'dispose' on global channel", () async {
        await initController();
        await controller.dispose();

        expect(
          globalCalls.where((c) => c.method == 'dispose'),
          isNotEmpty,
        );
      });

      test('is idempotent', () async {
        await initController();
        await controller.dispose();
        await controller.dispose(); // Should not throw.

        // Only one 'dispose' call.
        expect(
          globalCalls.where((c) => c.method == 'dispose'),
          hasLength(1),
        );
      });

      test('methods throw StateError after dispose', () async {
        await initController();
        await controller.dispose();

        expect(() => controller.play(), throwsStateError);
        expect(() => controller.pause(), throwsStateError);
      });

      test('disposes the Linux backend when active', () async {
        final fakeLinuxBackend = _ControllerFakeLinuxBackend();
        DivineVideoPlayerController.debugForceLinuxBackend = true;
        DivineVideoPlayerController.linuxBackendFactory = () =>
            fakeLinuxBackend;

        await controller.initialize();
        await controller.dispose();

        expect(fakeLinuxBackend.disposeCalls, 1);
      });
    });

    group('liveControllerCount', () {
      test('is zero after resetIdCounterForTesting', () {
        expect(DivineVideoPlayerController.liveControllerCount, equals(0));
      });

      test('reflects live instances across initialize and dispose', () async {
        expect(DivineVideoPlayerController.liveControllerCount, equals(0));

        await initController();
        expect(DivineVideoPlayerController.liveControllerCount, equals(1));

        await controller.dispose();
        expect(DivineVideoPlayerController.liveControllerCount, equals(0));
      });
    });

    group('static methods', () {
      test('configureCache invokes global channel on Android', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(
          () => debugDefaultTargetPlatformOverride = null,
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player'),
              (call) async {
                globalCalls.add(call);
                return null;
              },
            );

        await DivineVideoPlayerController.configureCache(
          maxSizeBytes: 100 * 1024 * 1024,
        );

        expect(globalCalls, hasLength(1));
        expect(globalCalls.first.method, equals('configureCache'));
        expect(
          globalCalls.first.arguments,
          containsPair('maxSizeBytes', 100 * 1024 * 1024),
        );
      });

      test('configureCache uses default size', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(
          () => debugDefaultTargetPlatformOverride = null,
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player'),
              (call) async {
                globalCalls.add(call);
                return null;
              },
            );

        await DivineVideoPlayerController.configureCache();

        expect(
          globalCalls.first.arguments,
          containsPair('maxSizeBytes', kDefaultCacheMaxSizeBytes),
        );
      });

      test('preload invokes global channel with clips', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player'),
              (call) async {
                globalCalls.add(call);
                return null;
              },
            );

        await DivineVideoPlayerController.preload([
          const VideoClip.network('https://example.com/video.mp4'),
        ]);

        expect(globalCalls, hasLength(1));
        expect(globalCalls.first.method, equals('preload'));
        final clips =
            (globalCalls.first.arguments as Map)['clips'] as List<dynamic>;
        expect(clips, hasLength(1));
      });

      test('disposeAll invokes global channel', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player'),
              (call) async {
                globalCalls.add(call);
                return null;
              },
            );

        await DivineVideoPlayerController.disposeAll();

        expect(globalCalls, hasLength(1));
        expect(globalCalls.first.method, equals('disposeAll'));
      });

      test('disposeAll is a no-op on Linux', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        addTearDown(
          () => debugDefaultTargetPlatformOverride = null,
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player'),
              (call) async {
                globalCalls.add(call);
                return null;
              },
            );

        await DivineVideoPlayerController.disposeAll();

        expect(globalCalls, isEmpty);
      });

      test('configureCache is a no-op on Linux', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        addTearDown(
          () => debugDefaultTargetPlatformOverride = null,
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player'),
              (call) async {
                globalCalls.add(call);
                return null;
              },
            );

        await DivineVideoPlayerController.configureCache();

        expect(globalCalls, isEmpty);
      });

      // AVFoundation never reads URLCache, so the Apple plugin has no cache
      // to configure; an earlier build replaced URLCache.shared for nothing.
      test('configureCache is a no-op on iOS', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(
          () => debugDefaultTargetPlatformOverride = null,
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player'),
              (call) async {
                globalCalls.add(call);
                return null;
              },
            );

        await DivineVideoPlayerController.configureCache();

        expect(globalCalls, isEmpty);
      });

      test('configureCache is a no-op on macOS', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        addTearDown(
          () => debugDefaultTargetPlatformOverride = null,
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player'),
              (call) async {
                globalCalls.add(call);
                return null;
              },
            );

        await DivineVideoPlayerController.configureCache();

        expect(globalCalls, isEmpty);
      });
    });
  });
}

class _TestStreamHandler extends MockStreamHandler {
  _TestStreamHandler(this._controller);

  final StreamController<Map<Object?, Object?>> _controller;
  StreamSubscription<Map<Object?, Object?>>? _subscription;

  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    _subscription = _controller.stream.listen(
      events.success,
      onError: (Object error) => events.error(code: 'error', message: '$error'),
      onDone: events.endOfStream,
    );
  }

  @override
  void onCancel(Object? arguments) {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}

class _ControllerFakeLinuxBackend implements LinuxVideoPlayerBackend {
  int initializeCalls = 0;
  int disposeCalls = 0;
  List<VideoClip>? lastClips;
  Duration? lastStartPosition;
  int? lastAudioTrackIndex;
  double? lastAudioTrackVolume;
  double? lastVolume;
  late void Function(DivineVideoPlayerState state) _onStateChanged;

  @override
  Widget buildView() => const SizedBox.shrink();

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }

  @override
  Future<void> initialize({
    required void Function(DivineVideoPlayerState state) onStateChanged,
    required void Function(Object error) onError,
  }) async {
    initializeCalls++;
    _onStateChanged = onStateChanged;
  }

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
  Future<void> setAudioTrackVolume(int index, double volume) async {
    lastAudioTrackIndex = index;
    lastAudioTrackVolume = volume;
  }

  @override
  Future<void> setAudioTracks(List<AudioTrack> tracks) async {}

  @override
  Future<void> setClips(
    List<VideoClip> clips, {
    Duration? startPosition,
  }) async {
    lastClips = clips;
    lastStartPosition = startPosition;
  }

  @override
  Future<void> setLooping({required bool looping}) async {}

  @override
  Future<void> setPlaybackSpeed(double speed) async {}

  @override
  Future<void> setVolume(double volume) async {
    lastVolume = volume;
    _onStateChanged(
      DivineVideoPlayerState(
        status: PlaybackStatus.ready,
        volume: volume,
      ),
    );
  }

  @override
  Future<void> stop() async {}
}
