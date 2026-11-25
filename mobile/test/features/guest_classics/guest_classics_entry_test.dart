import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/guest_classics/guest_classics_entry.dart';
import 'package:openvine/features/guest_classics/guest_classics_manifest.dart';
import 'package:openvine/features/guest_classics/guest_classics_providers.dart';
import 'package:openvine/l10n/l10n.dart';

final _now = DateTime.utc(2026, 11, 25);

GuestClassicsManifest manifest(
  List<int> ids, {
  int validFor = 20,
  Set<int> tagged = const {},
}) => GuestClassicsManifest.parse({
  'schema_version': 1,
  'revision': 'qa1',
  'expires_at': _now.add(Duration(seconds: validFor)).toIso8601String(),
  'items': [
    for (final id in ids)
      {
        'event_id': id.toRadixString(16).padLeft(64, '0'),
        'sha256': (id + 100).toRadixString(16).padLeft(64, '0'),
        'attribution': 'Creator $id',
        'video_url': 'https://media.divine.video/$id.mp4',
        'original_loops': 1000 - id,
        if (tagged.contains(id)) 'discovery_tags': ['format:sketch'],
      },
  ],
}, now: _now)!;

class _NativePlayback {
  _NativePlayback(this.tester, {this.holdSource}) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    const global = MethodChannel('divine_video_player');
    _channels.add(global);
    messenger.setMockMethodCallHandler(global, (call) async {
      calls.add(call.method);
      if (call.method == 'create') {
        final id = call.arguments['id'];
        _events = 'divine_video_player/player_$id/events';
        for (final name in ['divine_video_player/player_$id', _events]) {
          final channel = MethodChannel(name);
          _channels.add(channel);
          messenger.setMockMethodCallHandler(channel, (method) async {
            calls.add(method.method);
            if (method.method == 'setClips' && holdSource != null) {
              await holdSource!.future;
            }
            if (method.method == 'setVolume') {
              volumes.add(method.arguments['volume'] as double);
            }
            return null;
          });
        }
        return {'textureId': 3};
      }
      return null;
    });
    addTearDown(() {
      for (final channel in _channels) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });
  }
  final WidgetTester tester;
  final Completer<void>? holdSource;
  TestDefaultBinaryMessenger get messenger =>
      tester.binding.defaultBinaryMessenger;
  final _channels = <MethodChannel>[];
  final calls = <String>[];
  final volumes = <double>[];
  late String _events;
  Future<void> firstFrame() => report({
    'isFirstFrameRendered': true,
    'videoWidth': 1280,
    'videoHeight': 720,
  });

  Future<void> report(Map<String, Object> state) async {
    await messenger.handlePlatformMessage(
      _events,
      const StandardMethodCodec().encodeSuccessEnvelope(state),
      (_) {},
    );
    await tester.pump();
    await tester.pump();
  }
}

Future<void> openGuest(
  WidgetTester tester,
  Future<GuestClassicsManifest?> Function(http.Client, {required bool muted})
  load, {
  ValueChanged<GuestClassicsObservation>? observe,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: GuestClassicsEntry(
        load: load,
        now: () => _now,
        onObservation: observe,
        welcome: (open) =>
            TextButton(onPressed: open, child: const Text('Welcome')),
      ),
    ),
  );
  await tester.pump();
  expect(find.byType(DivineVideoPlayer), findsNothing);
  expect(
    tester.widget<TextButton>(find.byType(TextButton)).onPressed,
    isNotNull,
  );
  await tester.tap(find.text('Welcome'));
  await tester.pump();
  await tester.pump();
}

