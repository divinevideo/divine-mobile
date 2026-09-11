import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/comments/widgets/video_comment_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  // Records the native method invocations the widget drives through
  // divine_video_player, so tests can assert the migrated controller wiring
  // (create/play/pause/dispose) without a real native player.
  final methodCalls = <String>[];
  final createArguments = <Map<Object?, Object?>>[];
  final setClipsArguments = <Map<Object?, Object?>>[];

  // Per-created-player event streams keyed by native player id. Emitting to a
  // stream drives that controller's stateStream, letting tests simulate a
  // "playing" state without a real native player.
  late Map<int, StreamController<Map<Object?, Object?>>> playerEvents;
  final installedMethodChannels = <String>{};
  final installedEventChannels = <String>{};

  // When true, the mocked native `play` call throws, exercising the widget's
  // start-playback error path.
  var failNextPlay = false;

  void installPlayerChannels(int id) {
    final methodChannel = 'divine_video_player/player_$id';
    final eventChannel = 'divine_video_player/player_$id/events';
    installedMethodChannels.add(methodChannel);
    installedEventChannels.add(eventChannel);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(methodChannel), (call) async {
          methodCalls.add(call.method);
          if (call.method == 'setClips') {
            setClipsArguments.add(
              call.arguments! as Map<Object?, Object?>,
            );
          }
          if (call.method == 'play' && failNextPlay) {
            throw PlatformException(code: 'PLAY_FAILED');
          }
          return null;
        });

    final events = StreamController<Map<Object?, Object?>>.broadcast();
    playerEvents[id] = events;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          EventChannel(eventChannel),
          MockStreamHandler.inline(
            onListen: (arguments, sink) {
              events.stream.listen(sink.success, onDone: sink.endOfStream);
            },
          ),
        );
  }

  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    methodCalls.clear();
    createArguments.clear();
    setClipsArguments.clear();
    playerEvents = {};
    installedMethodChannels.clear();
    installedEventChannels.clear();
    failNextPlay = false;
    DivineVideoPlayerController.resetIdCounterForTesting();

    // The global channel dynamically mocks each per-player channel on `create`,
    // so tests that create more than one controller (e.g. retry after a failed
    // play) still route to a live handler.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('divine_video_player'), (
          call,
        ) async {
          methodCalls.add(call.method);
          if (call.method == 'create') {
            final arguments = call.arguments! as Map<Object?, Object?>;
            createArguments.add(arguments);
            installPlayerChannels(arguments['id']! as int);
            return <String, Object?>{'textureId': 1};
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('divine_video_player'),
          null,
        );
    for (final channel in installedMethodChannels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), null);
    }
    for (final channel in installedEventChannels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(EventChannel(channel), null);
    }
    for (final events in playerEvents.values) {
      unawaited(events.close());
    }
    // Restore the foreground lifecycle so a test that backgrounds the app
    // doesn't leak a paused state into the next test's playback guard.
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });

  Widget buildPlayer({VoidCallback? onOpenVideo}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: VideoCommentPlayer(
          videoUrl: 'https://media.divine.video/comment-video.mp4',
          onOpenVideo: onOpenVideo,
        ),
      ),
    );
  }

  // Flushes the async initialize→setSource→…→play chain that runs over the
  // mocked platform channels after a tap.
  Future<void> startPlayback(WidgetTester tester) async {
    await tester.tap(find.byType(VideoCommentPlayer));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('renders', () {
    testWidgets('clips to the provided border radius', (tester) async {
      const borderRadius = BorderRadius.all(Radius.circular(12));

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoCommentPlayer(
              videoUrl: 'https://media.divine.video/comment-video.mp4',
              borderRadius: borderRadius,
            ),
          ),
        ),
      );

      final clip = tester.widget<ClipRRect>(
        find.ancestor(
          of: find.byType(VisibilityDetector),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, borderRadius);
    });

    testWidgets('opens the full video page from the inline comment player', (
      tester,
    ) async {
      var opened = false;

      await tester.pumpWidget(buildPlayer(onOpenVideo: () => opened = true));

      expect(find.byType(VideoCommentPlayer), findsOneWidget);
      await tester.tap(find.byType(DivineIconButton));
      await tester.pump();

      expect(opened, isTrue);
    });

    testWidgets('renders a $DivineVideoPlayer surface', (tester) async {
      await tester.pumpWidget(buildPlayer());

      expect(find.byType(DivineVideoPlayer), findsOneWidget);
    });
  });

  group('playback lifecycle', () {
    testWidgets('creates and plays a Divine controller when tapped', (
      tester,
    ) async {
      await tester.pumpWidget(buildPlayer());
      await startPlayback(tester);

      expect(
        methodCalls,
        containsAll(<String>['create', 'setClips', 'setLooping', 'play']),
      );
      final clips = setClipsArguments.single['clips']! as List<Object?>;
      final clip = clips.single! as Map<Object?, Object?>;
      expect(clip['trimToCommonTrackEnd'], isTrue);
      // On Android only a full-profile player reads a remote clip's track
      // lengths before the load; a feed-profile player warms them behind it
      // and the play just started would keep its loop seam (#8897).
      expect(createArguments.single['bufferProfile'], 'full');
    });

    testWidgets('disposes the native controller when unmounted', (
      tester,
    ) async {
      await tester.pumpWidget(buildPlayer());
      await startPlayback(tester);
      expect(DivineVideoPlayerController.liveControllerCount, 1);

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(),
        ),
      );
      await tester.pump();

      // dispose() drops the controller from the live registry synchronously.
      expect(DivineVideoPlayerController.liveControllerCount, 0);
    });

    testWidgets('pauses playback when the app is backgrounded', (tester) async {
      await tester.pumpWidget(buildPlayer());
      await startPlayback(tester);

      methodCalls.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(methodCalls, contains('pause'));
    });

    testWidgets('recovers from a failed play() and starts a fresh controller', (
      tester,
    ) async {
      await tester.pumpWidget(buildPlayer());

      failNextPlay = true;
      await startPlayback(tester);

      // The failed controller is torn down (dropped from the live registry) and
      // its references cleared, so no controller lingers.
      expect(DivineVideoPlayerController.liveControllerCount, 0);

      // A second tap must build a brand-new controller instead of calling into
      // the disposed one (which would throw StateError from the package guard).
      failNextPlay = false;
      final createsBefore = methodCalls.where((m) => m == 'create').length;
      await startPlayback(tester);

      expect(tester.takeException(), isNull);
      expect(methodCalls.where((m) => m == 'create').length, createsBefore + 1);
      expect(DivineVideoPlayerController.liveControllerCount, 1);
    });

    testWidgets(
      'unmounting while playing never touches the disposed controller',
      (tester) async {
        await tester.pumpWidget(buildPlayer());
        await startPlayback(tester);

        // Drive the controller into a playing state so the visibility/lifecycle
        // pause guards would act on it if the widget still held a reference.
        playerEvents[0]!.add(<Object?, Object?>{'status': 'playing'});
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Unmount, then pump extra frames so any deferred VisibilityDetector
        // callback (delivered after the render object is disposed) fires.
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SizedBox(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(tester.takeException(), isNull);
        expect(DivineVideoPlayerController.liveControllerCount, 0);
      },
    );

    testWidgets('aborts playback when the app is not in the foreground', (
      tester,
    ) async {
      await tester.pumpWidget(buildPlayer());

      // Backgrounding does not unmount an inline comment player, and the play()
      // decision happens only after the initialize()/setSource() awaits. The
      // widget must abort instead of starting playback in the background.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await startPlayback(tester);

      expect(methodCalls, isNot(contains('play')));
      expect(DivineVideoPlayerController.liveControllerCount, 0);
    });

    testWidgets('pauses when scrolled offscreen after playback starts', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListView(
              children: const [
                SizedBox(
                  height: 400,
                  child: VideoCommentPlayer(
                    videoUrl: 'https://media.divine.video/comment-video.mp4',
                  ),
                ),
                SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      );

      // Start playback. No 'playing' event is emitted, so controller.state
      // .isPlaying stays false and only the optimistic _isPlaying flag is set.
      await tester.tap(find.byType(VideoCommentPlayer));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      methodCalls.clear();
      // Scroll the 400px player mostly offscreen (~12% visible, below the 0.35
      // threshold) while keeping it mounted (a full scroll past the ListView
      // cacheExtent would dispose it instead). The pause must still fire even
      // though state.isPlaying never flipped.
      await tester.drag(find.byType(Scrollable), const Offset(0, -350));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(methodCalls, contains('pause'));
    });
  });
}