void main() {
  group(GuestClassicsEntry, () {
    testWidgets(
      'explicit entry plays muted and reports the rendered frame and expires',
      (tester) async {
        final native = _NativePlayback(tester);
        final observed = <GuestClassicsObservation>[];
        var loads = 0;
        await openGuest(
          tester,
          (_, {required muted}) async =>
              ++loads == 1 ? manifest([1], validFor: 3) : null,
          observe: observed.add,
        );
        expect(native.volumes.last, 0);
        expect(native.calls, contains('play'));
        expect(observed, isEmpty);
        await native.firstFrame();
        expect(observed, [GuestClassicsObservation.firstFrame]);
        expect(
          tester.getSize(find.byType(DivineVideoPlayer)).aspectRatio,
          closeTo(16 / 9, .001),
        );
        await tester.pump(const Duration(seconds: 4));
        await tester.pump();
        expect(find.text('Creator 1'), findsNothing);
        expect(find.text('Welcome'), findsOneWidget);
      },
    );

    testWidgets(
      'a native frame while the surface is still preparing waits for presentation',
      (tester) async {
        final source = Completer<void>();
        final native = _NativePlayback(tester, holdSource: source);
        final observed = <GuestClassicsObservation>[];
        await openGuest(
          tester,
          (_, {required muted}) async => manifest([1]),
          observe: observed.add,
        );
        await native.firstFrame();
        expect(observed, isEmpty);
        expect(find.byType(DivineVideoPlayer), findsNothing);
        source.complete();
        await tester.pump();
        await tester.pump();
        expect(observed, [GuestClassicsObservation.firstFrame]);
        expect(find.byType(DivineVideoPlayer), findsOneWidget);
      },
    );

    testWidgets(
      'unmute checks audible candidates and mute silences before the request finishes',
      (tester) async {
        final native = _NativePlayback(tester);
        final pending = Completer<GuestClassicsManifest?>();
        var audible = 0;
        var mutedLoads = 0;
        await openGuest(tester, (_, {required muted}) async {
          if (muted) return ++mutedLoads == 1 ? manifest([1]) : pending.future;
          return ++audible == 1 ? null : manifest([2]);
        });
        await tester.tap(find.bySemanticsLabel('Unmute video'));
        await tester.pump();
        expect(native.volumes.last, 0);
        expect(find.text('Creator 1'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Unmute video'));
        await tester.pump();
        await tester.pump();
        expect(native.volumes.last, 1);
        expect(find.text('Creator 2'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Mute video'));
        await tester.pump();
        expect(native.volumes.last, 0);
        expect(find.text('Creator 2'), findsNothing);
        pending.complete(null);
        await tester.pump();
        expect(find.text('Welcome'), findsOneWidget);
      },
    );

    testWidgets(
      'swipe, close and reopen selects and plays the first unseen page',
      (tester) async {
        final native = _NativePlayback(tester);
        final observed = <GuestClassicsObservation>[];
        await openGuest(
          tester,
          (_, {required muted}) async => manifest([1, 2, 3]),
          observe: observed.add,
        );
        await native.firstFrame();
        await tester.drag(find.byType(PageView), const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(find.text('Creator 2'), findsOneWidget);
        await native.firstFrame();
        expect(observed, [
          GuestClassicsObservation.firstFrame,
          GuestClassicsObservation.swipe,
          GuestClassicsObservation.firstFrame,
        ]);
        await tester.tap(find.bySemanticsLabel('Close'));
        await tester.pump();
        await tester.tap(find.text('Welcome'));
        await tester.pump();
        await tester.pump();
        expect(
          find.text('Creator 3'),
          findsOneWidget,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data)
              .join('/'),
        );
        await native.firstFrame();
        expect(find.byType(DivineVideoPlayer), findsOneWidget);
        expect(observed, [
          GuestClassicsObservation.firstFrame,
          GuestClassicsObservation.swipe,
          GuestClassicsObservation.firstFrame,
          GuestClassicsObservation.firstFrame,
        ]);
      },
    );

    testWidgets(
      'loads the manifest on cold start when lifecycleState is null',
      (
        tester,
      ) async {
        tester.binding.resetInternalState();
        addTearDown(tester.binding.resetInternalState);
        var loads = 0;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: GuestClassicsEntry(
              load: (_, {required muted}) async {
                loads++;
                return manifest([1]);
              },
              now: () => _now,
              welcome: (open) =>
                  TextButton(onPressed: open, child: const Text('Welcome')),
            ),
          ),
        );
        await tester.pump();
        expect(loads, 1);
        expect(find.byType(DivineVideoPlayer), findsNothing);
        expect(
          tester.widget<TextButton>(find.byType(TextButton)).onPressed,
          isNotNull,
        );
      },
    );

    testWidgets(
      'skips initial manifest load when mounted outside foreground',
      (tester) async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        addTearDown(tester.binding.resetInternalState);
        var loads = 0;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: GuestClassicsEntry(
              load: (_, {required muted}) async {
                loads++;
                return manifest([1]);
              },
              now: () => _now,
              welcome: (open) =>
                  TextButton(onPressed: open, child: const Text('Welcome')),
            ),
          ),
        );
        await tester.pump();
        expect(loads, 0);
        expect(
          tester.widget<TextButton>(find.byType(TextButton)).onPressed,
          isNull,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(loads, 1);
        expect(
          tester.widget<TextButton>(find.byType(TextButton)).onPressed,
          isNotNull,
        );
      },
    );

    testWidgets(
      'backgrounding while unmuted silences and resets to muted welcome on resume',
      (tester) async {
        final native = _NativePlayback(tester);
        addTearDown(tester.binding.resetInternalState);
        final requestedMuted = <bool>[];
        await openGuest(tester, (_, {required muted}) async {
          requestedMuted.add(muted);
          return muted ? manifest([1]) : manifest([2]);
        });
        await tester.tap(find.bySemanticsLabel('Unmute video'));
        await tester.pump();
        await tester.pump();
        expect(find.text('Creator 2'), findsOneWidget);
        expect(native.volumes.last, 1);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        expect(native.volumes.last, 0);
        expect(find.text('Creator 2'), findsNothing);
        expect(find.text('Welcome'), findsOneWidget);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(requestedMuted.last, isTrue);
        expect(find.byType(DivineVideoPlayer), findsNothing);
        expect(find.text('Welcome'), findsOneWidget);
        expect(
          tester.widget<TextButton>(find.byType(TextButton)).onPressed,
          isNotNull,
        );
      },
    );

    testWidgets(
      'all clips failing resets viewing so later resume stays on welcome',
      (tester) async {
        _NativePlayback(tester);
        addTearDown(tester.binding.resetInternalState);
        var loads = 0;
        await openGuest(
          tester,
          (_, {required muted}) async =>
              ++loads == 1 ? manifest([1]) : manifest([2]),
        );
        await tester.pump(const Duration(seconds: 7));
        await tester.pump();
        expect(find.text('Welcome'), findsOneWidget);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(find.byType(DivineVideoPlayer), findsNothing);
        expect(
          tester.widget<TextButton>(find.byType(TextButton)).onPressed,
          isNotNull,
        );
      },
    );

    testWidgets(
      'failed retiring refresh clears viewing state before later resume',
      (tester) async {
        final native = _NativePlayback(tester);
        addTearDown(tester.binding.resetInternalState);
        var loads = 0;
        await openGuest(tester, (_, {required muted}) async {
          loads++;
          if (loads == 1) return manifest([1], validFor: 3);
          if (loads == 2) return null;
          return manifest([2]);
        });
        await native.firstFrame();
        await tester.pump(const Duration(seconds: 4));
        await tester.pump();
        expect(find.text('Welcome'), findsOneWidget);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(find.byType(DivineVideoPlayer), findsNothing);
        expect(
          tester.widget<TextButton>(find.byType(TextButton)).onPressed,
          isNotNull,
        );
      },
    );

    testWidgets('system back closes the player back to welcome', (
      tester,
    ) async {
      final native = _NativePlayback(tester);
      addTearDown(tester.binding.resetInternalState);
      await openGuest(
        tester,
        (_, {required muted}) async => manifest([1]),
      );
      expect(find.text('Creator 1'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(native.volumes.last, 0);
      expect(find.text('Creator 1'), findsNothing);
      expect(find.text('Welcome'), findsOneWidget);
      expect(find.byType(DivineVideoPlayer), findsNothing);
    });

    testWidgets(
      'muting preserves an admitted seen clip without flashing welcome',
      (tester) async {
        final native = _NativePlayback(tester);
        addTearDown(tester.binding.resetInternalState);
        final pendingMute = Completer<GuestClassicsManifest?>();
        var mutedLoads = 0;
        await openGuest(tester, (_, {required muted}) async {
          if (muted) {
            return ++mutedLoads == 1 ? manifest([1]) : pendingMute.future;
          }
          return manifest([1]);
        });
        await native.firstFrame();
        await tester.tap(find.bySemanticsLabel('Unmute video'));
        await tester.pump();
        await tester.pump();
        expect(find.text('Creator 1'), findsOneWidget);
        expect(native.volumes.last, 1);

        await tester.tap(find.bySemanticsLabel('Mute video'));
        await tester.pump();
        expect(native.volumes.last, 0);
        expect(find.text('Creator 1'), findsNothing);
        expect(find.text('Welcome'), findsNothing);
        expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);

        pendingMute.complete(manifest([1]));
        await tester.pump();
        await tester.pump();
        expect(find.text('Creator 1'), findsOneWidget);
        expect(native.volumes.last, 0);
      },
    );

    testWidgets(
      'inactive pauses and resumes without retiring while backgrounding retires',
      (tester) async {
        final native = _NativePlayback(tester);
        addTearDown(tester.binding.resetInternalState);
        var loads = 0;
        await openGuest(tester, (_, {required muted}) async {
          loads++;
          return manifest([1, 2]);
        });
        await native.firstFrame();
        expect(loads, 1);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        expect(native.calls.last, 'pause');
        expect(find.text('Creator 1'), findsOneWidget);
        expect(find.text('Welcome'), findsNothing);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(native.calls.last, 'play');
        expect(loads, 1);
        expect(find.text('Creator 1'), findsOneWidget);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(loads, 2);
        expect(find.text('Welcome'), findsOneWidget);
        expect(find.byType(DivineVideoPlayer), findsNothing);
      },
    );

    for (final (name, firstPlay, secondPlay, expected) in [
      ('two completions', 5800, 5800, 6),
      ('one completion and one early swipe', 5800, 700, 4),
    ]) {
      testWidgets('$name rerank only the unprepared tail', (tester) async {
        final native = _NativePlayback(tester);
        await openGuest(
          tester,
          (_, {required muted}) async =>
              manifest([1, 2, 3, 4, 5, 6], tagged: {1, 2, 6}),
        );
        Future<void> swipe({bool back = false}) async {
          await tester.drag(
            find.byType(PageView),
            Offset(0, back ? 500 : -500),
          );
          await tester.pumpAndSettle();
        }

        Future<void> watch(int position) async {
          await native.firstFrame();
          await native.report({
            'status': 'playing',
            'isPictureAdvancing': true,
            'isFirstFrameRendered': true,
            'positionMs': position,
            'durationMs': 6000,
          });
        }

        expect(find.text('Creator 1'), findsOneWidget);
        await watch(firstPlay);
        await swipe();
        expect(find.text('Creator 2'), findsOneWidget);
        await watch(secondPlay);
        await swipe(back: true);
        expect(find.text('Creator 1'), findsOneWidget);
        await swipe();
        expect(find.text('Creator 2'), findsOneWidget);
        await swipe();
        expect(find.text('Creator 3'), findsOneWidget);
        await native.firstFrame();
        await swipe();
        expect(find.text('Creator $expected'), findsOneWidget);
      });
    }
  });
}
